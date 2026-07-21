package com.vocacrm.api.controller;

import com.vocacrm.api.dto.TodayVisitResponse;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Visit;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.VisitService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VisitControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String MEMBER_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    private static final String VISIT_ID = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private VisitService visitService;
    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private VisitController visitController;

    @BeforeEach
    void setUp() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
    }

    private void grantAccess() {
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
    }

    private void denyAccess() {
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);
    }

    @Test
    void checkIn_정상_체크인이_이루어진다() {
        VisitController.CheckInRequest request = new VisitController.CheckInRequest();
        request.setMemberId(MEMBER_ID);
        request.setNote("방문 메모");
        Visit visit = Visit.builder().id(UUID.randomUUID()).memberId(UUID.fromString(MEMBER_ID)).build();
        when(visitService.checkInWithUserCheck(MEMBER_ID, USER_ID, "방문 메모")).thenReturn(visit);

        ResponseEntity<Visit> response = visitController.checkIn(request, servletRequest);

        assertThat(response.getBody()).isSameAs(visit);
    }

    @Test
    void checkIn_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        VisitController.CheckInRequest request = new VisitController.CheckInRequest();
        request.setMemberId(MEMBER_ID);
        when(visitService.checkInWithUserCheck(MEMBER_ID, USER_ID, null))
                .thenThrow(new AccessDeniedException("회원이 속한 사업장이 아닙니다."));

        assertThatThrownBy(() -> visitController.checkIn(request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getVisitsByMember_정상적으로_방문기록을_반환한다() {
        List<Visit> visits = List.of(Visit.builder().id(UUID.randomUUID()).build());
        when(visitService.getVisitsByMemberWithUserCheck(MEMBER_ID, USER_ID)).thenReturn(visits);

        ResponseEntity<List<Visit>> response = visitController.getVisitsByMember(MEMBER_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(visits);
    }

    @Test
    void getVisitsByMember_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        when(visitService.getVisitsByMemberWithUserCheck(MEMBER_ID, USER_ID))
                .thenThrow(new AccessDeniedException("회원이 속한 사업장이 아닙니다."));

        assertThatThrownBy(() -> visitController.getVisitsByMember(MEMBER_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getTodayVisits_권한이_있으면_정상_반환된다() {
        grantAccess();
        Visit visit = Visit.builder()
                .id(UUID.randomUUID())
                .memberId(UUID.fromString(MEMBER_ID))
                .visitedAt(LocalDateTime.now())
                .build();
        when(visitService.getTodayVisits(BUSINESS_PLACE_ID)).thenReturn(List.of(visit));

        ResponseEntity<List<TodayVisitResponse>> response =
                visitController.getTodayVisits(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getBody()).hasSize(1);
        assertThat(response.getBody().get(0).getId()).isEqualTo(visit.getId());
    }

    @Test
    void getTodayVisits_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> visitController.getTodayVisits(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void cancelCheckIn_권한이_있으면_체크인이_취소된다() {
        grantAccess();

        ResponseEntity<Void> response = visitController.cancelCheckIn(VISIT_ID, BUSINESS_PLACE_ID, servletRequest);

        verify(visitService).cancelCheckIn(VISIT_ID, BUSINESS_PLACE_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void cancelCheckIn_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> visitController.cancelCheckIn(VISIT_ID, BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }
}
