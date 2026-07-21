package com.vocacrm.api.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vocacrm.api.dto.AiAnalysisResult;
import com.vocacrm.api.dto.OllamaResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import reactor.core.publisher.Mono;

import java.lang.reflect.Method;
import java.time.Duration;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * AiServerClient는 WebClient(HTTP)와 Redis 기반 사용량 제한기에 의존한다.
 * WebClient의 fluent 체인(post -> uri -> bodyValue -> retrieve -> bodyToMono -> timeout -> block)은
 * 실제 인터페이스 타입을 그대로 Mockito로 스텁해 정상/HTTP오류/응답없음 분기를 검증한다.
 * JSON 파싱 로직(extractJsonFromResponse/parseAiResponse)은 실제 ObjectMapper로 동작을 검증하며,
 * private 메서드이므로 리플렉션으로 직접 호출한다.
 */
@ExtendWith(MockitoExtension.class)
class AiServerClientTest {

    @Mock
    private WebClient webClient;

    @Mock
    private DailyAiUsageLimiter dailyAiUsageLimiter;

    @Mock
    private WebClient.RequestBodyUriSpec requestBodyUriSpec;

    @Mock
    private WebClient.RequestBodySpec requestBodySpec;

    @Mock
    private WebClient.RequestHeadersSpec requestHeadersSpec;

    @Mock
    private WebClient.ResponseSpec responseSpec;

    @Mock
    private Mono<OllamaResponse> mono;

    private AiServerClient aiServerClient;

    @BeforeEach
    void setUp() {
        // ObjectMapper는 파싱 로직 검증을 위해 실제 인스턴스를 사용한다 (Mock 시 항상 null 반환하여 무의미).
        aiServerClient = new AiServerClient(webClient, new ObjectMapper(), dailyAiUsageLimiter);
        ReflectionTestUtils.setField(aiServerClient, "aiServerUrl", "http://localhost:11434");
        ReflectionTestUtils.setField(aiServerClient, "modelName", "voca-crm");
        ReflectionTestUtils.setField(aiServerClient, "timeout", 3000);
    }

