package com.vocacrm.api.controller;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.AuditLog;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.AccessControlService;
import com.vocacrm.api.service.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.ResponseEntity;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuditLogControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final UUID USER_UUID = UUID.fromString(USER_ID);
    private static final String TARGET_USER_ID = "660e8400-e29b-41d4-a716-446655440000";
    private static final UUID TARGET_USER_UUID = UUID.fromString(TARGET_USER_ID);
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private AuditLogService auditLogService;
    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;
    @Mock
    private AccessControlService accessControlService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private AuditLogController auditLogController;

    @BeforeEach
    void setUp() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
    }

    private void stubRole(String userId, Role role) {
        UserBusinessPlace ubp = UserBusinessPlace.builder().role(role).build();
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(userId), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ubp));
    }

    private void stubNoRole(String userId) {
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(userId), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.empty());
    }

    @Test
    void getAuditLogs_businessPlaceId가_없으면_defaultBusinessPlaceId를_사용한다() {
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(BUSINESS_PLACE_ID);
        stubRole(USER_ID, Role.OWNER);
        Page<AuditLog> page = new PageImpl<>(List.of(new AuditLog()));
        when(auditLogService.searchLogs(eq(BUSINESS_PLACE_ID), any(), any(), any(), anyInt(), anyInt()))
                .thenReturn(page);

        ResponseEntity<?> response = auditLogController.getAuditLogs(
                servletRequest, 0, 20, null, null, null, null);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        @SuppressWarnings("unchecked")
        Map<String, Object> body = (Map<String, Object>) response.getBody();
        assertThat(body).containsEntry("totalElements", 1L);
    }

    @Test
    void getAuditLogs_businessPlaceId가_전혀_없으면_400을_반환한다() {
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(null);

        ResponseEntity<?> response = auditLogController.getAuditLogs(
                servletRequest, 0, 20, null, null, null, null);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
        verify(auditLogService, never()).searchLogs(anyString(), any(), any(), any(), anyInt(), anyInt());
    }

    @Test
    void getAuditLogs_사업장_권한이_없으면_403을_반환한다() {
        stubNoRole(USER_ID);

        ResponseEntity<?> response = auditLogController.getAuditLogs(
                servletRequest, 0, 20, null, null, null, BUSINESS_PLACE_ID);

        assertThat(response.getStatusCode().value()).isEqualTo(403);
    }

    @Test
    void getAuditLogs_STAFF는_전체조회시_403을_반환한다() {
        stubRole(USER_ID, Role.STAFF);

        ResponseEntity<?> response = auditLogController.getAuditLogs(
                servletRequest, 0, 20, null, null, null, BUSINESS_PLACE_ID);

        assertThat(response.getStatusCode().value()).isEqualTo(403);
    }

    @Test
    void getAuditLogs_OWNER는_searchLogs를_호출한다() {
        stubRole(USER_ID, Role.OWNER);
        LocalDateTime start = LocalDateTime.now().minusDays(1);
        LocalDateTime end = LocalDateTime.now();
        Page<AuditLog> page = new PageImpl<>(List.of(new AuditLog()));
        when(auditLogService.searchLogs(BUSINESS_PLACE_ID, "MEMBER", start, end, 0, 20)).thenReturn(page);

        ResponseEntity<?> response = auditLogController.getAuditLogs(
                servletRequest, 0, 20, "MEMBER", start, end, BUSINESS_PLACE_ID);

        verify(auditLogService).searchLogs(BUSINESS_PLACE_ID, "MEMBER", start, end, 0, 20);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void getAuditLogs_MANAGER는_searchLogsForManager를_호출한다() {
        stubRole(USER_ID, Role.MANAGER);
        Page<AuditLog> page = new PageImpl<>(List.of(new AuditLog()));
        when(auditLogService.searchLogsForManager(eq(BUSINESS_PLACE_ID), eq(USER_ID), any(), any(), any(), anyInt(), anyInt()))
                .thenReturn(page);

        ResponseEntity<?> response = auditLogController.getAuditLogs(
                servletRequest, 0, 20, null, null, null, BUSINESS_PLACE_ID);

        verify(auditLogService).searchLogsForManager(eq(BUSINESS_PLACE_ID), eq(USER_ID), any(), any(), any(), anyInt(), anyInt());
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void getEntityHistory_사업장_정보가_없으면_400을_반환한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(null);

        ResponseEntity<?> response = auditLogController.getEntityHistory(servletRequest, "MEMBER", "id-1");

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void getEntityHistory_STAFF는_403을_반환한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        stubRole(USER_ID, Role.STAFF);

        ResponseEntity<?> response = auditLogController.getEntityHistory(servletRequest, "MEMBER", "id-1");

        assertThat(response.getStatusCode().value()).isEqualTo(403);
    }

    @Test
    void getEntityHistory_MANAGER이상은_이력을_조회한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        stubRole(USER_ID, Role.MANAGER);
        List<AuditLog> history = List.of(new AuditLog());
        when(auditLogService.getEntityHistory("MEMBER", "id-1", BUSINESS_PLACE_ID)).thenReturn(history);

        ResponseEntity<?> response = auditLogController.getEntityHistory(servletRequest, "member", "id-1");

        @SuppressWarnings("unchecked")
        Map<String, Object> body = (Map<String, Object>) response.getBody();
        assertThat(body).containsEntry("history", history);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void getUserLogs_사업장_정보가_없으면_400을_반환한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(null);

        ResponseEntity<?> response = auditLogController.getUserLogs(servletRequest, TARGET_USER_ID, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void getUserLogs_요청자가_사업장_권한이_없으면_403을_반환한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        stubNoRole(USER_ID);

        ResponseEntity<?> response = auditLogController.getUserLogs(servletRequest, TARGET_USER_ID, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(403);
    }

    @Test
    void getUserLogs_STAFF가_타인_로그_조회시_403을_반환한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        stubRole(USER_ID, Role.STAFF);

        ResponseEntity<?> response = auditLogController.getUserLogs(servletRequest, TARGET_USER_ID, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(403);
    }

    @Test
    void getUserLogs_MANAGER가_STAFF가_아닌_대상을_조회시_403을_반환한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        stubRole(USER_ID, Role.MANAGER);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                TARGET_USER_UUID, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(UserBusinessPlace.builder().role(Role.MANAGER).build()));

        ResponseEntity<?> response = auditLogController.getUserLogs(servletRequest, TARGET_USER_ID, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(403);
    }

    @Test
    void getUserLogs_MANAGER가_STAFF_대상을_조회하면_허용된다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        stubRole(USER_ID, Role.MANAGER);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                TARGET_USER_UUID, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(UserBusinessPlace.builder().role(Role.STAFF).build()));
        Page<AuditLog> page = new PageImpl<>(List.of(new AuditLog()));
        when(auditLogService.getLogsByUser(TARGET_USER_ID, BUSINESS_PLACE_ID, 0, 20)).thenReturn(page);

        ResponseEntity<?> response = auditLogController.getUserLogs(servletRequest, TARGET_USER_ID, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void getUserLogs_본인_로그_조회는_항상_허용된다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        stubRole(USER_ID, Role.STAFF);
        Page<AuditLog> page = new PageImpl<>(List.of(new AuditLog()));
        when(auditLogService.getLogsByUser(USER_ID, BUSINESS_PLACE_ID, 0, 20)).thenReturn(page);

        ResponseEntity<?> response = auditLogController.getUserLogs(servletRequest, USER_ID, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        verify(auditLogService).getLogsByUser(USER_ID, BUSINESS_PLACE_ID, 0, 20);
    }

    @Test
    void getUserLogs_OWNER는_모든_사용자_로그를_조회할_수_있다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        stubRole(USER_ID, Role.OWNER);
        Page<AuditLog> page = new PageImpl<>(List.of(new AuditLog()));
        when(auditLogService.getLogsByUser(TARGET_USER_ID, BUSINESS_PLACE_ID, 0, 20)).thenReturn(page);

        ResponseEntity<?> response = auditLogController.getUserLogs(servletRequest, TARGET_USER_ID, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void getMyLogs_userId가_없으면_400을_반환한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(null);

        ResponseEntity<?> response = auditLogController.getMyLogs(servletRequest, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void getMyLogs_사업장_정보가_없으면_400을_반환한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(null);

        ResponseEntity<?> response = auditLogController.getMyLogs(servletRequest, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void getMyLogs_정상적으로_본인_로그를_조회한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        Page<AuditLog> page = new PageImpl<>(List.of(new AuditLog()));
        when(auditLogService.getLogsByUser(USER_ID, BUSINESS_PLACE_ID, 0, 20)).thenReturn(page);

        ResponseEntity<?> response = auditLogController.getMyLogs(servletRequest, 0, 20);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void getActionStatistics_사업장_정보가_없으면_400을_반환한다() {
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(null);

        ResponseEntity<?> response = auditLogController.getActionStatistics(servletRequest, 30, null);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void getActionStatistics_STAFF는_403을_반환한다() {
        stubRole(USER_ID, Role.STAFF);

        ResponseEntity<?> response = auditLogController.getActionStatistics(servletRequest, 30, BUSINESS_PLACE_ID);

        assertThat(response.getStatusCode().value()).isEqualTo(403);
    }

    @Test
    void getActionStatistics_MANAGER이상은_통계를_조회한다() {
        stubRole(USER_ID, Role.MANAGER);
        Map<String, Long> stats = Map.of("CREATE", 5L);
        when(auditLogService.getActionStatistics(BUSINESS_PLACE_ID, 30)).thenReturn(stats);

        ResponseEntity<?> response = auditLogController.getActionStatistics(servletRequest, 30, BUSINESS_PLACE_ID);

        @SuppressWarnings("unchecked")
        Map<String, Object> body = (Map<String, Object>) response.getBody();
        assertThat(body).containsEntry("statistics", stats);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void getUserActivityStatistics_사업장_정보가_없으면_400을_반환한다() {
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(null);

        ResponseEntity<?> response = auditLogController.getUserActivityStatistics(servletRequest, 30, null);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void getUserActivityStatistics_OWNER가_아니면_403을_반환한다() {
        stubRole(USER_ID, Role.MANAGER);

        ResponseEntity<?> response = auditLogController.getUserActivityStatistics(servletRequest, 30, BUSINESS_PLACE_ID);

        assertThat(response.getStatusCode().value()).isEqualTo(403);
    }

    @Test
    void getUserActivityStatistics_OWNER는_통계를_조회한다() {
        stubRole(USER_ID, Role.OWNER);
        List<Map<String, Object>> stats = List.of(Map.of("userId", USER_ID, "count", 10));
        when(auditLogService.getUserActivityStatistics(BUSINESS_PLACE_ID, 30)).thenReturn(stats);

        ResponseEntity<?> response = auditLogController.getUserActivityStatistics(servletRequest, 30, BUSINESS_PLACE_ID);

        @SuppressWarnings("unchecked")
        Map<String, Object> body = (Map<String, Object>) response.getBody();
        assertThat(body).containsEntry("statistics", stats);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }
}
