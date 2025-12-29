package com.vocacrm.api.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

/**
 * WebClient 설정 클래스
 * 외부 API 호출을 위한 WebClient 빈 설정
 */
@Configuration
public class WebClientConfig {

    /**
     * WebClient 빈 생성
     * Kakao, Apple 등 외부 OAuth2 Provider API 호출에 사용
     */
    @Bean
    public WebClient webClient() {
        return WebClient.builder()
                .build();
    }
}
