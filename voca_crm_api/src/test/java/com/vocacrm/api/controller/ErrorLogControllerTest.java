package com.vocacrm.api.controller;

import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.ErrorLog;
import com.vocacrm.api.model.ErrorLog.ErrorSeverity;
import com.vocacrm.api.service.AdminService;
import com.vocacrm.api.service.ErrorLogService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.ResponseEntity;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ErrorLogControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String LOG_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private ErrorLogService errorLogService;
    @Mock
    private AdminService adminService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private ErrorLogController errorLogController;

    @Test
    void createErrorLog_로그인_상태에서_토큰_userId를_사용한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        ErrorLogController.ErrorLogCreateRequest request = new ErrorLogController.ErrorLogCreateRequest();
        request.setErrorMessage("오류 발생");
        request.setRequestBody("{\"password\":\"secret123\"}");

        ResponseEntity<Map<String, String>> response = errorLogController.createErrorLog(request, servletRequest);

        ArgumentCaptor<ErrorLog> captor = ArgumentCaptor.forClass(ErrorLog.class);
        verify(errorLogService).logErrorAsync(captor.capture());
        assertThat(captor.getValue().getUserId().toString()).isEqualTo(USER_ID);
        assertThat(captor.getValue().getSeverity()).isEqualTo(ErrorSeverity.ERROR);
        assertThat(captor.getValue().getRequestBody()).isEqualTo("{\"password\":\"***\"}");
        assertThat(response.getStatusCode().value()).isEqualTo(201);
    }

    @Test
    void createErrorLog_비로그인_상태에서는_요청바디의_userId를_사용한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(null);
        ErrorLogController.ErrorLogCreateRequest request = new ErrorLogController.ErrorLogCreateRequest();
        request.setErrorMessage("비로그인 오류");
        request.setUserId(null);

        ResponseEntity<Map<String, String>> response = errorLogController.createErrorLog(request, servletRequest);

        ArgumentCaptor<ErrorLog> captor = ArgumentCaptor.forClass(ErrorLog.class);
        verify(errorLogService).logErrorAsync(captor.capture());
        assertThat(captor.getValue().getUserId()).isNull();
        assertThat(response.getStatusCode().value()).isEqualTo(201);
    }

    @Test
    void getAllLogs_시스템관리자가_아니면_예외를_전파하고_서비스는_호출되지_않는다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.FALSE);
        doThrow(new AccessDeniedException("시스템 관리자 권한이 필요합니다."))
                .when(adminService).validateSystemAdmin(Boolean.FALSE);

        assertThatThrownBy(() -> errorLogController.getAllLogs(0, 20, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
        verify(errorLogService, never()).getAllLogs(org.mockito.ArgumentMatchers.anyInt(), org.mockito.ArgumentMatchers.anyInt());
    }

    @Test
    void getAllLogs_시스템관리자면_전체_로그를_반환한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        Page<ErrorLog> page = new PageImpl<>(List.of(ErrorLog.builder().errorMessage("e").build()));
        when(errorLogService.getAllLogs(0, 20)).thenReturn(page);

        ResponseEntity<Page<ErrorLog>> response = errorLogController.getAllLogs(0, 20, servletRequest);

        verify(adminService).validateSystemAdmin(Boolean.TRUE);
        assertThat(response.getBody()).isSameAs(page);
    }

    @Test
    void getLogById_시스템관리자면_정상반환한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        ErrorLog log = ErrorLog.builder().errorMessage("e").build();
        when(errorLogService.getLogById(LOG_ID)).thenReturn(log);

        ResponseEntity<ErrorLog> response = errorLogController.getLogById(LOG_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(log);
    }

    @Test
    void getLogById_시스템관리자가_아니면_예외를_전파한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.FALSE);
        doThrow(new AccessDeniedException("시스템 관리자 권한이 필요합니다."))
                .when(adminService).validateSystemAdmin(Boolean.FALSE);

        assertThatThrownBy(() -> errorLogController.getLogById(LOG_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
        verify(errorLogService, never()).getLogById(LOG_ID);
    }

    @Test
    void getLogsByBusinessPlace_시스템관리자면_정상반환한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        Page<ErrorLog> page = new PageImpl<>(List.of(ErrorLog.builder().errorMessage("e").build()));
        when(errorLogService.getLogsByBusinessPlace(BUSINESS_PLACE_ID, 0, 20)).thenReturn(page);

        ResponseEntity<Page<ErrorLog>> response =
                errorLogController.getLogsByBusinessPlace(BUSINESS_PLACE_ID, 0, 20, servletRequest);

        assertThat(response.getBody()).isSameAs(page);
    }

    @Test
    void getUnresolvedLogs_시스템관리자면_정상반환한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        Page<ErrorLog> page = new PageImpl<>(List.of(ErrorLog.builder().errorMessage("e").build()));
        when(errorLogService.getUnresolvedLogs(0, 20)).thenReturn(page);

        ResponseEntity<Page<ErrorLog>> response = errorLogController.getUnresolvedLogs(0, 20, servletRequest);

        assertThat(response.getBody()).isSameAs(page);
    }

    @Test
    void searchLogs_businessPlaceId가_있으면_searchLogsByBusinessPlace를_호출한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        Page<ErrorLog> page = new PageImpl<>(List.of(ErrorLog.builder().errorMessage("e").build()));
        when(errorLogService.searchLogsByBusinessPlace(BUSINESS_PLACE_ID, ErrorSeverity.ERROR, false, start, end, 0, 20))
                .thenReturn(page);

        ResponseEntity<Page<ErrorLog>> response = errorLogController.searchLogs(
                BUSINESS_PLACE_ID, ErrorSeverity.ERROR, false, start, end, 0, 20, servletRequest);

        verify(errorLogService).searchLogsByBusinessPlace(BUSINESS_PLACE_ID, ErrorSeverity.ERROR, false, start, end, 0, 20);
        assertThat(response.getBody()).isSameAs(page);
    }

    @Test
    void searchLogs_businessPlaceId가_없으면_searchLogs를_호출한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        Page<ErrorLog> page = new PageImpl<>(List.of(ErrorLog.builder().errorMessage("e").build()));
        when(errorLogService.searchLogs(ErrorSeverity.ERROR, null, start, end, 0, 20)).thenReturn(page);

        ResponseEntity<Page<ErrorLog>> response = errorLogController.searchLogs(
                null, ErrorSeverity.ERROR, null, start, end, 0, 20, servletRequest);

        verify(errorLogService).searchLogs(ErrorSeverity.ERROR, null, start, end, 0, 20);
        assertThat(response.getBody()).isSameAs(page);
    }

    @Test
    void resolveError_시스템관리자면_resolvedBy를_토큰userId로_전달한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        ErrorLogController.ResolveRequest request = new ErrorLogController.ResolveRequest();
        request.setResolutionNote("해결됨");
        ErrorLog resolved = ErrorLog.builder().errorMessage("e").build();
        when(errorLogService.resolveError(LOG_ID, USER_ID, "해결됨")).thenReturn(resolved);

        ResponseEntity<ErrorLog> response = errorLogController.resolveError(LOG_ID, request, servletRequest);

        assertThat(response.getBody()).isSameAs(resolved);
    }

    @Test
    void resolveError_시스템관리자가_아니면_예외를_전파한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.FALSE);
        doThrow(new AccessDeniedException("시스템 관리자 권한이 필요합니다."))
                .when(adminService).validateSystemAdmin(Boolean.FALSE);
        ErrorLogController.ResolveRequest request = new ErrorLogController.ResolveRequest();
        request.setResolutionNote("해결됨");

        assertThatThrownBy(() -> errorLogController.resolveError(LOG_ID, request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
        verify(errorLogService, never()).resolveError(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void unresolveError_시스템관리자면_정상반환한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        ErrorLog unresolved = ErrorLog.builder().errorMessage("e").build();
        when(errorLogService.unresolveError(LOG_ID)).thenReturn(unresolved);

        ResponseEntity<ErrorLog> response = errorLogController.unresolveError(LOG_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(unresolved);
    }

    @Test
    void getErrorSummary_시스템관리자면_정상반환한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        Map<String, Object> summary = Map.of("total", 5);
        when(errorLogService.getErrorSummary(7)).thenReturn(summary);

        ResponseEntity<Map<String, Object>> response = errorLogController.getErrorSummary(7, servletRequest);

        assertThat(response.getBody()).isSameAs(summary);
    }

    @Test
    void getUnresolvedCount_businessPlaceId가_있으면_사업장별_카운트를_사용한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        when(errorLogService.getUnresolvedCountByBusinessPlace(BUSINESS_PLACE_ID)).thenReturn(4L);

        ResponseEntity<Map<String, Long>> response =
                errorLogController.getUnresolvedCount(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getBody()).containsEntry("count", 4L);
    }

    @Test
    void getUnresolvedCount_businessPlaceId가_없으면_전체_카운트를_사용한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        when(errorLogService.getUnresolvedCount()).thenReturn(9L);

        ResponseEntity<Map<String, Long>> response = errorLogController.getUnresolvedCount(null, servletRequest);

        assertThat(response.getBody()).containsEntry("count", 9L);
        verify(errorLogService, never()).getUnresolvedCountByBusinessPlace(org.mockito.ArgumentMatchers.any());
    }
}
