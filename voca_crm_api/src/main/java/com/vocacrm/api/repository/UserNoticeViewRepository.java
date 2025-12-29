package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.UserNoticeView;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 사용자 공지사항 열람 기록 Repository
 *
 * UserNoticeView 엔티티에 대한 데이터베이스 접근을 담당합니다.
 */
@Repository
public interface UserNoticeViewRepository extends JpaRepository<UserNoticeView, UUID> {

    /**
     * 특정 사용자가 특정 공지사항을 읽은 기록 조회
     */
    Optional<UserNoticeView> findByUserIdAndNoticeId(UUID userId, UUID noticeId);

    /**
     * 특정 사용자가 "다시 보지 않기"를 체크한 공지사항 ID 목록
     */
    List<UserNoticeView> findByUserIdAndDoNotShowAgainTrue(UUID userId);

    /**
     * 특정 공지사항의 열람 기록 조회 (통계용)
     */
    List<UserNoticeView> findByNoticeId(UUID noticeId);

    /**
     * 특정 공지사항의 열람 수 카운트
     */
    long countByNoticeId(UUID noticeId);

    /**
     * 특정 공지사항의 "다시 보지 않기" 체크 수 카운트
     */
    long countByNoticeIdAndDoNotShowAgainTrue(UUID noticeId);
}
