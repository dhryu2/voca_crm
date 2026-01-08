package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 공지사항 수정 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NoticeUpdateRequest {

    @Size(max = 200, message = "공지사항 제목은 200자 이내로 입력해주세요")
    private String title;

    private String content;

    private LocalDateTime startDate;

    private LocalDateTime endDate;

    private Integer priority;

    private Boolean isActive;
}
