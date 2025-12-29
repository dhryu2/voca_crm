package com.vocacrm.api.controller;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.AuditLog;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static com.vocacrm.api.util.PaginationUtils.limitPageSize;
import static com.vocacrm.api.util.PaginationUtils.validatePage;

/**
 * 감사 로그 조회 API
 *
 * 권한 기반 접근 제어:
 * - STAFF: 본인 로그만 조회 가능 (/my 엔드포인트만)
 * - MANAGER: 본인 + STAFF 로그 조회 가능
 * - OWNER: 모든 로그 조회 가능
 */
@Slf4j
@RestController
@RequestMapping("/api/audit-logs")
@RequiredArgsConstructor
public class AuditLogController {

    private final AuditLogService auditLogService;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;

    /**
     * 사업장별 감사 로그 목록 조회
     *
     * GET /api/audit-logs?page=0&size=20
     *
     * 권한:
     * - OWNER: 모든 로그 조회 가능
     * - MANAGER: 본인 + STAFF 로그만 조회 가능
     * - STAFF: 403 Forbidden (본인 로그는 /my 사용)
     */
    @GetMapping
    public ResponseEntity<?> getAuditLogs(
            HttpServletRequest request,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String entityType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime endDate,
            @RequestParam(required = false) String businessPlaceId
    ) {
        String userId = (String) request.getAttribute("userId");
        // businessPlaceId 파라미터가 없으면 defaultBusinessPlaceId 사용
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            businessPlaceId = (String) request.getAttribute("defaultBusinessPlaceId");
        }

