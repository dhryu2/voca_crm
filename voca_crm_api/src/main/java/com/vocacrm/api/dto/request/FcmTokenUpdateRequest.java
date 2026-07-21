package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * FCM 토큰 수정 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FcmTokenUpdateRequest {

    @NotBlank(message = "FCM 토큰은 필수입니다")
    private String fcmToken;
}
