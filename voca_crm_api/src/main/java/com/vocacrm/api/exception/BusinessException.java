package com.vocacrm.api.exception;

/**
 * 비즈니스 로직 처리 중 발생하는 일반 예외
 *
 * HTTP 400 Bad Request 응답을 반환합니다.
 * 구체적인 예외 유형이 정의되지 않은 경우 사용합니다.
 */
public class BusinessException extends RuntimeException {

    private final String errorCode;

    public BusinessException(String message) {
        super(message);
        this.errorCode = "BUSINESS_ERROR";
    }

    public BusinessException(String message, String errorCode) {
        super(message);
        this.errorCode = errorCode;
    }

    public BusinessException(String message, Throwable cause) {
        super(message, cause);
        this.errorCode = "BUSINESS_ERROR";
    }

    public String getErrorCode() {
        return errorCode;
    }
}
