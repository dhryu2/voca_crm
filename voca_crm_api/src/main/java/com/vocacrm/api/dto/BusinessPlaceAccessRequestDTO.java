package com.vocacrm.api.dto;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.BusinessPlaceAccessRequest;
import com.vocacrm.api.model.Role;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 사업장 접근 요청 응답 DTO
 *
 * Entity 직접 노출을 방지하고 필요한 필드만 응답합니다.
 * 민감한 정보(processedBy 등)는 필요한 경우에만 노출합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BusinessPlaceAccessRequestDTO {

    private String id;
    private String userId;
    private String businessPlaceId;
    private Role role;
    private AccessStatus status;
    private LocalDateTime requestedAt;
    private LocalDateTime processedAt;
    private Boolean isReadByRequester;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    /**
     * Entity에서 DTO 생성
     */
    public static BusinessPlaceAccessRequestDTO from(BusinessPlaceAccessRequest request) {
        if (request == null) {
            return null;
        }
        return BusinessPlaceAccessRequestDTO.builder()
                .id(request.getId() != null ? request.getId().toString() : null)
                .userId(request.getUserId() != null ? request.getUserId().toString() : null)
                .businessPlaceId(request.getBusinessPlaceId())
                .role(request.getRole())
                .status(request.getStatus())
                .requestedAt(request.getRequestedAt())
                .processedAt(request.getProcessedAt())
                .isReadByRequester(request.getIsReadByRequester())
                .createdAt(request.getCreatedAt())
                .updatedAt(request.getUpdatedAt())
                .build();
    }
}
