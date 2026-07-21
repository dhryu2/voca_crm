package com.vocacrm.api.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.vocacrm.api.model.AuditLog;
import com.vocacrm.api.model.AuditLog.AuditAction;
import com.vocacrm.api.repository.AuditLogRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
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
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuditLogServiceTest {

    @Mock
    private AuditLogRepository auditLogRepository;
    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;

    private ObjectMapper objectMapper;

    private AuditLogService auditLogService;

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String ENTITY_ID = "660e8400-e29b-41d4-a716-446655440000";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        auditLogService = new AuditLogService(auditLogRepository, userBusinessPlaceRepository, objectMapper);
    }

    @Test
    void logCreate_생성_로그를_기록한다() {
        auditLogService.logCreate(USER_ID, "홍길동", BUSINESS_PLACE_ID, "MEMBER", ENTITY_ID, "회원A", Map.of("name", "회원A"));

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        AuditLog saved = captor.getValue();
        assertThat(saved.getAction()).isEqualTo(AuditAction.CREATE);
        assertThat(saved.getEntityType()).isEqualTo("MEMBER");
        assertThat(saved.getEntityId()).isEqualTo(UUID.fromString(ENTITY_ID));
        assertThat(saved.getChangesAfter()).contains("회원A");
    }

    @Test
    void logUpdate_수정_로그를_기록한다() {
        auditLogService.logUpdate(USER_ID, "홍길동", BUSINESS_PLACE_ID, "MEMBER", ENTITY_ID, "회원A",
                Map.of("grade", "SILVER"), Map.of("grade", "GOLD"));

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.UPDATE);
        assertThat(captor.getValue().getChangesBefore()).contains("SILVER");
        assertThat(captor.getValue().getChangesAfter()).contains("GOLD");
    }

    @Test
    void logDelete_삭제_로그를_기록한다() {
        auditLogService.logDelete(USER_ID, "홍길동", BUSINESS_PLACE_ID, "MEMBER", ENTITY_ID, "회원A", Map.of("name", "회원A"));

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.DELETE);
    }

    @Test
    void logRestore_복원_로그를_기록한다() {
        auditLogService.logRestore(USER_ID, "홍길동", BUSINESS_PLACE_ID, "MEMBER", ENTITY_ID, "회원A");

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.RESTORE);
    }

    @Test
    void logLogin_로그인_로그를_기록한다() {
        auditLogService.logLogin(USER_ID, "홍길동", BUSINESS_PLACE_ID);

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.LOGIN);
    }

    @Test
    void logLoginFailed_UUID형식이_아닌_경우_랜덤_UUID를_생성한다() {
        auditLogService.logLoginFailed("not-a-uuid", "비밀번호 불일치");

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        AuditLog saved = captor.getValue();
        assertThat(saved.getAction()).isEqualTo(AuditAction.LOGIN_FAILED);
        assertThat(saved.getUserId()).isNotNull();
        assertThat(saved.getEntityId()).isNotNull();
    }

    @Test
    void logLogout_로그아웃_로그를_기록한다() {
        auditLogService.logLogout(USER_ID, "홍길동", BUSINESS_PLACE_ID);

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.LOGOUT);
    }

    @Test
    void logAdminAction_관리자_작업_로그를_기록한다() {
        auditLogService.logAdminAction(USER_ID, "관리자", "USER", ENTITY_ID, "사용자 정보 수정", Map.of("field", "value"));

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.ADMIN_ACTION);
        assertThat(captor.getValue().getDescription()).contains("[시스템 관리자]");
    }

    @Test
    void logPermissionChange_권한_변경_로그를_기록한다() {
        auditLogService.logPermissionChange(USER_ID, "관리자", BUSINESS_PLACE_ID, ENTITY_ID, "대상자",
                Map.of("role", "STAFF"), Map.of("role", "MANAGER"), "역할 변경");

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.PERMISSION_CHANGE);
    }

    @Test
    void logUserSuspend_사용자_정지_로그를_기록한다() {
        auditLogService.logUserSuspend(USER_ID, "관리자", ENTITY_ID, "대상자", "이용약관 위반");

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.USER_SUSPEND);
        assertThat(captor.getValue().getDescription()).contains("이용약관 위반");
    }

    @Test
    void logUserActivate_사용자_활성화_로그를_기록한다() {
        auditLogService.logUserActivate(USER_ID, "관리자", ENTITY_ID, "대상자");

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.USER_ACTIVATE);
    }

    @Test
    void logBusinessPlaceDelete_사업장_삭제_로그를_기록한다() {
        auditLogService.logBusinessPlaceDelete(USER_ID, "관리자", BUSINESS_PLACE_ID, "테스트 사업장", Map.of("name", "테스트 사업장"));

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.BUSINESS_PLACE_DELETE);
    }

    @Test
    void logAccessDenied_접근_거부_로그를_기록한다() {
        auditLogService.logAccessDenied(USER_ID, "홍길동", BUSINESS_PLACE_ID, "MEMBER", ENTITY_ID, "삭제");

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.ACCESS_DENIED);
    }

    @Test
    void logSecurityAlert_보안_경고_로그를_기록한다() {
        auditLogService.logSecurityAlert(USER_ID, "홍길동", "REPEATED_FAILURE", "5회 이상 로그인 실패", Map.of("count", 5));

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.SECURITY_ALERT);
    }

    @Test
    void log_동기_로그를_기록한다() {
        auditLogService.log(USER_ID, "홍길동", BUSINESS_PLACE_ID, AuditAction.VIEW, "MEMBER", ENTITY_ID, "회원A",
                null, null, "조회");

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(AuditAction.VIEW);
        assertThat(captor.getValue().getChangesBefore()).isNull();
        assertThat(captor.getValue().getChangesAfter()).isNull();
    }

    @Test
    void logAsync_저장중_예외가_발생해도_전파하지_않는다() {
        AuditLogRepository failingRepository = mock(AuditLogRepository.class);
        when(failingRepository.save(any())).thenThrow(new RuntimeException("DB 오류"));
        AuditLogService failingService = new AuditLogService(failingRepository, userBusinessPlaceRepository, objectMapper);

        failingService.logAsync(USER_ID, "홍길동", BUSINESS_PLACE_ID, AuditAction.CREATE,
                "MEMBER", ENTITY_ID, "회원A", null, null, "생성");

        verify(failingRepository).save(any());
    }

    @Test
    void logAsync_직렬화_실패시_toString으로_대체한다() throws JsonProcessingException {
        ObjectMapper failingMapper = mock(ObjectMapper.class);
        when(failingMapper.writeValueAsString(any())).thenThrow(new com.fasterxml.jackson.core.JsonGenerationException("fail", (com.fasterxml.jackson.core.JsonGenerator) null));
        AuditLogService serviceWithFailingMapper = new AuditLogService(auditLogRepository, userBusinessPlaceRepository, failingMapper);

        serviceWithFailingMapper.logAsync(USER_ID, "홍길동", BUSINESS_PLACE_ID, AuditAction.CREATE,
                "MEMBER", ENTITY_ID, "회원A", null, "afterData", "생성");

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getChangesAfter()).isEqualTo("afterData");
    }

    @Test
    void getLogsByBusinessPlace_사업장별_로그를_조회한다() {
        Page<AuditLog> page = new PageImpl<>(Collections.singletonList(AuditLog.builder().build()));
        when(auditLogRepository.findByBusinessPlaceIdOrderByCreatedAtDesc(eq(BUSINESS_PLACE_ID), any()))
                .thenReturn(page);

        Page<AuditLog> result = auditLogService.getLogsByBusinessPlace(BUSINESS_PLACE_ID, 0, 10);

        assertThat(result.getTotalElements()).isEqualTo(1);
    }

    @Test
    void getLogsByUser_사업장ID가_없으면_예외를_던진다() {
        assertThatThrownBy(() -> auditLogService.getLogsByUser(USER_ID, null, 0, 10))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> auditLogService.getLogsByUser(USER_ID, "", 0, 10))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getLogsByUser_정상_조회한다() {
        Page<AuditLog> page = new PageImpl<>(Collections.singletonList(AuditLog.builder().build()));
        when(auditLogRepository.findByUserIdAndBusinessPlaceIdOrderByCreatedAtDesc(
                eq(UUID.fromString(USER_ID)), eq(BUSINESS_PLACE_ID), any())).thenReturn(page);

        Page<AuditLog> result = auditLogService.getLogsByUser(USER_ID, BUSINESS_PLACE_ID, 0, 10);

        assertThat(result.getTotalElements()).isEqualTo(1);
    }

    @Test
    void getEntityHistory_사업장ID가_없으면_예외를_던진다() {
        assertThatThrownBy(() -> auditLogService.getEntityHistory("MEMBER", ENTITY_ID, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getEntityHistory_정상_조회한다() {
        when(auditLogRepository.findByEntityTypeAndEntityIdAndBusinessPlaceIdOrderByCreatedAtAsc(
                "MEMBER", UUID.fromString(ENTITY_ID), BUSINESS_PLACE_ID))
                .thenReturn(List.of(AuditLog.builder().build()));

        List<AuditLog> result = auditLogService.getEntityHistory("MEMBER", ENTITY_ID, BUSINESS_PLACE_ID);

        assertThat(result).hasSize(1);
    }

    @Test
    void getLogsByDateRange_정상_조회한다() {
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        Page<AuditLog> page = new PageImpl<>(Collections.emptyList());
        when(auditLogRepository.findByBusinessPlaceIdAndDateRange(eq(BUSINESS_PLACE_ID), eq(start), eq(end), any()))
                .thenReturn(page);

        Page<AuditLog> result = auditLogService.getLogsByDateRange(BUSINESS_PLACE_ID, start, end, 0, 10);

        assertThat(result.getTotalElements()).isEqualTo(0);
    }

    @Test
    void searchLogs_엔티티타입이_없으면_기간조건만으로_조회한다() {
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        Page<AuditLog> page = new PageImpl<>(Collections.emptyList());
        when(auditLogRepository.findByBusinessPlaceIdAndDateRange(eq(BUSINESS_PLACE_ID), eq(start), eq(end), any()))
                .thenReturn(page);

        Page<AuditLog> result = auditLogService.searchLogs(BUSINESS_PLACE_ID, null, start, end, 0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void searchLogs_엔티티타입이_있으면_엔티티타입조건으로_조회한다() {
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        Page<AuditLog> page = new PageImpl<>(Collections.emptyList());
        when(auditLogRepository.findByBusinessPlaceIdAndEntityTypeAndDateRange(
                eq(BUSINESS_PLACE_ID), eq("MEMBER"), eq(start), eq(end), any())).thenReturn(page);

        Page<AuditLog> result = auditLogService.searchLogs(BUSINESS_PLACE_ID, "MEMBER", start, end, 0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void searchLogsForManager_엔티티타입이_없으면_사용자목록조건으로_조회한다() {
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        UUID staffId = UUID.randomUUID();
        when(userBusinessPlaceRepository.findStaffUserIdsByBusinessPlaceId(BUSINESS_PLACE_ID))
                .thenReturn(List.of(staffId));
        Page<AuditLog> page = new PageImpl<>(Collections.emptyList());
        when(auditLogRepository.findByBusinessPlaceIdAndUserIdInAndDateRange(
                eq(BUSINESS_PLACE_ID), anyList(), eq(start), eq(end), any())).thenReturn(page);

        Page<AuditLog> result = auditLogService.searchLogsForManager(
                BUSINESS_PLACE_ID, USER_ID, null, start, end, 0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void searchLogsForManager_엔티티타입이_있으면_엔티티조건도_포함해서_조회한다() {
        LocalDateTime start = LocalDateTime.now().minusDays(7);
        LocalDateTime end = LocalDateTime.now();
        when(userBusinessPlaceRepository.findStaffUserIdsByBusinessPlaceId(BUSINESS_PLACE_ID))
                .thenReturn(Collections.emptyList());
        Page<AuditLog> page = new PageImpl<>(Collections.emptyList());
        when(auditLogRepository.findByBusinessPlaceIdAndUserIdInAndEntityTypeAndDateRange(
                eq(BUSINESS_PLACE_ID), anyList(), eq("MEMBER"), eq(start), eq(end), any())).thenReturn(page);

        Page<AuditLog> result = auditLogService.searchLogsForManager(
                BUSINESS_PLACE_ID, USER_ID, "MEMBER", start, end, 0, 10);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void getActionStatistics_액션별_통계를_집계한다() {
        List<Object[]> rows = List.of(new Object[]{AuditAction.CREATE, 5L}, new Object[]{AuditAction.UPDATE, 3L});
        when(auditLogRepository.countByActionSince(eq(BUSINESS_PLACE_ID), any())).thenReturn(rows);

        Map<String, Long> result = auditLogService.getActionStatistics(BUSINESS_PLACE_ID, 30);

        assertThat(result).containsEntry("CREATE", 5L).containsEntry("UPDATE", 3L);
    }

    @Test
    void getActionStatistics_결과가_없으면_빈_맵을_반환한다() {
        when(auditLogRepository.countByActionSince(eq(BUSINESS_PLACE_ID), any())).thenReturn(Collections.emptyList());

        Map<String, Long> result = auditLogService.getActionStatistics(BUSINESS_PLACE_ID, 30);

        assertThat(result).isEmpty();
    }

    @Test
    void getUserActivityStatistics_사용자별_활동통계를_집계한다() {
        List<Object[]> rows = Collections.singletonList(new Object[]{UUID.fromString(USER_ID), "홍길동", 7L});
        when(auditLogRepository.countByUserSince(eq(BUSINESS_PLACE_ID), any())).thenReturn(rows);

        List<Map<String, Object>> result = auditLogService.getUserActivityStatistics(BUSINESS_PLACE_ID, 30);

        assertThat(result).hasSize(1);
        assertThat(result.get(0)).containsEntry("username", "홍길동").containsEntry("activityCount", 7L);
    }
}
