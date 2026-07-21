package com.vocacrm.api.dto;

import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class AiAnalysisResultTest {

    @Test
    void isCategory는_대소문자무관하게_비교한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setCategory("MEMBER");

        assertThat(result.isCategory("member")).isTrue();
        assertThat(result.isCategory("MEMO")).isFalse();
        assertThat(result.isCategory(null)).isFalse();
    }

    @Test
    void isError는_카테고리가ERROR일때_true이다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setCategory("ERROR");

        assertThat(result.isError()).isTrue();
    }

    @Test
    void parameters가_없으면_모든추출메서드는_null을반환한다() {
        AiAnalysisResult result = new AiAnalysisResult();

        assertThat(result.getSearchCriteria()).isNull();
        assertThat(result.getMemberData()).isNull();
        assertThat(result.getUpdateFields()).isNull();
        assertThat(result.getContent()).isNull();
        assertThat(result.getErrorMessage()).isNull();
        assertThat(result.getMissingField()).isNull();
        assertThat(result.getNote()).isNull();
        assertThat(result.getUserId()).isNull();
        assertThat(result.getBusinessPlaceId()).isNull();
        assertThat(result.getBusinessPlaceName()).isNull();
        assertThat(result.getRole()).isNull();
        assertThat(result.getRequestId()).isNull();
        assertThat(result.getLimit()).isNull();
        assertThat(result.getSearchField("name")).isNull();
        assertThat(result.getMemberField("name")).isNull();
        assertThat(result.getUpdateField("name")).isNull();
    }

    @Test
    void getSearchCriteria는_searchCriteria키를_우선사용한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        Map<String, Object> criteria = Map.of("name", "홍길동");
        Map<String, Object> params = new HashMap<>();
        params.put("searchCriteria", criteria);
        params.put("memberSearchCriteria", Map.of("name", "다른값"));
        result.setParameters(params);

        assertThat(result.getSearchCriteria()).isEqualTo(criteria);
    }

    @Test
    void getSearchCriteria는_searchCriteria가없으면_memberSearchCriteria를사용한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        Map<String, Object> memberCriteria = Map.of("phone", "010-1234-5678");
        Map<String, Object> params = new HashMap<>();
        params.put("memberSearchCriteria", memberCriteria);
        result.setParameters(params);

        assertThat(result.getSearchCriteria()).isEqualTo(memberCriteria);
    }

    @Test
    void getSearchCriteria는_Map이아니면_null을반환한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        Map<String, Object> params = new HashMap<>();
        params.put("searchCriteria", "문자열");
        result.setParameters(params);

        assertThat(result.getSearchCriteria()).isNull();
    }

    @Test
    void getMemberData는_memberData를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        Map<String, Object> memberData = Map.of("name", "홍길동");
        result.setParameters(Map.of("memberData", memberData));

        assertThat(result.getMemberData()).isEqualTo(memberData);
    }

    @Test
    void getUpdateFields는_updateFields를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        Map<String, Object> updateFields = Map.of("phone", "010-0000-0000");
        result.setParameters(Map.of("updateFields", updateFields));

        assertThat(result.getUpdateFields()).isEqualTo(updateFields);
    }

    @Test
    void getContent은_content문자열을추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("content", "메모 내용"));

        assertThat(result.getContent()).isEqualTo("메모 내용");
    }

    @Test
    void getContent은_문자열이아니면_null을반환한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("content", 123));

        assertThat(result.getContent()).isNull();
    }

    @Test
    void getErrorMessage는_message를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("message", "필수 파라미터 누락"));

        assertThat(result.getErrorMessage()).isEqualTo("필수 파라미터 누락");
    }

    @Test
    void getMissingField는_missingField를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("missingField", "name"));

        assertThat(result.getMissingField()).isEqualTo("name");
    }

    @Test
    void getNote는_note를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("note", "방문 메모"));

        assertThat(result.getNote()).isEqualTo("방문 메모");
    }

    @Test
    void getUserId는_userId를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("userId", "user-1"));

        assertThat(result.getUserId()).isEqualTo("user-1");
    }

    @Test
    void getBusinessPlaceId는_businessPlaceId를우선사용한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        Map<String, Object> params = new HashMap<>();
        params.put("businessPlaceId", "BP001");
        params.put("id", "BP999");
        result.setParameters(params);

        assertThat(result.getBusinessPlaceId()).isEqualTo("BP001");
    }

    @Test
    void getBusinessPlaceId는_businessPlaceId가없으면_id를사용한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("id", "BP999"));

        assertThat(result.getBusinessPlaceId()).isEqualTo("BP999");
    }

    @Test
    void getBusinessPlaceName은_name을추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("name", "강남지점"));

        assertThat(result.getBusinessPlaceName()).isEqualTo("강남지점");
    }

    @Test
    void getRole은_role을추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("role", "STAFF"));

        assertThat(result.getRole()).isEqualTo("STAFF");
    }

    @Test
    void getRequestId는_requestId를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("requestId", "req-1"));

        assertThat(result.getRequestId()).isEqualTo("req-1");
    }

    @Test
    void getLimit은_숫자를Integer로변환한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("limit", 10L));

        assertThat(result.getLimit()).isEqualTo(10);
    }

    @Test
    void getLimit은_숫자가아니면_null을반환한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("limit", "10"));

        assertThat(result.getLimit()).isNull();
    }

    @Test
    void getSearchField는_검색조건에서_필드를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("searchCriteria", Map.of("name", "홍길동")));

        assertThat(result.getSearchField("name")).isEqualTo("홍길동");
        assertThat(result.getSearchField("phone")).isNull();
    }

    @Test
    void getMemberField는_회원데이터에서_필드를추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("memberData", Map.of("phone", "010-1111-2222")));

        assertThat(result.getMemberField("phone")).isEqualTo("010-1111-2222");
    }

    @Test
    void getUpdateField는_업데이트필드에서_값을추출한다() {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setParameters(Map.of("updateFields", Map.of("email", "a@b.com")));

        assertThat(result.getUpdateField("email")).isEqualTo("a@b.com");
    }
}
