package com.vocacrm.api.service;

import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.ErrorLog;
import com.vocacrm.api.model.ErrorLog.ErrorSeverity;
import com.vocacrm.api.repository.ErrorLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 오류 로그 서비스
 *
 * 클라이언트(Flutter 앱)에서 발생한 오류를 기록하고 관리합니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ErrorLogService {

    private final ErrorLogRepository errorLogRepository;

    // ==================== 오류 로그 생성 ====================

    /**
     * 오류 로그 기록 (비동기)
     */
    @Async
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void logErrorAsync(ErrorLog errorLog) {
        try {
            errorLogRepository.save(errorLog);
            log.info("Error log saved: {} - {} - {}",
                    errorLog.getSeverity(), errorLog.getScreenName(), errorLog.getErrorMessage());
        } catch (Exception e) {
            log.error("Failed to save error log", e);
        }
    }

    /**
     * 오류 로그 기록 (동기)
     */
    @Transactional
    public ErrorLog logError(ErrorLog errorLog) {
        return errorLogRepository.save(errorLog);
    }

    /**
     * 간단한 오류 로그 생성
     */
    public void logSimple(
            String userId,
            String username,
            String businessPlaceId,
            String screenName,
            String action,
            String errorMessage,
            ErrorSeverity severity
    ) {
        ErrorLog errorLog = ErrorLog.builder()
                .userId(userId != null ? UUID.fromString(userId) : null)
                .username(username)
                .businessPlaceId(businessPlaceId)
                .screenName(screenName)
                .action(action)
                .errorMessage(errorMessage)
                .severity(severity)
                .build();
        logErrorAsync(errorLog);
    }

    // ==================== 조회 메서드 ====================

    /**
     * 전체 오류 로그 조회 (페이징)
     */
    @Transactional(readOnly = true)
    public Page<ErrorLog> getAllLogs(int page, int size) {
        return errorLogRepository.findAllByOrderByCreatedAtDesc(PageRequest.of(page, size));
    }

    /**
     * 오류 로그 상세 조회
     */
    @Transactional(readOnly = true)
    public ErrorLog getLogById(String id) {
        return errorLogRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("오류 로그를 찾을 수 없습니다: " + id));
    }

    /**
     * 사업장별 오류 로그 조회
     */
    @Transactional(readOnly = true)
    public Page<ErrorLog> getLogsByBusinessPlace(String businessPlaceId, int page, int size) {
        return errorLogRepository.findByBusinessPlaceIdOrderByCreatedAtDesc(
                businessPlaceId, PageRequest.of(page, size));
    }

    /**
     * 사용자별 오류 로그 조회
     */
    @Transactional(readOnly = true)
    public Page<ErrorLog> getLogsByUser(String userId, int page, int size) {
        return errorLogRepository.findByUserIdOrderByCreatedAtDesc(
                UUID.fromString(userId), PageRequest.of(page, size));
    }

    /**
     * 미해결 오류 로그 조회
     */
    @Transactional(readOnly = true)
    public Page<ErrorLog> getUnresolvedLogs(int page, int size) {
        return errorLogRepository.findByResolvedFalseOrderByCreatedAtDesc(PageRequest.of(page, size));
    }

    /**
     * 복합 조건 검색 (전체)
     */
    @Transactional(readOnly = true)
    public Page<ErrorLog> searchLogs(
            ErrorSeverity severity,
            Boolean resolved,
            LocalDateTime startDate,
            LocalDateTime endDate,
            int page,
            int size
    ) {
        return errorLogRepository.findByFilters(
                severity, resolved, startDate, endDate, PageRequest.of(page, size));
    }

    /**
     * 복합 조건 검색 (사업장별)
     */
    @Transactional(readOnly = true)
    public Page<ErrorLog> searchLogsByBusinessPlace(
            String businessPlaceId,
            ErrorSeverity severity,
            Boolean resolved,
            LocalDateTime startDate,
            LocalDateTime endDate,
            int page,
            int size
    ) {
        return errorLogRepository.findByBusinessPlaceIdAndFilters(
                businessPlaceId, severity, resolved, startDate, endDate, PageRequest.of(page, size));
    }

    // ==================== 오류 해결 ====================

    /**
     * 오류 해결 처리
     */
    @Transactional
    public ErrorLog resolveError(String id, String resolvedBy, String resolutionNote) {
        ErrorLog errorLog = getLogById(id);
        errorLog.setResolved(true);
        if (resolvedBy != null) {
            errorLog.setResolvedBy(UUID.fromString(resolvedBy));
        }
        errorLog.setResolvedAt(LocalDateTime.now());
        errorLog.setResolutionNote(resolutionNote);
        return errorLogRepository.save(errorLog);
    }

    /**
     * 오류 미해결로 되돌리기
     */
    @Transactional
    public ErrorLog unresolveError(String id) {
        ErrorLog errorLog = getLogById(id);
        errorLog.setResolved(false);
        errorLog.setResolvedBy(null);
        errorLog.setResolvedAt(null);
        errorLog.setResolutionNote(null);
        return errorLogRepository.save(errorLog);
    }

    // ==================== 통계 ====================

    /**
     * 미해결 오류 개수
     */
    @Transactional(readOnly = true)
    public long getUnresolvedCount() {
        return errorLogRepository.countByResolvedFalse();
    }

    /**
     * 사업장별 미해결 오류 개수
     */
    @Transactional(readOnly = true)
    public long getUnresolvedCountByBusinessPlace(String businessPlaceId) {
        return errorLogRepository.countByBusinessPlaceIdAndResolvedFalse(businessPlaceId);
    }

    /**
     * 심각도별 오류 통계
     */
    @Transactional(readOnly = true)
    public Map<String, Long> getSeverityStatistics(int days) {
        LocalDateTime since = LocalDateTime.now().minusDays(days);
        List<Object[]> results = errorLogRepository.countBySeveritySince(since);

        Map<String, Long> stats = new HashMap<>();
        for (Object[] row : results) {
            stats.put(((ErrorSeverity) row[0]).name(), (Long) row[1]);
        }
        return stats;
    }

    /**
     * 화면별 오류 통계
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getScreenStatistics(int days) {
        LocalDateTime since = LocalDateTime.now().minusDays(days);
        List<Object[]> results = errorLogRepository.countByScreenNameSince(since);

        return results.stream().map(row -> {
            Map<String, Object> stat = new HashMap<>();
            stat.put("screenName", row[0]);
            stat.put("errorCount", row[1]);
            return stat;
        }).toList();
    }

    /**
     * 오류 요약 통계
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getErrorSummary(int days) {
        LocalDateTime since = LocalDateTime.now().minusDays(days);
        LocalDateTime now = LocalDateTime.now();

        Map<String, Object> summary = new HashMap<>();
        summary.put("totalErrors", errorLogRepository.countByCreatedAtBetween(since, now));
        summary.put("unresolvedErrors", errorLogRepository.countByResolvedFalse());
        summary.put("bySeverity", getSeverityStatistics(days));
        summary.put("byScreen", getScreenStatistics(days));

        return summary;
    }

    // ==================== 정리 ====================

    /**
     * 오래된 로그 삭제 (보관 기간 초과)
     */
    @Transactional
    public void cleanupOldLogs(int retentionDays) {
        LocalDateTime before = LocalDateTime.now().minusDays(retentionDays);
        errorLogRepository.deleteByCreatedAtBefore(before);
        log.info("Deleted error logs older than {} days", retentionDays);
    }
}
