package com.vocacrm.api.exception;

/**
 * 접근 권한이 없을 때 발생하는 예외
 *
 * HTTP 403 Forbidden 응답을 반환합니다.
 */
public class AccessDeniedException extends RuntimeException {

    public AccessDeniedException(String message) {
        super(message);
    }

    public AccessDeniedException(String message, Throwable cause) {
        super(message, cause);
    }
}
