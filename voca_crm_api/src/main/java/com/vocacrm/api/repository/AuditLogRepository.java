package com.vocacrm.api.repository;

import com.vocacrm.api.model.AuditLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

/**
 * 감사 로그 Repository
 */
@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, UUID> {

    /**
     * 사용자별 감사 로그 조회 (사업장 필터링 포함)
     */
    Page<AuditLog> findByUserIdAndBusinessPlaceIdOrderByCreatedAtDesc(
            UUID userId, String businessPlaceId, Pageable pageable);

    /**
     * 엔티티별 감사 로그 조회 (사업장 필터링 포함)
     */
    Page<AuditLog> findByEntityTypeAndEntityIdAndBusinessPlaceIdOrderByCreatedAtDesc(
            String entityType, UUID entityId, String businessPlaceId, Pageable pageable);

    /**
     * 사업장별 감사 로그 조회
     */
    Page<AuditLog> findByBusinessPlaceIdOrderByCreatedAtDesc(
            String businessPlaceId, Pageable pageable);

    /**
     * 액션별 감사 로그 조회 (사업장 필터링 포함)
     */
    Page<AuditLog> findByActionAndBusinessPlaceIdOrderByCreatedAtDesc(
            AuditLog.AuditAction action, String businessPlaceId, Pageable pageable);

    /**
     * 기간별 감사 로그 조회 (사업장 필터링 포함)
     */
    Page<AuditLog> findByCreatedAtBetweenAndBusinessPlaceIdOrderByCreatedAtDesc(
            LocalDateTime startDate, LocalDateTime endDate, String businessPlaceId, Pageable pageable);

    /**
     * 복합 조건 검색 (사업장 + 기간)
     */
    @Query("SELECT a FROM AuditLog a WHERE a.businessPlaceId = :businessPlaceId " +
           "AND a.createdAt BETWEEN :startDate AND :endDate " +
           "ORDER BY a.createdAt DESC")
    Page<AuditLog> findByBusinessPlaceIdAndDateRange(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    /**
     * 복합 조건 검색 (사업장 + 엔티티 타입 + 기간)
     */
    @Query("SELECT a FROM AuditLog a WHERE a.businessPlaceId = :businessPlaceId " +
           "AND a.entityType = :entityType " +
           "AND a.createdAt BETWEEN :startDate AND :endDate " +
           "ORDER BY a.createdAt DESC")
    Page<AuditLog> findByBusinessPlaceIdAndEntityTypeAndDateRange(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("entityType") String entityType,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    /**
     * 복합 조건 검색 (사업장 + 사용자 ID 목록 + 기간)
     * MANAGER가 본인 + STAFF 로그만 조회할 때 사용
     */
    @Query("SELECT a FROM AuditLog a WHERE a.businessPlaceId = :businessPlaceId " +
           "AND a.userId IN :userIds " +
           "AND a.createdAt BETWEEN :startDate AND :endDate " +
           "ORDER BY a.createdAt DESC")
    Page<AuditLog> findByBusinessPlaceIdAndUserIdInAndDateRange(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("userIds") List<UUID> userIds,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    /**
     * 복합 조건 검색 (사업장 + 사용자 ID 목록 + 엔티티 타입 + 기간)
     */
    @Query("SELECT a FROM AuditLog a WHERE a.businessPlaceId = :businessPlaceId " +
           "AND a.userId IN :userIds " +
           "AND a.entityType = :entityType " +
           "AND a.createdAt BETWEEN :startDate AND :endDate " +
           "ORDER BY a.createdAt DESC")
    Page<AuditLog> findByBusinessPlaceIdAndUserIdInAndEntityTypeAndDateRange(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("userIds") List<UUID> userIds,
            @Param("entityType") String entityType,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    /**
     * 특정 엔티티의 변경 이력 조회 (사업장 필터링 포함)
     */
    List<AuditLog> findByEntityTypeAndEntityIdAndBusinessPlaceIdOrderByCreatedAtAsc(
            String entityType, UUID entityId, String businessPlaceId);

    /**
     * 최근 N일간 액션별 통계
     */
    @Query("SELECT a.action, COUNT(a) FROM AuditLog a " +
           "WHERE a.businessPlaceId = :businessPlaceId " +
           "AND a.createdAt >= :since " +
           "GROUP BY a.action")
    List<Object[]> countByActionSince(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("since") LocalDateTime since);

    /**
     * 사용자별 활동 통계
     */
    @Query("SELECT a.userId, a.username, COUNT(a) FROM AuditLog a " +
           "WHERE a.businessPlaceId = :businessPlaceId " +
           "AND a.createdAt >= :since " +
           "GROUP BY a.userId, a.username " +
           "ORDER BY COUNT(a) DESC")
    List<Object[]> countByUserSince(
            @Param("businessPlaceId") String businessPlaceId,
            @Param("since") LocalDateTime since);

    /**
     * 오래된 로그 삭제 (보관 기간 초과)
     */
    void deleteByCreatedAtBefore(LocalDateTime before);

    // ===== 사용자 참조 정리 (사업장 탈퇴 시 사용) =====

    /**
     * 특정 사업장에서 특정 사용자의 user_id를 NULL로 설정
     *
     * 주의: username은 비정규화된 필드로 보존하여 감사 로그의 가독성을 유지합니다.
     */
    @Modifying
    @Query("UPDATE AuditLog a SET a.userId = null WHERE a.businessPlaceId = :businessPlaceId AND a.userId = :userId")
    int clearUserIdByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 특정 사업장의 전체 감사 로그 수 조회
     */
    long countByBusinessPlaceId(String businessPlaceId);

    /**
     * 특정 사업장의 모든 감사 로그 삭제 (Hard Delete)
     */
    @Modifying
    @Query("DELETE FROM AuditLog a WHERE a.businessPlaceId = :businessPlaceId")
    int deleteAllByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);
}
