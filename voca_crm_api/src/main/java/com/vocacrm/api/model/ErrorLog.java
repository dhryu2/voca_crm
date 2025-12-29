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
 * 오류 로그 (Error Log) 엔티티
 *
 * 클라이언트(Flutter 앱)에서 발생한 오류를 기록합니다.
 * - 누가 (userId)
 * - 언제 (createdAt)
 * - 어느 화면에서 (screenName)
 * - 어떤 행동으로 (action)
 * - 어떤 요청으로 (requestUrl, requestMethod, requestBody)
 * - 어떤 오류가 (errorMessage, stackTrace)
 * - 어떤 기기에서 (deviceInfo, appVersion, osVersion)
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "error_logs", indexes = {
        @Index(name = "idx_error_user_id", columnList = "user_id"),
        @Index(name = "idx_error_created_at", columnList = "created_at"),
        @Index(name = "idx_error_business_place", columnList = "business_place_id"),
        @Index(name = "idx_error_severity", columnList = "severity"),
        @Index(name = "idx_error_screen", columnList = "screen_name"),
        @Index(name = "idx_error_resolved", columnList = "resolved")
})
public class ErrorLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 오류가 발생한 사용자 ID (비로그인 상태면 null)
     */
    @Column(name = "user_id")
    private UUID userId;

    /**
     * 사용자 이름 (조회 편의를 위해 비정규화)
     */
    @Column(name = "username", length = 100)
    private String username;

    /**
     * 사업장 ID
     */
    @Column(name = "business_place_id", length = 7)
    private String businessPlaceId;

    /**
     * 오류가 발생한 화면 이름
     */
    @Column(name = "screen_name", length = 100)
    private String screenName;

    /**
     * 사용자가 수행하던 행동
     */
    @Column(name = "action", length = 100)
    private String action;

    /**
     * API 요청 URL
     */
    @Column(name = "request_url", length = 500)
    private String requestUrl;

    /**
     * HTTP 메서드 (GET, POST, PUT, DELETE 등)
     */
    @Column(name = "request_method", length = 10)
    private String requestMethod;

    /**
     * 요청 본문 (민감 정보 제외)
     */
    @Column(name = "request_body", columnDefinition = "TEXT")
    private String requestBody;

    /**
     * HTTP 응답 상태 코드
     */
    @Column(name = "http_status_code")
    private Integer httpStatusCode;

    /**
     * 오류 코드 (앱에서 정의한 코드)
     */
    @Column(name = "error_code", length = 50)
    private String errorCode;

    /**
     * 오류 메시지
     */
    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    /**
     * 스택 트레이스
     */
    @Column(name = "stack_trace", columnDefinition = "TEXT")
    private String stackTrace;

    /**
     * 심각도
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "severity", length = 20, nullable = false)
    private ErrorSeverity severity = ErrorSeverity.ERROR;

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
     * OS 버전 (예: iOS 17.0, Android 14)
     */
    @Column(name = "os_version", length = 50)
    private String osVersion;

    /**
     * 플랫폼 (iOS, Android)
     */
    @Column(name = "platform", length = 20)
    private String platform;

    /**
     * 해결 여부
     */
    @Column(name = "resolved", nullable = false)
    private Boolean resolved = false;

    /**
     * 해결한 관리자 ID
     */
    @Column(name = "resolved_by")
    private UUID resolvedBy;

    /**
     * 해결 시간
     */
    @Column(name = "resolved_at")
    private LocalDateTime resolvedAt;

    /**
     * 해결 메모
     */
    @Column(name = "resolution_note", length = 500)
    private String resolutionNote;

    /**
     * 오류 발생 시간
     */
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * 오류 심각도
     */
    public enum ErrorSeverity {
        INFO,       // 정보 (참고용)
        WARNING,    // 경고 (주의 필요)
        ERROR,      // 오류 (처리 필요)
        CRITICAL    // 치명적 (즉시 처리 필요)
    }
}
