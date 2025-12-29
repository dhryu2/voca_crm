package com.vocacrm.api.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 푸시 알림 발송 로그
 *
 * 발송된 모든 푸시 알림을 기록합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "notification_logs", indexes = {
        @Index(name = "idx_notif_user_id", columnList = "user_id"),
        @Index(name = "idx_notif_type", columnList = "notification_type"),
        @Index(name = "idx_notif_created", columnList = "created_at")
})
public class NotificationLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 수신자 사용자 ID
     */
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /**
     * 알림 타입
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "notification_type", length = 30, nullable = false)
    private NotificationType notificationType;

    /**
     * 알림 제목
     */
    @Column(name = "title", length = 200, nullable = false)
    private String title;

    /**
     * 알림 본문
     */
    @Column(name = "body", length = 1000)
    private String body;

    /**
     * 연결된 엔티티 타입 (MEMBER, RESERVATION 등)
     */
    @Column(name = "entity_type", length = 50)
    private String entityType;

    /**
     * 연결된 엔티티 ID
     */
    @Column(name = "entity_id")
    private UUID entityId;

    /**
     * 추가 데이터 (JSON)
     */
    @Column(name = "data", columnDefinition = "TEXT")
    private String data;

    /**
     * 발송 상태
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20, nullable = false)
    @Builder.Default
    private NotificationStatus status = NotificationStatus.PENDING;

    /**
     * FCM 메시지 ID (발송 성공 시)
     */
    @Column(name = "fcm_message_id", length = 200)
    private String fcmMessageId;

    /**
     * 에러 메시지 (발송 실패 시)
     */
    @Column(name = "error_message", length = 500)
    private String errorMessage;

    /**
     * 읽음 여부
     */
    @Column(name = "is_read", nullable = false)
    @Builder.Default
    private Boolean isRead = false;

    /**
     * 읽은 시간
     */
    @Column(name = "read_at")
    private LocalDateTime readAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * 알림 타입
     */
    public enum NotificationType {
        // 예약 관련
        RESERVATION_CREATED,     // 새 예약 생성
        RESERVATION_REMINDER,    // 예약 리마인더 (1일 전, 1시간 전)
        RESERVATION_CANCELLED,   // 예약 취소됨
        RESERVATION_MODIFIED,    // 예약 변경됨

        // 메모 관련
        MEMO_CREATED,           // 새 메모 등록
        MEMO_MENTIONED,         // 메모에서 멘션됨

        // 회원 관련
        MEMBER_CREATED,         // 새 회원 등록
        MEMBER_VISITED,         // 회원 방문

        // 공지사항
        NOTICE_NEW,             // 새 공지사항

        // 시스템
        SYSTEM_ANNOUNCEMENT,    // 시스템 공지
        SECURITY_ALERT          // 보안 알림 (새 기기 로그인 등)
    }

    /**
     * 발송 상태
     */
    public enum NotificationStatus {
        PENDING,    // 대기 중
        SENT,       // 발송 완료
        FAILED,     // 발송 실패
        CANCELLED   // 취소됨
    }
}
