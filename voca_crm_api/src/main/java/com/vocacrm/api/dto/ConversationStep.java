package com.vocacrm.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

/**
 * 대화 단계 정보
 * 다단계 대화에서 현재 어느 단계인지 추적
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConversationStep {

    /**
     * 단계 타입
     * - member_selection: 회원 선택
     * - memo_selection: 메모 선택
     * - date_range_selection: 날짜 범위 선택
     * - content_input: 내용 입력
     * - field_input: 필드 입력 (전화번호, 이메일 등)
     * - confirmation: 최종 확인 (삭제, 수정 등)
     * - update_field_selection: 수정할 필드 선택
     */
    private String stepType;

    /**
     * 현재 단계 번호 (1부터 시작)
     */
    private int stepNumber;

    /**
     * 단계별 추가 데이터
     * 예: {"totalCount": 5, "filterApplied": "3일 전"}
     */
    private Map<String, Object> stepData;

    /**
     * 이 단계에서 선택해야 할 엔티티 타입
     */
    private String targetEntityType;

    /**
     * 다중 선택 허용 여부
     */
    private boolean allowMultipleSelection;

    /**
     * 전체 선택 옵션 제공 여부
     */
    private boolean allowSelectAll;
}
