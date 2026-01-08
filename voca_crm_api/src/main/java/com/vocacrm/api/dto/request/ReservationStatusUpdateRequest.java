package com.vocacrm.api.dto.request;

import com.vocacrm.api.model.Reservation.ReservationStatus;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

/**
 * 예약 상태 변경 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReservationStatusUpdateRequest {

    @NotNull(message = "변경할 상태는 필수입니다")
    private ReservationStatus status;

    private UUID updatedBy;
}
