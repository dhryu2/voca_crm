package com.vocacrm.api.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 시스템 전체 통계 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SystemStatsDTO {
    private long totalUsers;
    private long activeUsers;
    private long newUsersToday;
    private long newUsersThisWeek;
    private long totalBusinessPlaces;
    private long activeBusinessPlaces;
    private long dau;  // Daily Active Users
    private long mau;  // Monthly Active Users
}
