package com.vocacrm.api.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * Rate Limiting 설정
 *
 * 엔드포인트 유형별로 요청 제한을 설정합니다.
 * application.yaml의 rate-limit 섹션에서 값을 가져옵니다.
 */
@Data
@Configuration
@ConfigurationProperties(prefix = "rate-limit")
public class RateLimitConfig {

    /**
     * Rate Limiting 활성화 여부
     */
    private boolean enabled = true;

    /**
     * 인증 관련 엔드포인트 제한 (로그인, 회원가입, 토큰 갱신)
     * 기본값: 분당 10회
     */
    private EndpointLimit auth = new EndpointLimit(10, 60);

    /**
     * 일반 API 엔드포인트 제한
     * 기본값: 분당 60회
     */
    private EndpointLimit api = new EndpointLimit(60, 60);

    /**
     * 검색 엔드포인트 제한
     * 기본값: 분당 30회
     */
    private EndpointLimit search = new EndpointLimit(30, 60);

    /**
     * 음성 명령 AI 분석 엔드포인트 제한 (/api/voice/command)
     * DeepL + AI 사용으로 보수적 제한
     * 기본값: 분당 5회
     */
    private EndpointLimit voiceAi = new EndpointLimit(5, 60);

    /**
     * 음성 명령 기타 엔드포인트 제한 (/api/voice/continue, /api/voice/daily-briefing 등)
     * AI 분석 없음
     * 기본값: 분당 30회
     */
    private EndpointLimit voice = new EndpointLimit(30, 60);

    /**
     * 오류 로그 POST 엔드포인트 제한 (/api/error-logs POST)
     * 비인증 상태에서 호출 가능하므로 보수적 제한
     * 기본값: 분당 10회
     */
    private EndpointLimit errorLog = new EndpointLimit(10, 60);

    @Data
    public static class EndpointLimit {
        /**
         * 허용되는 요청 수
         */
        private int requests;

        /**
         * 시간 윈도우 (초)
         */
        private int periodSeconds;

        public EndpointLimit() {
            this.requests = 60;
            this.periodSeconds = 60;
        }

        public EndpointLimit(int requests, int periodSeconds) {
            this.requests = requests;
            this.periodSeconds = periodSeconds;
        }
    }
}
