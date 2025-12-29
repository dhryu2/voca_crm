package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.NotificationLog;
import com.vocacrm.api.model.NotificationLog.NotificationStatus;
import com.vocacrm.api.model.NotificationLog.NotificationType;
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
 * 알림 로그 Repository
 */
@Repository
public interface NotificationLogRepository extends JpaRepository<NotificationLog, UUID> {

    /**
     * 사용자의 알림 목록 조회 (최신순)
     */
    Page<NotificationLog> findByUserIdAndStatusOrderByCreatedAtDesc(
            UUID userId, NotificationStatus status, Pageable pageable);

    /**
     * 사용자의 모든 알림 조회 (최신순)
     */
    Page<NotificationLog> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    /**
     * 사용자의 읽지 않은 알림 수
     */
    long countByUserIdAndIsReadFalseAndStatus(UUID userId, NotificationStatus status);

    /**
     * 사용자의 읽지 않은 알림 목록
     */
    List<NotificationLog> findByUserIdAndIsReadFalseAndStatusOrderByCreatedAtDesc(
            UUID userId, NotificationStatus status);

    /**
     * 특정 엔티티 관련 알림 조회
     */
    List<NotificationLog> findByEntityTypeAndEntityIdOrderByCreatedAtDesc(
            String entityType, UUID entityId);

    /**
     * 알림 타입별 조회
     */
    Page<NotificationLog> findByUserIdAndNotificationTypeOrderByCreatedAtDesc(
            UUID userId, NotificationType notificationType, Pageable pageable);

    /**
     * 알림 읽음 처리
     */
    @Modifying
    @Query("UPDATE NotificationLog n SET n.isRead = true, n.readAt = :readAt WHERE n.id = :id")
    void markAsRead(@Param("id") UUID id, @Param("readAt") LocalDateTime readAt);

    /**
     * 사용자의 모든 알림 읽음 처리
     */
    @Modifying
    @Query("UPDATE NotificationLog n SET n.isRead = true, n.readAt = :readAt " +
           "WHERE n.userId = :userId AND n.isRead = false")
    void markAllAsRead(@Param("userId") UUID userId, @Param("readAt") LocalDateTime readAt);

    /**
     * 오래된 알림 삭제
     */
    @Modifying
    @Query("DELETE FROM NotificationLog n WHERE n.createdAt < :before")
    void deleteOldNotifications(@Param("before") LocalDateTime before);
}
