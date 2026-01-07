package com.vocacrm.api.filter;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vocacrm.api.config.RateLimitConfig;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Rate Limiting 필터
 *
 * IP 주소와 엔드포인트 유형별로 요청 횟수를 제한합니다.
 * Sliding Window Counter 알고리즘을 사용합니다.
 *
 * 제한 초과 시 429 (Too Many Requests) 응답을 반환합니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
@Order(Ordered.HIGHEST_PRECEDENCE)  // 가장 먼저 실행
public class RateLimitingFilter extends OncePerRequestFilter {

    private final RateLimitConfig rateLimitConfig;
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * Rate Limit 버킷 저장소
     * Key: "clientId:endpointType" (예: "ip:192.168.1.1:AUTH")
     */
    private final ConcurrentHashMap<String, RateLimitBucket> buckets = new ConcurrentHashMap<>();

    /**
     * 엔드포인트 유형
     */
    private enum EndpointType {
        AUTH,       // 인증 관련 (로그인, 회원가입, 토큰 갱신)
        SEARCH,     // 검색 API
        VOICE_AI,   // 음성 명령 AI 분석 (/api/voice/command) - 보수적 제한
        VOICE,      // 음성 명령 기타 (/api/voice/continue, /api/voice/daily-briefing 등)
        ERROR_LOG,  // 오류 로그 POST (비인증 허용, 보수적 제한)
        API,        // 일반 API
        EXCLUDED    // Rate Limit 제외 (헬스체크, Swagger 등)
    }

    /**
     * 간단한 Rate Limit 버킷 (Sliding Window Counter)
     */
    private static class RateLimitBucket {
        private final AtomicInteger count = new AtomicInteger(0);
        private volatile long windowStart;
        private final int limit;
        private final int windowSeconds;

        RateLimitBucket(int limit, int windowSeconds) {
            this.limit = limit;
            this.windowSeconds = windowSeconds;
            this.windowStart = Instant.now().getEpochSecond();
        }

        /**
         * 요청 허용 여부 확인 및 카운트 증가
         * @return 허용되면 true, 제한 초과면 false
         */
        synchronized boolean tryConsume() {
            long now = Instant.now().getEpochSecond();

            // 윈도우가 만료되면 리셋
            if (now - windowStart >= windowSeconds) {
                count.set(0);
                windowStart = now;
            }

            // 제한 확인
            if (count.get() >= limit) {
                return false;
            }

            count.incrementAndGet();
            return true;
        }

        /**
         * 남은 요청 수
         */
        int getRemaining() {
            return Math.max(0, limit - count.get());
        }

        /**
         * 윈도우 리셋까지 남은 시간 (초)
         */
        long getSecondsUntilReset() {
            long now = Instant.now().getEpochSecond();
            long elapsed = now - windowStart;
            return Math.max(1, windowSeconds - elapsed);
        }

        /**
         * 버킷이 오래되었는지 확인 (정리용)
         */
        boolean isStale() {
            long now = Instant.now().getEpochSecond();
            // 윈도우 시간의 3배 이상 지났으면 오래된 것으로 판단
            return (now - windowStart) > (windowSeconds * 3L);
        }
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        // Rate Limiting 비활성화 시 통과
        if (!rateLimitConfig.isEnabled()) {
            filterChain.doFilter(request, response);
            return;
        }

        // OPTIONS 요청 (CORS preflight)은 통과
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        String requestURI = request.getRequestURI();
        EndpointType endpointType = determineEndpointType(requestURI);

        // Rate Limit 제외 대상은 통과
        if (endpointType == EndpointType.EXCLUDED) {
            filterChain.doFilter(request, response);
            return;
        }

        // 클라이언트 식별 (IP 또는 인증된 사용자)
        String clientId = extractClientId(request);
        String bucketKey = clientId + ":" + endpointType.name();

        // 버킷 가져오기 또는 생성
        RateLimitConfig.EndpointLimit limitConfig = getLimitConfig(endpointType);
        RateLimitBucket bucket = buckets.computeIfAbsent(bucketKey,
                key -> new RateLimitBucket(limitConfig.getRequests(), limitConfig.getPeriodSeconds()));

