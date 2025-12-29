package com.vocacrm.api.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 웹 MVC 설정 클래스
 * CORS 설정 및 ObjectMapper 빈을 관리합니다.
 *
 * 참고: 이 API는 모바일 앱 전용입니다.
 * 모바일 앱은 CORS를 사용하지 않으므로 (CORS는 브라우저 전용 보안 메커니즘),
 * 아래 CORS 설정은 개발 환경의 Swagger UI 및 테스트용으로만 사용됩니다.
 */
@Configuration // Spring 설정 클래스임을 표시
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        // 모바일 앱 전용 API - CORS 설정은 개발/테스트 환경용
        // 프로덕션에서는 모바일 앱이 직접 API를 호출하므로 CORS가 적용되지 않음
        registry.addMapping("/api/**")
                .allowedOrigins("http://localhost:3000", "http://localhost:8080")  // 개발 환경만 허용
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH")
                .allowedHeaders("Content-Type", "Authorization", "X-User-Id", "X-Business-Place-Id")
                .allowCredentials(false)  // Credentials 비활성화 (모바일 앱 불필요)
                .maxAge(3600);

        // Swagger UI 및 API 문서용 CORS (개발 환경)
        registry.addMapping("/swagger-ui/**")
                .allowedOrigins("http://localhost:8080")
                .allowedMethods("GET")
                .allowCredentials(false);

        registry.addMapping("/v3/api-docs/**")
                .allowedOrigins("http://localhost:8080")
                .allowedMethods("GET")
                .allowCredentials(false);
    }

    /**
     * ObjectMapper 빈 설정
     * JSON 직렬화/역직렬화를 위한 ObjectMapper 빈을 생성합니다.
     */
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        // Java 8 날짜/시간 타입 지원
        mapper.registerModule(new JavaTimeModule());
        // 날짜를 타임스탬프 대신 ISO-8601 형식으로 직렬화
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        return mapper;
    }
}