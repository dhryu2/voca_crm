package com.vocacrm.api.dto.request;

import com.vocacrm.api.model.Reservation.ReservationStatus;
import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * 예약 수정 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReservationUpdateRequest {

    @NotNull(message = "예약 날짜는 필수입니다")
    private LocalDate reservationDate;

    @NotNull(message = "예약 시간은 필수입니다")
    private LocalTime reservationTime;

    private ReservationStatus status;

    @Size(max = 100, message = "서비스 유형은 100자 이내로 입력해주세요")
    private String serviceType;

    @Positive(message = "소요 시간은 양수여야 합니다")
    @Max(value = 480, message = "소요 시간은 최대 8시간(480분)까지 가능합니다")
    private Integer durationMinutes;

    @Size(max = 1000, message = "메모는 1000자 이내로 입력해주세요")
    private String notes;

    @Size(max = 200, message = "특이사항은 200자 이내로 입력해주세요")
    private String remark;

    @Size(max = 36, message = "수정자 ID 형식이 올바르지 않습니다")
    private String updatedBy;
}
