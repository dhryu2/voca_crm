package com.vocacrm.api.integration;

import com.vocacrm.api.model.Reservation;
import com.vocacrm.api.service.ReservationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * [분류 E(동시성)/C(500) · 회귀] 예약 슬롯 중복 제약(ux_reservation_active_slot) TOCTOU.
 *
 * <p>F6: createReservation 은 앱 레벨 중복체크 후 save 하는데, 동시에 같은 슬롯을 예약하면 두 요청 모두
 * 앱 체크를 통과한 뒤 두 번째 save 에서 DB 유니크 제약이 위반된다. 기존 코드는 이 예외를 잡지 않아
 * 500(DataIntegrityViolationException)이 노출됐다. 수정: saveAndFlush + try/catch 로 400 으로 변환.
 *
 * <p>실제 PostgreSQL 의 부분 유니크 인덱스가 실제로 동작해야 재현되므로 Testcontainers 통합테스트로만 검증 가능하다.
 */
class ReservationSlotConflictIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private ReservationService reservationService;

    private TestDataSeeder seed;

    @BeforeEach
    void setUp() {
        seed = new TestDataSeeder(jdbcTemplate);
    }

    @Test
    void 동시_중복예약은_500이_아니라_400계열로_처리되고_슬롯당_예약은_하나만_남는다() throws Exception {
        String bp = "BRESV01";
        seed.businessPlace(bp, "예약경합-사업장");
        UUID owner = seed.user("owner-resv");
        seed.approvedMembership(owner, bp, "OWNER");
        UUID member = seed.member(bp, owner, "M-RESV-1", "예약회원");

        LocalDate date = LocalDate.now().plusDays(1);
        LocalTime time = LocalTime.of(15, 0);

        int threads = 4;
        CyclicBarrier barrier = new CyclicBarrier(threads);
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        List<Callable<Object>> tasks = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            tasks.add(() -> {
                barrier.await(); // 모든 스레드가 동시에 save 하도록 정렬 → DB 제약 경합 유도
                Reservation r = new Reservation();
                r.setMemberId(member);
                r.setBusinessPlaceId(bp);
                r.setReservationDate(date);
                r.setReservationTime(time);
                r.setStatus(Reservation.ReservationStatus.PENDING);
                return reservationService.createReservation(r);
            });
        }

        List<Future<Object>> futures = pool.invokeAll(tasks);
        pool.shutdown();

        int success = 0;
        List<Throwable> failures = new ArrayList<>();
        for (Future<Object> f : futures) {
            try {
                f.get();
                success++;
            } catch (java.util.concurrent.ExecutionException e) {
                failures.add(e.getCause());
            }
        }

        // 정확히 하나만 성공, DB 에도 활성 예약은 1건만 존재
        assertThat(success).isEqualTo(1);
        Integer rows = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM reservations WHERE member_id = ? AND reservation_date = ? " +
                        "AND reservation_time = ? AND status IN ('PENDING','CONFIRMED')",
                Integer.class, member, date, time);
        assertThat(rows).isEqualTo(1);

        // 회귀 핵심: 실패는 전부 400 계열(IllegalArgumentException)이어야 하며,
        // 원시 DataIntegrityViolationException(→500)이 새어나오면 안 된다.
        assertThat(failures).isNotEmpty();
        assertThat(failures).allSatisfy(t ->
                assertThat(t)
                        .isInstanceOf(IllegalArgumentException.class)
                        .isNotInstanceOf(DataIntegrityViolationException.class));
    }
}
