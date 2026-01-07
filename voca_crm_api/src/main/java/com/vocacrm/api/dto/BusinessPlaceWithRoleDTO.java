package com.vocacrm.api.dto;

import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.Role;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 사업장 정보와 사용자 역할을 함께 반환하는 DTO
 *
 * Entity 직접 노출을 방지하고 필요한 필드만 응답합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BusinessPlaceWithRoleDTO {

    // 사업장 정보
    private String businessPlaceId;
    private String businessPlaceName;
    private String businessPlaceAddress;
    private String businessPlacePhone;
    private LocalDateTime businessPlaceCreatedAt;
    private LocalDateTime businessPlaceUpdatedAt;

    // 사용자 역할 및 멤버 수
    private Role userRole;
    private int memberCount;

    /**
     * Entity와 추가 정보에서 DTO 생성
     */
    public static BusinessPlaceWithRoleDTO from(BusinessPlace businessPlace, Role userRole, int memberCount) {
        return BusinessPlaceWithRoleDTO.builder()
                .businessPlaceId(businessPlace.getId())
                .businessPlaceName(businessPlace.getName())
                .businessPlaceAddress(businessPlace.getAddress())
                .businessPlacePhone(businessPlace.getPhone())
                .businessPlaceCreatedAt(businessPlace.getCreatedAt())
                .businessPlaceUpdatedAt(businessPlace.getUpdatedAt())
                .userRole(userRole)
                .memberCount(memberCount)
                .build();
    }

    /**
     * 하위 호환성을 위한 기존 생성자 (deprecated)
     * @deprecated 대신 from() 팩토리 메서드를 사용하세요
     */
    @Deprecated
    public BusinessPlaceWithRoleDTO(BusinessPlace businessPlace, Role userRole, int memberCount) {
        this.businessPlaceId = businessPlace.getId();
        this.businessPlaceName = businessPlace.getName();
        this.businessPlaceAddress = businessPlace.getAddress();
        this.businessPlacePhone = businessPlace.getPhone();
        this.businessPlaceCreatedAt = businessPlace.getCreatedAt();
        this.businessPlaceUpdatedAt = businessPlace.getUpdatedAt();
        this.userRole = userRole;
        this.memberCount = memberCount;
    }
}
