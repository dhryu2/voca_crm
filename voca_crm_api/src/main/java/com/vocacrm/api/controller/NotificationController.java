package com.vocacrm.api.controller;

import com.vocacrm.api.model.DeviceToken;
import com.vocacrm.api.model.DeviceToken.DeviceType;
import com.vocacrm.api.model.NotificationLog;
import com.vocacrm.api.repository.NotificationLogRepository;
import com.vocacrm.api.service.PushNotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static com.vocacrm.api.util.PaginationUtils.limitPageSize;
import static com.vocacrm.api.util.PaginationUtils.validatePage;

/**
 * 푸시 알림 관련 API 컨트롤러
 */
@Slf4j
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final PushNotificationService pushNotificationService;
    private final NotificationLogRepository notificationLogRepository;

    // ==================== 토큰 관리 API ====================

    /**
     * FCM 토큰 등록/갱신
     */
    @PostMapping("/token")
    public ResponseEntity<DeviceToken> registerToken(@RequestBody TokenRegistrationRequest request) {
        DeviceToken token = pushNotificationService.registerToken(
                request.userId(),
                request.fcmToken(),
                request.deviceType(),
                request.deviceInfo(),
                request.appVersion()
        );

        return ResponseEntity.ok(token);
    }

    /**
     * FCM 토큰 비활성화 (로그아웃 시)
     */
    @DeleteMapping("/token")
    public ResponseEntity<Void> deactivateToken(@RequestBody TokenDeactivationRequest request) {
        pushNotificationService.deactivateToken(request.fcmToken());
        return ResponseEntity.ok().build();
    }

    /**
     * 사용자의 모든 토큰 비활성화 (모든 기기 로그아웃)
     */
    @DeleteMapping("/token/all")
    public ResponseEntity<Void> deactivateAllTokens(jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        pushNotificationService.deactivateAllUserTokens(userId);
        return ResponseEntity.ok().build();
    }

    // ==================== 알림 조회 API ====================

    /**
     * 사용자의 알림 목록 조회
     */
    @GetMapping
    public ResponseEntity<Page<NotificationLog>> getNotifications(
            jakarta.servlet.http.HttpServletRequest servletRequest,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        String userId = (String) servletRequest.getAttribute("userId");
        Page<NotificationLog> notifications = notificationLogRepository
                .findByUserIdOrderByCreatedAtDesc(UUID.fromString(userId), PageRequest.of(validatePage(page), limitPageSize(size)));
        return ResponseEntity.ok(notifications);
    }

    /**
     * 읽지 않은 알림 목록 조회
     */
    @GetMapping("/unread")
    public ResponseEntity<List<NotificationLog>> getUnreadNotifications(jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<NotificationLog> notifications = notificationLogRepository
                .findByUserIdAndIsReadFalseAndStatusOrderByCreatedAtDesc(
                        UUID.fromString(userId), NotificationLog.NotificationStatus.SENT);
        return ResponseEntity.ok(notifications);
    }

    /**
     * 읽지 않은 알림 수 조회
     */
    @GetMapping("/unread-count")
    public ResponseEntity<Map<String, Long>> getUnreadCount(jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        long count = pushNotificationService.getUnreadCount(userId);
        return ResponseEntity.ok(Map.of("count", count));
    }

    /**
     * 알림 읽음 처리
     */
    @PostMapping("/{notificationId}/read")
    public ResponseEntity<Void> markAsRead(@PathVariable String notificationId) {
        pushNotificationService.markAsRead(notificationId);
        return ResponseEntity.ok().build();
    }

    /**
     * 모든 알림 읽음 처리
     */
    @PostMapping("/read-all")
    public ResponseEntity<Void> markAllAsRead(jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        pushNotificationService.markAllAsRead(userId);
        return ResponseEntity.ok().build();
    }

    // ==================== 테스트용 API (개발 환경에서만 사용) ====================

    /**
     * 테스트 알림 발송
     */
    @PostMapping("/test")
    public ResponseEntity<Map<String, String>> sendTestNotification(@RequestBody TestNotificationRequest request) {
        pushNotificationService.sendToUser(
                request.userId(),
                NotificationLog.NotificationType.SYSTEM_ANNOUNCEMENT,
                request.title(),
                request.body(),
                null,
                null,
                Map.of("type", "TEST")
        );

        return ResponseEntity.ok(Map.of("message", "Test notification sent"));
    }

    // ==================== Request DTOs ====================

    public record TokenRegistrationRequest(
            String userId,
            String fcmToken,
            DeviceType deviceType,
            String deviceInfo,
            String appVersion
    ) {}

    public record TokenDeactivationRequest(
            String fcmToken
    ) {}

    public record TestNotificationRequest(
            String userId,
            String title,
            String body
    ) {}
}