        if (businessPlaceId == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "BAD_REQUEST",
                    "message", "사업장 정보가 필요합니다"
            ));
        }

        // 권한 체크
        Role userRole = getUserRole(userId, businessPlaceId);
        if (userRole == null) {
            return ResponseEntity.status(403).body(Map.of(
                    "error", "FORBIDDEN",
                    "message", "해당 사업장에 대한 접근 권한이 없습니다"
            ));
        }

        // STAFF는 전체 로그 조회 불가 (/my 사용 안내)
        if (userRole == Role.STAFF) {
            return ResponseEntity.status(403).body(Map.of(
                    "error", "FORBIDDEN",
                    "message", "활동 로그 전체 조회 권한이 없습니다. /api/audit-logs/my를 사용해주세요."
            ));
        }

        // 기본 기간: 최근 30일
        if (startDate == null) {
            startDate = LocalDateTime.now().minusDays(30);
        }
        if (endDate == null) {
            endDate = LocalDateTime.now();
        }

        int validPage = validatePage(page);
        int validSize = limitPageSize(size);

        Page<AuditLog> logs;
        if (userRole == Role.OWNER) {
            // OWNER: 모든 로그
            logs = auditLogService.searchLogs(
                    businessPlaceId, entityType, startDate, endDate, validPage, validSize);
        } else {
            // MANAGER: 본인 + STAFF 로그만 (OWNER, 다른 MANAGER 로그는 제외)
            logs = auditLogService.searchLogsForManager(
                    businessPlaceId, userId, entityType, startDate, endDate, validPage, validSize);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("data", logs.getContent());
        response.put("totalElements", logs.getTotalElements());
        response.put("totalPages", logs.getTotalPages());
        response.put("currentPage", logs.getNumber());
        response.put("size", logs.getSize());

        return ResponseEntity.ok(response);
    }

    /**
     * 특정 엔티티의 변경 이력 조회 (사업장 필터링 포함)
     *
     * GET /api/audit-logs/entity/{entityType}/{entityId}
     *
     * 권한: MANAGER 이상만 조회 가능
     */
    @GetMapping("/entity/{entityType}/{entityId}")
    public ResponseEntity<?> getEntityHistory(
            HttpServletRequest request,
            @PathVariable String entityType,
            @PathVariable String entityId
    ) {
        String userId = (String) request.getAttribute("userId");
        String businessPlaceId = (String) request.getAttribute("defaultBusinessPlaceId");

        if (businessPlaceId == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "BAD_REQUEST",
                    "message", "사업장 정보가 필요합니다"
            ));
        }

        // 권한 체크: MANAGER 이상만
        Role userRole = getUserRole(userId, businessPlaceId);
        if (userRole == null || userRole == Role.STAFF) {
            return ResponseEntity.status(403).body(Map.of(
                    "error", "FORBIDDEN",
                    "message", "엔티티 이력 조회 권한이 없습니다. MANAGER 이상만 가능합니다."
            ));
        }

        List<AuditLog> history = auditLogService.getEntityHistory(
                entityType.toUpperCase(), entityId, businessPlaceId);

        return ResponseEntity.ok(Map.of(
                "entityType", entityType,
                "entityId", entityId,
                "history", history,
                "count", history.size()
        ));
    }

    /**
     * 특정 사용자의 활동 로그 조회 (사업장 필터링 포함)
     *
     * GET /api/audit-logs/user/{userId}
     *
     * 권한:
     * - OWNER: 모든 사용자 로그 조회 가능
     * - MANAGER: 본인 + STAFF 로그만 조회 가능
     * - STAFF: 본인 로그만 조회 가능
     */
    @GetMapping("/user/{userId}")
    public ResponseEntity<?> getUserLogs(
            HttpServletRequest request,
            @PathVariable String targetUserId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        String requestUserId = (String) request.getAttribute("userId");
        String businessPlaceId = (String) request.getAttribute("defaultBusinessPlaceId");

        if (businessPlaceId == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "BAD_REQUEST",
                    "message", "사업장 정보가 필요합니다"
            ));
        }

        // 권한 체크
        Role requestUserRole = getUserRole(requestUserId, businessPlaceId);
        if (requestUserRole == null) {
            return ResponseEntity.status(403).body(Map.of(
                    "error", "FORBIDDEN",
                    "message", "해당 사업장에 대한 접근 권한이 없습니다"
            ));
        }

        // 본인 로그 조회는 항상 허용
        if (!requestUserId.equals(targetUserId)) {
            // STAFF는 다른 사용자 로그 조회 불가
            if (requestUserRole == Role.STAFF) {
                return ResponseEntity.status(403).body(Map.of(
                        "error", "FORBIDDEN",
                        "message", "다른 사용자의 활동 로그를 조회할 권한이 없습니다"
                ));
            }

            // MANAGER는 대상이 STAFF인 경우만 조회 가능
            if (requestUserRole == Role.MANAGER) {
                Role targetUserRole = getUserRole(targetUserId, businessPlaceId);
                if (targetUserRole != Role.STAFF) {
                    return ResponseEntity.status(403).body(Map.of(
                            "error", "FORBIDDEN",
                            "message", "MANAGER는 STAFF의 활동 로그만 조회할 수 있습니다"
                    ));
                }
            }
            // OWNER는 모든 사용자 로그 조회 가능
        }

        Page<AuditLog> logs = auditLogService.getLogsByUser(targetUserId, businessPlaceId, validatePage(page), limitPageSize(size));

        Map<String, Object> response = new HashMap<>();
        response.put("userId", targetUserId);
        response.put("data", logs.getContent());
        response.put("totalElements", logs.getTotalElements());
        response.put("totalPages", logs.getTotalPages());
        response.put("currentPage", logs.getNumber());

        return ResponseEntity.ok(response);
    }

    /**
     * 내 활동 로그 조회 (사업장 필터링 포함)
     *
     * GET /api/audit-logs/my
     */
    @GetMapping("/my")
    public ResponseEntity<?> getMyLogs(
            HttpServletRequest request,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        String userId = (String) request.getAttribute("userId");
        String businessPlaceId = (String) request.getAttribute("defaultBusinessPlaceId");

        if (userId == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "BAD_REQUEST",
                    "message", "인증 정보가 필요합니다"
            ));
        }

        if (businessPlaceId == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "BAD_REQUEST",
                    "message", "사업장 정보가 필요합니다"
            ));
        }

        Page<AuditLog> logs = auditLogService.getLogsByUser(userId, businessPlaceId, validatePage(page), limitPageSize(size));

        Map<String, Object> response = new HashMap<>();
        response.put("data", logs.getContent());
        response.put("totalElements", logs.getTotalElements());
        response.put("totalPages", logs.getTotalPages());
        response.put("currentPage", logs.getNumber());

        return ResponseEntity.ok(response);
    }

    /**
     * 액션별 통계 조회
     *
     * GET /api/audit-logs/statistics/actions?days=30
     *
     * 권한: MANAGER 이상만 조회 가능
     */
    @GetMapping("/statistics/actions")
    public ResponseEntity<?> getActionStatistics(
            HttpServletRequest request,
            @RequestParam(defaultValue = "30") int days,
            @RequestParam(required = false) String businessPlaceId
    ) {
        String userId = (String) request.getAttribute("userId");
        // businessPlaceId 파라미터가 없으면 defaultBusinessPlaceId 사용
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            businessPlaceId = (String) request.getAttribute("defaultBusinessPlaceId");
        }

        if (businessPlaceId == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "BAD_REQUEST",
                    "message", "사업장 정보가 필요합니다"
            ));
        }

        // 권한 체크: MANAGER 이상만
        Role userRole = getUserRole(userId, businessPlaceId);
        if (userRole == null || userRole == Role.STAFF) {
            return ResponseEntity.status(403).body(Map.of(
                    "error", "FORBIDDEN",
                    "message", "통계 조회 권한이 없습니다. MANAGER 이상만 가능합니다."
            ));
        }

        Map<String, Long> stats = auditLogService.getActionStatistics(businessPlaceId, days);

        return ResponseEntity.ok(Map.of(
                "period", days + "일",
                "statistics", stats
        ));
    }

    /**
     * 사용자별 활동 통계 조회
     *
     * GET /api/audit-logs/statistics/users?days=30
     *
     * 권한: OWNER만 조회 가능 (사용자별 활동량은 민감 정보)
     */
    @GetMapping("/statistics/users")
    public ResponseEntity<?> getUserActivityStatistics(
            HttpServletRequest request,
            @RequestParam(defaultValue = "30") int days,
            @RequestParam(required = false) String businessPlaceId
    ) {
        String userId = (String) request.getAttribute("userId");
        // businessPlaceId 파라미터가 없으면 defaultBusinessPlaceId 사용
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            businessPlaceId = (String) request.getAttribute("defaultBusinessPlaceId");
        }

        if (businessPlaceId == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "BAD_REQUEST",
                    "message", "사업장 정보가 필요합니다"
            ));
        }

        // 권한 체크: OWNER만
        Role userRole = getUserRole(userId, businessPlaceId);
        if (userRole != Role.OWNER) {
            return ResponseEntity.status(403).body(Map.of(
                    "error", "FORBIDDEN",
                    "message", "사용자별 활동 통계 조회 권한이 없습니다. OWNER만 가능합니다."
            ));
        }

        List<Map<String, Object>> stats =
                auditLogService.getUserActivityStatistics(businessPlaceId, days);

        return ResponseEntity.ok(Map.of(
                "period", days + "일",
                "statistics", stats
        ));
    }

    // ==================== 헬퍼 메서드 ====================

    /**
     * 사용자의 사업장 내 Role 조회
     *
     * @param userId 사용자 ID
     * @param businessPlaceId 사업장 ID
     * @return 사용자의 Role (없으면 null)
     */
    private Role getUserRole(String userId, String businessPlaceId) {
        if (userId == null || businessPlaceId == null) {
            return null;
        }

        Optional<UserBusinessPlace> ubp = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        return ubp.map(UserBusinessPlace::getRole).orElse(null);
    }
}
