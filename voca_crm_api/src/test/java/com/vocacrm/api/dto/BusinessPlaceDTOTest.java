package com.vocacrm.api.dto;

import com.vocacrm.api.model.BusinessPlace;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

class BusinessPlaceDTOTest {

    @Test
    void from은_엔티티필드를_DTO로변환한다() {
        LocalDateTime now = LocalDateTime.now();
        BusinessPlace businessPlace = BusinessPlace.builder()
                .id("BP0001")
                .name("강남지점")
                .address("서울시 강남구")
                .phone("02-1234-5678")
                .createdAt(now)
                .updatedAt(now)
                .build();

        BusinessPlaceDTO dto = BusinessPlaceDTO.from(businessPlace);

        assertThat(dto.getId()).isEqualTo("BP0001");
        assertThat(dto.getName()).isEqualTo("강남지점");
        assertThat(dto.getAddress()).isEqualTo("서울시 강남구");
        assertThat(dto.getPhone()).isEqualTo("02-1234-5678");
        assertThat(dto.getCreatedAt()).isEqualTo(now);
        assertThat(dto.getUpdatedAt()).isEqualTo(now);
    }

    @Test
    void from은_엔티티가null이면_null을반환한다() {
        assertThat(BusinessPlaceDTO.from(null)).isNull();
    }
}
