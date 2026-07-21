package com.vocacrm.api.integration;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.UUID;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * [분류 C(500)·B(계약) · 회귀] 통계/직렬화 계약 검증.
 *
 * <p>F0: StatisticsService.getMemoStatistics 가 존재하지 않는 컬럼 memos.is_archived 를 조회 →
 * 실제 PostgreSQL 에서 BadSqlGrammarException → HTTP 500. 기존 mock jdbcTemplate 유닛테스트는
 * SQL 을 실행하지 않아 이 결함을 통과시켰다(거짓 안심). 실DB 통합테스트만이 잡을 수 있다.
 *
 * <p>B: 커스텀 ObjectMapper(WebConfig)가 application.yaml 의 date-format 을 무시하고 LocalDateTime 을
 * 'T' 포함·무타임존으로 직렬화하는지 실제 응답 JSON 으로 확인(Flutter date_parser 계약).
 */
class StatisticsContractIntegrationTest extends AbstractIntegrationTest {

    private TestDataSeeder seed;

    @BeforeEach
    void setUp() {
        seed = new TestDataSeeder(jdbcTemplate);
    }

    @Test
    void 메모통계_엔드포인트는_존재하지않는_컬럼_없이_200을_반환하고_archivedMemos는_0이다() throws Exception {
        String bp = "BMEMOS1";
        seed.businessPlace(bp, "메모통계-사업장");
        UUID owner = seed.user("owner-memo");
        seed.approvedMembership(owner, bp, "OWNER");
        UUID member = seed.member(bp, owner, "M-MEMO-1", "메모회원");
        seed.memo(member, owner, "중요 메모", true);
        seed.memo(member, owner, "일반 메모", false);
        String auth = bearer(owner.toString(), bp);

        // 회귀: 과거엔 실DB에서 500(BadSqlGrammar). 수정 후 200 + archivedMemos=0
        mockMvc.perform(get("/api/statistics/memo-statistics/{bp}", bp)
                        .header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalMemos").value(2))
                .andExpect(jsonPath("$.importantMemos").value(1))
                .andExpect(jsonPath("$.archivedMemos").value(0));
    }

    @Test
    void LocalDateTime_직렬화는_T포함_무타임존_형식이다_Flutter_date_parser_계약() throws Exception {
        String bp = "BDATE01";
        seed.businessPlace(bp, "날짜계약-사업장");
        UUID owner = seed.user("owner-date");
        seed.approvedMembership(owner, bp, "OWNER");
        UUID member = seed.member(bp, owner, "M-DATE-1", "날짜회원");
        // 오늘 날짜(Testcontainers CURRENT_DATE = 호스트 시각)에 초가 0이 아닌 시각으로 방문 시드
        // (ISO_LOCAL_DATE_TIME 은 초=0 이면 초를 생략하므로, 초를 명시해 형식을 명확히 관찰)
        seed.visit(member, owner, LocalDate.now().atTime(14, 30, 45));
        String auth = bearer(owner.toString(), bp);

        String body = mockMvc.perform(get("/api/visits/today/{bp}", bp)
                        .header("Authorization", auth))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        // visitedAt(LocalDateTime)은 "yyyy-MM-ddTHH:mm:ss" (T 구분, zone/offset 없음)으로 직렬화되어야 한다.
        assertThat(Pattern.compile("\"visitedAt\":\"\\d{4}-\\d{2}-\\d{2}T14:30:45\"").matcher(body).find())
                .as("visitedAt 은 T 구분·무타임존 형식이어야 한다 (Flutter date_parser 계약)")
                .isTrue();
        // 타임존/오프셋 표기가 붙으면 안 됨
        assertThat(Pattern.compile("\"visitedAt\":\"[^\"]*(Z|[+-]\\d{2}:\\d{2})\"").matcher(body).find())
                .as("visitedAt 에 타임존/오프셋이 포함되면 Flutter date_parser 계약 위반")
                .isFalse();
    }
}
