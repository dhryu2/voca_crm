package com.vocacrm.api.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * FCMService는 Firebase Admin SDK의 정적 메서드(FirebaseMessaging.getInstance())를 통해
 * 실제 푸시를 전송한다. 정적 호출은 Mockito의 mockStatic으로 스텁해 정상/예외 분기를 검증한다.
 */
@ExtendWith(MockitoExtension.class)
class FCMServiceTest {

    @InjectMocks
    private FCMService fcmService;

    private MockedStatic<FirebaseMessaging> firebaseMessagingStatic;
    private FirebaseMessaging firebaseMessaging;

    @BeforeEach
    void setUp() {
        firebaseMessagingStatic = mockStatic(FirebaseMessaging.class);
        firebaseMessaging = mock(FirebaseMessaging.class);
        firebaseMessagingStatic.when(FirebaseMessaging::getInstance).thenReturn(firebaseMessaging);
    }

    @AfterEach
    void tearDown() {
        firebaseMessagingStatic.close();
    }

    @Test
    void sendPushNotificationWithData_토큰이_null이면_전송하지_않는다() {
        fcmService.sendPushNotificationWithData(null, "제목", "내용", null);

        firebaseMessagingStatic.verifyNoInteractions();
    }

    @Test
    void sendPushNotificationWithData_토큰이_빈문자열이면_전송하지_않는다() throws FirebaseMessagingException {
        fcmService.sendPushNotificationWithData("", "제목", "내용", null);

        verify(firebaseMessaging, never()).send(any(Message.class));
    }

    @Test
    void sendPushNotificationWithData_정상_케이스면_전송한다() throws FirebaseMessagingException {
        when(firebaseMessaging.send(any(Message.class))).thenReturn("projects/x/messages/1");

        fcmService.sendPushNotificationWithData("token-123", "제목", "내용", null);

        verify(firebaseMessaging, times(1)).send(any(Message.class));
    }

    @Test
    void sendPushNotificationWithData_데이터가_있으면_함께_전송한다() throws FirebaseMessagingException {
        when(firebaseMessaging.send(any(Message.class))).thenReturn("projects/x/messages/1");

        fcmService.sendPushNotificationWithData("token-123", "제목", "내용", Map.of("type", "TEST"));

        verify(firebaseMessaging, times(1)).send(any(Message.class));
    }

    @Test
    void sendPushNotificationWithData_전송_실패시_예외를_전파하지_않는다() throws FirebaseMessagingException {
        when(firebaseMessaging.send(any(Message.class)))
                .thenThrow(mock(FirebaseMessagingException.class));

        fcmService.sendPushNotificationWithData("token-123", "제목", "내용", null);

        verify(firebaseMessaging, times(1)).send(any(Message.class));
    }

    @Test
    void sendPushNotification_기본_전송은_데이터없이_위임한다() throws FirebaseMessagingException {
        when(firebaseMessaging.send(any(Message.class))).thenReturn("projects/x/messages/1");

        fcmService.sendPushNotification("token-123", "제목", "내용");

        verify(firebaseMessaging, times(1)).send(any(Message.class));
    }

    @Test
    void sendAccessRequestNotification_요청자_정보로_알람을_전송한다() throws FirebaseMessagingException {
        when(firebaseMessaging.send(any(Message.class))).thenReturn("projects/x/messages/1");

        fcmService.sendAccessRequestNotification("token-123", "홍길동", "강남점", "biz-1", "user-1");

        verify(firebaseMessaging, times(1)).send(any(Message.class));
    }

    @Test
    void sendAccessRequestNotification_null_필드도_안전하게_처리한다() throws FirebaseMessagingException {
        when(firebaseMessaging.send(any(Message.class))).thenReturn("projects/x/messages/1");

        fcmService.sendAccessRequestNotification("token-123", null, null, null, null);

        verify(firebaseMessaging, times(1)).send(any(Message.class));
    }

    @Test
    void sendRequestApprovedNotification_승인_알람을_전송한다() throws FirebaseMessagingException {
        when(firebaseMessaging.send(any(Message.class))).thenReturn("projects/x/messages/1");

        fcmService.sendRequestApprovedNotification("token-123", "강남점", "biz-1");

        verify(firebaseMessaging, times(1)).send(any(Message.class));
    }

    @Test
    void sendRequestRejectedNotification_거절_알람을_전송한다() throws FirebaseMessagingException {
        when(firebaseMessaging.send(any(Message.class))).thenReturn("projects/x/messages/1");

        fcmService.sendRequestRejectedNotification("token-123", "강남점", "biz-1");

        verify(firebaseMessaging, times(1)).send(any(Message.class));
    }
}
