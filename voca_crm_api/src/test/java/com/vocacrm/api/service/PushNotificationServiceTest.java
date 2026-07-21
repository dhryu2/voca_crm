package com.vocacrm.api.service;

import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.DeviceToken;
import com.vocacrm.api.repository.DeviceTokenRepository;
import com.vocacrm.api.repository.NotificationLogRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PushNotificationServiceTest {

    @Mock
    private DeviceTokenRepository deviceTokenRepository;
    @Mock
    private NotificationLogRepository notificationLogRepository;

    @InjectMocks
    private PushNotificationService pushNotificationService;

    @Test
    void deactivateToken_본인_토큰이면_정상적으로_비활성화한다() {
        UUID userId = UUID.randomUUID();
        DeviceToken token = DeviceToken.builder().userId(userId).fcmToken("fcm-1").build();
        when(deviceTokenRepository.findByFcmToken("fcm-1")).thenReturn(Optional.of(token));

        assertThatCode(() -> pushNotificationService.deactivateToken(userId.toString(), "fcm-1"))
                .doesNotThrowAnyException();

        verify(deviceTokenRepository).deactivateByFcmToken("fcm-1");
    }

    @Test
    void deactivateToken_타인_토큰이면_AccessDeniedException을_던진다() {
        UUID ownerId = UUID.randomUUID();
        UUID otherUserId = UUID.randomUUID();
        DeviceToken token = DeviceToken.builder().userId(ownerId).fcmToken("fcm-2").build();
        when(deviceTokenRepository.findByFcmToken("fcm-2")).thenReturn(Optional.of(token));

        assertThatThrownBy(() -> pushNotificationService.deactivateToken(otherUserId.toString(), "fcm-2"))
                .isInstanceOf(AccessDeniedException.class);

        verify(deviceTokenRepository, never()).deactivateByFcmToken(anyString());
    }

    @Test
    void deactivateToken_존재하지_않는_토큰이면_예외없이_무시한다() {
        when(deviceTokenRepository.findByFcmToken("unknown-token")).thenReturn(Optional.empty());

        assertThatCode(() -> pushNotificationService.deactivateToken(UUID.randomUUID().toString(), "unknown-token"))
                .doesNotThrowAnyException();

        verify(deviceTokenRepository, never()).deactivateByFcmToken(anyString());
    }
}
