package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 공지사항 열람 기록 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NoticeViewRequest {

    @NotBlank(message = "사용자 ID는 필수입니다")
    @Size(max = 256, message = "사용자 ID 형식이 올바르지 않습니다")
    private String userId;

    private Boolean doNotShowAgain;
}
