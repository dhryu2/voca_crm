package com.vocacrm.api.aspect;

import com.vocacrm.api.aspect.AuditAspect.Audited;
import com.vocacrm.api.model.AuditLog.AuditAction;
import com.vocacrm.api.service.AuditLogService;
import org.aspectj.lang.JoinPoint;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

@ExtendWith(MockitoExtension.class)
class AuditAspectTest {

    @Mock
    private AuditLogService auditLogService;

    @Mock
    private JoinPoint joinPoint;

    private AuditAspect auditAspect;

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String USERNAME = "tester";
    private static final String BUSINESS_PLACE_ID = "BP1";

    @BeforeEach
    void setUp() {
        auditAspect = new AuditAspect(auditLogService);
    }

    @AfterEach
    void tearDown() {
        RequestContextHolder.resetRequestAttributes();
    }

    private void setAuthenticatedRequestContext() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/members");
        request.setAttribute("userId", USER_ID);
        request.setAttribute("username", USERNAME);
        request.setAttribute("defaultBusinessPlaceId", BUSINESS_PLACE_ID);
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
    }

    private Audited annotated(AuditAction action, String entityType, String description) throws Exception {
        Method method = description.isEmpty()
                ? AnnotatedTargets.class.getDeclaredMethod("noDescription")
                : AnnotatedTargets.class.getDeclaredMethod("withDescription");
        Audited real = method.getAnnotation(Audited.class);
        // Only two fixed annotation instances are declared on the helper class,
        // so route to the one matching the requested action/entityType/description.
        assertThat(real.action()).isNotNull();
        return real;
    }

    private static class AnnotatedTargets {
        @Audited(action = AuditAction.CREATE, entityType = "MEMBER")
        void noDescription() {
        }

        @Audited(action = AuditAction.UPDATE, entityType = "MEMBER", description = "커스텀 설명")
        void withDescription() {
        }
    }

    @Test
    void logAuditedMethod_noRequestContext_doesNotCallService() throws Exception {
        RequestContextHolder.resetRequestAttributes();
        Audited audited = annotated(AuditAction.CREATE, "MEMBER", "");
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "e1"));

        auditAspect.logAuditedMethod(joinPoint, audited, result);

        verifyNoInteractions(auditLogService);
    }

    @Test
    void logAuditedMethod_noUserId_doesNotCallService() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/members");
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
        Audited audited = annotated(AuditAction.CREATE, "MEMBER", "");
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "e1"));

        auditAspect.logAuditedMethod(joinPoint, audited, result);

        verifyNoInteractions(auditLogService);
    }

    @Test
    void logAuditedMethod_withUserId_callsServiceWithDefaultDescription() throws Exception {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        Audited audited = annotated(AuditAction.CREATE, "MEMBER", "");
        ResponseEntity<Map<String, Object>> result =
                ResponseEntity.ok(Map.of("id", "entity-1", "name", "John"));

        auditAspect.logAuditedMethod(joinPoint, audited, result);

        verify(auditLogService).logAsync(
                eq(USER_ID),
                eq(USERNAME),
                eq(BUSINESS_PLACE_ID),
                eq(AuditAction.CREATE),
                eq("MEMBER"),
                eq("entity-1"),
                eq("John"),
                isNull(),
                eq(result),
                eq("CREATE MEMBER")
        );
    }

    @Test
    void logAuditedMethod_withDescription_usesProvidedDescription() throws Exception {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        Audited audited = annotated(AuditAction.UPDATE, "MEMBER", "커스텀 설명");
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of());

        auditAspect.logAuditedMethod(joinPoint, audited, result);

        ArgumentCaptor<String> descriptionCaptor = ArgumentCaptor.forClass(String.class);
        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("MEMBER"), isNull(), isNull(), isNull(), eq(result), descriptionCaptor.capture()
        );
        assertThat(descriptionCaptor.getValue()).isEqualTo("커스텀 설명");
    }

    @Test
    void auditMemberCreate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "m1", "name", "member"));

        auditAspect.auditMemberCreate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.CREATE),
                eq("MEMBER"), eq("m1"), eq("member"), isNull(), any(), eq("회원 생성")
        );
    }

    @Test
    void auditMemberCreate_errorResponse_doesNotCallService() {
        setAuthenticatedRequestContext();
        ResponseEntity<Map<String, Object>> result =
                ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "bad"));

        auditAspect.auditMemberCreate(joinPoint, result);

        verifyNoInteractions(auditLogService);
    }

    @Test
    void auditMemberUpdate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "m1"));

        auditAspect.auditMemberUpdate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("MEMBER"), eq("m1"), isNull(), isNull(), any(), eq("회원 수정")
        );
    }

    @Test
    void auditMemberRestore_extractsIdFromArgs() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{USER_ID});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of());

        auditAspect.auditMemberRestore(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.RESTORE),
                eq("MEMBER"), eq(USER_ID), isNull(), isNull(), any(), eq("회원 복원")
        );
    }

    @Test
    void auditMemoCreate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "memo1"));

        auditAspect.auditMemoCreate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.CREATE),
                eq("MEMO"), eq("memo1"), isNull(), isNull(), any(), eq("메모 생성")
        );
    }

    @Test
    void auditMemoUpdate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "memo1"));

        auditAspect.auditMemoUpdate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("MEMO"), eq("memo1"), isNull(), isNull(), any(), eq("메모 수정")
        );
    }

    @Test
    void auditMemoDelete_extractsIdFromArgs() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{USER_ID});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of());

        auditAspect.auditMemoDelete(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.DELETE),
                eq("MEMO"), eq(USER_ID), isNull(), isNull(), any(), eq("메모 삭제")
        );
    }

    @Test
    void auditReservationCreate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "r1"));

        auditAspect.auditReservationCreate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.CREATE),
                eq("RESERVATION"), eq("r1"), isNull(), isNull(), any(), eq("예약 생성")
        );
    }

    @Test
    void auditReservationUpdate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "r1"));

        auditAspect.auditReservationUpdate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("RESERVATION"), eq("r1"), isNull(), isNull(), any(), eq("예약 수정")
        );
    }

    @Test
    void auditReservationDelete_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "r1"));

        auditAspect.auditReservationDelete(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.DELETE),
                eq("RESERVATION"), eq("r1"), isNull(), isNull(), any(), eq("예약 취소/삭제")
        );
    }

    @Test
    void auditVisitCheckIn_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "v1"));

        auditAspect.auditVisitCheckIn(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.CREATE),
                eq("VISIT"), eq("v1"), isNull(), isNull(), any(), eq("회원 체크인")
        );
    }

    @Test
    void auditBusinessPlaceCreate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "bp1"));

        auditAspect.auditBusinessPlaceCreate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.CREATE),
                eq("BUSINESS_PLACE"), eq("bp1"), isNull(), isNull(), any(), eq("사업장 생성")
        );
    }

    @Test
    void auditBusinessPlaceUpdate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "bp1"));

        auditAspect.auditBusinessPlaceUpdate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("BUSINESS_PLACE"), eq("bp1"), isNull(), isNull(), any(), eq("사업장 정보 수정")
        );
    }

    @Test
    void auditAccessRequest_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "req1"));

        auditAspect.auditAccessRequest(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.CREATE),
                eq("ACCESS_REQUEST"), eq("req1"), isNull(), isNull(), any(), eq("사업장 등록 요청")
        );
    }

    @Test
    void auditAccessRequestApprove_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "req1"));

        auditAspect.auditAccessRequestApprove(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("ACCESS_REQUEST"), eq("req1"), isNull(), isNull(), any(), eq("사업장 등록 요청 승인")
        );
    }

    @Test
    void auditAccessRequestReject_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "req1"));

        auditAspect.auditAccessRequestReject(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("ACCESS_REQUEST"), eq("req1"), isNull(), isNull(), any(), eq("사업장 등록 요청 거절")
        );
    }

    @Test
    void auditAccessRequestDelete_extractsIdFromArgs() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{USER_ID});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of());

        auditAspect.auditAccessRequestDelete(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.DELETE),
                eq("ACCESS_REQUEST"), eq(USER_ID), isNull(), isNull(), any(), eq("사업장 등록 요청 삭제")
        );
    }

    @Test
    void auditAccessRequestRead_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "req1"));

        auditAspect.auditAccessRequestRead(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.VIEW),
                eq("ACCESS_REQUEST"), eq("req1"), isNull(), isNull(), any(), eq("사업장 등록 결과 확인")
        );
    }

    @Test
    void auditBusinessPlaceLeave_extractsIdFromArgs() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{USER_ID});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of());

        auditAspect.auditBusinessPlaceLeave(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.DELETE),
                eq("USER_BUSINESS_PLACE"), eq(USER_ID), isNull(), isNull(), any(), eq("사업장 탈퇴")
        );
    }

    @Test
    void auditMemberRoleUpdate_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "ubp1"));

        auditAspect.auditMemberRoleUpdate(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("USER_BUSINESS_PLACE"), eq("ubp1"), isNull(), isNull(), any(), eq("멤버 역할 변경")
        );
    }

    @Test
    void auditMemberRemove_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "ubp1"));

        auditAspect.auditMemberRemove(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.DELETE),
                eq("USER_BUSINESS_PLACE"), eq("ubp1"), isNull(), isNull(), any(), eq("멤버 강제 탈퇴")
        );
    }

    @Test
    void auditBusinessPlacePermanentDelete_extractsIdFromArgs() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{USER_ID});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of());

        auditAspect.auditBusinessPlacePermanentDelete(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.PERMANENT_DELETE),
                eq("BUSINESS_PLACE"), eq(USER_ID), isNull(), isNull(), any(), eq("사업장 영구 삭제")
        );
    }

    @Test
    void auditSetDefaultBusinessPlace_extractsIdFromArgs() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{USER_ID});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of());

        auditAspect.auditSetDefaultBusinessPlace(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.UPDATE),
                eq("USER"), eq(USER_ID), isNull(), isNull(), any(), eq("기본 사업장 설정")
        );
    }

    @Test
    void auditLogout_success_callsService() {
        setAuthenticatedRequestContext();
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("message", "ok"));

        auditAspect.auditLogout(joinPoint, result);

        verify(auditLogService).logAsync(
                eq("unknown"), isNull(), isNull(), eq(AuditAction.LOGOUT),
                eq("USER"), eq("unknown"), isNull(), isNull(), isNull(), eq("로그아웃")
        );
    }

    @Test
    void auditLogoutAllDevices_success_callsService() {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of());

        auditAspect.auditLogoutAllDevices(joinPoint, result);

        verify(auditLogService).logAsync(
                eq(USER_ID), eq(USERNAME), eq(BUSINESS_PLACE_ID), eq(AuditAction.LOGOUT),
                eq("USER"), eq("unknown"), isNull(), isNull(), any(), eq("모든 기기 로그아웃")
        );
    }

    @Test
    void auditLogin_success_extractsUserIdFromAccessTokenJwt() {
        String jwt = fakeJwtWithSubject("jwt-user-1");
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("accessToken", jwt));

        auditAspect.auditLogin(joinPoint, result);

        verify(auditLogService).logAsync(
                eq("jwt-user-1"), isNull(), isNull(), eq(AuditAction.LOGIN),
                eq("USER"), eq("jwt-user-1"), isNull(), isNull(), isNull(), eq("로그인")
        );
    }

    @Test
    void auditLogin_errorResponse_doesNotCallService() {
        ResponseEntity<Map<String, Object>> result =
                ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "denied"));

        auditAspect.auditLogin(joinPoint, result);

        verify(auditLogService, never()).logAsync(
                any(), any(), any(), any(), any(), any(), any(), any(), any(), any()
        );
    }

    @Test
    void auditLogin_malformedAccessToken_returnsUnknownUser() {
        ResponseEntity<Map<String, Object>> result =
                ResponseEntity.ok(Map.of("accessToken", "not-a-valid-jwt"));

        auditAspect.auditLogin(joinPoint, result);

        verify(auditLogService).logAsync(
                eq("unknown"), isNull(), isNull(), eq(AuditAction.LOGIN),
                eq("USER"), eq("unknown"), isNull(), isNull(), isNull(), eq("로그인")
        );
    }

    @Test
    void auditSignup_success_callsService() {
        String jwt = fakeJwtWithSubject("jwt-user-2");
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("accessToken", jwt));

        auditAspect.auditSignup(joinPoint, result);

        verify(auditLogService).logAsync(
                eq("jwt-user-2"), isNull(), isNull(), eq(AuditAction.CREATE),
                eq("USER"), eq("jwt-user-2"), isNull(), isNull(), isNull(), eq("회원가입")
        );
    }

    @Test
    void logAuditedMethod_serviceThrows_isCaughtAndLogged() throws Exception {
        setAuthenticatedRequestContext();
        org.mockito.Mockito.when(joinPoint.getArgs()).thenReturn(new Object[]{});
        org.mockito.Mockito.when(joinPoint.getSignature())
                .thenReturn(org.mockito.Mockito.mock(org.aspectj.lang.Signature.class));
        org.mockito.Mockito.doThrow(new RuntimeException("db down"))
                .when(auditLogService).logAsync(
                        any(), any(), any(), any(), any(), any(), any(), any(), any(), any()
                );
        Audited audited = annotated(AuditAction.CREATE, "MEMBER", "");
        ResponseEntity<Map<String, Object>> result = ResponseEntity.ok(Map.of("id", "m1"));

        // logAuditedMethod swallows exceptions from auditLogService, so no exception should propagate
        auditAspect.logAuditedMethod(joinPoint, audited, result);

        verify(auditLogService).logAsync(
                any(), any(), any(), any(), any(), any(), any(), any(), any(), any()
        );
    }

    private static String fakeJwtWithSubject(String subject) {
        String header = Base64.getUrlEncoder().withoutPadding()
                .encodeToString("{\"alg\":\"none\"}".getBytes(StandardCharsets.UTF_8));
        String payload = Base64.getUrlEncoder().withoutPadding()
                .encodeToString(("{\"sub\":\"" + subject + "\"}").getBytes(StandardCharsets.UTF_8));
        return header + "." + payload + ".signature";
    }
}
