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
 * 감사 로그 (Audit Log) 엔티티
 *
 * 시스템의 모든 중요 변경사항을 기록합니다.
 * - 누가 (userId)
 * - 언제 (createdAt)
 * - 무엇을 (entityType, entityId)
 * - 어떻게 (action, changesBefore, changesAfter)
 * - 어디서 (ipAddress, deviceInfo)
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "audit_logs", indexes = {
        @Index(name = "idx_audit_user_id", columnList = "user_id"),
        @Index(name = "idx_audit_entity", columnList = "entity_type, entity_id"),
        @Index(name = "idx_audit_created_at", columnList = "created_at"),
        @Index(name = "idx_audit_business_place", columnList = "business_place_id"),
        @Index(name = "idx_audit_action", columnList = "action")
})
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 작업을 수행한 사용자 ID
     */
    @Column(name = "user_id", nullable = false)
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
     * 수행된 작업 종류
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "action", length = 20, nullable = false)
    private AuditAction action;

    /**
     * 대상 엔티티 타입 (MEMBER, MEMO, RESERVATION 등)
     */
    @Column(name = "entity_type", length = 50, nullable = false)
    private String entityType;

    /**
     * 대상 엔티티 ID
     */
    @Column(name = "entity_id", nullable = false)
    private UUID entityId;

    /**
     * 대상 엔티티 이름/설명 (조회 편의를 위해 비정규화)
     * 예: 회원 이름, 메모 제목 등
     */
    @Column(name = "entity_name", length = 200)
    private String entityName;

    /**
     * 변경 전 데이터 (JSON 형식)
     */
    @Column(name = "changes_before", columnDefinition = "TEXT")
    private String changesBefore;

    /**
     * 변경 후 데이터 (JSON 형식)
     */
    @Column(name = "changes_after", columnDefinition = "TEXT")
    private String changesAfter;

    /**
     * 작업 설명
     */
    @Column(name = "description", length = 500)
    private String description;

    /**
     * 클라이언트 IP 주소
     */
    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    /**
     * 디바이스/브라우저 정보
     */
    @Column(name = "device_info", length = 200)
    private String deviceInfo;

    /**
     * 요청 URI
     */
    @Column(name = "request_uri", length = 500)
    private String requestUri;

    /**
     * HTTP 메서드 (GET, POST, PUT, DELETE 등)
     */
    @Column(name = "http_method", length = 10)
    private String httpMethod;

    /**
     * 생성 시간 (로그 기록 시간)
     */
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;


    /**
     * 감사 로그 액션 타입
     */
    public enum AuditAction {
        CREATE,              // 생성
        UPDATE,              // 수정
        DELETE,              // 삭제 (Soft Delete)
        RESTORE,             // 복원
        PERMANENT_DELETE,    // 영구 삭제
        LOGIN,               // 로그인
        LOGOUT,              // 로그아웃
        LOGIN_FAILED,        // 로그인 실패
        EXPORT,              // 데이터 내보내기
        IMPORT,              // 데이터 가져오기
        VIEW,                // 조회 (선택적, 민감 데이터 조회 시)
        // === 시스템 관리자 전용 액션 ===
        ADMIN_ACTION,        // 시스템 관리자 일반 작업
        PERMISSION_CHANGE,   // 권한 변경 (Role 변경, 사업장 접근 권한 등)
        CONFIG_CHANGE,       // 시스템 설정 변경
        USER_SUSPEND,        // 사용자 정지
        USER_ACTIVATE,       // 사용자 활성화
        BUSINESS_PLACE_DELETE, // 사업장 삭제
        ACCESS_DENIED,       // 접근 거부 (보안 이벤트)
        SECURITY_ALERT       // 보안 경고 (비정상 접근 시도 등)
    }
}
