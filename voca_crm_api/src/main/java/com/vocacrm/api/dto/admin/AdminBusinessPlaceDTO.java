package com.vocacrm.api.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 관리자용 사업장 정보 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminBusinessPlaceDTO {
    private String id;
    private String name;
    private String address;
    private String phone;
    private String description;
    private String ownerId;
    private String ownerName;
    private String ownerEmail;
    private String status;      // ACTIVE, SUSPENDED, DELETED
    private long memberCount;
    private long staffCount;
    private LocalDateTime lastActivityAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
