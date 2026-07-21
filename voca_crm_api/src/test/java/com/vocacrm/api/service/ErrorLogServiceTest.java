package com.vocacrm.api.service;

import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.ErrorLog;
import com.vocacrm.api.model.ErrorLog.ErrorSeverity;
import com.vocacrm.api.repository.ErrorLogRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ErrorLogServiceTest {

    @Mock
    private ErrorLogRepository errorLogRepository;

    private ErrorLogService errorLogService;

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String LOG_ID = "660e8400-e29b-41d4-a716-446655440000";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @BeforeEach
    void setUp() {
        errorLogService = new ErrorLogService(errorLogRepository);
    }

    @Test
    void logErrorAsync_정상저장한다() {
        ErrorLog errorLog = ErrorLog.builder().severity(ErrorSeverity.ERROR).screenName("HomeScreen").build();
        when(errorLogRepository.save(errorLog)).thenReturn(errorLog);

        errorLogService.logErrorAsync(errorLog);

        verify(errorLogRepository).save(errorLog);
    }

    @Test
    void logErrorAsync_저장중_예외가_발생해도_전파하지_않는다() {
        ErrorLogRepository failingRepository = mock(ErrorLogRepository.class);
        when(failingRepository.save(any())).thenThrow(new RuntimeException("DB 오류"));
        ErrorLogService failingService = new ErrorLogService(failingRepository);
        ErrorLog errorLog = ErrorLog.builder().severity(ErrorSeverity.ERROR).build();

        failingService.logErrorAsync(errorLog);

        verify(failingRepository).save(errorLog);
    }

    @Test
    void logError_동기적으로_저장하고_반환한다() {
        ErrorLog errorLog = ErrorLog.builder().severity(ErrorSeverity.CRITICAL).build();
        when(errorLogRepository.save(errorLog)).thenReturn(errorLog);

        ErrorLog result = errorLogService.logError(errorLog);

        assertThat(result).isEqualTo(errorLog);
    }

    @Test
    void logSimple_userId가_있으면_UUID로_변환한다() {
        errorLogService.logSimple(USER_ID, "홍길동", BUSINESS_PLACE_ID, "HomeScreen", "조회", "오류 발생", ErrorSeverity.WARNING);

        ArgumentCaptor<ErrorLog> captor = ArgumentCaptor.forClass(ErrorLog.class);
        verify(errorLogRepository).save(captor.capture());
        assertThat(captor.getValue().getUserId()).isEqualTo(UUID.fromString(USER_ID));
        assertThat(captor.getValue().getSeverity()).isEqualTo(ErrorSeverity.WARNING);
    }

    @Test
    void logSimple_userId가_없으면_null로_저장한다() {
        errorLogService.logSimple(null, null, BUSINESS_PLACE_ID, "LoginScreen", "로그인", "인증 실패", ErrorSeverity.ERROR);

        ArgumentCaptor<ErrorLog> captor = ArgumentCaptor.forClass(ErrorLog.class);
        verify(errorLogRepository).save(captor.capture());
        assertThat(captor.getValue().getUserId()).isNull();
    }

    @Test
    void getAllLogs_전체_로그를_페이징조회한다() {
        Page<ErrorLog> page = new PageImpl<>(List.of(ErrorLog.builder().build()));
        when(errorLogRepository.findAllByOrderByCreatedAtDesc(any())).thenReturn(page);

        Page<ErrorLog> result = errorLogService.getAllLogs(0, 10);

        assertThat(result.getTotalElements()).isEqualTo(1);
    }

    @Test
    void getLogById_존재하면_반환한다() {
        ErrorLog errorLog = ErrorLog.builder().id(UUID.fromString(LOG_ID)).build();
        when(errorLogRepository.findById(UUID.fromString(LOG_ID))).thenReturn(Optional.of(errorLog));

        ErrorLog result = errorLogService.getLogById(LOG_ID);

        assertThat(result).isEqualTo(errorLog);
    }

    @Test
    void getLogById_없으면_예외를_던진다() {
        when(errorLogRepository.findById(UUID.fromString(LOG_ID))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> errorLogService.getLogById(LOG_ID))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getLogsByBusinessPlace_사업장별로_조회한다() {
        Page<ErrorLog> page = new PageImpl<>(Collections.emptyList());
        when(errorLogRepository.findByBusinessPlaceIdOrderByCreatedAtDesc(eq(BUSINESS_PLACE_ID), any()))
                .thenReturn(page);

        Page<ErrorLog> result = errorLogService.getLogsByBusinessPlace(BUSINESS_PLACE_ID, 0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void getLogsByUser_사용자별로_조회한다() {
        Page<ErrorLog> page = new PageImpl<>(Collections.emptyList());
        when(errorLogRepository.findByUserIdOrderByCreatedAtDesc(eq(UUID.fromString(USER_ID)), any()))
                .thenReturn(page);

        Page<ErrorLog> result = errorLogService.getLogsByUser(USER_ID, 0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void getUnresolvedLogs_미해결_로그를_조회한다() {
        Page<ErrorLog> page = new PageImpl<>(Collections.emptyList());
        when(errorLogRepository.findByResolvedFalseOrderByCreatedAtDesc(any())).thenReturn(page);

        Page<ErrorLog> result = errorLogService.getUnresolvedLogs(0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void searchLogs_복합조건으로_전체를_검색한다() {
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        Page<ErrorLog> page = new PageImpl<>(Collections.emptyList());
        when(errorLogRepository.findByFilters(eq(ErrorSeverity.ERROR), eq(true), eq(start), eq(end), any()))
                .thenReturn(page);

        Page<ErrorLog> result = errorLogService.searchLogs(ErrorSeverity.ERROR, true, start, end, 0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void searchLogsByBusinessPlace_복합조건으로_사업장별로_검색한다() {
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        Page<ErrorLog> page = new PageImpl<>(Collections.emptyList());
        when(errorLogRepository.findByBusinessPlaceIdAndFilters(
                eq(BUSINESS_PLACE_ID), eq(ErrorSeverity.CRITICAL), eq(false), eq(start), eq(end), any()))
                .thenReturn(page);

        Page<ErrorLog> result = errorLogService.searchLogsByBusinessPlace(
                BUSINESS_PLACE_ID, ErrorSeverity.CRITICAL, false, start, end, 0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void resolveError_해결자정보와_함께_해결처리한다() {
        ErrorLog errorLog = ErrorLog.builder().id(UUID.fromString(LOG_ID)).resolved(false).build();
        when(errorLogRepository.findById(UUID.fromString(LOG_ID))).thenReturn(Optional.of(errorLog));
        when(errorLogRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        ErrorLog result = errorLogService.resolveError(LOG_ID, USER_ID, "패치 배포로 해결");

        assertThat(result.getResolved()).isTrue();
        assertThat(result.getResolvedBy()).isEqualTo(UUID.fromString(USER_ID));
        assertThat(result.getResolutionNote()).isEqualTo("패치 배포로 해결");
        assertThat(result.getResolvedAt()).isNotNull();
    }

    @Test
    void resolveError_해결자ID가_없으면_null로_유지한다() {
        ErrorLog errorLog = ErrorLog.builder().id(UUID.fromString(LOG_ID)).resolved(false).build();
        when(errorLogRepository.findById(UUID.fromString(LOG_ID))).thenReturn(Optional.of(errorLog));
        when(errorLogRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        ErrorLog result = errorLogService.resolveError(LOG_ID, null, "자동 해결");

        assertThat(result.getResolved()).isTrue();
        assertThat(result.getResolvedBy()).isNull();
    }

    @Test
    void unresolveError_미해결_상태로_되돌린다() {
        ErrorLog errorLog = ErrorLog.builder().id(UUID.fromString(LOG_ID)).resolved(true)
                .resolvedBy(UUID.fromString(USER_ID)).resolvedAt(LocalDateTime.now()).resolutionNote("해결됨").build();
        when(errorLogRepository.findById(UUID.fromString(LOG_ID))).thenReturn(Optional.of(errorLog));
        when(errorLogRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        ErrorLog result = errorLogService.unresolveError(LOG_ID);

        assertThat(result.getResolved()).isFalse();
        assertThat(result.getResolvedBy()).isNull();
        assertThat(result.getResolvedAt()).isNull();
        assertThat(result.getResolutionNote()).isNull();
    }

    @Test
    void getUnresolvedCount_전체_미해결_개수를_반환한다() {
        when(errorLogRepository.countByResolvedFalse()).thenReturn(7L);

        long result = errorLogService.getUnresolvedCount();

        assertThat(result).isEqualTo(7L);
    }

    @Test
    void getUnresolvedCountByBusinessPlace_사업장별_미해결_개수를_반환한다() {
        when(errorLogRepository.countByBusinessPlaceIdAndResolvedFalse(BUSINESS_PLACE_ID)).thenReturn(3L);

        long result = errorLogService.getUnresolvedCountByBusinessPlace(BUSINESS_PLACE_ID);

        assertThat(result).isEqualTo(3L);
    }

    @Test
    void getSeverityStatistics_심각도별_통계를_집계한다() {
        List<Object[]> rows = List.of(new Object[]{ErrorSeverity.ERROR, 5L}, new Object[]{ErrorSeverity.CRITICAL, 1L});
        when(errorLogRepository.countBySeveritySince(any())).thenReturn(rows);

        Map<String, Long> result = errorLogService.getSeverityStatistics(30);

        assertThat(result).containsEntry("ERROR", 5L).containsEntry("CRITICAL", 1L);
    }

    @Test
    void getScreenStatistics_화면별_통계를_집계한다() {
        List<Object[]> rows = Collections.singletonList(new Object[]{"HomeScreen", 4L});
        when(errorLogRepository.countByScreenNameSince(any())).thenReturn(rows);

        List<Map<String, Object>> result = errorLogService.getScreenStatistics(30);

        assertThat(result).hasSize(1);
        assertThat(result.get(0)).containsEntry("screenName", "HomeScreen").containsEntry("errorCount", 4L);
    }

    @Test
    void getErrorSummary_전체_요약통계를_집계한다() {
        when(errorLogRepository.countByCreatedAtBetween(any(), any())).thenReturn(20L);
        when(errorLogRepository.countByResolvedFalse()).thenReturn(4L);
        when(errorLogRepository.countBySeveritySince(any())).thenReturn(Collections.emptyList());
        when(errorLogRepository.countByScreenNameSince(any())).thenReturn(Collections.emptyList());

        Map<String, Object> result = errorLogService.getErrorSummary(30);

        assertThat(result.get("totalErrors")).isEqualTo(20L);
        assertThat(result.get("unresolvedErrors")).isEqualTo(4L);
        assertThat(result.get("bySeverity")).isEqualTo(Collections.emptyMap());
        assertThat(result.get("byScreen")).isEqualTo(Collections.emptyList());
    }

    @Test
    void cleanupOldLogs_보관기간이_지난_로그를_삭제한다() {
        errorLogService.cleanupOldLogs(90);

        verify(errorLogRepository).deleteByCreatedAtBefore(any());
    }
}
