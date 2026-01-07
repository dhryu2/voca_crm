package com.vocacrm.api.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Arrays;
import java.util.List;

/**
 * OpenAPI/Swagger 설정
 *
 * API 문서화를 위한 OpenAPI 3.0 설정입니다.
 * Swagger UI 접속: http://localhost:8080/swagger-ui.html
 * OpenAPI JSON: http://localhost:8080/v3/api-docs
 */
@Configuration
public class OpenApiConfig {

    @Value("${spring.profiles.active:dev}")
    private String activeProfile;

    @Bean
    public OpenAPI vocaCrmOpenAPI() {
        // JWT 인증 스키마 정의
        SecurityScheme securityScheme = new SecurityScheme()
                .type(SecurityScheme.Type.HTTP)
                .scheme("bearer")
                .bearerFormat("JWT")
                .in(SecurityScheme.In.HEADER)
                .name("Authorization")
                .description("JWT 토큰을 입력하세요. 'Bearer ' 접두사는 자동으로 추가됩니다.");

        SecurityRequirement securityRequirement = new SecurityRequirement()
                .addList("bearerAuth");

        // 서버 정보
        List<Server> servers = Arrays.asList(
                new Server()
                        .url("http://localhost:8080")
                        .description("개발 서버"),
                new Server()
                        .url("https://api.vocacrm.com")
                        .description("운영 서버")
        );

        return new OpenAPI()
                .info(new Info()
                        .title("VocaCRM API")
                        .version("1.0.0")
                        .description("VocaCRM 백엔드 API 문서\n\n" +
                                "음성 기반 CRM 시스템의 REST API입니다.\n\n" +
                                "## 인증\n" +
                                "대부분의 API는 JWT 인증이 필요합니다.\n" +
                                "Authorization 헤더에 `Bearer {token}` 형식으로 전달하세요.\n\n" +
                                "## 공통 응답 코드\n" +
                                "- 200: 성공\n" +
                                "- 400: 잘못된 요청\n" +
                                "- 401: 인증 실패\n" +
                                "- 403: 권한 없음\n" +
                                "- 404: 리소스를 찾을 수 없음\n" +
                                "- 500: 서버 오류")
                        .contact(new Contact()
                                .name("VocaCRM Team")
                                .email("support@vocacrm.com"))
                        .license(new License()
                                .name("Proprietary")
                                .url("https://vocacrm.com/license")))
                .servers(servers)
                .components(new Components()
                        .addSecuritySchemes("bearerAuth", securityScheme))
                .addSecurityItem(securityRequirement);
    }
}
