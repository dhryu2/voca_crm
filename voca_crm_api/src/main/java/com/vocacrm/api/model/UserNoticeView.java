package com.vocacrm.api.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.ToString;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 사용자별 공지사항 열람 기록(UserNoticeView) 엔티티 클래스
 *
 * 각 사용자가 어떤 공지사항을 언제 읽었는지, "다시 보지 않기"를 체크했는지 추적합니다.
 * PostgreSQL의 'user_notice_views' 테이블과 매핑됩니다.
 *
 * 주요 특징:
 * - 사용자별 공지사항 열람 이력 추적
 * - "다시 보지 않기" 기능 지원
 * - (userId, noticeId) 조합으로 유니크 제약
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@Data
@Entity
@Table(
    name = "user_notice_views",
    uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "notice_id"})
)
public class UserNoticeView {

    /**
     * 열람 기록 고유 식별자 (Primary Key)
     */
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * 사용자 ID
     * 공지사항을 읽은 사용자
     */
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /**
     * 공지사항 ID (Foreign Key)
     * 읽은 공지사항
     */
    @Column(name = "notice_id", nullable = false)
    private UUID noticeId;

    /**
     * 열람 시각
     * 공지사항을 읽은 시간
     */
    @CreationTimestamp
    @Column(name = "viewed_at", nullable = false)
    private LocalDateTime viewedAt;

    /**
     * 다시 보지 않기 체크 여부
     * true: 해당 공지사항을 다시 표시하지 않음
     * false: 로그인할 때마다 계속 표시
     */
    @Column(name = "do_not_show_again", nullable = false)
    private Boolean doNotShowAgain = false;

    /**
     * 연관된 공지사항 엔티티
     * LAZY 페치 전략으로 성능 최적화
     * ON DELETE CASCADE: 공지사항 삭제 시 열람 기록도 함께 삭제
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "notice_id", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private Notice notice;

}
