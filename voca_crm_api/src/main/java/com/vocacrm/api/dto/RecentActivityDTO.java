package com.vocacrm.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RecentActivityDTO {
    private String activityId;
    private String activityType; // MEMO or VISIT
    private String memberId;
    private String memberName;
    private String content;
    private LocalDateTime activityTime;
}
