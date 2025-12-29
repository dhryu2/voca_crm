package com.vocacrm.api.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 공지사항(Notice) 엔티티 클래스
 *
 * 시스템 관리자가 등록하는 공지사항 정보를 담는 JPA 엔티티입니다.
 * PostgreSQL의 'notices' 테이블과 매핑됩니다.
 *
 * 주요 특징:
 * - 시작일/종료일 기반 활성화 관리
 * - 우선순위 지원 (높을수록 먼저 표시)
 * - 작성자 추적
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@Data
@Entity
@Table(name = "notices")
public class Notice {

    /**
     * 공지사항 고유 식별자 (Primary Key)
     */
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 공지사항 제목
     * 필수 입력 항목
     */
    @Column(nullable = false, length = 200)
    private String title;

    /**
     * 공지사항 내용
     * TEXT 타입으로 긴 내용 지원
     * 필수 입력 항목
     */
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    /**
     * 공지사항 시작일
     * 이 날짜부터 공지사항이 활성화됨
     */
    @Column(name = "start_date", nullable = false)
    private LocalDateTime startDate;

    /**
     * 공지사항 종료일
     * 이 날짜까지 공지사항이 활성화됨
     */
    @Column(name = "end_date", nullable = false)
    private LocalDateTime endDate;

    /**
     * 우선순위
     * 높을수록 먼저 표시됨 (기본값: 0)
     */
    @Column(nullable = false)
    private Integer priority = 0;

    /**
     * 활성화 여부
     * 관리자가 수동으로 비활성화할 수 있음
     */
    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    /**
     * 작성자 사용자 ID
     * 공지사항을 작성한 관리자의 ID
     */
    @Column(name = "created_by_user_id")
    private UUID createdByUserId;

    /**
     * 레코드 생성 시간
     */
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * 레코드 최종 수정 시간
     */
    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

}
