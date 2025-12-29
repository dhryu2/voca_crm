package com.vocacrm.api.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.vocacrm.api.model.AuditLog;
import com.vocacrm.api.model.AuditLog.AuditAction;
import com.vocacrm.api.repository.AuditLogRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 감사 로그 서비스
 *
 * 시스템의 모든 중요한 변경사항을 기록하고 조회합니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuditLogService {

    private final AuditLogRepository auditLogRepository;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;
    private final ObjectMapper objectMapper;

    /**
     * 감사 로그 기록 (비동기)
     *
     * 메인 트랜잭션과 독립적으로 실행되어 로깅 실패가 비즈니스 로직에 영향을 주지 않습니다.
     */
    @Async
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void logAsync(
            String userId,
            String username,
            String businessPlaceId,
            AuditAction action,
            String entityType,
            String entityId,
            String entityName,
            Object beforeData,
            Object afterData,
            String description
    ) {
        try {
            AuditLog auditLog = buildAuditLog(
                    userId, username, businessPlaceId, action,
                    entityType, entityId, entityName,
                    beforeData, afterData, description
            );
            auditLogRepository.save(auditLog);
        } catch (Exception e) {
            log.error("Failed to save audit log: {} {} {}",
                    action, entityType, entityId, e);
        }
    }

    /**
     * 감사 로그 기록 (동기)
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void log(
            String userId,
            String username,
            String businessPlaceId,
            AuditAction action,
            String entityType,
            String entityId,
            String entityName,
            Object beforeData,
            Object afterData,
            String description
    ) {
        AuditLog auditLog = buildAuditLog(
                userId, username, businessPlaceId, action,
                entityType, entityId, entityName,
                beforeData, afterData, description
        );
        auditLogRepository.save(auditLog);
    }

    /**
     * 간단한 로그 기록 (변경 데이터 없이)
     */
    @Async
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void logSimple(
            String userId,
            String username,
            String businessPlaceId,
            AuditAction action,
            String entityType,
            String entityId,
            String description
    ) {
        logAsync(userId, username, businessPlaceId, action,
                entityType, entityId, null, null, null, description);
    }

    /**
     * 엔티티 생성 로그
     */
    public void logCreate(
            String userId,
            String username,
            String businessPlaceId,
            String entityType,
            String entityId,
            String entityName,
            Object createdData
    ) {
        logAsync(userId, username, businessPlaceId, AuditAction.CREATE,
                entityType, entityId, entityName, null, createdData,
                entityType + " 생성: " + entityName);
    }

    /**
     * 엔티티 수정 로그
     */
    public void logUpdate(
            String userId,
            String username,
            String businessPlaceId,
            String entityType,
            String entityId,
            String entityName,
            Object beforeData,
            Object afterData
    ) {
        logAsync(userId, username, businessPlaceId, AuditAction.UPDATE,
                entityType, entityId, entityName, beforeData, afterData,
                entityType + " 수정: " + entityName);
    }

    /**
     * 엔티티 삭제 로그
     */
    public void logDelete(
            String userId,
            String username,
            String businessPlaceId,
            String entityType,
            String entityId,
            String entityName,
            Object deletedData
    ) {
        logAsync(userId, username, businessPlaceId, AuditAction.DELETE,
                entityType, entityId, entityName, deletedData, null,
                entityType + " 삭제: " + entityName);
    }

    /**
     * 엔티티 복원 로그
     */
    public void logRestore(
            String userId,
            String username,
            String businessPlaceId,
            String entityType,
            String entityId,
            String entityName
    ) {
        logAsync(userId, username, businessPlaceId, AuditAction.RESTORE,
                entityType, entityId, entityName, null, null,
                entityType + " 복원: " + entityName);
    }

    /**
     * 로그인 로그
     */
    public void logLogin(String userId, String username, String businessPlaceId) {
        logAsync(userId, username, businessPlaceId, AuditAction.LOGIN,
                "USER", userId, username, null, null, "로그인");
    }

    /**
     * 로그인 실패 로그
     */
    public void logLoginFailed(String attemptedUserId, String reason) {
        logAsync(attemptedUserId, null, null, AuditAction.LOGIN_FAILED,
                "USER", attemptedUserId, null, null, null,
                "로그인 실패: " + reason);
    }

    /**
     * 로그아웃 로그
     */
    public void logLogout(String userId, String username, String businessPlaceId) {
        logAsync(userId, username, businessPlaceId, AuditAction.LOGOUT,
                "USER", userId, username, null, null, "로그아웃");
    }

    // ==================== 시스템 관리자 전용 로깅 메서드 ====================

    /**
     * 시스템 관리자 작업 로그
     *
     * 시스템 관리자가 수행하는 민감한 작업을 기록합니다.
     */
    public void logAdminAction(
            String adminUserId,
            String adminUsername,
            String targetEntityType,
            String targetEntityId,
            String description,
            Object actionData
    ) {
        logAsync(adminUserId, adminUsername, null, AuditAction.ADMIN_ACTION,
                targetEntityType, targetEntityId, null, null, actionData,
                "[시스템 관리자] " + description);
    }

    /**
     * 권한 변경 로그
     *
     * 사용자 Role 변경, 사업장 접근 권한 변경 등을 기록합니다.
     */
    public void logPermissionChange(
            String adminUserId,
            String adminUsername,
            String businessPlaceId,
            String targetUserId,
            String targetUsername,
            Object beforePermission,
            Object afterPermission,
            String description
    ) {
        logAsync(adminUserId, adminUsername, businessPlaceId, AuditAction.PERMISSION_CHANGE,
                "USER_PERMISSION", targetUserId, targetUsername,
                beforePermission, afterPermission,
                "[권한 변경] " + description);
    }

    /**
     * 사용자 정지 로그
     */
    public void logUserSuspend(
            String adminUserId,
            String adminUsername,
            String targetUserId,
            String targetUsername,
            String reason
    ) {
        logAsync(adminUserId, adminUsername, null, AuditAction.USER_SUSPEND,
                "USER", targetUserId, targetUsername, null, null,
                "[사용자 정지] " + targetUsername + " - 사유: " + reason);
    }

    /**
     * 사용자 활성화 로그
     */
    public void logUserActivate(
            String adminUserId,
            String adminUsername,
            String targetUserId,
            String targetUsername
    ) {
        logAsync(adminUserId, adminUsername, null, AuditAction.USER_ACTIVATE,
                "USER", targetUserId, targetUsername, null, null,
                "[사용자 활성화] " + targetUsername);
    }

    /**
     * 사업장 삭제 로그
     *
     * 사업장 삭제는 매우 중요한 작업이므로 상세하게 기록합니다.
     */
    public void logBusinessPlaceDelete(
            String adminUserId,
            String adminUsername,
            String businessPlaceId,
            String businessPlaceName,
            Object deletedData
    ) {
        logAsync(adminUserId, adminUsername, businessPlaceId, AuditAction.BUSINESS_PLACE_DELETE,
                "BUSINESS_PLACE", businessPlaceId, businessPlaceName, deletedData, null,
                "[사업장 삭제] " + businessPlaceName + " (" + businessPlaceId + ")");
    }

    /**
     * 접근 거부 로그 (보안 이벤트)
     *
     * 권한 없는 접근 시도를 기록합니다.
     */
    public void logAccessDenied(
            String userId,
            String username,
            String businessPlaceId,
            String targetEntityType,
            String targetEntityId,
            String attemptedAction
    ) {
        logAsync(userId, username, businessPlaceId, AuditAction.ACCESS_DENIED,
                targetEntityType, targetEntityId, null, null, null,
                "[접근 거부] " + attemptedAction + " 시도 - " + targetEntityType + ":" + targetEntityId);
    }

    /**
     * 보안 경고 로그
     *
     * 비정상적인 접근 패턴, 반복적인 실패 등을 기록합니다.
     */
    public void logSecurityAlert(
            String userId,
            String username,
            String alertType,
            String alertDescription,
            Object alertData
    ) {
        logAsync(userId, username, null, AuditAction.SECURITY_ALERT,
                "SECURITY", alertType, null, null, alertData,
                "[보안 경고] " + alertDescription);
    }

    // ==================== 조회 메서드 ====================

    /**
     * 사업장별 감사 로그 조회
     */
    @Transactional(readOnly = true)
    public Page<AuditLog> getLogsByBusinessPlace(String businessPlaceId, int page, int size) {
        return auditLogRepository.findByBusinessPlaceIdOrderByCreatedAtDesc(
                businessPlaceId, PageRequest.of(page, size));
    }

    /**
     * 사용자별 감사 로그 조회 (사업장 필터링 포함)
     */
    @Transactional(readOnly = true)
    public Page<AuditLog> getLogsByUser(String userId, String businessPlaceId, int page, int size) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return auditLogRepository.findByUserIdAndBusinessPlaceIdOrderByCreatedAtDesc(
                UUID.fromString(userId), businessPlaceId, PageRequest.of(page, size));
    }

    /**
     * 특정 엔티티의 변경 이력 조회 (사업장 필터링 포함)
     */
    @Transactional(readOnly = true)
    public List<AuditLog> getEntityHistory(String entityType, String entityId, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return auditLogRepository.findByEntityTypeAndEntityIdAndBusinessPlaceIdOrderByCreatedAtAsc(
                entityType, UUID.fromString(entityId), businessPlaceId);
    }

    /**
     * 기간별 감사 로그 조회
     */
    @Transactional(readOnly = true)
    public Page<AuditLog> getLogsByDateRange(
            String businessPlaceId,
            LocalDateTime startDate,
            LocalDateTime endDate,
            int page,
            int size
    ) {
        return auditLogRepository.findByBusinessPlaceIdAndDateRange(
                businessPlaceId, startDate, endDate, PageRequest.of(page, size));
    }

    /**
     * 복합 조건 검색
     */
    @Transactional(readOnly = true)
    public Page<AuditLog> searchLogs(
            String businessPlaceId,
            String entityType,
            LocalDateTime startDate,
            LocalDateTime endDate,
            int page,
            int size
    ) {
        if (entityType != null && !entityType.isEmpty()) {
            return auditLogRepository.findByBusinessPlaceIdAndEntityTypeAndDateRange(
                    businessPlaceId, entityType, startDate, endDate, PageRequest.of(page, size));
        }
        return auditLogRepository.findByBusinessPlaceIdAndDateRange(
                businessPlaceId, startDate, endDate, PageRequest.of(page, size));
    }

    /**
     * MANAGER용 복합 조건 검색 (본인 + STAFF 로그만)
     *
     * MANAGER는 본인의 로그와 STAFF들의 로그만 조회할 수 있습니다.
     * OWNER나 다른 MANAGER의 로그는 조회할 수 없습니다.
     */
    @Transactional(readOnly = true)
    public Page<AuditLog> searchLogsForManager(
            String businessPlaceId,
            String managerId,
            String entityType,
            LocalDateTime startDate,
            LocalDateTime endDate,
            int page,
            int size
    ) {
        // STAFF 사용자 ID 목록 조회
        List<UUID> staffUserIds = userBusinessPlaceRepository.findStaffUserIdsByBusinessPlaceId(businessPlaceId);

        // 본인 ID 추가
        List<UUID> allowedUserIds = new ArrayList<>(staffUserIds);
        allowedUserIds.add(UUID.fromString(managerId));

        if (entityType != null && !entityType.isEmpty()) {
            return auditLogRepository.findByBusinessPlaceIdAndUserIdInAndEntityTypeAndDateRange(
                    businessPlaceId, allowedUserIds, entityType, startDate, endDate, PageRequest.of(page, size));
        }
        return auditLogRepository.findByBusinessPlaceIdAndUserIdInAndDateRange(
                businessPlaceId, allowedUserIds, startDate, endDate, PageRequest.of(page, size));
    }

    /**
     * 액션별 통계 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Long> getActionStatistics(String businessPlaceId, int days) {
        LocalDateTime since = LocalDateTime.now().minusDays(days);
        List<Object[]> results = auditLogRepository.countByActionSince(businessPlaceId, since);

        Map<String, Long> stats = new HashMap<>();
        for (Object[] row : results) {
            stats.put(((AuditAction) row[0]).name(), (Long) row[1]);
        }
        return stats;
    }

    /**
     * 사용자별 활동 통계 조회
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getUserActivityStatistics(String businessPlaceId, int days) {
        LocalDateTime since = LocalDateTime.now().minusDays(days);
        List<Object[]> results = auditLogRepository.countByUserSince(businessPlaceId, since);

        return results.stream().map(row -> {
            Map<String, Object> stat = new HashMap<>();
            stat.put("userId", row[0]);
            stat.put("username", row[1]);
            stat.put("actionCount", row[2]);
            return stat;
        }).toList();
    }

    // ==================== 내부 헬퍼 메서드 ====================

    /**
     * AuditLog 객체 생성
     */
    private AuditLog buildAuditLog(
            String userId,
            String username,
            String businessPlaceId,
            AuditAction action,
            String entityType,
            String entityId,
            String entityName,
            Object beforeData,
            Object afterData,
            String description
    ) {
        // 현재 HTTP 요청 정보 추출
        String ipAddress = null;
        String deviceInfo = null;
        String requestUri = null;
        String httpMethod = null;

        try {
            ServletRequestAttributes attrs =
                    (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
            if (attrs != null) {
                HttpServletRequest request = attrs.getRequest();
                ipAddress = extractIpAddress(request);
                deviceInfo = extractDeviceInfo(request);
                requestUri = request.getRequestURI();
                httpMethod = request.getMethod();
            }
        } catch (Exception e) {
            // 요청 정보 추출 실패 시 무시
        }

        return AuditLog.builder()
                .userId(parseUUID(userId))
                .username(username)
                .businessPlaceId(businessPlaceId)
                .action(action)
                .entityType(entityType)
                .entityId(parseUUID(entityId))
                .entityName(entityName)
                .changesBefore(toJson(beforeData))
                .changesAfter(toJson(afterData))
                .description(description)
                .ipAddress(ipAddress)
                .deviceInfo(deviceInfo)
                .requestUri(requestUri)
                .httpMethod(httpMethod)
                .build();
    }

    /**
     * 문자열을 UUID로 변환 (null 또는 유효하지 않은 경우 랜덤 UUID 생성)
     */
    private UUID parseUUID(String id) {
        if (id == null || id.isEmpty()) {
            return UUID.randomUUID();
        }
        try {
            return UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            // UUID 형식이 아닌 경우 (예: userId 문자열) 랜덤 UUID 생성
            log.warn("Invalid UUID format for entityId: {}, generating random UUID", id);
            return UUID.randomUUID();
        }
    }

    /**
     * 객체를 JSON 문자열로 변환
     */
    private String toJson(Object obj) {
        if (obj == null) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            log.warn("Failed to serialize object to JSON", e);
            return obj.toString();
        }
    }

    /**
     * IP 주소 추출
     */
    private String extractIpAddress(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("X-Real-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }
        return ip;
    }

    /**
     * 디바이스 정보 추출
     */
    private String extractDeviceInfo(HttpServletRequest request) {
        String userAgent = request.getHeader("User-Agent");
        if (userAgent == null) {
            return "Unknown";
        }
        if (userAgent.length() > 200) {
            return userAgent.substring(0, 200);
        }
        return userAgent;
    }
}
