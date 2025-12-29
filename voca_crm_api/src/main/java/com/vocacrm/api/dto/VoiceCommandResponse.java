package com.vocacrm.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

/**
 * 음성 명령 응답 DTO
 * API 서버에서 Flutter로 명령 처리 결과를 전송할 때 사용
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VoiceCommandResponse {

    /**
     * 응답 상태
     * - clarification_needed: 추가 정보 필요 (예: 중복 회원, 메모 선택)
     * - processing: 처리 중
     * - completed: 완료
     * - error: 오류
     */
    private String status;

    /**
     * 대화 세션 ID
     */
    private String conversationId;

    /**
     * 사용자에게 표시할 메시지
     */
    private String message;

    /**
     * 응답 데이터
     * - candidates: 선택 가능한 후보 리스트 (회원, 메모 등)
     * - member: 회원 정보
     * - memo: 메모 정보
     * - memos: 메모 리스트
     * - result: 처리 결과
     */
    private Map<String, Object> data;

    /**
     * 선택 옵션 정보
     */
    private SelectionOptions selectionOptions;

    /**
     * 다음 대화를 위한 컨텍스트
     */
    private ConversationContextDto context;

    /**
     * 오류 코드 (error 상태일 때)
     */
    private String errorCode;

    /**
     * 선택 옵션 정보
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SelectionOptions {
        /**
         * 다중 선택 허용 여부
         */
        private boolean allowMultipleSelection;

        /**
         * 전체 선택 옵션 제공 여부
         */
        private boolean allowSelectAll;

        /**
         * 선택해야 할 엔티티 타입
         */
        private String targetEntityType;

        /**
         * 최소 선택 개수
         */
        private Integer minSelection;

        /**
         * 최대 선택 개수
         */
        private Integer maxSelection;
    }
}
