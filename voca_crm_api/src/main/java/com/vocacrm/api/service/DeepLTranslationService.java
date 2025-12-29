package com.vocacrm.api.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.time.Duration;
import java.util.Map;

/**
 * DeepL API를 사용한 번역 서비스
 * 한국어 텍스트를 영어로 번역하여 AI 서버에 전달
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DeepLTranslationService {

    private final WebClient webClient;
    private final ObjectMapper objectMapper;

    @Value("${deepl.api-key:}")
    private String apiKey;

    @Value("${deepl.api-url:https://api-free.deepl.com/v2/translate}")
    private String apiUrl;

    @Value("${deepl.timeout:10000}")
    private int timeout;

    /**
     * 텍스트를 영어로 번역
     *
     * @param text 번역할 텍스트 (한국어)
     * @return 영어로 번역된 텍스트, 실패 시 원본 텍스트 반환
     */
    public String translateToEnglish(String text) {
        if (text == null || text.trim().isEmpty()) {
            return text;
        }

        if (apiKey == null || apiKey.trim().isEmpty()) {
            log.warn("DeepL API key is not configured. Skipping translation.");
            return text;
        }

        try {
            Map<String, Object> requestBody = Map.of(
                    "text", new String[]{text},
                    "target_lang", "EN"
            );

            String response = webClient.post()
                    .uri(apiUrl)
                    .header(HttpHeaders.AUTHORIZATION, "DeepL-Auth-Key " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(requestBody)
                    .retrieve()
                    .bodyToMono(String.class)
                    .timeout(Duration.ofMillis(timeout))
                    .block();

            if (response == null) {
                log.warn("DeepL API returned null response. Using original text.");
                return text;
            }

            String translatedText = parseTranslationResponse(response);
            if (translatedText != null) {
                log.debug("Translation successful: '{}' -> '{}'", text, translatedText);
                return translatedText;
            }

            log.warn("Failed to parse DeepL response. Using original text.");
            return text;

        } catch (WebClientResponseException e) {
            log.error("DeepL API HTTP error: {} - {}", e.getStatusCode(), e.getMessage());
            return text;
        } catch (Exception e) {
            log.error("DeepL translation error: {}", e.getMessage());
            return text;
        }
    }

    /**
     * DeepL API 응답에서 번역된 텍스트 추출
     *
     * 응답 형식:
     * {
     *   "translations": [
     *     {
     *       "detected_source_language": "KO",
     *       "text": "translated text"
     *     }
     *   ]
     * }
     */
    private String parseTranslationResponse(String response) {
        try {
            JsonNode root = objectMapper.readTree(response);
            JsonNode translations = root.get("translations");

            if (translations != null && translations.isArray() && translations.size() > 0) {
                JsonNode firstTranslation = translations.get(0);
                JsonNode textNode = firstTranslation.get("text");

                if (textNode != null) {
                    return textNode.asText();
                }
            }
        } catch (Exception e) {
            log.error("Failed to parse DeepL response: {}", e.getMessage());
        }
        return null;
    }

    /**
     * API 키가 설정되어 있는지 확인
     */
    public boolean isConfigured() {
        return apiKey != null && !apiKey.trim().isEmpty();
    }
}
