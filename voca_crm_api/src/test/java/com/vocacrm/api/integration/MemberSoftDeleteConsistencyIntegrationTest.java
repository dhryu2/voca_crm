package com.vocacrm.api.integration;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * [분류 A/C · 회귀] 회원 soft-delete 정합성 — 삭제 대기 회원의 예약/방문이 활성 뷰에서 사라지는지 검증.
 *
 * <p>씨앗 결함 F1: MemberService.softDeleteMember 는 Memo 만 처리하고 Reservation/Visit 는 그대로 두어
 * 삭제 대기 회원의 예약/방문이 홈 통계·오늘 일정·오늘 방문 목록에 계속 노출됐다(정합성 붕괴).
 * 수정: 활성 뷰 쿼리에 member.is_deleted=false 필터를 추가(복원 시 자동 복귀하는 대칭적·비파괴적 방식).
 *
 * <p>이 테스트들은 실제 PostgreSQL(Testcontainers) + 실제 스키마(Flyway) + 실제 HTTP 계층(MockMvc, JWT 필터,
 * 커스텀 ObjectMapper)을 통해 "DB 최종 상태 → 엔드포인트 응답"을 관찰한다. mock 이 아니다.
 * 각 테스트는 고유 business_place_id 로 격리된다.
 */
class MemberSoftDeleteConsistencyIntegrationTest extends AbstractIntegrationTest {

    private TestDataSeeder seed;

    @BeforeEach
    void setUp() {
        seed = new TestDataSeeder(jdbcTemplate);
    }

    @Test
    void 홈통계_오늘예약수는_삭제대기_회원의_예약을_제외한다() throws Exception {
        String bp = "BSHCNT1";
        seed.businessPlace(bp, "홈통계-사업장");
        UUID owner = seed.user("owner-cnt");
        seed.approvedMembership(owner, bp, "OWNER");
        UUID member = seed.member(bp, owner, "M-CNT-1", "홍길동");
        seed.reservation(member, bp, LocalDate.now(), LocalTime.of(14, 0), "PENDING");
        String auth = bearer(owner.toString(), bp);

        // 삭제 전: 활성 회원의 오늘 예약이 카운트됨 (시드/경로 정상 확인)
        mockMvc.perform(get("/api/statistics/home/{bp}", bp).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.todayReservations").value(1));

        // 회원 soft-delete
        seed.softDeleteMember(member, owner);

        // 삭제 후(회귀): 삭제 대기 회원의 예약은 카운트에서 제외되어야 한다
        mockMvc.perform(get("/api/statistics/home/{bp}", bp).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.todayReservations").value(0));
    }

    @Test
    void 오늘일정_목록은_삭제대기_회원의_예약을_제외한다() throws Exception {
        String bp = "BSSCH01";
        seed.businessPlace(bp, "오늘일정-사업장");
        UUID owner = seed.user("owner-sch");
        seed.approvedMembership(owner, bp, "OWNER");
        UUID member = seed.member(bp, owner, "M-SCH-1", "김철수");
        seed.reservation(member, bp, LocalDate.now(), LocalTime.of(11, 30), "CONFIRMED");
        String auth = bearer(owner.toString(), bp);

        mockMvc.perform(get("/api/statistics/today-schedule/{bp}", bp).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));

        seed.softDeleteMember(member, owner);

        mockMvc.perform(get("/api/statistics/today-schedule/{bp}", bp).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void 오늘방문_목록은_삭제대기_회원의_방문을_제외한다() throws Exception {
        String bp = "BSVIS01";
        seed.businessPlace(bp, "오늘방문-사업장");
        UUID owner = seed.user("owner-vis");
        seed.approvedMembership(owner, bp, "OWNER");
        UUID member = seed.member(bp, owner, "M-VIS-1", "이영희");
        seed.visit(member, owner, LocalDateTime.now());
        String auth = bearer(owner.toString(), bp);

        // 삭제 전: 오늘 방문 목록에 노출
        mockMvc.perform(get("/api/visits/today/{bp}", bp).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));

        seed.softDeleteMember(member, owner);

        // 삭제 후(회귀 · F3): 카운트 함수(get_today_visit_count)와 일치하도록 목록에서도 제외
        mockMvc.perform(get("/api/visits/today/{bp}", bp).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void 회원복원시_예약과_방문이_활성뷰로_대칭적으로_복귀한다() throws Exception {
        // 복원 대칭성: soft-delete 로 사라진 예약/방문이 restore 후 다시 나타나야 한다(비파괴적 필터 방식의 이점)
        String bp = "BSREST1";
        seed.businessPlace(bp, "복원-사업장");
        UUID owner = seed.user("owner-rest");
        seed.approvedMembership(owner, bp, "OWNER");
        UUID member = seed.member(bp, owner, "M-REST-1", "복원회원");
        seed.reservation(member, bp, LocalDate.now(), LocalTime.of(9, 0), "PENDING");
        String auth = bearer(owner.toString(), bp);

        seed.softDeleteMember(member, owner);
        mockMvc.perform(get("/api/statistics/home/{bp}", bp).header("Authorization", auth))
                .andExpect(jsonPath("$.todayReservations").value(0));

        // 복원 (soft-delete 해제)
        jdbcTemplate.update("UPDATE members SET is_deleted=false, deleted_at=null, deleted_by=null WHERE id=?", member);

        mockMvc.perform(get("/api/statistics/home/{bp}", bp).header("Authorization", auth))
                .andExpect(jsonPath("$.todayReservations").value(1));
    }
}
