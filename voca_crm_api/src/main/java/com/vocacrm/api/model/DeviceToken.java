package com.vocacrm.api.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 디바이스 FCM 토큰 엔티티
 *
 * 사용자의 디바이스별 푸시 알림 토큰을 저장합니다.
 * 한 사용자가 여러 디바이스를 사용할 수 있습니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "device_tokens", indexes = {
        @Index(name = "idx_device_user_id", columnList = "user_id"),
        @Index(name = "idx_device_token", columnList = "fcm_token"),
        @Index(name = "idx_device_active", columnList = "is_active")
})
public class DeviceToken {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 사용자 ID
     */
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /**
     * FCM 토큰
     */
    @Column(name = "fcm_token", length = 500, nullable = false)
    private String fcmToken;

    /**
     * 디바이스 타입 (iOS, Android, Web)
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "device_type", length = 20)
    private DeviceType deviceType;

    /**
     * 디바이스 정보 (모델명 등)
     */
    @Column(name = "device_info", length = 200)
    private String deviceInfo;

    /**
     * 앱 버전
     */
    @Column(name = "app_version", length = 20)
    private String appVersion;

    /**
     * 토큰 활성 여부
     */
    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    /**
     * 마지막 사용 시간
     */
    @Column(name = "last_used_at")
    private LocalDateTime lastUsedAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public enum DeviceType {
        IOS,
        ANDROID,
        WEB
    }
}
