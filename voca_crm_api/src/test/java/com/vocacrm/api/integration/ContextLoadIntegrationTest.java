package com.vocacrm.api.integration;

import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 통합테스트 인프라 스모크 테스트.
 * 컨테이너(PostgreSQL/Redis) 기동 + Flyway(V1~V6) 적용 + Spring 컨텍스트 로드 + JWT 필터 동작을 검증한다.
 * 이 테스트가 GREEN 이면 이후 도메인 통합테스트의 토대가 성립함을 보장한다.
 */
class ContextLoadIntegrationTest extends AbstractIntegrationTest {

    @Test
    void flyway_마이그레이션_V1부터_V6까지_실제_스키마에_적용된다() {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM flyway_schema_history WHERE success = true", Integer.class);
        // V1~V6 (+ baseline 은 없음) → 최소 6개의 성공한 마이그레이션
        assertThat(count).isGreaterThanOrEqualTo(6);
    }

    @Test
    void 핵심_테이블이_실제로_생성되어_있다() {
        Integer tables = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.tables " +
                        "WHERE table_schema = 'public' AND table_name IN " +
                        "('members','memos','reservations','visit','business_places','users','user_business_places')",
                Integer.class);
        assertThat(tables).isEqualTo(7);
    }

    @Test
    void 인증없이_보호된_엔드포인트_호출시_JWT필터가_401을_반환한다() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.get("/api/members"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void 유효한_토큰이면_JWT필터를_통과한다_401이_아니다() throws Exception {
        // 존재하지 않는 사용자여도 필터는 통과해야 한다(인가/비즈니스 로직은 그 다음 단계)
        int statusCode = mockMvc.perform(MockMvcRequestBuilders.get("/api/members")
                        .header("Authorization", bearer("00000000-0000-0000-0000-000000000001", null)))
                .andReturn().getResponse().getStatus();
        assertThat(statusCode).isNotEqualTo(401);
    }
}
