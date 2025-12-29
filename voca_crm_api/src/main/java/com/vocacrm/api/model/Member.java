package com.vocacrm.api.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.ToString;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 회원(Member) 엔티티 클래스
 *
 * VocaCRM 시스템의 회원 정보를 담는 JPA 엔티티입니다.
 * PostgreSQL의 'members' 테이블과 매핑됩니다.
 *
 * 주요 특징:
 * - UUID를 기본키로 사용하여 분산 시스템에서의 확장성 보장
 * - memberNumber는 중복 가능 (동일 회원번호로 여러 레코드 등록 가능)
 * - 생성/수정 시간 자동 관리
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@Data // Lombok: Getter, Setter, toString, equals, hashCode 자동 생성
@Entity // JPA 엔티티임을 표시
@Table(name = "members") // 매핑될 데이터베이스 테이블명 지정
public class Member {

    /**
     * 회원 고유 식별자 (Primary Key)
     */
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 회원번호
     * 업무적으로 사용되는 회원번호로, 중복 가능
     * 음성 검색의 주요 검색 키로 사용됨
     */
    @Column(name = "member_number", length = 50, nullable = false)
    private String memberNumber;

    /**
     * 회원 이름
     * 필수 입력 항목 (nullable = false)
     */
    @Column(nullable = false, length = 100)
    private String name;

    /**
     * 전화번호
     * 선택 입력 항목, 하이픈 포함 최대 20자
     * 예: "010-1234-5678"
     */
    @Column(length = 20)
    private String phone;

    /**
     * 이메일 주소
     * 선택 입력 항목, 최대 100자
     */
    @Column(length = 100)
    private String email;

    @Column(name = "business_place_id", length = 7, nullable = false)
    private String businessPlaceId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "business_place_id", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private BusinessPlace businessPlace;

    /**
     * 회원 소유자 ID (Ownership 기반 권한 체크)
     *
     * 권한 규칙:
     * - 소유자: 수정/삭제 가능
     * - 같은 Role: 수정 가능, 삭제 불가
     * - 상위 Role: 수정/삭제 가능
     */
    @Column(name = "owner_id")
    private UUID ownerId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private User owner;

    /**
     * 마지막으로 수정한 사용자 ID
     */
    @Column(name = "last_modified_by_id")
    private UUID lastModifiedById;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "last_modified_by_id", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private User lastModifiedBy;

    @Column(length = 20)
    private String grade;

    /**
     * 회원 비고
     * 추가 메모나 특이사항 기록용
     */
    @Column(columnDefinition = "TEXT")
    private String remark;

    /**
     * Soft Delete 여부
     * true인 경우 삭제 대기 상태
     */
    @Column(name = "is_deleted", nullable = false)
    private Boolean isDeleted = false;

    /**
     * 삭제 요청 시간
     */
    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    /**
     * 삭제 요청자 ID
     */
    @Column(name = "deleted_by")
    private UUID deletedBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "deleted_by", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private User deletedByUser;

    /**
     * 레코드 생성 시간
     * 자동으로 현재 시간이 설정되며, 이후 변경 불가 (updatable = false)
     */
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * 레코드 최종 수정 시간
     * 엔티티가 업데이트될 때마다 자동으로 현재 시간으로 갱신됨
     */
    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

}