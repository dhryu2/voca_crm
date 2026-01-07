package com.vocacrm.api.controller;

import com.vocacrm.api.model.ErrorLog;
import com.vocacrm.api.model.ErrorLog.ErrorSeverity;
import com.vocacrm.api.service.ErrorLogService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

/**
 * 오류 로그 컨트롤러
 *
 * 클라이언트에서 발생한 오류를 수집하고 관리자가 조회/관리할 수 있는 API
 */
@Slf4j
@RestController
@RequestMapping("/api/error-logs")
@RequiredArgsConstructor
public class ErrorLogController {

    private final ErrorLogService errorLogService;

    // ==================== 오류 로그 수집 (클라이언트용) ====================

    /**
     * 오류 로그 생성 (클라이언트에서 오류 발생 시 호출)
     * POST /api/error-logs
     *
     * 인증 불필요 - 비로그인 상태에서도 오류 로그를 수집해야 함
     */
    @PostMapping
    public ResponseEntity<Map<String, String>> createErrorLog(
            @Valid @RequestBody ErrorLogCreateRequest request,
            HttpServletRequest servletRequest) {

        // 사용자 ID는 토큰에서 추출 (있는 경우)
        String userId = (String) servletRequest.getAttribute("userId");
        String userIdStr = userId != null ? userId : request.getUserId();

        ErrorLog errorLog = ErrorLog.builder()
                .userId(userIdStr != null ? UUID.fromString(userIdStr) : null)
                .username(request.getUsername())
                .businessPlaceId(request.getBusinessPlaceId())
                .screenName(request.getScreenName())
                .action(request.getAction())
                .requestUrl(request.getRequestUrl())
                .requestMethod(request.getRequestMethod())
                .requestBody(sanitizeRequestBody(request.getRequestBody()))
                .httpStatusCode(request.getHttpStatusCode())
                .errorCode(request.getErrorCode())
                .errorMessage(request.getErrorMessage())
                .stackTrace(request.getStackTrace())
                .severity(request.getSeverity() != null ? request.getSeverity() : ErrorSeverity.ERROR)
                .deviceInfo(request.getDeviceInfo())
                .appVersion(request.getAppVersion())
                .osVersion(request.getOsVersion())
                .platform(request.getPlatform())
                .build();

        errorLogService.logErrorAsync(errorLog);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("message", "오류 로그가 기록되었습니다"));
    }

    // ==================== 관리자용 조회 API ====================

    /**
     * 전체 오류 로그 조회 (관리자용)
     * GET /api/error-logs
     */
    @GetMapping
    public ResponseEntity<Page<ErrorLog>> getAllLogs(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            HttpServletRequest servletRequest) {
        // TODO: 관리자 권한 확인 로직 추가
        return ResponseEntity.ok(errorLogService.getAllLogs(page, size));
    }

    /**
     * 오류 로그 상세 조회
     * GET /api/error-logs/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<ErrorLog> getLogById(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        return ResponseEntity.ok(errorLogService.getLogById(id));
    }

    /**
     * 사업장별 오류 로그 조회
     * GET /api/error-logs/business-place/{businessPlaceId}
     */
    @GetMapping("/business-place/{businessPlaceId}")
    public ResponseEntity<Page<ErrorLog>> getLogsByBusinessPlace(
            @PathVariable String businessPlaceId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            HttpServletRequest servletRequest) {
        return ResponseEntity.ok(errorLogService.getLogsByBusinessPlace(businessPlaceId, page, size));
    }

    /**
     * 미해결 오류 로그 조회
     * GET /api/error-logs/unresolved
     */
    @GetMapping("/unresolved")
    public ResponseEntity<Page<ErrorLog>> getUnresolvedLogs(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            HttpServletRequest servletRequest) {
        return ResponseEntity.ok(errorLogService.getUnresolvedLogs(page, size));
    }

    /**
     * 오류 로그 검색
     * GET /api/error-logs/search
     */
    @GetMapping("/search")
    public ResponseEntity<Page<ErrorLog>> searchLogs(
            @RequestParam(required = false) String businessPlaceId,
            @RequestParam(required = false) ErrorSeverity severity,
            @RequestParam(required = false) Boolean resolved,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime endDate,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            HttpServletRequest servletRequest) {

        Page<ErrorLog> logs;
        if (businessPlaceId != null && !businessPlaceId.isEmpty()) {
            logs = errorLogService.searchLogsByBusinessPlace(
                    businessPlaceId, severity, resolved, startDate, endDate, page, size);
        } else {
            logs = errorLogService.searchLogs(severity, resolved, startDate, endDate, page, size);
        }
        return ResponseEntity.ok(logs);
    }

    // ==================== 오류 해결 처리 ====================

    /**
     * 오류 해결 처리
     * PATCH /api/error-logs/{id}/resolve
     */
    @PatchMapping("/{id}/resolve")
    public ResponseEntity<ErrorLog> resolveError(
            @PathVariable String id,
            @Valid @RequestBody ResolveRequest request,
            HttpServletRequest servletRequest) {
        String resolvedBy = (String) servletRequest.getAttribute("userId");
        return ResponseEntity.ok(
                errorLogService.resolveError(id, resolvedBy, request.getResolutionNote()));
    }

    /**
     * 오류 미해결로 되돌리기
     * PATCH /api/error-logs/{id}/unresolve
     */
    @PatchMapping("/{id}/unresolve")
    public ResponseEntity<ErrorLog> unresolveError(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        return ResponseEntity.ok(errorLogService.unresolveError(id));
    }

    // ==================== 통계 ====================

    /**
     * 오류 통계 요약
     * GET /api/error-logs/summary
     */
    @GetMapping("/summary")
    public ResponseEntity<Map<String, Object>> getErrorSummary(
            @RequestParam(defaultValue = "7") int days,
            HttpServletRequest servletRequest) {
        return ResponseEntity.ok(errorLogService.getErrorSummary(days));
    }

    /**
     * 미해결 오류 개수
     * GET /api/error-logs/unresolved-count
     */
    @GetMapping("/unresolved-count")
    public ResponseEntity<Map<String, Long>> getUnresolvedCount(
            @RequestParam(required = false) String businessPlaceId,
            HttpServletRequest servletRequest) {
        long count;
        if (businessPlaceId != null && !businessPlaceId.isEmpty()) {
            count = errorLogService.getUnresolvedCountByBusinessPlace(businessPlaceId);
        } else {
            count = errorLogService.getUnresolvedCount();
        }
        return ResponseEntity.ok(Map.of("count", count));
    }

    // ==================== 헬퍼 메서드 ====================

    /**
     * 요청 본문에서 민감 정보 제거
     */
    private String sanitizeRequestBody(String requestBody) {
        if (requestBody == null) {
            return null;
        }
        // 비밀번호, 토큰 등 민감 정보 마스킹
        return requestBody
                .replaceAll("\"password\"\\s*:\\s*\"[^\"]*\"", "\"password\":\"***\"")
                .replaceAll("\"token\"\\s*:\\s*\"[^\"]*\"", "\"token\":\"***\"")
                .replaceAll("\"accessToken\"\\s*:\\s*\"[^\"]*\"", "\"accessToken\":\"***\"")
                .replaceAll("\"refreshToken\"\\s*:\\s*\"[^\"]*\"", "\"refreshToken\":\"***\"");
    }

    // ==================== Request DTOs ====================

    @Data
    public static class ErrorLogCreateRequest {
        private String userId;

        @Size(max = 100)
        private String username;

        @Size(max = 7)
        private String businessPlaceId;

        @Size(max = 100)
        private String screenName;

        @Size(max = 100)
        private String action;

        @Size(max = 500)
        private String requestUrl;

        @Size(max = 10)
        private String requestMethod;

        private String requestBody;

        private Integer httpStatusCode;

        @Size(max = 50)
        private String errorCode;

        @NotBlank(message = "오류 메시지는 필수입니다")
        private String errorMessage;

        private String stackTrace;

        private ErrorSeverity severity;

        @Size(max = 200)
        private String deviceInfo;

        @Size(max = 20)
        private String appVersion;

        @Size(max = 50)
        private String osVersion;

        @Size(max = 20)
        private String platform;
    }

    @Data
    public static class ResolveRequest {
        @Size(max = 500)
        private String resolutionNote;
    }
}
