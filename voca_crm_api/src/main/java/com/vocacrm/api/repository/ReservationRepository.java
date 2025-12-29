package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.Reservation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

/**
 * 예약 레포지토리
 */
@Repository
public interface ReservationRepository extends JpaRepository<Reservation, UUID> {

    // ===== 사업장 필터링이 포함된 메서드들 =====

    /**
     * 회원 ID와 사업장 ID로 예약 목록 조회 (최신순)
     * 사업장 권한 검증을 위해 businessPlaceId 필수
     */
    List<Reservation> findByMemberIdAndBusinessPlaceIdOrderByReservationDateDescReservationTimeDesc(
            UUID memberId,
            String businessPlaceId
    );

    // REMOVED: findByMemberIdOrderByReservationDateDescReservationTimeDesc() - 사업장 필터링 필수

    /**
     * 사업장 ID로 예약 목록 조회 (날짜 오름차순)
     */
    List<Reservation> findByBusinessPlaceIdOrderByReservationDateAscReservationTimeAsc(String businessPlaceId);

    /**
     * 사업장 ID와 날짜로 예약 목록 조회
     */
    List<Reservation> findByBusinessPlaceIdAndReservationDateOrderByReservationTimeAsc(
            String businessPlaceId,
            LocalDate reservationDate
    );

    /**
     * 사업장 ID와 날짜 범위로 예약 목록 조회
     */
    @Query("SELECT r FROM Reservation r WHERE r.businessPlaceId = :businessPlaceId " +
           "AND r.reservationDate BETWEEN :startDate AND :endDate " +
           "ORDER BY r.reservationDate ASC, r.reservationTime ASC")
    List<Reservation> findByBusinessPlaceIdAndDateRange(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate
    );

    /**
     * 사업장 ID와 상태로 예약 목록 조회
     */
    List<Reservation> findByBusinessPlaceIdAndStatusOrderByReservationDateAscReservationTimeAsc(
            String businessPlaceId,
            Reservation.ReservationStatus status
    );

    /**
     * 사업장 ID와 날짜, 상태로 예약 목록 조회
     */
    List<Reservation> findByBusinessPlaceIdAndReservationDateAndStatusOrderByReservationTimeAsc(
            String businessPlaceId,
            LocalDate reservationDate,
            Reservation.ReservationStatus status
    );

    /**
     * 특정 날짜의 예약 개수 조회
     */
    @Query("SELECT COUNT(r) FROM Reservation r WHERE r.businessPlaceId = :businessPlaceId " +
           "AND r.reservationDate = :date AND r.status IN ('PENDING', 'CONFIRMED')")
    Long countByBusinessPlaceIdAndDate(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("date") LocalDate date
    );

    /**
     * 오늘 예약 개수 조회
     */
    @Query("SELECT COUNT(r) FROM Reservation r WHERE r.businessPlaceId = :businessPlaceId " +
           "AND r.reservationDate = CURRENT_DATE AND r.status IN ('PENDING', 'CONFIRMED')")
    Long countTodayReservations(@Param("businessPlaceId") String businessPlaceId);

    /**
     * 회원의 예약 개수 조회 (사업장 필터링 포함)
     * 사업장 권한 검증을 위해 businessPlaceId 필수
     */
    Long countByMemberIdAndBusinessPlaceId(UUID memberId, String businessPlaceId);

    /**
     * 회원의 특정 상태 예약 개수 조회 (사업장 필터링 포함)
     * 사업장 권한 검증을 위해 businessPlaceId 필수
     */
    Long countByMemberIdAndBusinessPlaceIdAndStatus(
            UUID memberId,
            String businessPlaceId,
            Reservation.ReservationStatus status
    );

    // REMOVED: countByMemberId() - 사업장 필터링 필수
    // REMOVED: countByMemberIdAndStatus() - 사업장 필터링 필수

    // ===== 예약 검증용 메서드 =====

    /**
     * 중복 예약 체크 (같은 회원이 같은 날짜/시간에 예약이 있는지)
     *
     * PENDING, CONFIRMED 상태의 예약만 체크합니다 (CANCELLED, NO_SHOW는 제외).
     *
     * @param memberId 회원 ID
     * @param businessPlaceId 사업장 ID
     * @param reservationDate 예약 날짜
     * @param reservationTime 예약 시간
     * @return 중복 예약 존재 여부
     */
    @Query("SELECT COUNT(r) > 0 FROM Reservation r " +
           "WHERE r.memberId = :memberId " +
           "AND r.businessPlaceId = :businessPlaceId " +
           "AND r.reservationDate = :reservationDate " +
           "AND r.reservationTime = :reservationTime " +
           "AND r.status IN ('PENDING', 'CONFIRMED')")
    boolean existsDuplicateReservation(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId,
            @Param("reservationDate") LocalDate reservationDate,
            @Param("reservationTime") java.time.LocalTime reservationTime
    );

    /**
     * 수정 시 중복 예약 체크 (자기 자신 제외)
     */
    @Query("SELECT COUNT(r) > 0 FROM Reservation r " +
           "WHERE r.memberId = :memberId " +
           "AND r.businessPlaceId = :businessPlaceId " +
           "AND r.reservationDate = :reservationDate " +
           "AND r.reservationTime = :reservationTime " +
           "AND r.status IN ('PENDING', 'CONFIRMED') " +
           "AND r.id != :excludeId")
    boolean existsDuplicateReservationExcluding(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId,
            @Param("reservationDate") LocalDate reservationDate,
            @Param("reservationTime") java.time.LocalTime reservationTime,
            @Param("excludeId") UUID excludeId
    );

    // ===== 사용자 참조 정리 (사업장 탈퇴 시 사용) =====

    /**
     * 특정 사업장에서 특정 사용자의 created_by를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE Reservation r SET r.createdBy = null WHERE r.businessPlaceId = :businessPlaceId AND r.createdBy = :userId")
    int clearCreatedByByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 특정 사업장의 전체 예약 수 조회
     */
    long countByBusinessPlaceId(String businessPlaceId);

    /**
     * 특정 사업장의 모든 예약 삭제 (Hard Delete)
     */
    @Modifying
    @Query("DELETE FROM Reservation r WHERE r.businessPlaceId = :businessPlaceId")
    int deleteAllByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    // ===== 데이터 보관 정책 (1년 후 자동 삭제) =====

    /**
     * 특정 날짜 이전의 예약 삭제 (보관 기간 만료)
     * 스케줄러에서 사용
     *
     * @param cutoffDate 이 날짜 이전의 예약 삭제
     * @return 삭제된 레코드 수
     */
    @Modifying
    @Query("DELETE FROM Reservation r WHERE r.reservationDate < :cutoffDate")
    int deleteByReservationDateBefore(@Param("cutoffDate") LocalDate cutoffDate);

    /**
     * 특정 날짜 이전의 예약 개수 조회 (삭제 전 미리보기용)
     *
     * @param cutoffDate 이 날짜 이전의 예약 개수
     * @return 예약 개수
     */
    @Query("SELECT COUNT(r) FROM Reservation r WHERE r.reservationDate < :cutoffDate")
    long countByReservationDateBefore(@Param("cutoffDate") LocalDate cutoffDate);
}
