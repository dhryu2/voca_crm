package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.UserNoticeView;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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

    /**
     * 열람 기록 원자적 upsert (WB-10).
     * check-then-insert 의 TOCTOU 경합(동시 최초 열람 시 uk_user_notice 위반 → 500)을 제거하기 위해
     * PostgreSQL ON CONFLICT 로 삽입-또는-갱신을 한 번의 원자적 쿼리로 처리한다.
     */
    @Modifying
    @Query(value =
            "INSERT INTO user_notice_views (id, user_id, notice_id, viewed_at, do_not_show_again) " +
            "VALUES (gen_random_uuid(), :userId, :noticeId, now(), :doNotShowAgain) " +
            "ON CONFLICT (user_id, notice_id) " +
            "DO UPDATE SET viewed_at = now(), do_not_show_again = :doNotShowAgain",
            nativeQuery = true)
    void upsertView(@Param("userId") UUID userId,
                    @Param("noticeId") UUID noticeId,
                    @Param("doNotShowAgain") boolean doNotShowAgain);
}
