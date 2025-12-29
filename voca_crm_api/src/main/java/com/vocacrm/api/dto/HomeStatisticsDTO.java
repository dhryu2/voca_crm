package com.vocacrm.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HomeStatisticsDTO {
    private String businessPlaceId;
    private String businessPlaceName;
    private Integer todayReservations;
    private Integer todayVisits;
    private Integer pendingMemos;
    private Integer totalMembers;
}
