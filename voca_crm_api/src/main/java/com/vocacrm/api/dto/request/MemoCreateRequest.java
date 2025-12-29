package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 메모 생성 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MemoCreateRequest {

    @NotBlank(message = "회원 ID는 필수입니다")
    @Size(max = 36, message = "회원 ID 형식이 올바르지 않습니다")
    private String memberId;

    @NotBlank(message = "메모 내용은 필수입니다")
    @Size(min = 1, max = 5000, message = "메모 내용은 1~5000자 사이로 입력해주세요")
    private String content;

    @Size(max = 128, message = "소유자 ID 형식이 올바르지 않습니다")
    private String ownerId;

    private Boolean isImportant;
}
