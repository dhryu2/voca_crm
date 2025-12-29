package com.vocacrm.api.service;

import com.google.firebase.messaging.*;
import com.vocacrm.api.model.DeviceToken;
import com.vocacrm.api.model.NotificationLog;
import com.vocacrm.api.model.NotificationLog.NotificationStatus;
import com.vocacrm.api.model.NotificationLog.NotificationType;
import com.vocacrm.api.repository.DeviceTokenRepository;
import com.vocacrm.api.repository.NotificationLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * 푸시 알림 서비스
 *
 * Firebase Cloud Messaging(FCM)을 통해 푸시 알림을 발송합니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PushNotificationService {

    private final DeviceTokenRepository deviceTokenRepository;
    private final NotificationLogRepository notificationLogRepository;

    // ==================== 토큰 관리 ====================

    /**
     * FCM 토큰 등록/갱신
     */
    @Transactional
    public DeviceToken registerToken(
            String userId,
            String fcmToken,
            DeviceToken.DeviceType deviceType,
            String deviceInfo,
            String appVersion
    ) {
        // 기존 토큰이 있으면 업데이트
        Optional<DeviceToken> existing = deviceTokenRepository.findByFcmToken(fcmToken);

        UUID userUuid = UUID.fromString(userId);
        if (existing.isPresent()) {
            DeviceToken token = existing.get();
            // 다른 사용자의 토큰이면 소유권 이전
            if (!token.getUserId().equals(userUuid)) {
                token.setUserId(userUuid);
            }
            token.setIsActive(true);
            token.setDeviceType(deviceType);
            token.setDeviceInfo(deviceInfo);
            token.setAppVersion(appVersion);
            token.setLastUsedAt(LocalDateTime.now());
            return deviceTokenRepository.save(token);
        }

        // 새 토큰 생성
        DeviceToken newToken = DeviceToken.builder()
                .userId(userUuid)
                .fcmToken(fcmToken)
                .deviceType(deviceType)
                .deviceInfo(deviceInfo)
                .appVersion(appVersion)
                .isActive(true)
                .lastUsedAt(LocalDateTime.now())
                .build();

        return deviceTokenRepository.save(newToken);
    }

    /**
     * FCM 토큰 비활성화 (로그아웃 시)
     */
    @Transactional
    public void deactivateToken(String fcmToken) {
        deviceTokenRepository.deactivateByFcmToken(fcmToken);
    }

    /**
     * 사용자의 모든 토큰 비활성화 (모든 기기 로그아웃 시)
     */
    @Transactional
    public void deactivateAllUserTokens(String userId) {
        deviceTokenRepository.deactivateAllByUserId(UUID.fromString(userId));
    }

    // ==================== 알림 발송 ====================

    /**
     * 특정 사용자에게 알림 발송
     */
    @Async
    @Transactional
    public void sendToUser(
            String userId,
            NotificationType type,
            String title,
            String body,
            String entityType,
            String entityId,
            Map<String, String> data
    ) {
        UUID userUuid = UUID.fromString(userId);
        List<DeviceToken> tokens = deviceTokenRepository.findByUserIdAndIsActiveTrue(userUuid);

        if (tokens.isEmpty()) {
            return;
        }

        // 알림 로그 생성
        NotificationLog notificationLog = NotificationLog.builder()
                .userId(userUuid)
                .notificationType(type)
                .title(title)
                .body(body)
                .entityType(entityType)
                .entityId(entityId != null ? UUID.fromString(entityId) : null)
                .data(data != null ? data.toString() : null)
                .status(NotificationStatus.PENDING)
                .build();

        notificationLog = notificationLogRepository.save(notificationLog);

        // 각 토큰에 발송
        for (DeviceToken token : tokens) {
            try {
                String messageId = sendNotification(token.getFcmToken(), title, body, data);
                notificationLog.setStatus(NotificationStatus.SENT);
                notificationLog.setFcmMessageId(messageId);
            } catch (FirebaseMessagingException e) {
                handleMessagingException(e, token);
                notificationLog.setStatus(NotificationStatus.FAILED);
                notificationLog.setErrorMessage(e.getMessage());
            }
        }

        notificationLogRepository.save(notificationLog);
    }

    /**
     * 여러 사용자에게 알림 발송
     */
    @Async
    public void sendToUsers(
            List<String> userIds,
            NotificationType type,
            String title,
            String body,
            String entityType,
            String entityId,
            Map<String, String> data
    ) {
        for (String userId : userIds) {
            sendToUser(userId, type, title, body, entityType, entityId, data);
        }
    }

    /**
     * FCM 토큰으로 직접 알림 발송
     */
    private String sendNotification(
            String fcmToken,
            String title,
            String body,
            Map<String, String> data
    ) throws FirebaseMessagingException {
        // 알림 빌더
        Notification notification = Notification.builder()
                .setTitle(title)
                .setBody(body)
                .build();

        // 메시지 빌더
        Message.Builder messageBuilder = Message.builder()
                .setToken(fcmToken)
                .setNotification(notification);

        // 데이터 페이로드 추가
        if (data != null && !data.isEmpty()) {
            messageBuilder.putAllData(data);
        }

        // Android 설정
        messageBuilder.setAndroidConfig(AndroidConfig.builder()
                .setPriority(AndroidConfig.Priority.HIGH)
                .setNotification(AndroidNotification.builder()
                        .setSound("default")
                        .setClickAction("FLUTTER_NOTIFICATION_CLICK")
                        .build())
                .build());

        // iOS (APNs) 설정
        messageBuilder.setApnsConfig(ApnsConfig.builder()
                .setAps(Aps.builder()
                        .setSound("default")
                        .setBadge(1)
                        .build())
                .build());

        Message message = messageBuilder.build();
        return FirebaseMessaging.getInstance().send(message);
    }

    /**
     * FCM 예외 처리
     */
    private void handleMessagingException(FirebaseMessagingException e, DeviceToken token) {
        MessagingErrorCode errorCode = e.getMessagingErrorCode();

        if (errorCode == MessagingErrorCode.UNREGISTERED ||
            errorCode == MessagingErrorCode.INVALID_ARGUMENT) {
            // 토큰이 더 이상 유효하지 않음
            token.setIsActive(false);
            deviceTokenRepository.save(token);
            log.warn("Deactivated invalid FCM token for user: {}", token.getUserId());
        } else {
            log.error("Failed to send FCM notification: {}", e.getMessage());
        }
    }

    // ==================== 알림 유틸리티 메서드 ====================

    /**
     * 예약 리마인더 알림
     */
    public void sendReservationReminder(
            String userId,
            String reservationId,
            String memberName,
            String reservationTime,
            String reminderType  // "1_DAY", "1_HOUR"
    ) {
        String title = "예약 알림";
        String body = reminderType.equals("1_DAY")
                ? memberName + "님의 예약이 내일입니다. (" + reservationTime + ")"
                : memberName + "님의 예약이 1시간 후입니다. (" + reservationTime + ")";

        Map<String, String> data = new HashMap<>();
        data.put("type", "RESERVATION_REMINDER");
        data.put("reservationId", reservationId);
        data.put("screen", "/reservations/" + reservationId);

        sendToUser(userId, NotificationType.RESERVATION_REMINDER, title, body,
                "RESERVATION", reservationId, data);
    }

    /**
     * 새 예약 생성 알림
     */
    public void sendNewReservationNotification(
            String userId,
            String reservationId,
            String memberName,
            String reservationTime
    ) {
        String title = "새 예약";
        String body = memberName + "님의 예약이 등록되었습니다. (" + reservationTime + ")";

        Map<String, String> data = new HashMap<>();
        data.put("type", "RESERVATION_CREATED");
        data.put("reservationId", reservationId);
        data.put("screen", "/reservations/" + reservationId);

        sendToUser(userId, NotificationType.RESERVATION_CREATED, title, body,
                "RESERVATION", reservationId, data);
    }

    /**
     * 새 메모 알림
     */
    public void sendNewMemoNotification(
            String userId,
            String memoId,
            String memberName,
            String creatorName
    ) {
        String title = "새 메모";
        String body = creatorName + "님이 " + memberName + "님에 대한 메모를 작성했습니다.";

        Map<String, String> data = new HashMap<>();
        data.put("type", "MEMO_CREATED");
        data.put("memoId", memoId);
        data.put("screen", "/memos/" + memoId);

        sendToUser(userId, NotificationType.MEMO_CREATED, title, body,
                "MEMO", memoId, data);
    }

    /**
     * 새 회원 등록 알림
     */
    public void sendNewMemberNotification(
            List<String> userIds,
            String memberId,
            String memberName,
            String creatorName
    ) {
        String title = "새 회원 등록";
        String body = creatorName + "님이 " + memberName + "님을 등록했습니다.";

        Map<String, String> data = new HashMap<>();
        data.put("type", "MEMBER_CREATED");
        data.put("memberId", memberId);
        data.put("screen", "/members/" + memberId);

        sendToUsers(userIds, NotificationType.MEMBER_CREATED, title, body,
                "MEMBER", memberId, data);
    }

    /**
     * 새 공지사항 알림
     */
    public void sendNoticeNotification(
            List<String> userIds,
            String noticeId,
            String title
    ) {
        Map<String, String> data = new HashMap<>();
        data.put("type", "NOTICE_NEW");
        data.put("noticeId", noticeId);
        data.put("screen", "/notices/" + noticeId);

        sendToUsers(userIds, NotificationType.NOTICE_NEW, "새 공지사항", title,
                "NOTICE", noticeId, data);
    }

    /**
     * 보안 알림 (새 기기 로그인)
     */
    public void sendSecurityAlert(
            String userId,
            String deviceInfo,
            String ipAddress
    ) {
        String title = "새 기기 로그인";
        String body = "새로운 기기에서 로그인했습니다. (" + deviceInfo + ")";

        Map<String, String> data = new HashMap<>();
        data.put("type", "SECURITY_ALERT");
        data.put("deviceInfo", deviceInfo);
        data.put("ipAddress", ipAddress);

        sendToUser(userId, NotificationType.SECURITY_ALERT, title, body,
                "USER", userId, data);
    }

    // ==================== 알림 조회 ====================

    /**
     * 읽지 않은 알림 수 조회
     */
    public long getUnreadCount(String userId) {
        return notificationLogRepository.countByUserIdAndIsReadFalseAndStatus(
                UUID.fromString(userId), NotificationStatus.SENT);
    }

    /**
     * 알림 읽음 처리
     */
    @Transactional
    public void markAsRead(String notificationId) {
        notificationLogRepository.markAsRead(UUID.fromString(notificationId), LocalDateTime.now());
    }

    /**
     * 모든 알림 읽음 처리
     */
    @Transactional
    public void markAllAsRead(String userId) {
        notificationLogRepository.markAllAsRead(UUID.fromString(userId), LocalDateTime.now());
    }
}
