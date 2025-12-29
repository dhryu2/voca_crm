package com.vocacrm.api.dto;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.BusinessPlaceAccessRequest;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 사업장 접근 요청 DTO (요청자 정보 포함)
 *
 * 사업장 Owner가 받은 요청 목록을 조회할 때 사용됩니다.
 * 요청자의 상세 정보(이름, 전화번호, 이메일)를 포함합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AccessRequestWithRequesterDTO {

    private String id;
    private String userId;
    private String businessPlaceId;
    private Role role;
    private AccessStatus status;
    private LocalDateTime requestedAt;
    private LocalDateTime processedAt;
    private String processedBy;
    private Boolean isReadByRequester;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // 요청자 정보
    private String requesterName;
    private String requesterPhone;
    private String requesterEmail;

    // 사업장 정보
    private String businessPlaceName;

    /**
     * Entity와 관련 정보를 DTO로 변환
     */
    public static AccessRequestWithRequesterDTO from(BusinessPlaceAccessRequest request, User requester, BusinessPlace businessPlace) {
        return AccessRequestWithRequesterDTO.builder()
                .id(request.getId() != null ? request.getId().toString() : null)
                .userId(request.getUserId() != null ? request.getUserId().toString() : null)
                .businessPlaceId(request.getBusinessPlaceId())
                .role(request.getRole())
                .status(request.getStatus())
                .requestedAt(request.getRequestedAt())
                .processedAt(request.getProcessedAt())
                .processedBy(request.getProcessedBy() != null ? request.getProcessedBy().toString() : null)
                .isReadByRequester(request.getIsReadByRequester())
                .createdAt(request.getCreatedAt())
                .updatedAt(request.getUpdatedAt())
                // 요청자 정보
                .requesterName(requester != null ? requester.getUsername() : null)
                .requesterPhone(requester != null ? requester.getPhone() : null)
                .requesterEmail(requester != null ? requester.getEmail() : null)
                // 사업장 정보
                .businessPlaceName(businessPlace != null ? businessPlace.getName() : null)
                .build();
    }
}
