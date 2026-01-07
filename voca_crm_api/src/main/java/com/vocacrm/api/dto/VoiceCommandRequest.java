package com.vocacrm.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
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
    @NotBlank(message = "음성 텍스트는 필수입니다")
    @Size(max = 1000, message = "음성 텍스트는 1000자를 초과할 수 없습니다")
    private String text;

    /**
     * 대화 컨텍스트 (대화형 처리를 위한 이전 상태 정보)
     */
    private ConversationContextDTO context;

    /**
     * 사용자 ID (providerId)
     * 사용자의 defaultBusinessPlaceId를 조회하기 위해 필요
     *
     * 참고: JWT 토큰에서 userId를 추출하므로 이 필드는 선택적입니다.
     * JWT 인증이 적용된 경우 서버에서 토큰으로부터 userId를 가져옵니다.
     */
    private String userId;
}
