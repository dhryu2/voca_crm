package com.vocacrm.api.service;

import com.vocacrm.api.model.Notice;
import com.vocacrm.api.model.UserNoticeView;
import com.vocacrm.api.repository.NoticeRepository;
import com.vocacrm.api.repository.UserNoticeViewRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 공지사항 Service
 *
 * 공지사항 관련 비즈니스 로직을 처리합니다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NoticeService {

    private final NoticeRepository noticeRepository;
    private final UserNoticeViewRepository userNoticeViewRepository;

    /**
     * 시스템 관리자 권한 확인
     *
     * @param isSystemAdmin 시스템 관리자 여부
     * @throws SecurityException 관리자 권한이 없는 경우
     */
    private void requireSystemAdmin(Boolean isSystemAdmin) {
        if (isSystemAdmin == null || !isSystemAdmin) {
            throw new SecurityException("시스템 관리자 권한이 필요합니다");
        }
    }

    /**
     * 특정 사용자가 볼 수 있는 활성 공지사항 조회
     *
     * 조건:
     * - 현재 활성화된 공지사항
     * - 사용자가 "다시 보지 않기"를 체크하지 않은 공지사항
     */
    public List<Notice> getActiveNoticesForUser(String userId) {
        // 1. 현재 활성화된 모든 공지사항 조회
        List<Notice> activeNotices = noticeRepository.findActiveNotices(LocalDateTime.now());

        // 2. 사용자가 "다시 보지 않기"를 체크한 공지사항 ID 목록
        List<UUID> hiddenNoticeIds = userNoticeViewRepository
                .findByUserIdAndDoNotShowAgainTrue(UUID.fromString(userId))
                .stream()
                .map(UserNoticeView::getNoticeId)
                .collect(Collectors.toList());

        // 3. "다시 보지 않기" 체크한 공지사항 제외
        return activeNotices.stream()
                .filter(notice -> !hiddenNoticeIds.contains(notice.getId()))
                .collect(Collectors.toList());
    }

    /**
     * 모든 공지사항 조회 (관리자용)
     *
     * @param isSystemAdmin 시스템 관리자 여부 (JWT에서 추출)
     * @return 전체 공지사항 목록
     * @throws SecurityException 관리자 권한이 없는 경우
     */
    public List<Notice> getAllNotices(Boolean isSystemAdmin) {
        requireSystemAdmin(isSystemAdmin);
        return noticeRepository.findAllByOrderByPriorityDescCreatedAtDesc();
    }

    /**
     * ID로 공지사항 조회 (내부용)
     */
    public Notice getNoticeById(String id) {
        return noticeRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new RuntimeException("Notice not found with id: " + id));
    }

    /**
     * ID로 공지사항 조회 (관리자용)
     *
     * @param id 공지사항 ID
     * @param isSystemAdmin 시스템 관리자 여부 (JWT에서 추출)
     * @return 공지사항
     * @throws SecurityException 관리자 권한이 없는 경우
     */
    public Notice getNoticeByIdForAdmin(String id, Boolean isSystemAdmin) {
        requireSystemAdmin(isSystemAdmin);
        return getNoticeById(id);
    }

    /**
     * 공지사항 생성 (관리자용)
     *
     * @param notice 생성할 공지사항
     * @param isSystemAdmin 시스템 관리자 여부 (JWT에서 추출)
     * @return 생성된 공지사항
     * @throws SecurityException 관리자 권한이 없는 경우
     */
    @Transactional
    public Notice createNotice(Notice notice, Boolean isSystemAdmin) {
        requireSystemAdmin(isSystemAdmin);
        return noticeRepository.save(notice);
    }

    /**
     * 공지사항 수정 (관리자용)
     *
     * @param id 공지사항 ID
     * @param noticeDetails 수정할 내용
     * @param isSystemAdmin 시스템 관리자 여부 (JWT에서 추출)
     * @return 수정된 공지사항
     * @throws SecurityException 관리자 권한이 없는 경우
     */
    @Transactional
    public Notice updateNotice(String id, Notice noticeDetails, Boolean isSystemAdmin) {
        requireSystemAdmin(isSystemAdmin);
        Notice notice = getNoticeById(id);

        if (noticeDetails.getTitle() != null) notice.setTitle(noticeDetails.getTitle());
        if (noticeDetails.getContent() != null) notice.setContent(noticeDetails.getContent());
        if (noticeDetails.getStartDate() != null) notice.setStartDate(noticeDetails.getStartDate());
        if (noticeDetails.getEndDate() != null) notice.setEndDate(noticeDetails.getEndDate());
        if (noticeDetails.getPriority() != null) notice.setPriority(noticeDetails.getPriority());
        if (noticeDetails.getIsActive() != null) notice.setIsActive(noticeDetails.getIsActive());

        return noticeRepository.save(notice);
    }

    /**
     * 공지사항 삭제 (관리자용)
     *
     * @param id 공지사항 ID
     * @param isSystemAdmin 시스템 관리자 여부 (JWT에서 추출)
     * @throws SecurityException 관리자 권한이 없는 경우
     */
    @Transactional
    public void deleteNotice(String id, Boolean isSystemAdmin) {
        requireSystemAdmin(isSystemAdmin);
        noticeRepository.deleteById(UUID.fromString(id));
    }

    /**
     * 공지사항 열람 기록 저장
     *
     * @param userId 사용자 ID
     * @param noticeId 공지사항 ID
     * @param doNotShowAgain 다시 보지 않기 체크 여부
     */
    @Transactional
    public void recordView(String userId, String noticeId, boolean doNotShowAgain) {
        // 원자적 upsert(ON CONFLICT). check-then-insert 의 TOCTOU 경합(동시 최초 열람 시 uk_user_notice
        // 위반 → 500)을 제거한다. catch-in-transaction 방식은 제약 위반이 트랜잭션을 rollback-only 로
        // 오염시켜 동작하지 않으므로, DB 레벨 원자적 upsert 로 처리한다(WB-10).
        userNoticeViewRepository.upsertView(
                UUID.fromString(userId), UUID.fromString(noticeId), doNotShowAgain);
    }

    /**
     * 공지사항 통계 조회 (관리자용)
     *
     * @param noticeId 공지사항 ID
     * @param isSystemAdmin 시스템 관리자 여부 (JWT에서 추출)
     * @return 열람 수, "다시 보지 않기" 체크 수
     * @throws SecurityException 관리자 권한이 없는 경우
     */
    public Map<String, Long> getNoticeStats(String noticeId, Boolean isSystemAdmin) {
        requireSystemAdmin(isSystemAdmin);
        UUID noticeUuid = UUID.fromString(noticeId);
        long viewCount = userNoticeViewRepository.countByNoticeId(noticeUuid);
        long hideCount = userNoticeViewRepository.countByNoticeIdAndDoNotShowAgainTrue(noticeUuid);

        Map<String, Long> stats = new HashMap<>();
        stats.put("viewCount", viewCount);
        stats.put("hideCount", hideCount);
        return stats;
    }
}
