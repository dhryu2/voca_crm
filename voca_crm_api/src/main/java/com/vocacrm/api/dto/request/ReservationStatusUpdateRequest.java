package com.vocacrm.api.dto.request;

import com.vocacrm.api.model.Reservation.ReservationStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

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

    @Size(max = 36, message = "수정자 ID 형식이 올바르지 않습니다")
    private String updatedBy;
}
