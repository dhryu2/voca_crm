package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 공지사항 생성 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NoticeCreateRequest {

    @NotBlank(message = "공지사항 제목은 필수입니다")
    @Size(max = 200, message = "공지사항 제목은 200자 이내로 입력해주세요")
    private String title;

    @NotBlank(message = "공지사항 내용은 필수입니다")
    private String content;

    @NotNull(message = "공지사항 시작일은 필수입니다")
    private LocalDateTime startDate;

    @NotNull(message = "공지사항 종료일은 필수입니다")
    private LocalDateTime endDate;

    private Integer priority;

    private Boolean isActive;
}
