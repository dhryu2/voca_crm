package com.vocacrm.api.dto;

import com.vocacrm.api.model.BusinessPlace;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 사업장 단일 조회/수정 응답 DTO
 *
 * Entity 직접 노출을 방지하고 필요한 필드만 응답합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BusinessPlaceDTO {

    private String id;
    private String name;
    private String address;
    private String phone;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    /**
     * Entity에서 DTO 생성
     */
    public static BusinessPlaceDTO from(BusinessPlace businessPlace) {
        if (businessPlace == null) {
            return null;
        }
        return BusinessPlaceDTO.builder()
                .id(businessPlace.getId())
                .name(businessPlace.getName())
                .address(businessPlace.getAddress())
                .phone(businessPlace.getPhone())
                .createdAt(businessPlace.getCreatedAt())
                .updatedAt(businessPlace.getUpdatedAt())
                .build();
    }
}
