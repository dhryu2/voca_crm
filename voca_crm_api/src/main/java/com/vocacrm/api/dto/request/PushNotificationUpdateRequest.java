package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 푸시 알림 설정 수정 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PushNotificationUpdateRequest {

    @NotNull(message = "알림 설정 값은 필수입니다")
    private Boolean enabled;
}
