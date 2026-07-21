package com.vocacrm.api.integration;

import com.vocacrm.api.dto.VoiceCommandResponse;
import com.vocacrm.api.service.VoiceCommandService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * [분류 D(권한/테넌트 격리) · 회귀] 음성 데일리 브리핑의 사업장 미지정 시 전역 조회 폴백 제거.
 *
 * <p>FINDING A: caller 의 사업장이 null 이면 generateDailyBriefing / handleMemberGetAll 이
 * memberService.getAllMembers(0, N)(전역, 사업장 필터 없음)로 폴백하여 <b>모든 사업장</b>의 회원명과
 * 중요 메모 내용을 응답에 노출했다(테넌트 격리 위반). 수정: null 이면 거부(NO_BUSINESS_PLACE).
 *
 * <p>실DB(Testcontainers)에 서로 다른 두 사업장을 시드하고 서비스 계층을 직접 호출해 검증한다.
 */
class VoiceTenantIsolationIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private VoiceCommandService voiceCommandService;

    private TestDataSeeder seed;

    @BeforeEach
    void setUp() {
        seed = new TestDataSeeder(jdbcTemplate);
    }

    @Test
    void 데일리브리핑_사업장이_null이면_전역조회로_폴백하지_않고_거부한다() {
        // 두 사업장 각각에 중요 메모 보유 회원 시드
        String bpA = "BVOICEA";
        String bpB = "BVOICEB";
        UUID ownerA = seed.user("voice-a");
        UUID ownerB = seed.user("voice-b");
        seed.businessPlaceMemberWithImportantMemo(bpA, ownerA, "A-사업장-비밀회원");
        seed.businessPlaceMemberWithImportantMemo(bpB, ownerB, "B-사업장-비밀회원");

        // 사업장 미지정 호출: 과거엔 전역 조회로 A/B 양쪽 데이터를 노출했다
        VoiceCommandResponse resp = voiceCommandService.generateDailyBriefing(ownerA.toString(), null);

        assertThat(resp.getStatus()).isEqualTo("error");
        assertThat(resp.getErrorCode()).isEqualTo("NO_BUSINESS_PLACE");
        // 어떤 사업장의 데이터도 응답에 실려서는 안 된다
        assertThat(resp.getData()).isNull();
        assertThat(resp.getMessage()).doesNotContain("비밀회원");
    }

    @Test
    void 데일리브리핑_사업장_지정시_해당_사업장의_중요메모만_집계한다() {
        // 격리 검증: bpA 지정 시 bpB 의 중요 메모는 절대 포함되면 안 됨 (수정이 정상 경로를 깨지 않음도 확인)
        String bpA = "BVONLYA";
        String bpB = "BVONLYB";
        UUID ownerA = seed.user("vonly-a");
        UUID ownerB = seed.user("vonly-b");
        seed.businessPlaceMemberWithImportantMemo(bpA, ownerA, "A전용회원");
        seed.businessPlaceMemberWithImportantMemo(bpB, ownerB, "B전용회원");

        VoiceCommandResponse resp = voiceCommandService.generateDailyBriefing(ownerA.toString(), bpA);

        assertThat(resp.getStatus()).isEqualTo("completed");
        // bpA 의 중요 메모 1개만 집계되어야 함 (bpB 것이 새어들어오면 2가 됨)
        assertThat(resp.getData().get("importantMemoCount")).isEqualTo(1);
        assertThat(resp.getMessage()).doesNotContain("B전용회원");
    }
}
