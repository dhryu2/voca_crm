package com.vocacrm.api.dto;

import lombok.Data;

/**
 * Ollama API 응답 DTO
 */
@Data
public class OllamaResponse {

    /**
     * 생성된 응답 텍스트 (JSON 문자열)
     */
    private String response;

    /**
     * 사용된 모델 이름
     */
    private String model;

    /**
     * 생성 완료 여부
     */
    private boolean done;
}
