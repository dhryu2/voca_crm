package com.vocacrm.api.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 관리자용 사용자 정보 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminUserDTO {
    private String providerId;  // User UUID
    private String provider;    // OAuth provider (GOOGLE, KAKAO, APPLE)
    private String name;
    private String email;
    private String phone;
    private String role;        // USER or ADMIN
    private boolean isSystemAdmin;
    private String status;      // ACTIVE, SUSPENDED, BANNED
    private LocalDateTime lastLoginAt;
    private long loginCount;
    private long businessPlaceCount;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
