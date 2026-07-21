package com.vocacrm.api.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.vocacrm.api.dto.AiAnalysisRequest;
import com.vocacrm.api.dto.AiAnalysisResult;
import com.vocacrm.api.dto.OllamaResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.time.Duration;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * AI 서버 (Ollama) 통신 클라이언트
 * Modelfile.txt에서 정의한 JSON 형식 응답을 파싱
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiServerClient {

    private final WebClient webClient;
    private final ObjectMapper objectMapper;
    private final DailyAiUsageLimiter dailyAiUsageLimiter;

    @Value("${ai.server.url}")
    private String aiServerUrl;

    @Value("${ai.server.model}")
    private String modelName;

    @Value("${ai.server.timeout}")
    private int timeout;

    // JSON 추출을 위한 정규식 패턴
    private static final Pattern JSON_PATTERN = Pattern.compile("\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}");
    private static final Pattern CODE_BLOCK_PATTERN = Pattern.compile("```(?:json)?\\s*([\\s\\S]*?)```");

    /**
     * AI 서버에 텍스트를 전송하여 명령 분석 수행
     *
     * @param text 사용자 음성 명령 텍스트
     * @return AI가 분석한 결과 목록 (멀티액션 시 다수, 단일 명령 시 1개)
     */
    public List<AiAnalysisResult> analyzeCommand(String text) {
        // 일일 사용량 제한 체크
        if (!dailyAiUsageLimiter.tryConsume()) {
            log.warn("Daily AI usage limit exceeded. Current: {}, Max: {}",
                    dailyAiUsageLimiter.getCurrentUsage(),
                    dailyAiUsageLimiter.getMaxDailyRequests());
            return Collections.singletonList(createDailyLimitExceededResult());
        }

        log.debug("Voice command text: '{}'", text);

        // 상세 옵션 설정 (무작위성 제거)
        Map<String, Object> options = new HashMap<>();
        options.put("temperature", 0.0);
        // 멀티액션 배열 및 긴 메모 내용이 잘리지 않도록 충분히 확보
        options.put("num_predict", 512);

        // 모델이 인식하기 좋게 프롬프트 가공 (Prefix/Suffix 추가)
        String optimizedPrompt = String.format("Input: \"%s\"\nOutput:", text);

        // 요청 객체 빌드
        // 주의: format("json")을 지정하면 출력이 단일 객체로 강제되어 멀티액션 배열이 깨진다.
        //       Modelfile이 temperature 0 + raw JSON 배열 출력으로 설계되어 있으므로 format을 지정하지 않는다.
        AiAnalysisRequest request = AiAnalysisRequest.builder()
                .model(modelName)
                .prompt(optimizedPrompt)
                .stream(false)
                .options(options)
                .build();

        int maxRetries = 2;
        Exception lastException = null;

        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                OllamaResponse response = webClient.post()
                        .uri(aiServerUrl + "/api/generate")
                        .bodyValue(request)
                        .retrieve()
                        .bodyToMono(OllamaResponse.class)
                        .timeout(Duration.ofMillis(timeout))
                        .block();

                if (response == null || response.getResponse() == null) {
                    log.warn("AI server returned null response (attempt {})", attempt + 1);
                    continue;
                }

                // JSON 문자열을 AiAnalysisResult 목록으로 파싱 (배열/객체 모두 지원)
                List<AiAnalysisResult> results = parseAiResponse(response.getResponse());
                AiAnalysisResult firstResult = (results != null && !results.isEmpty()) ? results.get(0) : null;

                if (firstResult != null && firstResult.getCategory() != null && !isParseFailure(firstResult)) {
                    return results;
                }

                log.warn("Parsed result is incomplete or unparsable (attempt {})", attempt + 1);

            } catch (WebClientResponseException e) {
                log.warn("AI server HTTP error (attempt {}): {} - {}", attempt + 1, e.getStatusCode(), e.getMessage());
                lastException = e;
            } catch (Exception e) {
                log.warn("AI server error (attempt {}): {}", attempt + 1, e.getMessage());
                lastException = e;
            }

            // 재시도 전 대기
            if (attempt < maxRetries) {
                try {
                    Thread.sleep(500 * (attempt + 1));
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }

        // 모든 시도 실패 시 에러 응답 반환
        log.error("All AI server attempts failed");
        return Collections.singletonList(createErrorResult("AI 서버 응답을 받을 수 없습니다.", lastException));
    }

    /**
     * AI 응답 JSON 문자열을 AiAnalysisResult 목록으로 파싱
     * 멀티액션 배열([{...},{...}])과 단일 객체({...})를 모두 처리
     */
    private List<AiAnalysisResult> parseAiResponse(String rawResponse) {
        if (rawResponse == null || rawResponse.trim().isEmpty()) {
            return Collections.singletonList(createErrorResult("AI 응답이 비어있습니다.", null));
        }

        String jsonString = extractJsonFromResponse(rawResponse);

        if (jsonString == null) {
            log.error("Could not extract JSON from AI response: {}", rawResponse);
            return Collections.singletonList(createErrorResult("AI 응답에서 JSON을 추출할 수 없습니다.", null));
        }

        try {
            if (jsonString.startsWith("[")) {
                List<AiAnalysisResult> results =
                        objectMapper.readValue(jsonString, new TypeReference<List<AiAnalysisResult>>() {});
                if (results == null || results.isEmpty()) {
                    return Collections.singletonList(createErrorResult("AI 응답 배열이 비어있습니다.", null));
                }
                return results;
            }
            return Collections.singletonList(objectMapper.readValue(jsonString, AiAnalysisResult.class));
        } catch (JsonProcessingException e) {
            log.error("Failed to parse JSON: {} - Error: {}", jsonString, e.getMessage());
            return Collections.singletonList(createErrorResult("AI 응답 JSON 파싱 오류: " + e.getMessage(), e));
        }
    }

    /**
     * AI 응답에서 JSON 문자열 추출
     * 다양한 형식의 응답을 처리 (배열 우선 → 단일 객체)
     */
    private String extractJsonFromResponse(String response) {
        String cleaned = response.trim();

        // 1. 코드블록 내의 JSON 추출
        Matcher codeBlockMatcher = CODE_BLOCK_PATTERN.matcher(cleaned);
        if (codeBlockMatcher.find()) {
            String extracted = codeBlockMatcher.group(1).trim();
            if (isValidJson(extracted)) {
                return extracted;
            }
        }

        // 2. 시작/끝 코드블록 마커 제거
        if (cleaned.startsWith("```json")) {
            cleaned = cleaned.substring(7);
        } else if (cleaned.startsWith("```")) {
            cleaned = cleaned.substring(3);
        }
        if (cleaned.endsWith("```")) {
            cleaned = cleaned.substring(0, cleaned.length() - 3);
        }
        cleaned = cleaned.trim();

        // 3. 직접 JSON 배열인 경우 (멀티액션)
        if (cleaned.startsWith("[") && cleaned.endsWith("]") && isValidJson(cleaned)) {
            return cleaned;
        }

        // 4. 직접 JSON 객체인 경우
        if (cleaned.startsWith("{") && cleaned.endsWith("}") && isValidJson(cleaned)) {
            return cleaned;
        }

        // 5. 텍스트 사이에 JSON 배열이 있는 경우 추출
        int firstBracket = cleaned.indexOf('[');
        int lastBracket = cleaned.lastIndexOf(']');
        if (firstBracket != -1 && lastBracket > firstBracket) {
            String extracted = cleaned.substring(firstBracket, lastBracket + 1);
            if (isValidJson(extracted)) {
                return extracted;
            }
        }

        // 6. 텍스트 사이에 JSON 객체가 있는 경우 추출
        int firstBrace = cleaned.indexOf('{');
        int lastBrace = cleaned.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace > firstBrace) {
            String extracted = cleaned.substring(firstBrace, lastBrace + 1);
            if (isValidJson(extracted)) {
                return extracted;
            }
        }

        // 7. 정규식으로 JSON 객체 찾기 (단일 객체 폴백)
        Matcher jsonMatcher = JSON_PATTERN.matcher(cleaned);
        while (jsonMatcher.find()) {
            String candidate = jsonMatcher.group();
            if (isValidJson(candidate) && candidate.contains("category")) {
                return candidate;
            }
        }

        // 8. 줄바꿈 제거 후 다시 시도
        String noNewlines = cleaned.replaceAll("\\s+", " ");
        firstBrace = noNewlines.indexOf('{');
        lastBrace = noNewlines.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace > firstBrace) {
            String extracted = noNewlines.substring(firstBrace, lastBrace + 1);
            if (isValidJson(extracted)) {
                return extracted;
            }
        }

        return null;
    }

    /**
     * 문자열이 유효한 JSON인지 확인
     */
    private boolean isValidJson(String str) {
        if (str == null || str.trim().isEmpty()) {
            return false;
        }
        try {
            objectMapper.readTree(str);
            return true;
        } catch (JsonProcessingException e) {
            return false;
        }
    }

    /**
     * AI 응답 파싱 자체가 실패한 결과인지 확인
     * (모델이 실제로 ERROR 카테고리를 응답한 것이 아니라, 서버 통신/JSON 추출·파싱이 실패한 경우)
     */
    private boolean isParseFailure(AiAnalysisResult result) {
        return "ERROR".equalsIgnoreCase(result.getCategory()) && "PARSE_FAILURE".equals(result.getAction());
    }

    /**
     * 에러 결과 생성 (AI 응답 파싱 실패)
     */
    private AiAnalysisResult createErrorResult(String message, Exception cause) {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setCategory("ERROR");
        result.setAction("PARSE_FAILURE");

        Map<String, Object> parameters = new HashMap<>();
        parameters.put("message", message);
        if (cause != null) {
            parameters.put("errorDetail", cause.getMessage());
        }
        result.setParameters(parameters);

        return result;
    }

    /**
     * 일일 사용량 초과 에러 결과 생성
     */
    private AiAnalysisResult createDailyLimitExceededResult() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setCategory("ERROR");
        result.setAction("DAILY_LIMIT_EXCEEDED");

        Map<String, Object> parameters = new HashMap<>();
        parameters.put("message", "오늘의 AI 분석 사용량을 초과했습니다. 내일 다시 시도해주세요.");
        parameters.put("currentUsage", dailyAiUsageLimiter.getCurrentUsage());
        parameters.put("maxRequests", dailyAiUsageLimiter.getMaxDailyRequests());
        result.setParameters(parameters);

        return result;
    }
}
