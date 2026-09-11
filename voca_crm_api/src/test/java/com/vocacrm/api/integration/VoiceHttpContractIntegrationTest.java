package com.vocacrm.api.integration;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 음성 HTTP 계약: 헬스 공개 여부, 데일리 브리핑의 사업장 선택 근거(JWT 클레임 vs DB).
 */
class VoiceHttpContractIntegrationTest extends AbstractIntegrationTest {

    private TestDataSeeder seed;

    @BeforeEach
    void setUp() {
        seed = new TestDataSeeder(jdbcTemplate);
    }

    @Test
    void 음성헬스_토큰없이_200이다() throws Exception {
        mockMvc.perform(get("/api/voice/health"))
                .andExpect(status().isOk())
                .andExpect(content().string("Voice command service is running"));
    }

    @Test
    void 데일리브리핑_쿼리없으면_JWT클레임이_아니라_DB기본사업장을_쓴다() throws Exception {
        UUID owner = seed.user("brief-owner");
        String bpDb = "BDBDEF1";
        String bpJwt = "BJWTST1";
        seed.businessPlace(bpDb, "DB기본사업장");
        seed.businessPlace(bpJwt, "JWT박제사업장");
        seed.approvedMembership(owner, bpDb, "OWNER");
        seed.approvedMembership(owner, bpJwt, "OWNER");
        jdbcTemplate.update(
                "UPDATE users SET default_business_place_id = ? WHERE id = ?",
                bpDb, owner);

        UUID memberDb = seed.member(bpDb, owner, "MN-DB", "DB전용회원");
        UUID memberJwt = seed.member(bpJwt, owner, "MN-JWT", "JWT전용회원");
        seed.memo(memberDb, owner, "DB전용중요메모", true);
        seed.memo(memberJwt, owner, "JWT전용중요메모", true);

        String body = mockMvc.perform(get("/api/voice/daily-briefing")
                        .header("Authorization", bearer(owner.toString(), bpJwt)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("completed"))
                .andExpect(jsonPath("$.data.importantMemoCount").value(1))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(body).contains("DB전용중요메모");
        assertThat(body).doesNotContain("JWT전용중요메모");
    }
}
