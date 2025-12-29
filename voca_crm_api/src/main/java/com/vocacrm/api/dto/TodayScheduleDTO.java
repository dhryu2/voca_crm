package com.vocacrm.api.dto;

import com.vocacrm.api.model.Reservation;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TodayScheduleDTO {
    private UUID reservationId;
    private UUID memberId;
    private String memberName;
    private LocalTime reservationTime;
    private String serviceType;
    private Integer durationMinutes;
    private Reservation.ReservationStatus status;
    private String notes;
}
