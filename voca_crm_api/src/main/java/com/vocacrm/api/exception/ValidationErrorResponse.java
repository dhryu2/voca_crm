package com.vocacrm.api.exception;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

/**
 * 입력값 검증 오류 응답 DTO
 *
 * @Valid 검증 실패 시 클라이언트에게 상세한 오류 정보를 제공합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ValidationErrorResponse {

    /**
     * 오류 메시지 (한글)
     */
    private String message;

    /**
     * HTTP 상태 코드
     */
    private int status;

    /**
     * 오류 유형 식별자
     */
    private String error;

    /**
     * 필드별 상세 오류 목록
     * key: 필드명, value: 해당 필드의 오류 메시지
     */
    private Map<String, String> fieldErrors;

    /**
     * 오류 개수
     */
    private int errorCount;
}
