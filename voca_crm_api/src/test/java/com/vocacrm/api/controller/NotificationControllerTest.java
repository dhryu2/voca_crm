package com.vocacrm.api.controller;

import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.DeviceToken;
import com.vocacrm.api.model.NotificationLog;
import com.vocacrm.api.repository.NotificationLogRepository;
import com.vocacrm.api.service.AdminService;
import com.vocacrm.api.service.PushNotificationService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NotificationControllerTest {

    private static final String JWT_USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String BODY_USER_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";

    @Mock
    private PushNotificationService pushNotificationService;
    @Mock
    private NotificationLogRepository notificationLogRepository;
    @Mock
    private AdminService adminService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private NotificationController notificationController;

    @BeforeEach
    void setUp() {
        lenient().when(servletRequest.getAttribute("userId")).thenReturn(JWT_USER_ID);
    }

    @Test
    void registerToken_JWT_userId를_서비스에_전달하고_바디의_userId는_무시한다() {
        NotificationController.TokenRegistrationRequest request =
                new NotificationController.TokenRegistrationRequest(
                        BODY_USER_ID, "fcm-token-1", DeviceToken.DeviceType.ANDROID, "Pixel 7", "1.0.0");
        DeviceToken token = DeviceToken.builder()
                .userId(UUID.fromString(JWT_USER_ID))
                .fcmToken("fcm-token-1")
                .build();
        when(pushNotificationService.registerToken(
                JWT_USER_ID, "fcm-token-1", DeviceToken.DeviceType.ANDROID, "Pixel 7", "1.0.0"))
                .thenReturn(token);

        ResponseEntity<DeviceToken> response = notificationController.registerToken(request, servletRequest);

        verify(pushNotificationService).registerToken(
                JWT_USER_ID, "fcm-token-1", DeviceToken.DeviceType.ANDROID, "Pixel 7", "1.0.0");
        verify(pushNotificationService, never()).registerToken(
                eq(BODY_USER_ID), anyString(), eq(DeviceToken.DeviceType.ANDROID), anyString(), anyString());
        assertThat(response.getBody()).isSameAs(token);
    }

    @Test
    void deactivateToken_JWT_userId를_서비스에_전달한다() {
        NotificationController.TokenDeactivationRequest request =
                new NotificationController.TokenDeactivationRequest("fcm-token-1");

        notificationController.deactivateToken(request, servletRequest);

        verify(pushNotificationService).deactivateToken(JWT_USER_ID, "fcm-token-1");
    }

    @Test
    void deactivateAllTokens_JWT_userId의_모든_토큰을_비활성화한다() {
        ResponseEntity<Void> response = notificationController.deactivateAllTokens(servletRequest);

        verify(pushNotificationService).deactivateAllUserTokens(JWT_USER_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void getNotifications_JWT_userId의_알림_목록을_페이징하여_반환한다() {
        Page<NotificationLog> page = new PageImpl<>(List.of(NotificationLog.builder().build()));
        when(notificationLogRepository.findByUserIdOrderByCreatedAtDesc(
                UUID.fromString(JWT_USER_ID), PageRequest.of(0, 20)))
                .thenReturn(page);

        ResponseEntity<Page<NotificationLog>> response =
                notificationController.getNotifications(servletRequest, 0, 20);

        assertThat(response.getBody()).isSameAs(page);
    }

    @Test
    void getUnreadNotifications_JWT_userId의_읽지_않은_알림_목록을_반환한다() {
        List<NotificationLog> unread = List.of(NotificationLog.builder().build());
        when(notificationLogRepository.findByUserIdAndIsReadFalseAndStatusOrderByCreatedAtDesc(
                UUID.fromString(JWT_USER_ID), NotificationLog.NotificationStatus.SENT))
                .thenReturn(unread);

        ResponseEntity<List<NotificationLog>> response = notificationController.getUnreadNotifications(servletRequest);

        assertThat(response.getBody()).isSameAs(unread);
    }

    @Test
    void getUnreadCount_JWT_userId의_읽지_않은_알림_수를_반환한다() {
        when(pushNotificationService.getUnreadCount(JWT_USER_ID)).thenReturn(3L);

        ResponseEntity<Map<String, Long>> response = notificationController.getUnreadCount(servletRequest);

        assertThat(response.getBody()).containsEntry("count", 3L);
    }

    @Test
    void markAsRead_본인_알림이면_읽음_처리된다() {
        String notificationId = "cccccccc-dddd-eeee-ffff-000000000000";
        NotificationLog notification = NotificationLog.builder()
                .id(UUID.fromString(notificationId))
                .userId(UUID.fromString(JWT_USER_ID))
                .build();
        when(notificationLogRepository.findById(UUID.fromString(notificationId)))
                .thenReturn(Optional.of(notification));

        ResponseEntity<Void> response = notificationController.markAsRead(notificationId, servletRequest);

        verify(pushNotificationService).markAsRead(notificationId);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void markAsRead_알림이_존재하지_않으면_AccessDeniedException() {
        String notificationId = "cccccccc-dddd-eeee-ffff-000000000000";
        when(notificationLogRepository.findById(UUID.fromString(notificationId)))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> notificationController.markAsRead(notificationId, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void markAsRead_타인의_알림이면_AccessDeniedException() {
        String notificationId = "cccccccc-dddd-eeee-ffff-000000000000";
        NotificationLog notification = NotificationLog.builder()
                .id(UUID.fromString(notificationId))
                .userId(UUID.fromString(BODY_USER_ID))
                .build();
        when(notificationLogRepository.findById(UUID.fromString(notificationId)))
                .thenReturn(Optional.of(notification));

        assertThatThrownBy(() -> notificationController.markAsRead(notificationId, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void markAllAsRead_JWT_userId의_모든_알림을_읽음_처리한다() {
        ResponseEntity<Void> response = notificationController.markAllAsRead(servletRequest);

        verify(pushNotificationService).markAllAsRead(JWT_USER_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void sendTestNotification_시스템관리자면_테스트_알림을_발송한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        NotificationController.TestNotificationRequest request =
                new NotificationController.TestNotificationRequest(BODY_USER_ID, "제목", "본문");

        ResponseEntity<Map<String, String>> response =
                notificationController.sendTestNotification(request, servletRequest);

        verify(pushNotificationService).sendToUser(
                eq(BODY_USER_ID),
                eq(NotificationLog.NotificationType.SYSTEM_ANNOUNCEMENT),
                eq("제목"),
                eq("본문"),
                eq(null),
                eq(null),
                eq(Map.of("type", "TEST")));
        assertThat(response.getBody()).containsEntry("message", "Test notification sent");
    }

    @Test
    void sendTestNotification_시스템관리자가_아니면_AccessDeniedException_전파() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.FALSE);
        doThrow(new AccessDeniedException("시스템 관리자 권한이 필요합니다."))
                .when(adminService).validateSystemAdmin(Boolean.FALSE);
        NotificationController.TestNotificationRequest request =
                new NotificationController.TestNotificationRequest(BODY_USER_ID, "제목", "본문");

        assertThatThrownBy(() -> notificationController.sendTestNotification(request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }
}
