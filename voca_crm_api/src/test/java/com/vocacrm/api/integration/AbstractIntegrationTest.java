package com.vocacrm.api.integration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vocacrm.api.util.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * 통합테스트 베이스 클래스.
 *
 * <p>기존 57개 유닛테스트는 전부 Mockito 로 repository/DB 를 가짜로 대체하므로
 * 데이터 정합성(A)·클라이언트 계약(B)·Null→500(C) 부류의 결함을 원리적으로 잡지 못한다.
 * 이 베이스는 그 공백을 메우기 위해 <b>실제 계층</b>을 구동한다:
 *
 * <ul>
 *   <li><b>실제 DB</b>: Testcontainers PostgreSQL (Docker 필요)</li>
 *   <li><b>실제 스키마</b>: 컨테이너 DB 에 Flyway 마이그레이션(V1~V6)을 그대로 적용</li>
 *   <li><b>실제 Redis</b>: Testcontainers Redis (Spring Session / RefreshToken / AI usage limiter)</li>
 *   <li><b>실제 HTTP 계층</b>: {@code @AutoConfigureMockMvc} — JWT 필터, 커스텀 ObjectMapper 직렬화,
 *       GlobalExceptionHandler, 트랜잭션이 실제로 동작한다. (FilterRegistrationBean 으로 등록된
 *       JWT/RateLimit/SecurityHeaders 필터가 MockMvc 요청에도 적용된다.)</li>
 * </ul>
 *
 * <p><b>싱글턴 컨테이너 패턴</b>: 컨테이너를 static 블록에서 JVM 당 1회만 기동하고 종료하지 않는다
 * (Testcontainers Ryuk 가 JVM 종료 시 정리). {@code @Testcontainers}/{@code @Container} 는
 * 클래스마다 static 컨테이너를 <em>afterAll 에서 stop</em> 하므로, 여러 테스트 클래스가 공유하면
 * 두 번째 클래스부터 죽은 컨테이너에 연결되어 실패한다 — 그래서 사용하지 않는다.
 *
 * <p>외부 서비스(Firebase/AI 서버)는 test 프로파일에서 비활성/미도달 처리되어 실호출이 발생하지 않는다.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
public abstract class AbstractIntegrationTest {

    static final PostgreSQLContainer<?> POSTGRES;
    static final GenericContainer<?> REDIS;

    static {
        POSTGRES = new PostgreSQLContainer<>(DockerImageName.parse("postgres:16-alpine"));
        REDIS = new GenericContainer<>(DockerImageName.parse("redis:7-alpine")).withExposedPorts(6379);
        POSTGRES.start();
        REDIS.start();
    }

    @DynamicPropertySource
    static void containerProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
        registry.add("spring.data.redis.password", () -> "");
    }

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    protected JwtUtil jwtUtil;

    /** 컨트롤러 응답과 동일한 커스텀 ObjectMapper (WebConfig 정의) — 요청 바디 직렬화에 사용 */
    @Autowired
    protected ObjectMapper objectMapper;

    @Autowired
    protected JdbcTemplate jdbcTemplate;

    /**
     * 실제 JwtUtil 로 유효한 access token 을 발급해 Authorization 헤더 값을 만든다.
     * JWT 필터가 이 토큰을 검증하고 userId/defaultBusinessPlaceId/isSystemAdmin 을 request attribute 로 세팅한다.
     */
    protected String bearer(String userId, String defaultBusinessPlaceId, boolean isSystemAdmin) {
        String token = jwtUtil.generateAccessToken(
                userId,
                "test-user",
                "010-0000-0000",
                "test@example.com",
                "테스트유저",
                true,
                defaultBusinessPlaceId,
                isSystemAdmin);
        return "Bearer " + token;
    }

    /** 일반 사용자 토큰 (시스템 관리자 아님) */
    protected String bearer(String userId, String defaultBusinessPlaceId) {
        return bearer(userId, defaultBusinessPlaceId, false);
    }
}
