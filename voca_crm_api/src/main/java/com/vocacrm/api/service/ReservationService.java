package com.vocacrm.api.service;

import com.vocacrm.api.model.Reservation;
import com.vocacrm.api.repository.ReservationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

/**
 * 예약 서비스
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReservationService {

    private final ReservationRepository reservationRepository;

    // 예약 가능 최대 일수 (오늘로부터 90일 이내만 예약 가능)
    private static final int MAX_RESERVATION_DAYS_AHEAD = 90;

    /**
     * 예약 생성
     *
     * 검증 항목:
     * - 과거 날짜 예약 불가
     * - 90일 초과 미래 예약 불가
     * - 동일 회원의 동일 날짜/시간 중복 예약 불가
     */
    @Transactional
    public Reservation createReservation(Reservation reservation) {
        // 필수 필드 검증
        validateReservationRequired(reservation);

        // 비즈니스 로직 검증
        validateReservationDate(reservation.getReservationDate());
        validateNoDuplicateReservation(reservation);

        return reservationRepository.save(reservation);
    }

    /**
     * 예약 필수 필드 검증
     */
    private void validateReservationRequired(Reservation reservation) {
        if (reservation.getMemberId() == null) {
            throw new IllegalArgumentException("회원 ID는 필수입니다.");
        }
        if (reservation.getBusinessPlaceId() == null || reservation.getBusinessPlaceId().isEmpty()) {
            throw new IllegalArgumentException("사업장 ID는 필수입니다.");
        }
        if (reservation.getReservationDate() == null) {
            throw new IllegalArgumentException("예약 날짜는 필수입니다.");
        }
        if (reservation.getReservationTime() == null) {
            throw new IllegalArgumentException("예약 시간은 필수입니다.");
        }
    }

    /**
     * 예약 날짜 검증
     *
     * - 과거 날짜 예약 불가
     * - 90일 초과 미래 예약 불가
     */
    private void validateReservationDate(LocalDate reservationDate) {
        LocalDate today = LocalDate.now();

        // 과거 날짜 체크
        if (reservationDate.isBefore(today)) {
            throw new IllegalArgumentException("과거 날짜에는 예약할 수 없습니다.");
        }

        // 너무 먼 미래 체크 (90일 초과)
        LocalDate maxDate = today.plusDays(MAX_RESERVATION_DAYS_AHEAD);
        if (reservationDate.isAfter(maxDate)) {
            throw new IllegalArgumentException("예약은 " + MAX_RESERVATION_DAYS_AHEAD + "일 이내만 가능합니다.");
        }
    }

    /**
     * 중복 예약 검증 (생성 시)
     *
     * 같은 회원이 같은 날짜/시간에 활성 상태(PENDING, CONFIRMED)의 예약이 있는지 체크
     */
    private void validateNoDuplicateReservation(Reservation reservation) {
        boolean exists = reservationRepository.existsDuplicateReservation(
                reservation.getMemberId(),
                reservation.getBusinessPlaceId(),
                reservation.getReservationDate(),
                reservation.getReservationTime()
        );

        if (exists) {
            throw new IllegalArgumentException("해당 날짜/시간에 이미 예약이 존재합니다.");
        }
    }

    /**
     * 중복 예약 검증 (수정 시, 자기 자신 제외)
     */
    private void validateNoDuplicateReservationExcluding(Reservation reservation, UUID excludeId) {
        boolean exists = reservationRepository.existsDuplicateReservationExcluding(
                reservation.getMemberId(),
                reservation.getBusinessPlaceId(),
                reservation.getReservationDate(),
                reservation.getReservationTime(),
                excludeId
        );

        if (exists) {
            throw new IllegalArgumentException("해당 날짜/시간에 이미 다른 예약이 존재합니다.");
        }
    }

    /**
     * 예약 조회 by ID
     */
    public Reservation getReservationById(UUID id) {
        return reservationRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("예약을 찾을 수 없습니다: " + id));
    }

    /**
     * 회원의 예약 목록 조회 (사업장 필터링 포함)
     * 사업장 권한 검증을 위해 businessPlaceId 필수
     */
    public List<Reservation> getReservationsByMemberId(UUID memberId, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return reservationRepository.findByMemberIdAndBusinessPlaceIdOrderByReservationDateDescReservationTimeDesc(
                memberId, businessPlaceId);
    }

    /**
     * 사업장의 예약 목록 조회
     */
    public List<Reservation> getReservationsByBusinessPlaceId(String businessPlaceId) {
        return reservationRepository.findByBusinessPlaceIdOrderByReservationDateAscReservationTimeAsc(businessPlaceId);
    }

    /**
     * 사업장의 특정 날짜 예약 목록 조회
     */
    public List<Reservation> getReservationsByBusinessPlaceAndDate(String businessPlaceId, LocalDate date) {
        return reservationRepository.findByBusinessPlaceIdAndReservationDateOrderByReservationTimeAsc(
                businessPlaceId, date);
    }

    /**
     * 사업장의 날짜 범위 예약 목록 조회
     */
    public List<Reservation> getReservationsByDateRange(String businessPlaceId, LocalDate startDate, LocalDate endDate) {
        return reservationRepository.findByBusinessPlaceIdAndDateRange(businessPlaceId, startDate, endDate);
    }

    /**
     * 사업장의 특정 상태 예약 목록 조회
     */
    public List<Reservation> getReservationsByStatus(String businessPlaceId, Reservation.ReservationStatus status) {
        return reservationRepository.findByBusinessPlaceIdAndStatusOrderByReservationDateAscReservationTimeAsc(
                businessPlaceId, status);
    }

    /**
     * 예약 수정
     *
     * 날짜/시간이 변경되는 경우 검증 수행:
     * - 과거 날짜 예약 불가
     * - 90일 초과 미래 예약 불가
     * - 중복 예약 체크 (자기 자신 제외)
     */
    @Transactional
    public Reservation updateReservation(UUID id, Reservation updatedReservation) {
        Reservation existing = getReservationById(id);

        // 날짜/시간 변경 여부 확인
        LocalDate newDate = updatedReservation.getReservationDate() != null
                ? updatedReservation.getReservationDate()
                : existing.getReservationDate();
        LocalTime newTime = updatedReservation.getReservationTime() != null
                ? updatedReservation.getReservationTime()
                : existing.getReservationTime();

        boolean dateTimeChanged = !newDate.equals(existing.getReservationDate())
                || !newTime.equals(existing.getReservationTime());

        // 날짜/시간이 변경되면 검증 수행
        if (dateTimeChanged) {
            validateReservationDate(newDate);

            // 중복 체크를 위한 임시 객체 생성
            Reservation tempForValidation = new Reservation();
            tempForValidation.setMemberId(existing.getMemberId());
            tempForValidation.setBusinessPlaceId(existing.getBusinessPlaceId());
            tempForValidation.setReservationDate(newDate);
            tempForValidation.setReservationTime(newTime);

            validateNoDuplicateReservationExcluding(tempForValidation, id);
        }

        if (updatedReservation.getReservationDate() != null) {
            existing.setReservationDate(updatedReservation.getReservationDate());
        }
        if (updatedReservation.getReservationTime() != null) {
            existing.setReservationTime(updatedReservation.getReservationTime());
        }
        if (updatedReservation.getStatus() != null) {
            existing.setStatus(updatedReservation.getStatus());
        }
        if (updatedReservation.getServiceType() != null) {
            existing.setServiceType(updatedReservation.getServiceType());
        }
        if (updatedReservation.getDurationMinutes() != null) {
            existing.setDurationMinutes(updatedReservation.getDurationMinutes());
        }
        if (updatedReservation.getNotes() != null) {
            existing.setNotes(updatedReservation.getNotes());
        }
        // remark는 null로 설정 가능 (특이사항 삭제)
        existing.setRemark(updatedReservation.getRemark());
        if (updatedReservation.getUpdatedBy() != null) {
            existing.setUpdatedBy(updatedReservation.getUpdatedBy());
        }

        Reservation saved = reservationRepository.save(existing);
        return saved;
    }

    /**
     * 예약 상태 변경
     */
    @Transactional
    public Reservation updateReservationStatus(UUID id, Reservation.ReservationStatus status, UUID updatedBy) {
        Reservation reservation = getReservationById(id);
        reservation.setStatus(status);
        if (updatedBy != null) {
            reservation.setUpdatedBy(updatedBy);
        }
        return reservationRepository.save(reservation);
    }

    // ===== 예약 삭제 정책 =====
    // 사용자 API를 통한 예약 삭제는 제공하지 않음
    // - 고객 취소: 상태를 CANCELLED로 변경
    // - 노쇼: 상태를 NO_SHOW로 변경
    // - 오래된 데이터: 스케줄러가 1년 후 자동 삭제

    /**
     * 오래된 예약 자동 삭제 (스케줄러 전용)
     *
     * 1년이 지난 예약을 자동으로 삭제합니다.
     * ReservationCleanupScheduler에서만 호출해야 합니다.
     *
     * @param retentionDays 보관 기간 (일 단위, 기본 365일)
     * @return 삭제된 예약 수
     */
    @Transactional
    public int deleteExpiredReservations(int retentionDays) {
        LocalDate cutoffDate = LocalDate.now().minusDays(retentionDays);
        return reservationRepository.deleteByReservationDateBefore(cutoffDate);
    }

    /**
     * 삭제 예정 예약 수 조회 (미리보기용)
     *
     * @param retentionDays 보관 기간 (일 단위)
     * @return 삭제 예정 예약 수
     */
    public long countExpiredReservations(int retentionDays) {
        LocalDate cutoffDate = LocalDate.now().minusDays(retentionDays);
        return reservationRepository.countByReservationDateBefore(cutoffDate);
    }

    /**
     * 특정 날짜의 예약 개수 조회
     */
    public Long getReservationCountByDate(String businessPlaceId, LocalDate date) {
        return reservationRepository.countByBusinessPlaceIdAndDate(businessPlaceId, date);
    }

    /**
     * 오늘 예약 개수 조회
     */
    public Long getTodayReservationCount(String businessPlaceId) {
        return reservationRepository.countTodayReservations(businessPlaceId);
    }

    /**
     * 회원의 총 예약 개수 조회 (사업장 필터링 포함)
     * 사업장 권한 검증을 위해 businessPlaceId 필수
     */
    public Long getMemberReservationCount(UUID memberId, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return reservationRepository.countByMemberIdAndBusinessPlaceId(memberId, businessPlaceId);
    }

    /**
     * 회원의 완료된 예약 개수 조회 (사업장 필터링 포함)
     * 사업장 권한 검증을 위해 businessPlaceId 필수
     */
    public Long getMemberCompletedReservationCount(UUID memberId, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return reservationRepository.countByMemberIdAndBusinessPlaceIdAndStatus(
                memberId, businessPlaceId, Reservation.ReservationStatus.COMPLETED);
    }
}
