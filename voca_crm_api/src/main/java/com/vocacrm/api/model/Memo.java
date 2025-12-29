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
 * 메모(Memo) 엔티티 클래스
 *
 * VocaCRM 시스템에서 회원별 메모 정보를 담는 JPA 엔티티입니다.
 * PostgreSQL의 'memos' 테이블과 매핑됩니다.
 *
 * 주요 특징:
 * - 회원(Member)과 다대일(Many-to-One) 관계
 * - 하나의 회원에 대해 여러 개의 메모 작성 가능
 * - 지연 로딩(LAZY)을 통한 성능 최적화
 * - TEXT 타입을 사용하여 긴 메모 내용 지원
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@Data // Lombok: Getter, Setter, toString, equals, hashCode 자동 생성
@Entity // JPA 엔티티임을 표시
@Table(name = "memos") // 매핑될 데이터베이스 테이블명 지정
public class Memo {

    /**
     * 메모 고유 식별자 (Primary Key)
     */
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 메모가 속한 회원의 ID (Foreign Key)
     * Member 엔티티의 id와 연관됨
     * 필수 입력 항목 (nullable = false)
     */
    @Column(name = "member_id", nullable = false)
    private UUID memberId;

    /**
     * 메모 내용
     * TEXT 타입을 사용하여 제한 없이 긴 내용 저장 가능
     * 필수 입력 항목 (nullable = false)
     */
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    /**
     * 중요 메모 여부
     * true면 중요 메모로 표시되어 상단에 노출
     */
    @Column(name = "is_important", nullable = false)
    private Boolean isImportant = false;

    /**
     * 메모 소유자 ID (Ownership 기반 권한 체크)
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

    /**
     * 연관된 회원 엔티티
     *
     * 다대일(Many-to-One) 관계 설정:
     * - LAZY 페치 전략: 실제 사용 시점까지 로딩 지연 (성능 최적화)
     * - insertable/updatable = false: 외래키 관리는 memberId 필드에서 담당
     * (member 객체를 통한 직접 수정 방지, 무결성 보장)
     *
     * 사용 예:
     * - memo.getMember().getName() 호출 시 LAZY 로딩으로 Member 조회
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private Member member;

}