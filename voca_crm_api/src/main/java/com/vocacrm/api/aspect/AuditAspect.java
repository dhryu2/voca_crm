package com.vocacrm.api.aspect;

import com.vocacrm.api.model.AuditLog.AuditAction;
import com.vocacrm.api.service.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.AfterReturning;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.lang.annotation.*;
import java.util.Map;

/**
 * 감사 로그 Aspect
 *
 * @Audited 어노테이션이 붙은 메서드의 실행을 자동으로 감사 로그에 기록합니다.
 */
@Slf4j
@Aspect
@Component
@RequiredArgsConstructor
public class AuditAspect {

    private final AuditLogService auditLogService;

    /**
     * 감사 로그 대상 메서드 지정 어노테이션
     */
    @Target(ElementType.METHOD)
    @Retention(RetentionPolicy.RUNTIME)
    @Documented
    public @interface Audited {
        /**
         * 액션 타입
         */
        AuditAction action();

        /**
         * 엔티티 타입 (예: "MEMBER", "MEMO")
         */
        String entityType();

        /**
         * 설명 (선택)
         */
        String description() default "";
    }

    /**
     * @Audited 어노테이션이 붙은 메서드 실행 후 로깅
     */
    @AfterReturning(
            pointcut = "@annotation(audited)",
            returning = "result"
    )
    public void logAuditedMethod(JoinPoint joinPoint, Audited audited, Object result) {
        try {
            // 현재 요청에서 사용자 정보 추출
            ServletRequestAttributes attrs =
                    (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();

            if (attrs == null) {
                return;
            }

            HttpServletRequest request = attrs.getRequest();
            String userId = (String) request.getAttribute("userId");
            String username = (String) request.getAttribute("username");
            String businessPlaceId = (String) request.getAttribute("defaultBusinessPlaceId");

            if (userId == null) {
                return;
            }

            // 결과에서 엔티티 ID 추출 시도
            String entityId = extractEntityId(result, joinPoint.getArgs());
            String entityName = extractEntityName(result);

            // 감사 로그 기록
            auditLogService.logAsync(
                    userId,
                    username,
                    businessPlaceId,
                    audited.action(),
                    audited.entityType(),
                    entityId,
                    entityName,
                    null,  // beforeData는 별도 처리 필요
                    result,
                    audited.description().isEmpty() ?
                            audited.action() + " " + audited.entityType() :
                            audited.description()
            );

        } catch (Exception e) {
            log.error("Failed to create audit log for method: {}",
                    joinPoint.getSignature().getName(), e);
        }
    }

    /**
     * Member 컨트롤러의 생성 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.MemberController.createMember(..))",
            returning = "result"
    )
    public void auditMemberCreate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.CREATE, "MEMBER", "회원 생성");
    }

    /**
     * Member 컨트롤러의 수정 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.MemberController.updateMember(..))",
            returning = "result"
    )
    public void auditMemberUpdate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.UPDATE, "MEMBER", "회원 수정");
    }

    /**
     * Member 컨트롤러의 삭제 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.MemberController.deleteMember(..))",
            returning = "result"
    )
    public void auditMemberDelete(JoinPoint joinPoint, Object result) {
        String memberId = extractIdFromArgs(joinPoint.getArgs(), "id");
        logControllerAction(joinPoint, result, AuditAction.DELETE, "MEMBER", "회원 삭제", memberId);
    }

    /**
     * Member 컨트롤러의 복원 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.MemberController.restoreMember(..))",
            returning = "result"
    )
    public void auditMemberRestore(JoinPoint joinPoint, Object result) {
        String memberId = extractIdFromArgs(joinPoint.getArgs(), "id");
        logControllerAction(joinPoint, result, AuditAction.RESTORE, "MEMBER", "회원 복원", memberId);
    }

    /**
     * Memo 컨트롤러의 생성 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.MemoController.createMemo(..))",
            returning = "result"
    )
    public void auditMemoCreate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.CREATE, "MEMO", "메모 생성");
    }

    /**
     * Memo 컨트롤러의 수정 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.MemoController.updateMemo(..))",
            returning = "result"
    )
    public void auditMemoUpdate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.UPDATE, "MEMO", "메모 수정");
    }

    /**
     * Memo 컨트롤러의 삭제 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.MemoController.deleteMemo(..))",
            returning = "result"
    )
    public void auditMemoDelete(JoinPoint joinPoint, Object result) {
        String memoId = extractIdFromArgs(joinPoint.getArgs(), "id");
        logControllerAction(joinPoint, result, AuditAction.DELETE, "MEMO", "메모 삭제", memoId);
    }

    /**
     * Reservation 컨트롤러의 생성 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.ReservationController.create*(..))",
            returning = "result"
    )
    public void auditReservationCreate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.CREATE, "RESERVATION", "예약 생성");
    }

    /**
     * Reservation 컨트롤러의 수정 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.ReservationController.update*(..))",
            returning = "result"
    )
    public void auditReservationUpdate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.UPDATE, "RESERVATION", "예약 수정");
    }

    /**
     * Reservation 컨트롤러의 삭제/취소 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.ReservationController.delete*(..))" +
                    " || execution(* com.vocacrm.api.controller.ReservationController.cancel*(..))",
            returning = "result"
    )
    public void auditReservationDelete(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.DELETE, "RESERVATION", "예약 취소/삭제");
    }

    /**
     * Visit 컨트롤러의 체크인 메서드 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.VisitController.checkIn(..))",
            returning = "result"
    )
    public void auditVisitCheckIn(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.CREATE, "VISIT", "회원 체크인");
    }

    // ==================== 인증 관련 감사 ====================

    /**
     * 로그인 성공 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.AuthController.loginWithSocialToken(..))",
            returning = "result"
    )
    public void auditLogin(JoinPoint joinPoint, Object result) {
        logAuthAction(joinPoint, result, AuditAction.LOGIN, "로그인");
    }

    /**
     * 회원가입 성공 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.AuthController.signupWithSocialToken(..))",
            returning = "result"
    )
    public void auditSignup(JoinPoint joinPoint, Object result) {
        logAuthAction(joinPoint, result, AuditAction.CREATE, "회원가입");
    }

    /**
     * 로그아웃 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.AuthController.logout(..))",
            returning = "result"
    )
    public void auditLogout(JoinPoint joinPoint, Object result) {
        logAuthAction(joinPoint, result, AuditAction.LOGOUT, "로그아웃");
    }

    /**
     * 모든 기기 로그아웃 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.AuthController.logoutAllDevices(..))",
            returning = "result"
    )
    public void auditLogoutAllDevices(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.LOGOUT, "USER", "모든 기기 로그아웃");
    }

    // ==================== 사업장 관련 감사 ====================

    /**
     * 사업장 생성 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.createBusinessPlace(..))",
            returning = "result"
    )
    public void auditBusinessPlaceCreate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.CREATE, "BUSINESS_PLACE", "사업장 생성");
    }

    /**
     * 사업장 수정 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.updateBusinessPlace(..))",
            returning = "result"
    )
    public void auditBusinessPlaceUpdate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.UPDATE, "BUSINESS_PLACE", "사업장 정보 수정");
    }

    /**
     * 사업장 등록 요청 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.requestAccess(..))",
            returning = "result"
    )
    public void auditAccessRequest(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.CREATE, "ACCESS_REQUEST", "사업장 등록 요청");
    }

    /**
     * 사업장 등록 요청 승인 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.approveRequest(..))",
            returning = "result"
    )
    public void auditAccessRequestApprove(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.UPDATE, "ACCESS_REQUEST", "사업장 등록 요청 승인");
    }

    /**
     * 사업장 등록 요청 거절 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.rejectRequest(..))",
            returning = "result"
    )
    public void auditAccessRequestReject(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.UPDATE, "ACCESS_REQUEST", "사업장 등록 요청 거절");
    }

    /**
     * 사업장 등록 요청 삭제 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.deleteRequest(..))",
            returning = "result"
    )
    public void auditAccessRequestDelete(JoinPoint joinPoint, Object result) {
        String requestId = extractIdFromArgs(joinPoint.getArgs(), "id");
        logControllerAction(joinPoint, result, AuditAction.DELETE, "ACCESS_REQUEST", "사업장 등록 요청 삭제", requestId);
    }

    /**
     * 사업장 등록 결과 확인 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.markRequestAsRead(..))",
            returning = "result"
    )
    public void auditAccessRequestRead(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.VIEW, "ACCESS_REQUEST", "사업장 등록 결과 확인");
    }

    /**
     * 사업장 탈퇴 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.removeBusinessPlace(..))",
            returning = "result"
    )
    public void auditBusinessPlaceLeave(JoinPoint joinPoint, Object result) {
        String businessPlaceId = extractIdFromArgs(joinPoint.getArgs(), "id");
        logControllerAction(joinPoint, result, AuditAction.DELETE, "USER_BUSINESS_PLACE", "사업장 탈퇴", businessPlaceId);
    }

    /**
     * 멤버 역할 변경 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.updateMemberRole(..))",
            returning = "result"
    )
    public void auditMemberRoleUpdate(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.UPDATE, "USER_BUSINESS_PLACE", "멤버 역할 변경");
    }

    /**
     * 멤버 강제 탈퇴 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.removeMember(..))",
            returning = "result"
    )
    public void auditMemberRemove(JoinPoint joinPoint, Object result) {
        logControllerAction(joinPoint, result, AuditAction.DELETE, "USER_BUSINESS_PLACE", "멤버 강제 탈퇴");
    }

    /**
     * 사업장 영구 삭제 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.deleteBusinessPlacePermanently(..))",
            returning = "result"
    )
    public void auditBusinessPlacePermanentDelete(JoinPoint joinPoint, Object result) {
        String businessPlaceId = extractIdFromArgs(joinPoint.getArgs(), "id");
        logControllerAction(joinPoint, result, AuditAction.PERMANENT_DELETE, "BUSINESS_PLACE", "사업장 영구 삭제", businessPlaceId);
    }

    /**
     * 기본 사업장 설정 감사
     */
    @AfterReturning(
            pointcut = "execution(* com.vocacrm.api.controller.BusinessPlaceController.setDefaultBusinessPlace(..))",
            returning = "result"
    )
    public void auditSetDefaultBusinessPlace(JoinPoint joinPoint, Object result) {
        String businessPlaceId = extractIdFromArgs(joinPoint.getArgs(), "id");
        logControllerAction(joinPoint, result, AuditAction.UPDATE, "USER", "기본 사업장 설정", businessPlaceId);
    }

    // ==================== 헬퍼 메서드 ====================

    /**
     * 인증 액션 로깅 (로그인/로그아웃 등)
     * 인증 API는 JWT가 없으므로 응답에서 사용자 정보를 추출
     */
    private void logAuthAction(
            JoinPoint joinPoint,
            Object result,
            AuditAction action,
            String description
    ) {
        try {
            // 응답이 에러인 경우 로깅 스킵
            if (result instanceof ResponseEntity<?> response) {
                if (!response.getStatusCode().is2xxSuccessful()) {
                    return;
                }

                // 응답에서 사용자 ID 추출 시도 (로그인 성공 시 JWT에서)
                Object body = response.getBody();
                String userId = "unknown";
                String username = null;

                if (body instanceof Map<?, ?> map) {
                    // accessToken이 있으면 JWT에서 userId 추출 시도
                    Object accessToken = map.get("accessToken");
                    if (accessToken != null) {
                        userId = extractUserIdFromJwt(accessToken.toString());
                    }
                }

                auditLogService.logAsync(
                        userId,
                        username,
                        null, // 로그인 시점에는 businessPlaceId 없음
                        action,
                        "USER",
                        userId,
                        null,
                        null,
                        null,
                        description
                );
            }
        } catch (Exception e) {
            log.error("Failed to create auth audit log", e);
        }
    }

    /**
     * JWT에서 userId 추출 (간단한 파싱)
     */
    private String extractUserIdFromJwt(String jwt) {
        try {
            String[] parts = jwt.split("\\.");
            if (parts.length >= 2) {
                String payload = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
                // 간단한 JSON 파싱 - "sub":"..." 패턴 찾기
                int subIndex = payload.indexOf("\"sub\"");
                if (subIndex >= 0) {
                    int colonIndex = payload.indexOf(":", subIndex);
                    int startQuote = payload.indexOf("\"", colonIndex);
                    int endQuote = payload.indexOf("\"", startQuote + 1);
                    if (startQuote >= 0 && endQuote > startQuote) {
                        return payload.substring(startQuote + 1, endQuote);
                    }
                }
            }
        } catch (Exception e) {
            log.debug("Failed to extract userId from JWT", e);
        }
        return "unknown";
    }

    /**
     * 컨트롤러 액션 로깅
     */
    private void logControllerAction(
            JoinPoint joinPoint,
            Object result,
            AuditAction action,
            String entityType,
            String description
    ) {
        logControllerAction(joinPoint, result, action, entityType, description, null);
    }

    private void logControllerAction(
            JoinPoint joinPoint,
            Object result,
            AuditAction action,
            String entityType,
            String description,
            String entityIdOverride
    ) {
        try {
            // 응답이 에러인 경우 로깅 스킵
            if (result instanceof ResponseEntity<?> response) {
                if (!response.getStatusCode().is2xxSuccessful()) {
                    return;
                }
            }

            ServletRequestAttributes attrs =
                    (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
            if (attrs == null) return;

            HttpServletRequest request = attrs.getRequest();
            String userId = (String) request.getAttribute("userId");
            String username = (String) request.getAttribute("username");
            String businessPlaceId = (String) request.getAttribute("defaultBusinessPlaceId");

            if (userId == null) return;

            String entityId = entityIdOverride != null ?
                    entityIdOverride : extractEntityId(result, joinPoint.getArgs());
            String entityName = extractEntityName(result);

            auditLogService.logAsync(
                    userId,
                    username,
                    businessPlaceId,
                    action,
                    entityType,
                    entityId != null ? entityId : "unknown",
                    entityName,
                    null,
                    extractResponseBody(result),
                    description
            );

        } catch (Exception e) {
            log.error("Failed to create audit log", e);
        }
    }

    /**
     * 결과에서 엔티티 ID 추출
     */
    private String extractEntityId(Object result, Object[] args) {
        // ResponseEntity에서 body 추출
        if (result instanceof ResponseEntity<?> response) {
            Object body = response.getBody();
            if (body instanceof Map<?, ?> map) {
                Object id = map.get("id");
                if (id != null) return id.toString();
            }
        }

        // 첫 번째 String 인자가 ID일 가능성
        for (Object arg : args) {
            if (arg instanceof String str && str.length() == 36) {
                return str;  // UUID 형식
            }
        }

        return null;
    }

    /**
     * 메서드 인자에서 특정 이름의 ID 추출
     */
    private String extractIdFromArgs(Object[] args, String paramName) {
        for (Object arg : args) {
            if (arg instanceof String str && str.length() == 36) {
                return str;
            }
        }
        return null;
    }

    /**
     * 결과에서 엔티티 이름 추출
     */
    private String extractEntityName(Object result) {
        if (result instanceof ResponseEntity<?> response) {
            Object body = response.getBody();
            if (body instanceof Map<?, ?> map) {
                // name, title, content 순으로 시도
                for (String key : new String[]{"name", "title", "memberNumber", "content"}) {
                    Object value = map.get(key);
                    if (value != null) {
                        String str = value.toString();
                        return str.length() > 100 ? str.substring(0, 100) : str;
                    }
                }
            }
        }
        return null;
    }

    /**
     * ResponseEntity에서 body 추출
     */
    private Object extractResponseBody(Object result) {
        if (result instanceof ResponseEntity<?> response) {
            return response.getBody();
        }
        return result;
    }
}
