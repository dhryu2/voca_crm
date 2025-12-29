package com.vocacrm.api.dto;

import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 사업장 멤버 정보 DTO
 *
 * 사업장 멤버 관리 화면에서 사용됩니다.
 * 멤버의 사용자 정보와 역할 정보를 포함합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BusinessPlaceMemberDTO {

    private String userBusinessPlaceId;
    private String userId;
    private String businessPlaceId;
    private Role role;

    // 사용자 정보
    private String username;
    private String phone;
    private String email;
    private String displayName;

    // 가입 일시
    private LocalDateTime joinedAt;

    /**
     * Entity와 사용자 정보를 DTO로 변환
     */
    public static BusinessPlaceMemberDTO from(UserBusinessPlace ubp, User user) {
        return BusinessPlaceMemberDTO.builder()
                .userBusinessPlaceId(ubp.getId() != null ? ubp.getId().toString() : null)
                .userId(ubp.getUserId() != null ? ubp.getUserId().toString() : null)
                .businessPlaceId(ubp.getBusinessPlaceId())
                .role(ubp.getRole())
                .username(user != null ? user.getUsername() : null)
                .phone(user != null ? user.getPhone() : null)
                .email(user != null ? user.getEmail() : null)
                .displayName(user != null ? user.getDisplayName() : null)
                .joinedAt(ubp.getCreatedAt())
                .build();
    }
}