    @SuppressWarnings("unchecked")
    private void stubWebClientChain(OllamaResponse response) {
        when(webClient.post()).thenReturn(requestBodyUriSpec);
        when(requestBodyUriSpec.uri(anyString())).thenReturn(requestBodySpec);
        when(requestBodySpec.bodyValue(any())).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.retrieve()).thenReturn(responseSpec);
        when(responseSpec.bodyToMono(OllamaResponse.class)).thenReturn(mono);
        when(mono.timeout(any(Duration.class))).thenReturn(mono);
        when(mono.block()).thenReturn(response);
    }

    @SuppressWarnings("unchecked")
    private void stubWebClientChainThrowing(RuntimeException exception) {
        when(webClient.post()).thenReturn(requestBodyUriSpec);
        when(requestBodyUriSpec.uri(anyString())).thenReturn(requestBodySpec);
        when(requestBodySpec.bodyValue(any())).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.retrieve()).thenReturn(responseSpec);
        when(responseSpec.bodyToMono(OllamaResponse.class)).thenReturn(mono);
        when(mono.timeout(any(Duration.class))).thenReturn(mono);
        when(mono.block()).thenThrow(exception);
    }

    private OllamaResponse ollamaResponse(String text) {
        OllamaResponse response = new OllamaResponse();
        response.setResponse(text);
        response.setModel("voca-crm");
        response.setDone(true);
        return response;
    }

    // ===== analyzeCommand =====

    @Test
    void analyzeCommand_일일사용량_초과시_DAILY_LIMIT_EXCEEDED_결과를_반환한다() {
        when(dailyAiUsageLimiter.tryConsume()).thenReturn(false);
        when(dailyAiUsageLimiter.getCurrentUsage()).thenReturn(500L);
        when(dailyAiUsageLimiter.getMaxDailyRequests()).thenReturn(500);

        List<AiAnalysisResult> results = aiServerClient.analyzeCommand("회원 검색");

        assertThat(results).hasSize(1);
        assertThat(results.get(0).getCategory()).isEqualTo("ERROR");
        assertThat(results.get(0).getAction()).isEqualTo("DAILY_LIMIT_EXCEEDED");
        verifyNoInteractions(webClient);
    }

    @Test
    void analyzeCommand_정상_단일객체_응답을_파싱한다() {
        when(dailyAiUsageLimiter.tryConsume()).thenReturn(true);
        stubWebClientChain(ollamaResponse("{\"category\":\"MEMBER\",\"action\":\"SEARCH\",\"parameters\":{}}"));

        List<AiAnalysisResult> results = aiServerClient.analyzeCommand("회원 검색해줘");

        assertThat(results).hasSize(1);
        assertThat(results.get(0).getCategory()).isEqualTo("MEMBER");
        assertThat(results.get(0).getAction()).isEqualTo("SEARCH");
    }

    @Test
    void analyzeCommand_멀티액션_배열_응답을_파싱한다() {
        when(dailyAiUsageLimiter.tryConsume()).thenReturn(true);
        stubWebClientChain(ollamaResponse(
                "[{\"category\":\"MEMBER\",\"action\":\"SEARCH\"},{\"category\":\"VISIT\",\"action\":\"CHECKIN\"}]"));

        List<AiAnalysisResult> results = aiServerClient.analyzeCommand("회원 검색하고 체크인해줘");

        assertThat(results).hasSize(2);
        assertThat(results.get(0).getCategory()).isEqualTo("MEMBER");
        assertThat(results.get(1).getCategory()).isEqualTo("VISIT");
    }

    @Test
    void analyzeCommand_응답이_계속_null이면_에러결과를_반환한다() {
        when(dailyAiUsageLimiter.tryConsume()).thenReturn(true);
        // OllamaResponse 자체는 null이 아니지만 getResponse()가 null인 경우
        stubWebClientChain(ollamaResponse(null));

        List<AiAnalysisResult> results = aiServerClient.analyzeCommand("알수없는 명령");

        assertThat(results).hasSize(1);
        assertThat(results.get(0).getCategory()).isEqualTo("ERROR");
        assertThat(results.get(0).getAction()).isEqualTo("PARSE_FAILURE");
        // null 응답 분기는 재시도 3회(0~maxRetries) 모두 수행된다
        verify(mono, times(3)).block();
    }

    @Test
    void analyzeCommand_HTTP_오류가_모든_시도에서_발생하면_에러결과를_반환한다() {
        when(dailyAiUsageLimiter.tryConsume()).thenReturn(true);
        WebClientResponseException httpError =
                WebClientResponseException.create(500, "Internal Server Error", null, null, null);
        stubWebClientChainThrowing(httpError);

        List<AiAnalysisResult> results = aiServerClient.analyzeCommand("회원 검색");

        assertThat(results).hasSize(1);
        assertThat(results.get(0).getCategory()).isEqualTo("ERROR");
        assertThat(results.get(0).getAction()).isEqualTo("PARSE_FAILURE");
        assertThat(results.get(0).getParameters()).containsEntry("errorDetail", httpError.getMessage());
        verify(mono, times(3)).block();
    }

    // ===== extractJsonFromResponse (리플렉션, 8단계 폴백) =====

    private String extractJson(String raw) throws Exception {
        Method m = AiServerClient.class.getDeclaredMethod("extractJsonFromResponse", String.class);
        m.setAccessible(true);
        return (String) m.invoke(aiServerClient, raw);
    }

    @Test
    void extractJson_코드블록_내_JSON을_추출한다() throws Exception {
        String raw = "결과입니다\n```json\n{\"category\":\"MEMBER\",\"action\":\"SEARCH\"}\n```\n끝";
        String result = extractJson(raw);
        assertThat(result).isEqualTo("{\"category\":\"MEMBER\",\"action\":\"SEARCH\"}");
    }

    @Test
    void extractJson_시작_코드블록_마커만_있는_배열을_추출한다() throws Exception {
        String raw = "```json\n[{\"category\":\"MEMBER\"}]";
        String result = extractJson(raw);
        assertThat(result).isEqualTo("[{\"category\":\"MEMBER\"}]");
    }

    @Test
    void extractJson_순수_JSON_객체를_그대로_추출한다() throws Exception {
        String raw = "{\"category\":\"MEMBER\",\"action\":\"SEARCH\"}";
        String result = extractJson(raw);
        assertThat(result).isEqualTo(raw);
    }

    @Test
    void extractJson_텍스트_사이의_JSON_배열을_추출한다() throws Exception {
        String raw = "다음은 결과입니다: [{\"category\":\"MEMBER\"}] 이상입니다";
        String result = extractJson(raw);
        assertThat(result).isEqualTo("[{\"category\":\"MEMBER\"}]");
    }

    @Test
    void extractJson_텍스트_사이의_JSON_객체를_추출한다() throws Exception {
        String raw = "다음은 결과입니다 {\"category\":\"MEMBER\"} 이상입니다";
        String result = extractJson(raw);
        assertThat(result).isEqualTo("{\"category\":\"MEMBER\"}");
    }

    @Test
    void extractJson_불균형_텍스트에서_정규식으로_category를_포함한_객체를_찾는다() throws Exception {
        // 첫 중괄호부터 마지막 중괄호까지의 구간(step6)이 그 자체로 문법 오류라 파싱에 실패해야
        // step7(정규식 폴백)까지 내려간다. (readTree는 후행 텍스트는 무시하므로 첫 토큰 자체가
        // 깨져 있어야 step6이 실패한다.)
        String raw = "broken start { , invalid} noise {\"category\":\"MEMBER\",\"action\":\"SEARCH\"} tail {unclosed";
        String result = extractJson(raw);
        assertThat(result).isEqualTo("{\"category\":\"MEMBER\",\"action\":\"SEARCH\"}");
    }

    @Test
    void extractJson_JSON이_전혀_없으면_null을_반환한다() throws Exception {
        String result = extractJson("이것은 그냥 평범한 텍스트입니다");
        assertThat(result).isNull();
    }

    // ===== parseAiResponse (리플렉션) =====

    @SuppressWarnings("unchecked")
    private List<AiAnalysisResult> parseAiResponse(String raw) throws Exception {
        Method m = AiServerClient.class.getDeclaredMethod("parseAiResponse", String.class);
        m.setAccessible(true);
        return (List<AiAnalysisResult>) m.invoke(aiServerClient, raw);
    }

    @Test
    void parseAiResponse_빈_문자열이면_에러결과를_반환한다() throws Exception {
        List<AiAnalysisResult> results = parseAiResponse("   ");
        assertThat(results).hasSize(1);
        assertThat(results.get(0).getCategory()).isEqualTo("ERROR");
        assertThat(results.get(0).getParameters()).containsEntry("message", "AI 응답이 비어있습니다.");
    }

    @Test
    void parseAiResponse_JSON을_추출할_수_없으면_에러결과를_반환한다() throws Exception {
        List<AiAnalysisResult> results = parseAiResponse("평범한 텍스트");
        assertThat(results).hasSize(1);
        assertThat(results.get(0).getParameters()).containsEntry("message", "AI 응답에서 JSON을 추출할 수 없습니다.");
    }

    @Test
    void parseAiResponse_빈_배열이면_에러결과를_반환한다() throws Exception {
        List<AiAnalysisResult> results = parseAiResponse("[]");
        assertThat(results).hasSize(1);
        assertThat(results.get(0).getParameters()).containsEntry("message", "AI 응답 배열이 비어있습니다.");
    }

    @Test
    void parseAiResponse_유효한_배열을_파싱한다() throws Exception {
        List<AiAnalysisResult> results = parseAiResponse(
                "[{\"category\":\"MEMBER\",\"action\":\"SEARCH\"},{\"category\":\"VISIT\",\"action\":\"CHECKIN\"}]");
        assertThat(results).hasSize(2);
    }

    @Test
    void parseAiResponse_JSON_파싱_오류시_에러결과를_반환한다() throws Exception {
        // category 필드는 String이어야 하나 배열을 전달하여 Jackson 매핑 실패를 유도
        List<AiAnalysisResult> results = parseAiResponse("{\"category\":[1,2,3]}");
        assertThat(results).hasSize(1);
        assertThat(results.get(0).getCategory()).isEqualTo("ERROR");
        assertThat(results.get(0).getAction()).isEqualTo("PARSE_FAILURE");
    }

    // 참고: extractJsonFromResponse의 8단계(줄바꿈 제거 후 재시도) 폴백은
    // 정규식 기반 7단계가 개행 문자를 포함한 JSON도 이미 매칭하기 때문에
    // 별도로 도달시키는 입력을 구성하기 어려워(7단계에서 선점) 스킵한다.
}
