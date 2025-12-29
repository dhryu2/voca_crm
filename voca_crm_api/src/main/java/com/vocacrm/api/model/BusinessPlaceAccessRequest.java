package com.vocacrm.api.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.ToString;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 사업장 접근 요청 이력 엔티티
 *
 * 사용자가 사업장에 접근 권한을 요청한 이력과 처리 결과를 관리합니다.
 * 요청, 승인/거절, 결과 확인의 전체 라이프사이클을 추적합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "business_place_access_requests")
public class BusinessPlaceAccessRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 요청자 ID
     */
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /**
     * 요청 대상 사업장 ID
     */
    @Column(name = "business_place_id", length = 7, nullable = false)
    private String businessPlaceId;

    /**
     * 요청한 권한 (MANAGER, STAFF)
     * OWNER는 요청할 수 없음 (사업장 생성 시 자동 부여)
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    /**
     * 요청 상태
     * PENDING: 대기중, APPROVED: 승인됨, REJECTED: 거절됨
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AccessStatus status;

    /**
     * 요청 시간
     */
    @Column(name = "requested_at", nullable = false)
    private LocalDateTime requestedAt;

    /**
     * 처리 시간 (승인 또는 거절된 시간)
     */
    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    /**
     * 처리자 ID (사업장 owner)
     */
    @Column(name = "processed_by")
    private UUID processedBy;

    /**
     * 요청자가 처리 결과를 확인했는지 여부
     */
    @Column(name = "is_read_by_requester", nullable = false)
    @Builder.Default
    private Boolean isReadByRequester = false;

    /**
     * 요청자 정보
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private User user;

    /**
     * 사업장 정보
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "business_place_id", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private BusinessPlace businessPlace;

    /**
     * 처리자 정보
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "processed_by", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private User processor;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (this.status == null) {
            this.status = AccessStatus.PENDING;
        }
        if (this.requestedAt == null) {
            this.requestedAt = LocalDateTime.now();
        }
        if (this.isReadByRequester == null) {
            this.isReadByRequester = false;
        }
    }
}
