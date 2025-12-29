package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.ErrorLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 오류 로그 Repository
 */
@Repository
public interface ErrorLogRepository extends JpaRepository<ErrorLog, UUID> {

    /**
     * 전체 오류 로그 조회 (최신순)
     */
    Page<ErrorLog> findAllByOrderByCreatedAtDesc(Pageable pageable);

    /**
     * 사용자별 오류 로그 조회
     */
    Page<ErrorLog> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    /**
     * 사업장별 오류 로그 조회
     */
    Page<ErrorLog> findByBusinessPlaceIdOrderByCreatedAtDesc(String businessPlaceId, Pageable pageable);

    /**
     * 화면별 오류 로그 조회
     */
    Page<ErrorLog> findByScreenNameOrderByCreatedAtDesc(String screenName, Pageable pageable);

    /**
     * 심각도별 오류 로그 조회
     */
    Page<ErrorLog> findBySeverityOrderByCreatedAtDesc(ErrorLog.ErrorSeverity severity, Pageable pageable);

    /**
     * 미해결 오류 로그 조회
     */
    Page<ErrorLog> findByResolvedFalseOrderByCreatedAtDesc(Pageable pageable);

    /**
     * 기간별 오류 로그 조회
     */
    Page<ErrorLog> findByCreatedAtBetweenOrderByCreatedAtDesc(
            LocalDateTime startDate, LocalDateTime endDate, Pageable pageable);

    /**
     * 복합 조건 검색 (전체 - 심각도 + 해결 여부 + 기간)
     */
    @Query("SELECT e FROM ErrorLog e WHERE " +
           "(:severity IS NULL OR e.severity = :severity) " +
           "AND (:resolved IS NULL OR e.resolved = :resolved) " +
           "AND e.createdAt BETWEEN :startDate AND :endDate " +
           "ORDER BY e.createdAt DESC")
    Page<ErrorLog> findByFilters(
            @Param("severity") ErrorLog.ErrorSeverity severity,
            @Param("resolved") Boolean resolved,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    /**
     * 복합 조건 검색 (사업장 + 심각도 + 해결 여부 + 기간)
     */
    @Query("SELECT e FROM ErrorLog e WHERE e.businessPlaceId = :businessPlaceId " +
           "AND (:severity IS NULL OR e.severity = :severity) " +
           "AND (:resolved IS NULL OR e.resolved = :resolved) " +
           "AND e.createdAt BETWEEN :startDate AND :endDate " +
           "ORDER BY e.createdAt DESC")
    Page<ErrorLog> findByBusinessPlaceIdAndFilters(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("severity") ErrorLog.ErrorSeverity severity,
            @Param("resolved") Boolean resolved,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    /**
     * 심각도별 오류 개수 (전체)
     */
    @Query("SELECT e.severity, COUNT(e) FROM ErrorLog e " +
           "WHERE e.createdAt >= :since " +
           "GROUP BY e.severity")
    List<Object[]> countBySeveritySince(@Param("since") LocalDateTime since);

    /**
     * 화면별 오류 개수
     */
    @Query("SELECT e.screenName, COUNT(e) FROM ErrorLog e " +
           "WHERE e.createdAt >= :since " +
           "GROUP BY e.screenName " +
           "ORDER BY COUNT(e) DESC")
    List<Object[]> countByScreenNameSince(@Param("since") LocalDateTime since);

    /**
     * 미해결 오류 개수 (전체)
     */
    long countByResolvedFalse();

    /**
     * 미해결 오류 개수 (사업장별)
     */
    long countByBusinessPlaceIdAndResolvedFalse(String businessPlaceId);

    /**
     * 특정 기간 오류 개수
     */
    long countByCreatedAtBetween(LocalDateTime startDate, LocalDateTime endDate);

    /**
     * 오래된 로그 삭제 (보관 기간 초과)
     */
    void deleteByCreatedAtBefore(LocalDateTime before);

    /**
     * 사업장 삭제 시 관련 로그 삭제
     */
    @Modifying
    @Query("DELETE FROM ErrorLog e WHERE e.businessPlaceId = :businessPlaceId")
    int deleteAllByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    /**
     * 특정 사업장에서 특정 사용자의 user_id를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE ErrorLog e SET e.userId = null WHERE e.businessPlaceId = :businessPlaceId AND e.userId = :userId")
    int clearUserIdByBusinessPlaceIdAndUserId(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("userId") UUID userId);
}
