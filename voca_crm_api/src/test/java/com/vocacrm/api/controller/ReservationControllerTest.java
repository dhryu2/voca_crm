package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.ReservationCreateRequest;
import com.vocacrm.api.dto.request.ReservationStatusUpdateRequest;
import com.vocacrm.api.dto.request.ReservationUpdateRequest;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Reservation;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.MemberService;
import com.vocacrm.api.service.ReservationService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReservationControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String MEMBER_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    private static final String RESERVATION_ID = "11111111-2222-3333-4444-555555555555";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private ReservationService reservationService;
    @Mock
    private MemberService memberService;
    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private ReservationController reservationController;

    @BeforeEach
    void setUp() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
    }

    private void grantAccess(boolean granted) {
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(any(), any(), any()))
                .thenReturn(granted);
    }

    private Member memberIn(String businessPlaceId) {
        Member member = new Member();
        member.setBusinessPlaceId(businessPlaceId);
        return member;
    }

    private ReservationCreateRequest createRequest() {
        return ReservationCreateRequest.builder()
                .memberId(MEMBER_ID)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .reservationDate(LocalDate.of(2026, 7, 20))
                .reservationTime(LocalTime.of(14, 0))
                .serviceType("커트")
                .durationMinutes(60)
                .notes("메모")
                .remark("특이사항")
                .build();
    }

    private ReservationUpdateRequest updateRequest() {
        return ReservationUpdateRequest.builder()
                .reservationDate(LocalDate.of(2026, 7, 21))
                .reservationTime(LocalTime.of(15, 0))
                .serviceType("펌")
                .durationMinutes(90)
                .notes("메모")
                .remark("특이사항")
                .build();
    }

    // ===== createReservation =====

    @Test
    void createReservation_성공하면_201과_생성된_예약을_반환한다() {
        grantAccess(true);
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID)).thenReturn(memberIn(BUSINESS_PLACE_ID));
        Reservation created = new Reservation();
        when(reservationService.createReservation(any(Reservation.class))).thenReturn(created);

        ResponseEntity<Reservation> response = reservationController.createReservation(createRequest(), servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(201);
        assertThat(response.getBody()).isSameAs(created);
    }

    @Test
    void createReservation_사업장_접근권한이_없으면_AccessDenied를_던진다() {
        grantAccess(false);

        assertThatThrownBy(() -> reservationController.createReservation(createRequest(), servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void createReservation_회원이_다른_사업장_소속이면_IllegalArgument를_던진다() {
        grantAccess(true);
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID)).thenReturn(memberIn("OTHER99"));

        assertThatThrownBy(() -> reservationController.createReservation(createRequest(), servletRequest))
                .isInstanceOf(IllegalArgumentException.class);
    }

    // ===== getReservation =====

    @Test
    void getReservation_성공하면_예약을_반환한다() {
        Reservation reservation = new Reservation();
        reservation.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(reservationService.getReservationById(any(UUID.class))).thenReturn(reservation);
        grantAccess(true);

        ResponseEntity<Reservation> response = reservationController.getReservation(RESERVATION_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(reservation);
    }

    @Test
    void getReservation_접근권한이_없으면_AccessDenied를_던진다() {
        Reservation reservation = new Reservation();
        reservation.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(reservationService.getReservationById(any(UUID.class))).thenReturn(reservation);
        grantAccess(false);

        assertThatThrownBy(() -> reservationController.getReservation(RESERVATION_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getReservationsByMember =====

    @Test
    void getReservationsByMember_예약목록을_반환한다() {
        when(memberService.getMemberByIdWithUserCheckIncludeDeleted(MEMBER_ID, USER_ID))
                .thenReturn(memberIn(BUSINESS_PLACE_ID));
        List<Reservation> reservations = List.of(new Reservation());
        when(reservationService.getReservationsByMemberId(any(UUID.class), eq(BUSINESS_PLACE_ID)))
                .thenReturn(reservations);

        ResponseEntity<List<Reservation>> response =
                reservationController.getReservationsByMember(MEMBER_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(reservations);
    }

    @Test
    void getReservationsByMember_회원검증이_실패하면_예외를_전파한다() {
        when(memberService.getMemberByIdWithUserCheckIncludeDeleted(MEMBER_ID, USER_ID))
                .thenThrow(new AccessDeniedException("권한 없음"));

        assertThatThrownBy(() -> reservationController.getReservationsByMember(MEMBER_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getReservationsByBusinessPlace =====

    @Test
    void getReservationsByBusinessPlace_예약목록을_반환한다() {
        grantAccess(true);
        List<Reservation> reservations = List.of(new Reservation());
        when(reservationService.getReservationsByBusinessPlaceId(BUSINESS_PLACE_ID)).thenReturn(reservations);

        ResponseEntity<List<Reservation>> response =
                reservationController.getReservationsByBusinessPlace(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(reservations);
    }

    @Test
    void getReservationsByBusinessPlace_접근권한이_없으면_AccessDenied를_던진다() {
        grantAccess(false);

        assertThatThrownBy(() ->
                reservationController.getReservationsByBusinessPlace(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getReservationsByDate =====

    @Test
    void getReservationsByDate_예약목록을_반환한다() {
        grantAccess(true);
        LocalDate date = LocalDate.of(2026, 7, 20);
        List<Reservation> reservations = List.of(new Reservation());
        when(reservationService.getReservationsByBusinessPlaceAndDate(BUSINESS_PLACE_ID, date))
                .thenReturn(reservations);

        ResponseEntity<List<Reservation>> response =
                reservationController.getReservationsByDate(BUSINESS_PLACE_ID, date, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(reservations);
    }

    @Test
    void getReservationsByDate_접근권한이_없으면_AccessDenied를_던진다() {
        grantAccess(false);

        assertThatThrownBy(() -> reservationController.getReservationsByDate(
                BUSINESS_PLACE_ID, LocalDate.of(2026, 7, 20), servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getReservationsByDateRange =====

    @Test
    void getReservationsByDateRange_예약목록을_반환한다() {
        grantAccess(true);
        LocalDate start = LocalDate.of(2026, 7, 1);
        LocalDate end = LocalDate.of(2026, 7, 31);
        List<Reservation> reservations = List.of(new Reservation());
        when(reservationService.getReservationsByDateRange(BUSINESS_PLACE_ID, start, end)).thenReturn(reservations);

        ResponseEntity<List<Reservation>> response =
                reservationController.getReservationsByDateRange(BUSINESS_PLACE_ID, start, end, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(reservations);
    }

    // ===== getReservationsByStatus =====

    @Test
    void getReservationsByStatus_예약목록을_반환한다() {
        grantAccess(true);
        List<Reservation> reservations = List.of(new Reservation());
        when(reservationService.getReservationsByStatus(BUSINESS_PLACE_ID, Reservation.ReservationStatus.CONFIRMED))
                .thenReturn(reservations);

        ResponseEntity<List<Reservation>> response = reservationController.getReservationsByStatus(
                BUSINESS_PLACE_ID, Reservation.ReservationStatus.CONFIRMED, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(reservations);
    }

    // ===== updateReservation =====

    @Test
    void updateReservation_성공하면_수정된_예약을_반환한다() {
        Reservation existing = new Reservation();
        existing.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(reservationService.getReservationById(any(UUID.class))).thenReturn(existing);
        grantAccess(true);
        Reservation updated = new Reservation();
        when(reservationService.updateReservation(any(UUID.class), any(Reservation.class), any())).thenReturn(updated);

        ResponseEntity<Reservation> response =
                reservationController.updateReservation(RESERVATION_ID, updateRequest(), servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(updated);
    }

    @Test
    void updateReservation_접근권한이_없으면_AccessDenied를_던진다() {
        Reservation existing = new Reservation();
        existing.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(reservationService.getReservationById(any(UUID.class))).thenReturn(existing);
        grantAccess(false);

        assertThatThrownBy(() ->
                reservationController.updateReservation(RESERVATION_ID, updateRequest(), servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== updateReservationStatus =====

    @Test
    void updateReservationStatus_성공하면_수정된_예약을_반환한다() {
        Reservation existing = new Reservation();
        existing.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(reservationService.getReservationById(any(UUID.class))).thenReturn(existing);
        grantAccess(true);
        Reservation updated = new Reservation();
        when(reservationService.updateReservationStatus(any(UUID.class), any(), any(UUID.class))).thenReturn(updated);

        ReservationStatusUpdateRequest request = ReservationStatusUpdateRequest.builder()
                .status(Reservation.ReservationStatus.COMPLETED)
                .build();

        ResponseEntity<Reservation> response =
                reservationController.updateReservationStatus(RESERVATION_ID, request, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(updated);
    }

    @Test
    void updateReservationStatus_접근권한이_없으면_AccessDenied를_던진다() {
        Reservation existing = new Reservation();
        existing.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(reservationService.getReservationById(any(UUID.class))).thenReturn(existing);
        grantAccess(false);

        ReservationStatusUpdateRequest request = ReservationStatusUpdateRequest.builder()
                .status(Reservation.ReservationStatus.CANCELLED)
                .build();

        assertThatThrownBy(() ->
                reservationController.updateReservationStatus(RESERVATION_ID, request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getReservationCount =====

    @Test
    void getReservationCount_날짜가_주어지면_해당_날짜_개수를_반환한다() {
        grantAccess(true);
        LocalDate date = LocalDate.of(2026, 7, 20);
        when(reservationService.getReservationCountByDate(BUSINESS_PLACE_ID, date)).thenReturn(5L);

        ResponseEntity<Map<String, Object>> response =
                reservationController.getReservationCount(BUSINESS_PLACE_ID, date, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).containsEntry("count", 5L);
        assertThat(response.getBody()).containsEntry("businessPlaceId", BUSINESS_PLACE_ID);
    }

    @Test
    void getReservationCount_날짜가_없으면_오늘_개수를_반환한다() {
        grantAccess(true);
        when(reservationService.getTodayReservationCount(BUSINESS_PLACE_ID)).thenReturn(3L);

        ResponseEntity<Map<String, Object>> response =
                reservationController.getReservationCount(BUSINESS_PLACE_ID, null, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).containsEntry("count", 3L);
    }

    @Test
    void getReservationCount_접근권한이_없으면_AccessDenied를_던진다() {
        grantAccess(false);

        assertThatThrownBy(() ->
                reservationController.getReservationCount(BUSINESS_PLACE_ID, null, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getMemberReservationStats =====

    @Test
    void getMemberReservationStats_통계를_반환한다() {
        when(memberService.getMemberByIdWithUserCheckIncludeDeleted(MEMBER_ID, USER_ID))
                .thenReturn(memberIn(BUSINESS_PLACE_ID));
        when(reservationService.getMemberReservationCount(any(UUID.class), eq(BUSINESS_PLACE_ID))).thenReturn(10L);
        when(reservationService.getMemberCompletedReservationCount(any(UUID.class), eq(BUSINESS_PLACE_ID)))
                .thenReturn(7L);

        ResponseEntity<Map<String, Object>> response =
                reservationController.getMemberReservationStats(MEMBER_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).containsEntry("totalReservations", 10L);
        assertThat(response.getBody()).containsEntry("completedReservations", 7L);
    }
}
