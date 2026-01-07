package com.vocacrm.api.dto;

import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 사업장 생성 응답 DTO
 *
 * Entity 직접 노출을 방지하고 필요한 필드만 응답합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateBusinessPlaceResponse {

    // 사업장 정보
    private String businessPlaceId;
    private String businessPlaceName;
    private String businessPlaceAddress;
    private String businessPlacePhone;
    private LocalDateTime businessPlaceCreatedAt;

    // 사용자 정보
    private UUID userId;
    private String username;
    private String displayName;
    private String email;
    private String defaultBusinessPlaceId;

    /**
     * Entity에서 Response DTO 생성
     */
    public static CreateBusinessPlaceResponse from(BusinessPlace businessPlace, User user) {
        return CreateBusinessPlaceResponse.builder()
                .businessPlaceId(businessPlace.getId())
                .businessPlaceName(businessPlace.getName())
                .businessPlaceAddress(businessPlace.getAddress())
                .businessPlacePhone(businessPlace.getPhone())
                .businessPlaceCreatedAt(businessPlace.getCreatedAt())
                .userId(user.getId())
                .username(user.getUsername())
                .displayName(user.getDisplayName())
                .email(user.getEmail())
                .defaultBusinessPlaceId(user.getDefaultBusinessPlaceId())
                .build();
    }
}