        // 요청 허용 여부 확인
        if (bucket.tryConsume()) {
            // 요청 허용 - Rate Limit 정보를 헤더에 추가
            response.setHeader("X-RateLimit-Limit", String.valueOf(limitConfig.getRequests()));
            response.setHeader("X-RateLimit-Remaining", String.valueOf(bucket.getRemaining()));
            response.setHeader("X-RateLimit-Reset", String.valueOf(bucket.getSecondsUntilReset()));
            filterChain.doFilter(request, response);
        } else {
            // 요청 거부 - 429 응답
            long retryAfter = bucket.getSecondsUntilReset();

            log.warn("Rate limit exceeded for client: {}, endpoint: {}, URI: {}",
                    clientId, endpointType, requestURI);

            sendRateLimitExceeded(response, retryAfter, limitConfig.getRequests());
        }
    }

    /**
     * URI에 따른 엔드포인트 유형 결정
     */
    private EndpointType determineEndpointType(String uri) {
        // Rate Limit 제외 대상
        if (uri.startsWith("/actuator") ||
            uri.startsWith("/swagger") ||
            uri.startsWith("/v3/api-docs")) {
            return EndpointType.EXCLUDED;
        }

        // 인증 관련
        if (uri.startsWith("/api/auth/")) {
            return EndpointType.AUTH;
        }

        // 오류 로그 POST (비인증 허용, 보수적 제한)
        if (uri.equals("/api/error-logs") || uri.startsWith("/api/error-logs/")) {
            return EndpointType.ERROR_LOG;
        }

        // 검색 관련
        if (uri.contains("/search") || uri.contains("/find")) {
            return EndpointType.SEARCH;
        }

        // 음성 명령 AI 분석 (보수적 제한) - DeepL + AI 사용
        if (uri.equals("/api/voice/command")) {
            return EndpointType.VOICE_AI;
        }

        // 음성 명령 기타 (일반 제한) - AI 분석 없음
        if (uri.startsWith("/api/voice")) {
            return EndpointType.VOICE;
        }

        // 그 외 일반 API
        return EndpointType.API;
    }

    /**
     * 클라이언트 ID 추출 (IP 주소 기반)
     */
    private String extractClientId(HttpServletRequest request) {
        // 인증된 사용자가 있으면 userId 사용 (더 정확한 제한)
        String userId = (String) request.getAttribute("userId");
        if (userId != null) {
            return "user:" + userId;
        }

        // IP 주소 추출 (프록시 헤더 확인)
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("X-Real-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }
        // 여러 IP가 있으면 첫 번째 사용
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }

        return "ip:" + ip;
    }

    /**
     * 엔드포인트 유형별 제한 설정 반환
     */
    private RateLimitConfig.EndpointLimit getLimitConfig(EndpointType endpointType) {
        return switch (endpointType) {
            case AUTH -> rateLimitConfig.getAuth();
            case SEARCH -> rateLimitConfig.getSearch();
            case VOICE_AI -> rateLimitConfig.getVoiceAi();
            case VOICE -> rateLimitConfig.getVoice();
            case ERROR_LOG -> rateLimitConfig.getErrorLog();
            default -> rateLimitConfig.getApi();
        };
    }

    /**
     * 429 Too Many Requests 응답 전송
     */
    private void sendRateLimitExceeded(
            HttpServletResponse response,
            long retryAfterSeconds,
            int limit
    ) throws IOException {
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.setHeader("Retry-After", String.valueOf(retryAfterSeconds));
        response.setHeader("X-RateLimit-Remaining", "0");
        response.setHeader("X-RateLimit-Limit", String.valueOf(limit));

        Map<String, Object> errorResponse = Map.of(
                "error", "TOO_MANY_REQUESTS",
                "message", "요청 횟수가 너무 많습니다. " + retryAfterSeconds + "초 후에 다시 시도해주세요.",
                "status", 429,
                "retryAfterSeconds", retryAfterSeconds
        );

        response.getWriter().write(objectMapper.writeValueAsString(errorResponse));
    }

    /**
     * 주기적으로 오래된 버킷 정리 (메모리 관리)
     * 5분마다 실행
     */
    @Scheduled(fixedRate = 300000)
    public void cleanupStaleBuckets() {
        if (buckets.isEmpty()) {
            return;
        }

        buckets.entrySet().removeIf(entry -> entry.getValue().isStale());
    }
}
