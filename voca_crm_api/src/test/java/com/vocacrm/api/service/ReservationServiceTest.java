package com.vocacrm.api.service;

import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.Reservation;
import com.vocacrm.api.repository.ReservationRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReservationServiceTest {

    @Mock
    private ReservationRepository reservationRepository;

    @InjectMocks
    private ReservationService reservationService;

    private static final String BUSINESS_PLACE_ID = "ABC1234";

    private Reservation newReservation(UUID memberId, LocalDate date, LocalTime time) {
        return Reservation.builder()
                .memberId(memberId)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .reservationDate(date)
                .reservationTime(time)
                .build();
    }

    @Test
    void createReservation_정상_케이스면_예약을_저장한다() {
        Reservation reservation = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        when(reservationRepository.existsDuplicateReservation(
                reservation.getMemberId(), BUSINESS_PLACE_ID, reservation.getReservationDate(), reservation.getReservationTime()))
                .thenReturn(false);
        // 슬롯 중복 제약을 잡기 위해 서비스가 saveAndFlush 를 사용하도록 변경됨(WB-03)
        when(reservationRepository.saveAndFlush(reservation)).thenReturn(reservation);

        Reservation result = reservationService.createReservation(reservation);

        assertThat(result).isEqualTo(reservation);
    }

    @Test
    void createReservation_과거_날짜면_IllegalArgumentException을_던진다() {
        Reservation reservation = newReservation(UUID.randomUUID(), LocalDate.now().minusDays(1), LocalTime.of(10, 0));

        assertThatThrownBy(() -> reservationService.createReservation(reservation))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createReservation_중복_예약이면_IllegalArgumentException을_던진다() {
        Reservation reservation = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        when(reservationRepository.existsDuplicateReservation(
                reservation.getMemberId(), BUSINESS_PLACE_ID, reservation.getReservationDate(), reservation.getReservationTime()))
                .thenReturn(true);

        assertThatThrownBy(() -> reservationService.createReservation(reservation))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void updateReservation_정상_케이스면_변경사항을_반영해_저장한다() {
        UUID id = UUID.randomUUID();
        Reservation existing = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        existing.setId(id);
        existing.setStatus(Reservation.ReservationStatus.PENDING);

        Reservation updated = new Reservation();
        updated.setNotes("변경된 메모");

        when(reservationRepository.findById(id)).thenReturn(Optional.of(existing));
        when(reservationRepository.saveAndFlush(any(Reservation.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Reservation result = reservationService.updateReservation(id, updated, null);

        assertThat(result.getNotes()).isEqualTo("변경된 메모");
    }

    @Test
    void updateReservation_status를_생략하면_종료된_예약이라도_기존_상태를_유지한다() {
        UUID id = UUID.randomUUID();
        Reservation existing = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        existing.setId(id);
        existing.setStatus(Reservation.ReservationStatus.COMPLETED);

        // status 변경 의도 없이(newStatus=null) 메모만 수정
        Reservation updated = new Reservation();
        updated.setNotes("메모만 변경");

        when(reservationRepository.findById(id)).thenReturn(Optional.of(existing));
        when(reservationRepository.saveAndFlush(any(Reservation.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Reservation result = reservationService.updateReservation(id, updated, null);

        // 종료 상태가 덮어써지거나 전이 검증에 걸리지 않고 그대로 유지되어야 한다
        assertThat(result.getStatus()).isEqualTo(Reservation.ReservationStatus.COMPLETED);
        assertThat(result.getNotes()).isEqualTo("메모만 변경");
    }

    @Test
    void updateReservation_status를_포함하면_정상적으로_상태를_전이한다() {
        UUID id = UUID.randomUUID();
        Reservation existing = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        existing.setId(id);
        existing.setStatus(Reservation.ReservationStatus.PENDING);

        when(reservationRepository.findById(id)).thenReturn(Optional.of(existing));
        when(reservationRepository.saveAndFlush(any(Reservation.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Reservation result = reservationService.updateReservation(
                id, new Reservation(), Reservation.ReservationStatus.CONFIRMED);

        assertThat(result.getStatus()).isEqualTo(Reservation.ReservationStatus.CONFIRMED);
    }

    @Test
    void updateReservation_존재하지_않는_예약이면_ResourceNotFoundException을_던진다() {
        UUID id = UUID.randomUUID();
        when(reservationRepository.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> reservationService.updateReservation(id, new Reservation(), null))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void updateReservationStatus_정상_케이스면_취소_상태로_변경한다() {
        UUID id = UUID.randomUUID();
        Reservation existing = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        existing.setId(id);
        existing.setStatus(Reservation.ReservationStatus.PENDING);

        when(reservationRepository.findById(id)).thenReturn(Optional.of(existing));
        when(reservationRepository.save(any(Reservation.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Reservation result = reservationService.updateReservationStatus(id, Reservation.ReservationStatus.CANCELLED, null);

        assertThat(result.getStatus()).isEqualTo(Reservation.ReservationStatus.CANCELLED);
    }

    @Test
    void updateReservationStatus_종료된_예약을_활성상태로_변경하면_IllegalArgumentException을_던진다() {
        UUID id = UUID.randomUUID();
        Reservation existing = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        existing.setId(id);
        existing.setStatus(Reservation.ReservationStatus.COMPLETED);

        when(reservationRepository.findById(id)).thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> reservationService.updateReservationStatus(id, Reservation.ReservationStatus.CONFIRMED, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getReservationsByMemberId_businessPlaceId가_없으면_IllegalArgumentException을_던진다() {
        assertThatThrownBy(() -> reservationService.getReservationsByMemberId(UUID.randomUUID(), null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createReservation_회원ID가_없으면_IllegalArgumentException을_던진다() {
        Reservation reservation = newReservation(null, LocalDate.now().plusDays(1), LocalTime.of(10, 0));

        assertThatThrownBy(() -> reservationService.createReservation(reservation))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createReservation_사업장ID가_없으면_IllegalArgumentException을_던진다() {
        Reservation reservation = Reservation.builder()
                .memberId(UUID.randomUUID())
                .businessPlaceId("")
                .reservationDate(LocalDate.now().plusDays(1))
                .reservationTime(LocalTime.of(10, 0))
                .build();

        assertThatThrownBy(() -> reservationService.createReservation(reservation))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createReservation_90일_초과_미래면_IllegalArgumentException을_던진다() {
        Reservation reservation = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(91), LocalTime.of(10, 0));

        assertThatThrownBy(() -> reservationService.createReservation(reservation))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getReservationById_존재하지_않으면_ResourceNotFoundException을_던진다() {
        UUID id = UUID.randomUUID();
        when(reservationRepository.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> reservationService.getReservationById(id))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getReservationsByBusinessPlaceId_정상_목록을_반환한다() {
        Reservation reservation = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        when(reservationRepository.findByBusinessPlaceIdOrderByReservationDateAscReservationTimeAsc(BUSINESS_PLACE_ID))
                .thenReturn(List.of(reservation));

        List<Reservation> result = reservationService.getReservationsByBusinessPlaceId(BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(reservation);
    }

    @Test
    void getReservationsByStatus_정상_목록을_반환한다() {
        Reservation reservation = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        reservation.setStatus(Reservation.ReservationStatus.PENDING);
        when(reservationRepository.findByBusinessPlaceIdAndStatusOrderByReservationDateAscReservationTimeAsc(
                BUSINESS_PLACE_ID, Reservation.ReservationStatus.PENDING))
                .thenReturn(List.of(reservation));

        List<Reservation> result = reservationService.getReservationsByStatus(BUSINESS_PLACE_ID, Reservation.ReservationStatus.PENDING);

        assertThat(result).containsExactly(reservation);
    }

    @Test
    void deleteExpiredReservations_보관기간_이전_예약을_삭제한다() {
        when(reservationRepository.deleteByReservationDateBefore(any(LocalDate.class))).thenReturn(3);

        int result = reservationService.deleteExpiredReservations(365);

        assertThat(result).isEqualTo(3);
    }

    @Test
    void getMemberReservationCount_businessPlaceId가_없으면_IllegalArgumentException을_던진다() {
        assertThatThrownBy(() -> reservationService.getMemberReservationCount(UUID.randomUUID(), ""))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createReservation_예약시간이_없으면_IllegalArgumentException을_던진다() {
        Reservation reservation = Reservation.builder()
                .memberId(UUID.randomUUID())
                .businessPlaceId(BUSINESS_PLACE_ID)
                .reservationDate(LocalDate.now().plusDays(1))
                .build();

        assertThatThrownBy(() -> reservationService.createReservation(reservation))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void updateReservation_날짜변경시_중복이면_IllegalArgumentException을_던진다() {
        UUID id = UUID.randomUUID();
        Reservation existing = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        existing.setId(id);
        existing.setStatus(Reservation.ReservationStatus.PENDING);

        Reservation updated = new Reservation();
        updated.setReservationDate(LocalDate.now().plusDays(2));

        when(reservationRepository.findById(id)).thenReturn(Optional.of(existing));
        when(reservationRepository.existsDuplicateReservationExcluding(
                any(UUID.class), eq(BUSINESS_PLACE_ID), any(LocalDate.class), any(LocalTime.class), eq(id)))
                .thenReturn(true);

        assertThatThrownBy(() -> reservationService.updateReservation(id, updated, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void updateReservation_서비스타입_담당자_비고등_모든_필드를_반영한다() {
        UUID id = UUID.randomUUID();
        Reservation existing = newReservation(UUID.randomUUID(), LocalDate.now().plusDays(1), LocalTime.of(10, 0));
        existing.setId(id);
        existing.setStatus(Reservation.ReservationStatus.PENDING);

        UUID updatedBy = UUID.randomUUID();
        Reservation updated = new Reservation();
        updated.setServiceType("헤어컷");
        updated.setDurationMinutes(60);
        updated.setRemark("특이사항 없음");
        updated.setUpdatedBy(updatedBy);

        when(reservationRepository.findById(id)).thenReturn(Optional.of(existing));
        when(reservationRepository.saveAndFlush(any(Reservation.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Reservation result = reservationService.updateReservation(id, updated, null);

        assertThat(result.getServiceType()).isEqualTo("헤어컷");
        assertThat(result.getDurationMinutes()).isEqualTo(60);
        assertThat(result.getRemark()).isEqualTo("특이사항 없음");
        assertThat(result.getUpdatedBy()).isEqualTo(updatedBy);
    }

    @Test
    void getReservationsByBusinessPlaceAndDate_정상_목록을_반환한다() {
        LocalDate date = LocalDate.now().plusDays(1);
        Reservation reservation = newReservation(UUID.randomUUID(), date, LocalTime.of(10, 0));
        when(reservationRepository.findByBusinessPlaceIdAndReservationDateOrderByReservationTimeAsc(BUSINESS_PLACE_ID, date))
                .thenReturn(List.of(reservation));

        List<Reservation> result = reservationService.getReservationsByBusinessPlaceAndDate(BUSINESS_PLACE_ID, date);

        assertThat(result).containsExactly(reservation);
    }

    @Test
    void getReservationsByDateRange_정상_목록을_반환한다() {
        LocalDate start = LocalDate.now();
        LocalDate end = LocalDate.now().plusDays(7);
        Reservation reservation = newReservation(UUID.randomUUID(), start, LocalTime.of(10, 0));
        when(reservationRepository.findByBusinessPlaceIdAndDateRange(BUSINESS_PLACE_ID, start, end))
                .thenReturn(List.of(reservation));

        List<Reservation> result = reservationService.getReservationsByDateRange(BUSINESS_PLACE_ID, start, end);

        assertThat(result).containsExactly(reservation);
    }

    @Test
    void countExpiredReservations_삭제예정_건수를_반환한다() {
        when(reservationRepository.countByReservationDateBefore(any(LocalDate.class))).thenReturn(5L);

        long result = reservationService.countExpiredReservations(365);

        assertThat(result).isEqualTo(5L);
    }

    @Test
    void getReservationCountByDate_정상_건수를_반환한다() {
        LocalDate date = LocalDate.now();
        when(reservationRepository.countByBusinessPlaceIdAndDate(BUSINESS_PLACE_ID, date)).thenReturn(2L);

        Long result = reservationService.getReservationCountByDate(BUSINESS_PLACE_ID, date);

        assertThat(result).isEqualTo(2L);
    }

    @Test
    void getTodayReservationCount_정상_건수를_반환한다() {
        when(reservationRepository.countTodayReservations(BUSINESS_PLACE_ID)).thenReturn(4L);

        Long result = reservationService.getTodayReservationCount(BUSINESS_PLACE_ID);

        assertThat(result).isEqualTo(4L);
    }

    @Test
    void getMemberCompletedReservationCount_businessPlaceId가_없으면_IllegalArgumentException을_던진다() {
        assertThatThrownBy(() -> reservationService.getMemberCompletedReservationCount(UUID.randomUUID(), null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getMemberCompletedReservationCount_정상_건수를_반환한다() {
        UUID memberId = UUID.randomUUID();
        when(reservationRepository.countByMemberIdAndBusinessPlaceIdAndStatus(
                memberId, BUSINESS_PLACE_ID, Reservation.ReservationStatus.COMPLETED))
                .thenReturn(7L);

        Long result = reservationService.getMemberCompletedReservationCount(memberId, BUSINESS_PLACE_ID);

        assertThat(result).isEqualTo(7L);
    }
}
