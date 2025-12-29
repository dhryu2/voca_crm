package com.vocacrm.api.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

import java.util.Map;

/**
 * AI 서버 응답 DTO
 * Modelfile.txt에서 정의한 JSON 응답 형식과 일치하도록 설계
 *
 * 응답 형식:
 * {
 *   "category": "MEMBER|MEMO|BUSINESS_PLACE|VISIT|STATISTICS|ERROR",
 *   "action": "SEARCH|CREATE|UPDATE|DELETE|...",
 *   "parameters": { ... }
 * }
 */
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class AiAnalysisResult {

    /**
     * 카테고리
     * - MEMBER: 회원 관리
     * - MEMO: 메모 관리
     * - BUSINESS_PLACE: 사업장 관리
     * - VISIT: 방문 관리
     * - STATISTICS: 통계
     * - ERROR: 에러
     */
    private String category;

    /**
     * 액션
     *
     * MEMBER 액션:
     * - SEARCH: 회원 검색
     * - CREATE: 회원 생성
     * - UPDATE: 회원 수정
     * - DELETE: 회원 삭제
     * - GET_ALL: 전체 회원 목록
     *
     * MEMO 액션:
     * - GET_BY_MEMBER: 회원 메모 조회
     * - GET_LATEST: 최신 메모 조회
     * - CREATE: 메모 생성
     * - UPDATE_LATEST: 최신 메모 수정
     * - DELETE_LATEST: 최신 메모 삭제
     * - DELETE_ALL: 모든 메모 삭제
     *
     * VISIT 액션:
     * - CHECKIN: 방문 체크인
     * - GET_BY_MEMBER: 방문 기록 조회
     *
     * BUSINESS_PLACE 액션:
     * - GET_MY_LIST: 내 사업장 목록
     * - CREATE: 사업장 생성
     * - UPDATE: 사업장 수정
     * - DELETE: 사업장 삭제
     * - SET_DEFAULT: 기본 사업장 설정
     * - REQUEST_ACCESS: 접근 권한 요청
     * - APPROVE_REQUEST: 요청 승인
     * - REJECT_REQUEST: 요청 거절
     * - GET_RECEIVED_REQUESTS: 받은 요청 목록
     * - GET_SENT_REQUESTS: 보낸 요청 목록
     * - GET_PENDING_COUNT: 대기 요청 개수
     *
     * STATISTICS 액션:
     * - GET_HOME: 홈 통계
     * - GET_RECENT_ACTIVITIES: 최근 활동
     *
     * ERROR 액션:
     * - MISSING_PARAMETER: 필수 파라미터 부족
     * - UNKNOWN: 명령 이해 불가
     */
    private String action;

    /**
     * 파라미터 맵
     * 각 액션에 따라 다른 필드들이 포함됨
     */
    private Map<String, Object> parameters;

    // ===== Helper Methods =====

    /**
     * 카테고리 확인
     */
    public boolean isCategory(String cat) {
        return cat != null && cat.equalsIgnoreCase(this.category);
    }

    /**
     * 에러 응답인지 확인
     */
    public boolean isError() {
        return isCategory("ERROR");
    }

    /**
     * 파라미터에서 검색 조건 추출
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> getSearchCriteria() {
        if (parameters == null) return null;
        Object criteria = parameters.get("searchCriteria");
        if (criteria == null) {
            criteria = parameters.get("memberSearchCriteria");
        }
        return criteria instanceof Map ? (Map<String, Object>) criteria : null;
    }

    /**
     * 파라미터에서 회원 데이터 추출
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> getMemberData() {
        if (parameters == null) return null;
        Object data = parameters.get("memberData");
        return data instanceof Map ? (Map<String, Object>) data : null;
    }

    /**
     * 파라미터에서 업데이트 필드 추출
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> getUpdateFields() {
        if (parameters == null) return null;
        Object fields = parameters.get("updateFields");
        return fields instanceof Map ? (Map<String, Object>) fields : null;
    }

    /**
     * 파라미터에서 콘텐츠(메모 내용 등) 추출
     */
    public String getContent() {
        if (parameters == null) return null;
        Object content = parameters.get("content");
        return content instanceof String ? (String) content : null;
    }

    /**
     * 파라미터에서 에러 메시지 추출
     */
    public String getErrorMessage() {
        if (parameters == null) return null;
        Object message = parameters.get("message");
        return message instanceof String ? (String) message : null;
    }

    /**
     * 파라미터에서 누락 필드 추출
     */
    public String getMissingField() {
        if (parameters == null) return null;
        Object field = parameters.get("missingField");
        return field instanceof String ? (String) field : null;
    }

    /**
     * 파라미터에서 메모 내용 추출
     */
    public String getNote() {
        if (parameters == null) return null;
        Object note = parameters.get("note");
        return note instanceof String ? (String) note : null;
    }

    /**
     * 파라미터에서 userId 추출
     */
    public String getUserId() {
        if (parameters == null) return null;
        Object userId = parameters.get("userId");
        return userId instanceof String ? (String) userId : null;
    }

    /**
     * 파라미터에서 businessPlaceId 추출
     */
    public String getBusinessPlaceId() {
        if (parameters == null) return null;
        Object id = parameters.get("businessPlaceId");
        if (id == null) {
            id = parameters.get("id");
        }
        return id instanceof String ? (String) id : null;
    }

    /**
     * 파라미터에서 사업장 이름 추출
     */
    public String getBusinessPlaceName() {
        if (parameters == null) return null;
        Object name = parameters.get("name");
        return name instanceof String ? (String) name : null;
    }

    /**
     * 파라미터에서 역할 추출
     */
    public String getRole() {
        if (parameters == null) return null;
        Object role = parameters.get("role");
        return role instanceof String ? (String) role : null;
    }

    /**
     * 파라미터에서 요청 ID 추출
     */
    public String getRequestId() {
        if (parameters == null) return null;
        Object requestId = parameters.get("requestId");
        return requestId instanceof String ? (String) requestId : null;
    }

    /**
     * 파라미터에서 limit 추출
     */
    public Integer getLimit() {
        if (parameters == null) return null;
        Object limit = parameters.get("limit");
        if (limit instanceof Number) {
            return ((Number) limit).intValue();
        }
        return null;
    }

    /**
     * 검색 조건에서 특정 필드 추출
     */
    public String getSearchField(String fieldName) {
        Map<String, Object> criteria = getSearchCriteria();
        if (criteria == null) return null;
        Object value = criteria.get(fieldName);
        return value instanceof String ? (String) value : null;
    }

    /**
     * 회원 데이터에서 특정 필드 추출
     */
    public String getMemberField(String fieldName) {
        Map<String, Object> data = getMemberData();
        if (data == null) return null;
        Object value = data.get(fieldName);
        return value instanceof String ? (String) value : null;
    }

    /**
     * 업데이트 필드에서 특정 필드 추출
     */
    public String getUpdateField(String fieldName) {
        Map<String, Object> fields = getUpdateFields();
        if (fields == null) return null;
        Object value = fields.get(fieldName);
        return value instanceof String ? (String) value : null;
    }
}
