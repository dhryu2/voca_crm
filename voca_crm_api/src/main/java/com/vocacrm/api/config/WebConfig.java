package com.vocacrm.api.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.Arrays;

/**
 * 웹 MVC 설정 클래스
 * CORS 설정 및 ObjectMapper 빈을 관리합니다.
 *
 * 참고: 이 API는 모바일 앱 전용입니다.
 * 모바일 앱은 CORS를 사용하지 않으므로 (CORS는 브라우저 전용 보안 메커니즘),
 * 아래 CORS 설정은 개발 환경의 Swagger UI 및 테스트용으로만 사용됩니다.
 *
 * 프로파일별 CORS 정책:
 * - dev/local: localhost 허용 (개발 편의성)
 * - prod: 특정 도메인만 허용 (보안 강화)
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final Environment environment;

    /**
     * 운영 환경에서 허용할 Origin 목록 (환경변수로 설정 가능)
     * 기본값: 빈 배열 (운영 환경에서는 명시적 설정 필요)
     */
    @Value("${cors.allowed-origins:}")
    private String[] allowedOrigins;

    public WebConfig(Environment environment) {
        this.environment = environment;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        boolean isProduction = Arrays.asList(environment.getActiveProfiles()).contains("prod");

        if (isProduction) {
            // 운영 환경: 명시적으로 설정된 Origin만 허용
            configureProductionCors(registry);
        } else {
            // 개발 환경: localhost 허용
            configureDevelopmentCors(registry);
        }
    }

    /**
     * 운영 환경 CORS 설정
     * - 환경변수로 설정된 특정 도메인만 허용
     * - 설정되지 않은 경우 CORS 비활성화 (모바일 앱 전용이므로 문제 없음)
     */
    private void configureProductionCors(CorsRegistry registry) {
        if (allowedOrigins == null || allowedOrigins.length == 0 ||
            (allowedOrigins.length == 1 && allowedOrigins[0].isEmpty())) {
            // 운영 환경에서 CORS Origin이 설정되지 않은 경우
            // 모바일 앱 전용 API이므로 CORS 없이도 정상 동작
            return;
        }

        registry.addMapping("/api/**")
                .allowedOrigins(allowedOrigins)
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH")
                .allowedHeaders("Content-Type", "Authorization", "X-User-Id", "X-Business-Place-Id")
                .allowCredentials(false)
                .maxAge(3600);
    }

    /**
     * 개발 환경 CORS 설정
     * - localhost 허용 (개발 편의성)
     * - Swagger UI 접근 허용
     */
    private void configureDevelopmentCors(CorsRegistry registry) {
        // API 엔드포인트
        registry.addMapping("/api/**")
                .allowedOrigins("http://localhost:3000", "http://localhost:8080", "http://127.0.0.1:3000", "http://127.0.0.1:8080")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH")
                .allowedHeaders("Content-Type", "Authorization", "X-User-Id", "X-Business-Place-Id")
                .allowCredentials(false)
                .maxAge(3600);

        // Swagger UI 및 API 문서용 CORS
        registry.addMapping("/swagger-ui/**")
                .allowedOrigins("http://localhost:8080", "http://127.0.0.1:8080")
                .allowedMethods("GET")
                .allowCredentials(false);

        registry.addMapping("/v3/api-docs/**")
                .allowedOrigins("http://localhost:8080", "http://127.0.0.1:8080")
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
