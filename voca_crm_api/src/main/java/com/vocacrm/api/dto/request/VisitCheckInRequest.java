package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 방문 체크인 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VisitCheckInRequest {

    @NotBlank(message = "회원 ID는 필수입니다")
    @Size(max = 36, message = "회원 ID 형식이 올바르지 않습니다")
    private String memberId;

    @Size(max = 500, message = "메모는 500자를 초과할 수 없습니다")
    private String note;
}
