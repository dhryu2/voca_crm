package com.vocacrm.api.scheduler;

import com.vocacrm.api.service.ReservationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 예약 데이터 자동 정리 스케줄러
 *
 * 보관 기간(기본 1년)이 지난 예약 데이터를 자동으로 삭제합니다.
 * 매일 새벽 3시에 실행됩니다.
 *
 * 설정:
 * - app.reservation.retention-days: 보관 기간 (일 단위, 기본값: 365)
 * - 스케줄링 활성화 필요: @EnableScheduling
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ReservationCleanupScheduler {

    private final ReservationService reservationService;

    /**
     * 예약 데이터 보관 기간 (일 단위)
     * application.yml에서 설정 가능: app.reservation.retention-days
     * 기본값: 900일 (약 2년 6개월)
     */
    @Value("${app.reservation.retention-days:900}")
    private int retentionDays;

    /**
     * 오래된 예약 데이터 정리
     *
     * 매일 새벽 3시에 실행됩니다.
     * 보관 기간이 지난 예약을 자동으로 삭제합니다.
     */
    @Scheduled(cron = "0 0 3 * * *")
    public void cleanupExpiredReservations() {
        log.info("[ReservationCleanup] Starting cleanup job. Retention period: {} days", retentionDays);

        try {
            // 삭제 전 개수 확인
            long countToDelete = reservationService.countExpiredReservations(retentionDays);

            if (countToDelete == 0) {
                log.info("[ReservationCleanup] No expired reservations to delete");
                return;
            }

            log.info("[ReservationCleanup] Found {} expired reservations to delete", countToDelete);

            // 삭제 실행
            int deletedCount = reservationService.deleteExpiredReservations(retentionDays);

            log.info("[ReservationCleanup] Successfully deleted {} expired reservations", deletedCount);
        } catch (Exception e) {
            log.error("[ReservationCleanup] Failed to cleanup expired reservations", e);
        }
    }
}
