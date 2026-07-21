package com.vocacrm.api.exception;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class CustomExceptionsTest {

    @Test
    void accessDeniedException_메시지만으로_생성한다() {
        AccessDeniedException ex = new AccessDeniedException("접근 거부");

        assertThat(ex.getMessage()).isEqualTo("접근 거부");
        assertThat(ex.getCause()).isNull();
    }

    @Test
    void accessDeniedException_원인과_함께_생성한다() {
        Throwable cause = new RuntimeException("원인");
        AccessDeniedException ex = new AccessDeniedException("접근 거부", cause);

        assertThat(ex.getMessage()).isEqualTo("접근 거부");
        assertThat(ex.getCause()).isEqualTo(cause);
    }

    @Test
    void businessException_메시지만으로_생성하면_기본_에러코드를_가진다() {
        BusinessException ex = new BusinessException("비즈니스 오류");

        assertThat(ex.getMessage()).isEqualTo("비즈니스 오류");
        assertThat(ex.getErrorCode()).isEqualTo("BUSINESS_ERROR");
    }

    @Test
    void businessException_에러코드를_지정해_생성한다() {
        BusinessException ex = new BusinessException("비즈니스 오류", "CUSTOM_CODE");

        assertThat(ex.getMessage()).isEqualTo("비즈니스 오류");
        assertThat(ex.getErrorCode()).isEqualTo("CUSTOM_CODE");
    }

    @Test
    void businessException_원인과_함께_생성하면_기본_에러코드를_가진다() {
        Throwable cause = new RuntimeException("원인");
        BusinessException ex = new BusinessException("비즈니스 오류", cause);

        assertThat(ex.getMessage()).isEqualTo("비즈니스 오류");
        assertThat(ex.getCause()).isEqualTo(cause);
        assertThat(ex.getErrorCode()).isEqualTo("BUSINESS_ERROR");
    }

    @Test
    void duplicateUserException_메시지를_보관한다() {
        DuplicateUserException ex = new DuplicateUserException("중복 사용자");

        assertThat(ex.getMessage()).isEqualTo("중복 사용자");
    }

    @Test
    void duplicateUsernameException_메시지를_보관한다() {
        DuplicateUsernameException ex = new DuplicateUsernameException("중복 아이디");

        assertThat(ex.getMessage()).isEqualTo("중복 아이디");
    }

    @Test
    void invalidCredentialsException_메시지를_보관한다() {
        InvalidCredentialsException ex = new InvalidCredentialsException("자격 증명 오류");

        assertThat(ex.getMessage()).isEqualTo("자격 증명 오류");
    }

    @Test
    void invalidInputException_메시지를_보관한다() {
        InvalidInputException ex = new InvalidInputException("잘못된 입력");

        assertThat(ex.getMessage()).isEqualTo("잘못된 입력");
    }

    @Test
    void invalidTokenException_메시지를_보관한다() {
        InvalidTokenException ex = new InvalidTokenException("유효하지 않은 토큰");

        assertThat(ex.getMessage()).isEqualTo("유효하지 않은 토큰");
    }

    @Test
    void resourceNotFoundException_메시지를_보관한다() {
        ResourceNotFoundException ex = new ResourceNotFoundException("리소스 없음");

        assertThat(ex.getMessage()).isEqualTo("리소스 없음");
    }

    @Test
    void userNotFoundException_메시지를_보관한다() {
        UserNotFoundException ex = new UserNotFoundException("사용자 없음");

        assertThat(ex.getMessage()).isEqualTo("사용자 없음");
    }

    @Test
    void errorResponse_필드값을_보관한다() {
        ErrorResponse response = new ErrorResponse("에러 메시지", 400);

        assertThat(response.getMessage()).isEqualTo("에러 메시지");
        assertThat(response.getStatus()).isEqualTo(400);
    }

    @Test
    void validationErrorResponse_빌더로_필드값을_보관한다() {
        ValidationErrorResponse response = ValidationErrorResponse.builder()
                .message("검증 실패")
                .status(400)
                .error("VALIDATION_ERROR")
                .fieldErrors(java.util.Map.of("name", "필수입니다"))
                .errorCount(1)
                .build();

        assertThat(response.getMessage()).isEqualTo("검증 실패");
        assertThat(response.getStatus()).isEqualTo(400);
        assertThat(response.getError()).isEqualTo("VALIDATION_ERROR");
        assertThat(response.getFieldErrors()).containsEntry("name", "필수입니다");
        assertThat(response.getErrorCount()).isEqualTo(1);
    }
}
