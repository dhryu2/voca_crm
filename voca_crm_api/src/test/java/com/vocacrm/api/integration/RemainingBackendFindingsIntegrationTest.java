package com.vocacrm.api.integration;

import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.service.MemberService;
import com.vocacrm.api.service.NoticeService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * [회귀] 화이트박스 나머지 발견(WB-07~10, 14) 실DB/HTTP 검증.
 */
class RemainingBackendFindingsIntegrationTest extends AbstractIntegrationTest {

    @Autowired private MemberRepository memberRepository;
    @Autowired private MemberService memberService;
    @Autowired private NoticeService noticeService;

    private TestDataSeeder seed;

    @BeforeEach
    void setUp() {
        seed = new TestDataSeeder(jdbcTemplate);
    }

    // ===== WB-08: 회원 한도 카운트가 삭제 대기 회원을 제외 =====
    @Test
    @Transactional // countByBusinessPlaceIdWithLock 은 PESSIMISTIC_WRITE 라 트랜잭션 필요
    void 회원한도_카운트는_삭제대기_회원을_제외한다() {
        String bp = "BLIMIT1";
        seed.businessPlace(bp, "한도-사업장");
        UUID owner = seed.user("owner-limit");
        UUID m1 = seed.member(bp, owner, "L-1", "회원1");
        seed.member(bp, owner, "L-2", "회원2");
        seed.member(bp, owner, "L-3", "회원3");
        seed.softDeleteMember(m1, owner); // 3명 중 1명 soft-delete → 활성 2명

        long activeCount = memberRepository.countByBusinessPlaceIdWithLock(bp);

        assertThat(activeCount).isEqualTo(2); // 수정 전엔 3(삭제 대기 포함) → 한도 오탐 유발
    }

    // ===== WB-09: refresh 토큰을 access 토큰으로 오용하면 401 =====
    @Test
    void refresh_토큰을_access로_사용하면_401이다() throws Exception {
        String refreshToken = jwtUtil.generateRefreshToken(
                "00000000-0000-0000-0000-000000000009", "someone");

        mockMvc.perform(get("/api/members").header("Authorization", "Bearer " + refreshToken))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void access_토큰은_정상적으로_필터를_통과한다() throws Exception {
        int statusCode = mockMvc.perform(get("/api/members")
                        .header("Authorization", bearer("00000000-0000-0000-0000-000000000010", null)))
                .andReturn().getResponse().getStatus();
        assertThat(statusCode).isNotEqualTo(401); // access 토큰은 401 아님(하위호환·정상 통과)
    }

    // ===== WB-14: 예약 생성 바디에 알 수 없는 필드가 있어도 400 이 아니라 201 =====
    @Test
    void 예약생성_요청에_알수없는_필드가_있어도_400이_아니다() throws Exception {
        String bp = "BRWB141";
        seed.businessPlace(bp, "예약계약-사업장");
        UUID owner = seed.user("owner-wb14");
        seed.approvedMembership(owner, bp, "OWNER");
        UUID member = seed.member(bp, owner, "R14-1", "예약회원");
        String date = LocalDate.now().plusDays(1).toString();

        String body = String.format(
                "{\"memberId\":\"%s\",\"businessPlaceId\":\"%s\",\"reservationDate\":\"%s\"," +
                        "\"reservationTime\":\"15:00:00\",\"status\":\"PENDING\"," +
                        "\"unknownFutureField\":\"should-be-ignored\"}",
                member, bp, date);

        mockMvc.perform(post("/api/reservations")
                        .header("Authorization", bearer(owner.toString(), bp))
                        .contentType("application/json")
                        .content(body))
                .andExpect(status().isCreated());
    }

    // ===== WB-07: restoreMember 는 회원과 함께 삭제된 메모만 복원 =====
    @Test
    void 회원복원시_개별삭제됐던_메모는_복원되지_않는다() {
        String bp = "BREST07";
        seed.businessPlace(bp, "복원판별-사업장");
        UUID owner = seed.user("owner-wb07");
        seed.approvedMembership(owner, bp, "OWNER"); // restore 는 MANAGER 이상 필요
        UUID member = seed.member(bp, owner, "M07-1", "복원회원");

        // memoA: 회원 삭제 이전에 개별적으로 삭제됨(다른 시각/주체)
        UUID memoA = seed.individuallyDeletedMemo(member, owner, "개별삭제 메모",
                LocalDateTime.now().minusHours(1), owner);
        // memoB: 활성 메모(회원 삭제 시 함께 cascade 삭제될 것)
        UUID memoB = seed.memo(member, owner, "활성 메모", false);

        memberService.softDeleteMember(member.toString(), owner.toString(), bp);
        memberService.restoreMember(member.toString(), owner.toString(), bp);

        // memoB(회원과 함께 삭제) → 복원됨, memoA(개별 삭제) → 삭제 상태 유지
        assertThat(seed.isMemoDeleted(memoB)).as("회원과 함께 삭제된 메모는 복원되어야 함").isFalse();
        assertThat(seed.isMemoDeleted(memoA)).as("개별 삭제됐던 메모는 복원되면 안 됨").isTrue();
    }

    // ===== WB-10: 동시 최초 공지 열람이 500 을 내지 않고 멱등 =====
    @Test
    void 동시_최초_공지열람은_500없이_멱등적으로_처리된다() throws Exception {
        UUID user = seed.user("owner-wb10");
        UUID notice = seed.notice("공지사항");

        int threads = 4;
        CyclicBarrier barrier = new CyclicBarrier(threads);
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        List<Callable<Object>> tasks = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            tasks.add(() -> {
                barrier.await();
                noticeService.recordView(user.toString(), notice.toString(), false);
                return null;
            });
        }
        List<Future<Object>> futures = pool.invokeAll(tasks);
        pool.shutdown();

        List<Throwable> failures = new ArrayList<>();
        for (Future<Object> f : futures) {
            try {
                f.get();
            } catch (java.util.concurrent.ExecutionException e) {
                failures.add(e.getCause());
            }
        }

        assertThat(failures).as("동시 최초 열람이 예외를 던지면 안 됨(멱등)").isEmpty();
        Integer rows = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM user_notice_views WHERE user_id = ? AND notice_id = ?",
                Integer.class, user, notice);
        assertThat(rows).isEqualTo(1);
    }
}
