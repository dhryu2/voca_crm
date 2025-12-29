package com.vocacrm.api.dto;

import lombok.Data;

/**
 * 음성 명령 요청 DTO
 * Flutter에서 API 서버로 음성 명령을 전송할 때 사용
 */
@Data
public class VoiceCommandRequest {

    /**
     * STT로 변환된 음성 텍스트
     */
    private String text;

    /**
     * 대화 컨텍스트 (대화형 처리를 위한 이전 상태 정보)
     */
    private ConversationContextDto context;

    /**
     * 사용자 ID (providerId)
     * 사용자의 defaultBusinessPlaceId를 조회하기 위해 필요
     */
    private String userId;
}
