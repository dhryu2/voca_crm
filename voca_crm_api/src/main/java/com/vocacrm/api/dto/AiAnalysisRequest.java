package com.vocacrm.api.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.Map;

/**
 * AI 서버로 전송하는 분석 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AiAnalysisRequest {

    /**
     * Ollama 모델명
     */
    private String model;

    /**
     * 분석할 텍스트 (사용자 음성 명령)
     */
    private String prompt;

    /**
     * 스트리밍 여부 (false로 설정하여 전체 응답 수신)
     */
    private boolean stream;

    // 온도를 0으로 설정하기 위한 옵션 객체
    private Map<String, Object> options;

    /**
     * Ollama 모델 메모리 유지 시간. 미설정 시 Ollama 기본(5분)이라
     * 사장 출근 후 첫 명령마다 콜드스타트 타임아웃이 난다.
     */
    @JsonProperty("keep_alive")
    private String keepAlive;
}
