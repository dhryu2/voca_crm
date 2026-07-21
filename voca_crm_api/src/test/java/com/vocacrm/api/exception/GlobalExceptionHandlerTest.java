package com.vocacrm.api.exception;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.Path;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GlobalExceptionHandlerTest {

    private GlobalExceptionHandler handler;

    @BeforeEach
    void setUp() {
        handler = new GlobalExceptionHandler();
    }

    @Test
    void handleValidationException_필드오류를_모아_400을_반환한다() {
        MethodArgumentNotValidException ex = mock(MethodArgumentNotValidException.class);
        BindingResult bindingResult = mock(BindingResult.class);
        FieldError fieldError = new FieldError("member", "name", "이름은 필수입니다");
        when(ex.getBindingResult()).thenReturn(bindingResult);
        when(bindingResult.getFieldErrors()).thenReturn(List.of(fieldError));

        ResponseEntity<ValidationErrorResponse> response = handler.handleValidationException(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).isEqualTo("이름은 필수입니다");
        assertThat(response.getBody().getError()).isEqualTo("VALIDATION_ERROR");
        assertThat(response.getBody().getFieldErrors()).containsEntry("name", "이름은 필수입니다");
        assertThat(response.getBody().getErrorCount()).isEqualTo(1);
    }

    @Test
    void handleValidationException_필드오류가_없으면_기본메시지를_사용한다() {
        MethodArgumentNotValidException ex = mock(MethodArgumentNotValidException.class);
        BindingResult bindingResult = mock(BindingResult.class);
        when(ex.getBindingResult()).thenReturn(bindingResult);
        when(bindingResult.getFieldErrors()).thenReturn(List.of());

        ResponseEntity<ValidationErrorResponse> response = handler.handleValidationException(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).isEqualTo("입력값이 유효하지 않습니다");
        assertThat(response.getBody().getErrorCount()).isZero();
    }

    @Test
    void handleConstraintViolation_필드오류를_모아_400을_반환한다() {
        ConstraintViolation<?> violation = mock(ConstraintViolation.class);
        Path path = mock(Path.class);
        when(path.toString()).thenReturn("createMember.name");
        when(violation.getPropertyPath()).thenReturn(path);
        when(violation.getMessage()).thenReturn("이름은 필수입니다");

        ConstraintViolationException ex = new ConstraintViolationException("검증 실패", Set.of(violation));

        ResponseEntity<ValidationErrorResponse> response = handler.handleConstraintViolation(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getFieldErrors()).containsEntry("name", "이름은 필수입니다");
        assertThat(response.getBody().getMessage()).isEqualTo("이름은 필수입니다");
    }

    @Test
    void handleConstraintViolation_필드오류가_없으면_기본메시지를_사용한다() {
        ConstraintViolationException ex = new ConstraintViolationException("검증 실패", Set.of());

        ResponseEntity<ValidationErrorResponse> response = handler.handleConstraintViolation(ex);

        assertThat(response.getBody().getMessage()).isEqualTo("입력값이 유효하지 않습니다");
    }

    @Test
    void handleHttpMessageNotReadable_400을_반환한다() {
        HttpMessageNotReadableException ex = mock(HttpMessageNotReadableException.class);

        ResponseEntity<ErrorResponse> response = handler.handleHttpMessageNotReadable(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).isEqualTo("요청 데이터 형식이 올바르지 않습니다.");
    }

    @Test
    void handleMissingParameter_파라미터명을_포함해_400을_반환한다() {
        MissingServletRequestParameterException ex =
                new MissingServletRequestParameterException("memberId", "String");

        ResponseEntity<ErrorResponse> response = handler.handleMissingParameter(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).contains("memberId");
    }

    @Test
    void handleMissingHeader_헤더명을_포함해_400을_반환한다() {
        MissingRequestHeaderException ex = mock(MissingRequestHeaderException.class);
        when(ex.getHeaderName()).thenReturn("Authorization");

        ResponseEntity<ErrorResponse> response = handler.handleMissingHeader(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).contains("Authorization");
    }

    @Test
    void handleTypeMismatch_파라미터명을_포함해_400을_반환한다() {
        MethodArgumentTypeMismatchException ex = mock(MethodArgumentTypeMismatchException.class);
        when(ex.getName()).thenReturn("page");

        ResponseEntity<ErrorResponse> response = handler.handleTypeMismatch(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).contains("page");
    }

    @Test
    void handleInvalidCredentials_401을_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleInvalidCredentials(new InvalidCredentialsException("자격 증명 오류"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody().getMessage()).isEqualTo("아이디 또는 비밀번호가 일치하지 않습니다.");
    }

    @Test
    void handleInvalidToken_400을_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleInvalidToken(new InvalidTokenException("토큰 오류"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).isEqualTo("인증 토큰이 유효하지 않거나 만료되었습니다.");
    }

    @Test
    void handleAccessDenied_403을_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleAccessDenied(new AccessDeniedException("접근 거부"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(response.getBody().getMessage()).isEqualTo("접근 거부");
    }

    @Test
    void handleSecurityException_메시지가_있으면_그대로_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleSecurityException(new SecurityException("권한 없음"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(response.getBody().getMessage()).isEqualTo("권한 없음");
    }

    @Test
    void handleSecurityException_메시지가_없으면_기본메시지를_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleSecurityException(new SecurityException());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(response.getBody().getMessage()).isEqualTo("접근 권한이 없습니다.");
    }

    @Test
    void handleUserNotFound_404를_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleUserNotFound(new UserNotFoundException("사용자 없음"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody().getMessage()).isEqualTo("사용자를 찾을 수 없습니다.");
    }

    @Test
    void handleResourceNotFound_404를_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleResourceNotFound(new ResourceNotFoundException("회원을 찾을 수 없습니다"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody().getMessage()).isEqualTo("회원을 찾을 수 없습니다");
    }

    @Test
    void handleDuplicateUsername_400을_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleDuplicateUsername(new DuplicateUsernameException("중복 아이디"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).isEqualTo("이미 사용 중인 아이디입니다.");
    }

    @Test
    void handleDuplicateUser_409를_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleDuplicateUser(new DuplicateUserException("중복 사용자입니다"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody().getMessage()).isEqualTo("중복 사용자입니다");
    }

    @Test
    void handleInvalidInput_400을_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleInvalidInput(new InvalidInputException("입력값 오류"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).isEqualTo("입력값 오류");
    }

    @Test
    void handleBusinessException_400을_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleBusinessException(new BusinessException("비즈니스 오류", "CODE1"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).isEqualTo("비즈니스 오류");
    }

    @Test
    void handleDataIntegrityViolation_중복키_메시지면_중복_안내를_반환한다() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException("Duplicate entry 'x' for key");

        ResponseEntity<ErrorResponse> response = handler.handleDataIntegrityViolation(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody().getMessage()).isEqualTo("이미 존재하는 데이터입니다.");
    }

    @Test
    void handleDataIntegrityViolation_그외_메시지면_기본_안내를_반환한다() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException("foreign key constraint fails");

        ResponseEntity<ErrorResponse> response = handler.handleDataIntegrityViolation(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody().getMessage()).isEqualTo("데이터 처리 중 오류가 발생했습니다.");
    }

    @Test
    void handleIllegalArgument_400을_반환한다() {
        ResponseEntity<ErrorResponse> response =
                handler.handleIllegalArgument(new IllegalArgumentException("잘못된 인자"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).isEqualTo("잘못된 인자");
    }

    @Test
    void handleRuntimeException_500을_반환하고_참조코드를_포함한다() {
        WebRequest request = mock(WebRequest.class);
        when(request.getDescription(false)).thenReturn("uri=/api/test");

        ResponseEntity<ErrorResponse> response =
                handler.handleRuntimeException(new RuntimeException("예상치 못한 오류"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody().getMessage()).contains("참조코드");
    }

    @Test
    void handleGeneralException_500을_반환하고_참조코드를_포함한다() {
        WebRequest request = mock(WebRequest.class);
        when(request.getDescription(false)).thenReturn("uri=/api/test");

        ResponseEntity<ErrorResponse> response =
                handler.handleGeneralException(new Exception("일반 오류"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody().getMessage()).contains("참조코드");
    }
}
