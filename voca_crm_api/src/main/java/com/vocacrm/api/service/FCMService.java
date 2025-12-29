package com.vocacrm.api.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * Firebase Cloud Messaging 서비스
 *
 * Push 알람 전송을 담당합니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FCMService {

    /**
     * FCM Push 알람 전송 (기본)
     *
     * @param fcmToken 대상 사용자의 FCM 토큰
     * @param title 알람 제목
     * @param body 알람 내용
     */
    public void sendPushNotification(String fcmToken, String title, String body) {
        sendPushNotificationWithData(fcmToken, title, body, null);
    }

    /**
     * FCM Push 알람 전송 (데이터 포함)
     *
     * @param fcmToken 대상 사용자의 FCM 토큰
     * @param title 알람 제목
     * @param body 알람 내용
     * @param data 추가 데이터 (타입, ID 등)
     */
    public void sendPushNotificationWithData(String fcmToken, String title, String body, Map<String, String> data) {
        if (fcmToken == null || fcmToken.isEmpty()) {
            log.warn("FCM token is null or empty. Skipping push notification.");
            return;
        }

        try {
            Message.Builder messageBuilder = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build());

            // 데이터 필드 추가 (Flutter에서 포그라운드 메시지 처리용)
            if (data != null && !data.isEmpty()) {
                messageBuilder.putAllData(data);
            }

            String response = FirebaseMessaging.getInstance().send(messageBuilder.build());
        } catch (Exception e) {
            log.error("Failed to send FCM message to token: {}", fcmToken, e);
        }
    }

    /**
     * 사업장 접근 요청 알람 (Owner에게)
     *
     * @param fcmToken Owner의 FCM 토큰
     * @param requesterName 요청자 이름
     * @param businessPlaceName 사업장 이름
     * @param businessPlaceId 사업장 ID
     * @param requesterId 요청자 ID
     */
    public void sendAccessRequestNotification(
            String fcmToken,
            String requesterName,
            String businessPlaceName,
            String businessPlaceId,
            String requesterId) {
        String title = "새로운 사업장 접근 요청";
        String body = String.format("%s님이 %s 사업장에 접근 요청을 보냈습니다.", requesterName, businessPlaceName);

        Map<String, String> data = Map.of(
                "type", "ACCESS_REQUEST",
                "businessPlaceId", businessPlaceId != null ? businessPlaceId : "",
                "businessPlaceName", businessPlaceName != null ? businessPlaceName : "",
                "requesterId", requesterId != null ? requesterId : "",
                "requesterName", requesterName != null ? requesterName : ""
        );

        sendPushNotificationWithData(fcmToken, title, body, data);
    }

    /**
     * 요청 승인 알람 (요청자에게)
     *
     * @param fcmToken 요청자의 FCM 토큰
     * @param businessPlaceName 사업장 이름
     * @param businessPlaceId 사업장 ID
     */
    public void sendRequestApprovedNotification(String fcmToken, String businessPlaceName, String businessPlaceId) {
        String title = "사업장 접근 요청 승인";
        String body = String.format("%s 사업장 접근 요청이 승인되었습니다.", businessPlaceName);

        Map<String, String> data = Map.of(
                "type", "ACCESS_APPROVED",
                "businessPlaceId", businessPlaceId != null ? businessPlaceId : "",
                "businessPlaceName", businessPlaceName != null ? businessPlaceName : ""
        );

        sendPushNotificationWithData(fcmToken, title, body, data);
    }

    /**
     * 요청 거절 알람 (요청자에게)
     *
     * @param fcmToken 요청자의 FCM 토큰
     * @param businessPlaceName 사업장 이름
     * @param businessPlaceId 사업장 ID
     */
    public void sendRequestRejectedNotification(String fcmToken, String businessPlaceName, String businessPlaceId) {
        String title = "사업장 접근 요청 거절";
        String body = String.format("%s 사업장 접근 요청이 거절되었습니다.", businessPlaceName);

        Map<String, String> data = Map.of(
                "type", "ACCESS_REJECTED",
                "businessPlaceId", businessPlaceId != null ? businessPlaceId : "",
                "businessPlaceName", businessPlaceName != null ? businessPlaceName : ""
        );

        sendPushNotificationWithData(fcmToken, title, body, data);
    }
}
