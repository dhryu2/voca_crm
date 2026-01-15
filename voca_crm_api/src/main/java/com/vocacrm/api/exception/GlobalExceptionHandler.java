package com.vocacrm.api.exception;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 전역 예외 처리기
 *
 * 모든 컨트롤러에서 발생하는 예외를 일관된 형식으로 처리합니다.
 * Correlation ID를 통해 요청 추적이 가능합니다.
 *
 * 예외 처리 전략:
 * - 400 BAD_REQUEST: 클라이언트 입력 오류 (검증 실패, 잘못된 요청)
 * - 401 UNAUTHORIZED: 인증 실패 (잘못된 자격 증명)
 * - 403 FORBIDDEN: 권한 부족 (인증됐지만 접근 불가)
 * - 404 NOT_FOUND: 리소스 없음
 * - 409 CONFLICT: 데이터 충돌 (중복 등)
 * - 500 INTERNAL_SERVER_ERROR: 서버 오류 (예상치 못한 예외)
 *
 * 핸들러 우선순위 (구체적 → 일반):
 * 1. 검증 관련 예외
 * 2. 요청 파싱 예외
 * 3. 인증/인가 예외
 * 4. 비즈니스 예외
 * 5. DB 예외
 * 6. 일반 예외
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    // ========================================
    // 1. 검증 관련 예외 (Validation Exceptions)
    // ========================================

    /**
     * MethodArgumentNotValidException 처리
     * @Valid 검증 실패 시 발생
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ValidationErrorResponse> handleValidationException(MethodArgumentNotValidException ex) {
        Map<String, String> fieldErrors = new LinkedHashMap<>();

        // 모든 필드 오류 수집
        for (FieldError fieldError : ex.getBindingResult().getFieldErrors()) {
            fieldErrors.put(fieldError.getField(), fieldError.getDefaultMessage());
        }

        // 첫 번째 오류 메시지를 대표 메시지로 사용
        String firstErrorMessage = fieldErrors.isEmpty()
                ? "입력값이 유효하지 않습니다"
                : fieldErrors.values().iterator().next();

        ValidationErrorResponse response = ValidationErrorResponse.builder()
                .message(firstErrorMessage)
                .status(HttpStatus.BAD_REQUEST.value())
                .error("VALIDATION_ERROR")
                .fieldErrors(fieldErrors)
                .errorCount(fieldErrors.size())
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    /**
     * ConstraintViolationException 처리
     * @Validated 사용 시 발생
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ValidationErrorResponse> handleConstraintViolation(ConstraintViolationException ex) {
        Map<String, String> fieldErrors = new LinkedHashMap<>();

        for (ConstraintViolation<?> violation : ex.getConstraintViolations()) {
            String fieldName = violation.getPropertyPath().toString();
            // 메서드 파라미터 이름에서 필드 이름만 추출
            if (fieldName.contains(".")) {
                fieldName = fieldName.substring(fieldName.lastIndexOf(".") + 1);
            }
            fieldErrors.put(fieldName, violation.getMessage());
        }

        String firstErrorMessage = fieldErrors.isEmpty()
                ? "입력값이 유효하지 않습니다"
                : fieldErrors.values().iterator().next();

        ValidationErrorResponse response = ValidationErrorResponse.builder()
                .message(firstErrorMessage)
                .status(HttpStatus.BAD_REQUEST.value())
                .error("VALIDATION_ERROR")
                .fieldErrors(fieldErrors)
                .errorCount(fieldErrors.size())
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    // ========================================
    // 2. 요청 파싱 예외 (Request Parsing Exceptions)
    // ========================================

    /**
     * HttpMessageNotReadableException 처리
     * JSON 파싱 오류 시 발생
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleHttpMessageNotReadable(HttpMessageNotReadableException ex) {
        log.warn("JSON parsing error: {}", ex.getMessage());
        ErrorResponse error = new ErrorResponse(
            "요청 데이터 형식이 올바르지 않습니다.",
            HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    /**
     * MissingServletRequestParameterException 처리
     * 필수 요청 파라미터 누락 시 발생
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ErrorResponse> handleMissingParameter(MissingServletRequestParameterException ex) {
        log.warn("Missing parameter: {}", ex.getParameterName());
        ErrorResponse error = new ErrorResponse(
            "필수 파라미터가 누락되었습니다: " + ex.getParameterName(),
            HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    /**
     * MethodArgumentTypeMismatchException 처리
     * 요청 파라미터 타입 불일치 시 발생
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorResponse> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        log.warn("Type mismatch for parameter: {}", ex.getName());
        ErrorResponse error = new ErrorResponse(
            "파라미터 형식이 올바르지 않습니다: " + ex.getName(),
            HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    // ========================================
    // 3. 인증/인가 예외 (Auth Exceptions)
    // ========================================

    /**
     * InvalidCredentialsException 처리
     * 잘못된 자격 증명 시 발생
     * HTTP 401 UNAUTHORIZED 응답
     */
    @ExceptionHandler(InvalidCredentialsException.class)
    public ResponseEntity<ErrorResponse> handleInvalidCredentials(InvalidCredentialsException ex) {
        ErrorResponse error = new ErrorResponse(
            "아이디 또는 비밀번호가 일치하지 않습니다.",
            HttpStatus.UNAUTHORIZED.value()
        );
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(error);
    }

    /**
     * InvalidTokenException 처리
     * 유효하지 않은 토큰 시 발생
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(InvalidTokenException.class)
    public ResponseEntity<ErrorResponse> handleInvalidToken(InvalidTokenException ex) {
        ErrorResponse error = new ErrorResponse(
            "인증 토큰이 유효하지 않거나 만료되었습니다.",
            HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    /**
     * AccessDeniedException 처리
     * 권한이 없는 리소스에 접근할 때 발생
     * HTTP 403 FORBIDDEN 응답
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException ex) {
        log.warn("Access denied: {}", ex.getMessage());
        ErrorResponse error = new ErrorResponse(
            ex.getMessage(),
            HttpStatus.FORBIDDEN.value()
        );
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error);
    }

    // ========================================
    // 4. 비즈니스 예외 (Business Exceptions)
    // ========================================

    /**
     * UserNotFoundException 처리
     * 사용자를 찾을 수 없을 때 발생
     * HTTP 404 NOT_FOUND 응답
     */
    @ExceptionHandler(UserNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleUserNotFound(UserNotFoundException ex) {
        ErrorResponse error = new ErrorResponse(
            "사용자를 찾을 수 없습니다.",
            HttpStatus.NOT_FOUND.value()
        );
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(error);
    }

    /**
     * ResourceNotFoundException 처리
     * 리소스를 찾을 수 없을 때 발생
     * HTTP 404 NOT_FOUND 응답
     */
    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleResourceNotFound(ResourceNotFoundException ex) {
        log.warn("Resource not found: {}", ex.getMessage());
        ErrorResponse error = new ErrorResponse(
            ex.getMessage(),
            HttpStatus.NOT_FOUND.value()
        );
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(error);
    }

    /**
     * DuplicateUsernameException 처리
     * 중복 아이디 시 발생
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(DuplicateUsernameException.class)
    public ResponseEntity<ErrorResponse> handleDuplicateUsername(DuplicateUsernameException ex) {
        ErrorResponse error = new ErrorResponse(
            "이미 사용 중인 아이디입니다.",
            HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    /**
     * DuplicateUserException 처리
     * 중복 사용자 시 발생
     * HTTP 409 CONFLICT 응답
     */
    @ExceptionHandler(DuplicateUserException.class)
    public ResponseEntity<ErrorResponse> handleDuplicateUser(DuplicateUserException ex) {
        log.warn("Duplicate user: {}", ex.getMessage());
        ErrorResponse error = new ErrorResponse(
            ex.getMessage(),
            HttpStatus.CONFLICT.value()
        );
        return ResponseEntity.status(HttpStatus.CONFLICT).body(error);
    }

    /**
     * InvalidInputException 처리
     * 잘못된 입력값 시 발생
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(InvalidInputException.class)
    public ResponseEntity<ErrorResponse> handleInvalidInput(InvalidInputException ex) {
        log.warn("Invalid input: {}", ex.getMessage());
        ErrorResponse error = new ErrorResponse(
            ex.getMessage(),
            HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    /**
     * BusinessException 처리
     * 비즈니스 로직에서 발생하는 일반 예외
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(BusinessException ex) {
        log.warn("Business exception [{}]: {}", ex.getErrorCode(), ex.getMessage());
        ErrorResponse error = new ErrorResponse(
            ex.getMessage(),
            HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    // ========================================
    // 5. DB 예외 (Database Exceptions)
    // ========================================

    /**
     * DataIntegrityViolationException 처리
     * DB 제약 조건 위반 시 발생 (unique 제약, foreign key 등)
     * HTTP 409 CONFLICT 응답
     */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> handleDataIntegrityViolation(DataIntegrityViolationException ex) {
        log.warn("Data integrity violation: {}", ex.getMessage());

        // 중복 키 에러인지 확인
        String message = "데이터 처리 중 오류가 발생했습니다.";
        if (ex.getMessage() != null && ex.getMessage().toLowerCase().contains("duplicate")) {
            message = "이미 존재하는 데이터입니다.";
        }

        ErrorResponse error = new ErrorResponse(
            message,
            HttpStatus.CONFLICT.value()
        );
        return ResponseEntity.status(HttpStatus.CONFLICT).body(error);
    }

    // ========================================
    // 6. 일반 예외 (General Exceptions)
    // ========================================

    /**
     * IllegalArgumentException 처리
     * 비즈니스 로직에서 발생하는 검증 오류 (예: 중복 예약, 잘못된 날짜 등)
     * HTTP 400 BAD_REQUEST 응답
     */
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorResponse> handleIllegalArgument(IllegalArgumentException ex) {
        log.warn("Illegal argument: {}", ex.getMessage());
        ErrorResponse error = new ErrorResponse(
            ex.getMessage(),
            HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    /**
     * RuntimeException 처리
     * 예상치 못한 런타임 예외를 서버 오류(500)로 처리
     * HTTP 500 INTERNAL_SERVER_ERROR 응답
     *
     * Spring은 더 구체적인 예외 핸들러를 먼저 선택하므로,
     * BusinessException, AccessDeniedException 등은 이 핸들러보다 먼저 처리됨
     */
    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ErrorResponse> handleRuntimeException(RuntimeException ex, WebRequest request) {
        // Correlation ID 생성 (요청 추적용)
        String correlationId = UUID.randomUUID().toString().substring(0, 8);

        // 상세 에러 로깅 (운영 환경에서도 추적 가능)
        log.error("[{}] Unexpected runtime error. URI: {}, Message: {}",
                correlationId,
                request.getDescription(false),
                ex.getMessage(),
                ex  // 전체 스택트레이스 로깅
        );

        ErrorResponse error = new ErrorResponse(
            "서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요. (참조코드: " + correlationId + ")",
            HttpStatus.INTERNAL_SERVER_ERROR.value()
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }

    /**
     * Exception 처리
     * 모든 예외의 최종 폴백 핸들러
     * HTTP 500 INTERNAL_SERVER_ERROR 응답
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneralException(Exception ex, WebRequest request) {
        // Correlation ID 생성 (요청 추적용)
        String correlationId = UUID.randomUUID().toString().substring(0, 8);

        // 상세 에러 로깅 (운영 환경에서도 추적 가능)
        log.error("[{}] Unexpected error occurred. URI: {}, Message: {}",
                correlationId,
                request.getDescription(false),
                ex.getMessage(),
                ex  // 전체 스택트레이스 로깅
        );

        ErrorResponse error = new ErrorResponse(
            "서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요. (참조코드: " + correlationId + ")",
            HttpStatus.INTERNAL_SERVER_ERROR.value()
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
}
