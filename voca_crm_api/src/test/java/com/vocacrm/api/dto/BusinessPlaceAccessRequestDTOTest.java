package com.vocacrm.api.dto;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.BusinessPlaceAccessRequest;
import com.vocacrm.api.model.Role;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class BusinessPlaceAccessRequestDTOTest {

    @Test
    void from은_엔티티필드를_DTO로변환한다() {
        UUID id = UUID.randomUUID();
        UUID userId = UUID.randomUUID();
        LocalDateTime requestedAt = LocalDateTime.now();
        LocalDateTime processedAt = requestedAt.plusHours(1);
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(id)
                .userId(userId)
                .businessPlaceId("BP0001")
                .role(Role.STAFF)
                .status(AccessStatus.PENDING)
                .requestedAt(requestedAt)
                .processedAt(processedAt)
                .isReadByRequester(false)
                .createdAt(requestedAt)
                .updatedAt(processedAt)
                .build();

        BusinessPlaceAccessRequestDTO dto = BusinessPlaceAccessRequestDTO.from(request);

        assertThat(dto.getId()).isEqualTo(id.toString());
        assertThat(dto.getUserId()).isEqualTo(userId.toString());
        assertThat(dto.getBusinessPlaceId()).isEqualTo("BP0001");
        assertThat(dto.getRole()).isEqualTo(Role.STAFF);
        assertThat(dto.getStatus()).isEqualTo(AccessStatus.PENDING);
        assertThat(dto.getRequestedAt()).isEqualTo(requestedAt);
        assertThat(dto.getProcessedAt()).isEqualTo(processedAt);
        assertThat(dto.getIsReadByRequester()).isFalse();
        assertThat(dto.getCreatedAt()).isEqualTo(requestedAt);
        assertThat(dto.getUpdatedAt()).isEqualTo(processedAt);
    }

    @Test
    void from은_id와userId가null이면_문자열로변환하지않는다() {
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .businessPlaceId("BP0002")
                .role(Role.MANAGER)
                .status(AccessStatus.APPROVED)
                .build();

        BusinessPlaceAccessRequestDTO dto = BusinessPlaceAccessRequestDTO.from(request);

        assertThat(dto.getId()).isNull();
        assertThat(dto.getUserId()).isNull();
        assertThat(dto.getBusinessPlaceId()).isEqualTo("BP0002");
    }

    @Test
    void from은_엔티티가null이면_null을반환한다() {
        assertThat(BusinessPlaceAccessRequestDTO.from(null)).isNull();
    }
}
