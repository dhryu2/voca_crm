package com.vocacrm.api.scheduler;

import com.vocacrm.api.service.ReservationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReservationCleanupSchedulerTest {

    @Mock
    private ReservationService reservationService;

    private ReservationCleanupScheduler scheduler;

    @BeforeEach
    void setUp() {
        scheduler = new ReservationCleanupScheduler(reservationService);
        ReflectionTestUtils.setField(scheduler, "retentionDays", 900);
    }

    @Test
    void cleanupExpiredReservations_삭제대상이있으면_삭제를수행한다() {
        when(reservationService.countExpiredReservations(900)).thenReturn(5L);
        when(reservationService.deleteExpiredReservations(900)).thenReturn(5);

        scheduler.cleanupExpiredReservations();

        verify(reservationService).countExpiredReservations(eq(900));
        verify(reservationService).deleteExpiredReservations(eq(900));
    }

    @Test
    void cleanupExpiredReservations_삭제대상이없으면_삭제를호출하지않는다() {
        when(reservationService.countExpiredReservations(900)).thenReturn(0L);

        scheduler.cleanupExpiredReservations();

        verify(reservationService).countExpiredReservations(eq(900));
        verify(reservationService, never()).deleteExpiredReservations(anyInt());
    }

    @Test
    void cleanupExpiredReservations_예외가발생해도_전파되지않는다() {
        when(reservationService.countExpiredReservations(900))
                .thenThrow(new RuntimeException("db error"));

        scheduler.cleanupExpiredReservations();

        verify(reservationService, times(1)).countExpiredReservations(900);
        verify(reservationService, never()).deleteExpiredReservations(anyInt());
    }
}
