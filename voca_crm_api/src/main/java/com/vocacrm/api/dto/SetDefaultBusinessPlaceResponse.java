package com.vocacrm.api.dto;

import com.vocacrm.api.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

/**
 * 기본 사업장 설정 응답 DTO
 *
 * Entity 직접 노출을 방지하고 필요한 필드만 응답합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SetDefaultBusinessPlaceResponse {

    private UUID userId;
    private String username;
    private String displayName;
    private String email;
    private String defaultBusinessPlaceId;

    /**
     * User Entity에서 Response DTO 생성
     */
    public static SetDefaultBusinessPlaceResponse from(User user) {
        return SetDefaultBusinessPlaceResponse.builder()
                .userId(user.getId())
                .username(user.getUsername())
                .displayName(user.getDisplayName())
                .email(user.getEmail())
                .defaultBusinessPlaceId(user.getDefaultBusinessPlaceId())
                .build();
    }
}
