package com.vocacrm.api.service;

import com.vocacrm.api.model.Notice;
import com.vocacrm.api.model.UserNoticeView;
import com.vocacrm.api.repository.NoticeRepository;
import com.vocacrm.api.repository.UserNoticeViewRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NoticeServiceTest {

    @Mock
    private NoticeRepository noticeRepository;

    @Mock
    private UserNoticeViewRepository userNoticeViewRepository;

    @InjectMocks
    private NoticeService noticeService;

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";

    private Notice newNotice(UUID id) {
        Notice notice = new Notice();
        notice.setId(id);
        notice.setTitle("제목");
        notice.setContent("내용");
        notice.setStartDate(LocalDateTime.now().minusDays(1));
        notice.setEndDate(LocalDateTime.now().plusDays(1));
        notice.setPriority(0);
        notice.setIsActive(true);
        return notice;
    }

    // ===== getActiveNoticesForUser =====

    @Test
    void getActiveNoticesForUser_다시보지않기_체크한_공지는_제외한다() {
        UUID hiddenId = UUID.randomUUID();
        UUID visibleId = UUID.randomUUID();
        Notice hiddenNotice = newNotice(hiddenId);
        Notice visibleNotice = newNotice(visibleId);

        UserNoticeView hiddenView = new UserNoticeView();
        hiddenView.setNoticeId(hiddenId);

        when(noticeRepository.findActiveNotices(any(LocalDateTime.class)))
                .thenReturn(List.of(hiddenNotice, visibleNotice));
        when(userNoticeViewRepository.findByUserIdAndDoNotShowAgainTrue(UUID.fromString(USER_ID)))
                .thenReturn(List.of(hiddenView));

        List<Notice> result = noticeService.getActiveNoticesForUser(USER_ID);

        assertThat(result).containsExactly(visibleNotice);
    }

    @Test
    void getActiveNoticesForUser_숨긴_공지가_없으면_전체를_반환한다() {
        Notice notice = newNotice(UUID.randomUUID());

        when(noticeRepository.findActiveNotices(any(LocalDateTime.class))).thenReturn(List.of(notice));
        when(userNoticeViewRepository.findByUserIdAndDoNotShowAgainTrue(UUID.fromString(USER_ID)))
                .thenReturn(List.of());

        List<Notice> result = noticeService.getActiveNoticesForUser(USER_ID);

        assertThat(result).containsExactly(notice);
    }

    // ===== getAllNotices =====

    @Test
    void getAllNotices_관리자면_전체_목록을_반환한다() {
        Notice notice = newNotice(UUID.randomUUID());
        when(noticeRepository.findAllByOrderByPriorityDescCreatedAtDesc()).thenReturn(List.of(notice));

        List<Notice> result = noticeService.getAllNotices(true);

        assertThat(result).containsExactly(notice);
    }

    @Test
    void getAllNotices_관리자가_아니면_SecurityException을_던진다() {
        assertThatThrownBy(() -> noticeService.getAllNotices(false))
                .isInstanceOf(SecurityException.class);
    }

    @Test
    void getAllNotices_isSystemAdmin이_null이면_SecurityException을_던진다() {
        assertThatThrownBy(() -> noticeService.getAllNotices(null))
                .isInstanceOf(SecurityException.class);
    }

    // ===== getNoticeById / getNoticeByIdForAdmin =====

    @Test
    void getNoticeById_정상_케이스면_공지사항을_반환한다() {
        UUID id = UUID.randomUUID();
        Notice notice = newNotice(id);
        when(noticeRepository.findById(id)).thenReturn(Optional.of(notice));

        Notice result = noticeService.getNoticeById(id.toString());

        assertThat(result).isEqualTo(notice);
    }

    @Test
    void getNoticeById_존재하지_않으면_RuntimeException을_던진다() {
        UUID id = UUID.randomUUID();
        when(noticeRepository.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> noticeService.getNoticeById(id.toString()))
                .isInstanceOf(RuntimeException.class);
    }

    @Test
    void getNoticeByIdForAdmin_관리자가_아니면_SecurityException을_던진다() {
        String id = UUID.randomUUID().toString();

        assertThatThrownBy(() -> noticeService.getNoticeByIdForAdmin(id, false))
                .isInstanceOf(SecurityException.class);

        verify(noticeRepository, never()).findById(any(UUID.class));
    }

    // ===== createNotice =====

    @Test
    void createNotice_관리자면_공지사항을_생성한다() {
        Notice notice = newNotice(null);
        when(noticeRepository.save(notice)).thenReturn(notice);

        Notice result = noticeService.createNotice(notice, true);

        assertThat(result).isEqualTo(notice);
    }

    @Test
    void createNotice_관리자가_아니면_SecurityException을_던진다() {
        Notice notice = newNotice(null);

        assertThatThrownBy(() -> noticeService.createNotice(notice, false))
                .isInstanceOf(SecurityException.class);

        verify(noticeRepository, never()).save(any(Notice.class));
    }

    // ===== updateNotice =====

    @Test
    void updateNotice_정상_케이스면_변경된_필드만_반영한다() {
        UUID id = UUID.randomUUID();
        Notice existing = newNotice(id);
        existing.setTitle("기존 제목");

        Notice details = new Notice();
        details.setTitle("새 제목");

        when(noticeRepository.findById(id)).thenReturn(Optional.of(existing));
        when(noticeRepository.save(any(Notice.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Notice result = noticeService.updateNotice(id.toString(), details, true);

        assertThat(result.getTitle()).isEqualTo("새 제목");
        assertThat(result.getContent()).isEqualTo("내용");
    }

    @Test
    void updateNotice_관리자가_아니면_SecurityException을_던진다() {
        String id = UUID.randomUUID().toString();

        assertThatThrownBy(() -> noticeService.updateNotice(id, new Notice(), false))
                .isInstanceOf(SecurityException.class);

        verify(noticeRepository, never()).save(any(Notice.class));
    }

    // ===== deleteNotice =====

    @Test
    void deleteNotice_관리자면_삭제한다() {
        UUID id = UUID.randomUUID();

        noticeService.deleteNotice(id.toString(), true);

        verify(noticeRepository).deleteById(id);
    }

    @Test
    void deleteNotice_관리자가_아니면_SecurityException을_던지고_삭제하지_않는다() {
        String id = UUID.randomUUID().toString();

        assertThatThrownBy(() -> noticeService.deleteNotice(id, false))
                .isInstanceOf(SecurityException.class);

        verify(noticeRepository, never()).deleteById(any(UUID.class));
    }

    // ===== recordView =====

    @Test
    void recordView_기존_기록이_있으면_업데이트한다() {
        UUID userUuid = UUID.fromString(USER_ID);
        UUID noticeUuid = UUID.randomUUID();

        noticeService.recordView(USER_ID, noticeUuid.toString(), true);

        // 원자적 upsert(ON CONFLICT)로 삽입-또는-갱신을 처리한다(WB-10). 기존 기록이 있으면 do_not_show_again 갱신.
        verify(userNoticeViewRepository).upsertView(userUuid, noticeUuid, true);
    }

    @Test
    void recordView_기존_기록이_없으면_새로_생성한다() {
        UUID userUuid = UUID.fromString(USER_ID);
        UUID noticeUuid = UUID.randomUUID();

        noticeService.recordView(USER_ID, noticeUuid.toString(), false);

        // 기록이 없으면 삽입 — 동일한 upsert 로 처리(동시 최초 열람 경합도 원자적으로 안전)
        verify(userNoticeViewRepository).upsertView(userUuid, noticeUuid, false);
    }

    // ===== getNoticeStats =====

    @Test
    void getNoticeStats_관리자면_열람수와_숨김수를_반환한다() {
        UUID noticeUuid = UUID.randomUUID();
        when(userNoticeViewRepository.countByNoticeId(noticeUuid)).thenReturn(10L);
        when(userNoticeViewRepository.countByNoticeIdAndDoNotShowAgainTrue(noticeUuid)).thenReturn(3L);

        Map<String, Long> result = noticeService.getNoticeStats(noticeUuid.toString(), true);

        assertThat(result).containsEntry("viewCount", 10L).containsEntry("hideCount", 3L);
    }

    @Test
    void getNoticeStats_관리자가_아니면_SecurityException을_던진다() {
        String id = UUID.randomUUID().toString();

        assertThatThrownBy(() -> noticeService.getNoticeStats(id, false))
                .isInstanceOf(SecurityException.class);

        verify(userNoticeViewRepository, never()).countByNoticeId(any(UUID.class));
    }
}
