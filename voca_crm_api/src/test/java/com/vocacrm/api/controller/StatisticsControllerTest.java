package com.vocacrm.api.controller;

import com.vocacrm.api.dto.ChartDataDTO;
import com.vocacrm.api.dto.HomeStatisticsDTO;
import com.vocacrm.api.dto.RecentActivityDTO;
import com.vocacrm.api.dto.TodayScheduleDTO;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.StatisticsService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StatisticsControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private StatisticsService statisticsService;
    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private StatisticsController statisticsController;

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
    void getHomeStatistics_권한이_있으면_정상_반환된다() {
        grantAccess();
        HomeStatisticsDTO dto = HomeStatisticsDTO.builder().businessPlaceId(BUSINESS_PLACE_ID).build();
        when(statisticsService.getHomeStatistics(BUSINESS_PLACE_ID)).thenReturn(dto);

        ResponseEntity<HomeStatisticsDTO> response = statisticsController.getHomeStatistics(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(dto);
    }

    @Test
    void getHomeStatistics_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> statisticsController.getHomeStatistics(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getRecentActivities_권한이_있으면_정상_반환된다() {
        grantAccess();
        List<RecentActivityDTO> activities = List.of(RecentActivityDTO.builder().activityId("a1").build());
        when(statisticsService.getRecentActivities(BUSINESS_PLACE_ID, 10)).thenReturn(activities);

        ResponseEntity<List<RecentActivityDTO>> response =
                statisticsController.getRecentActivities(BUSINESS_PLACE_ID, 10, servletRequest);

        assertThat(response.getBody()).isSameAs(activities);
    }

    @Test
    void getRecentActivities_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> statisticsController.getRecentActivities(BUSINESS_PLACE_ID, 10, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getTodaySchedule_권한이_있으면_정상_반환된다() {
        grantAccess();
        List<TodayScheduleDTO> schedule = List.of(TodayScheduleDTO.builder().memberName("홍길동").build());
        when(statisticsService.getTodaySchedule(BUSINESS_PLACE_ID, 10)).thenReturn(schedule);

        ResponseEntity<List<TodayScheduleDTO>> response =
                statisticsController.getTodaySchedule(BUSINESS_PLACE_ID, 10, servletRequest);

        assertThat(response.getBody()).isSameAs(schedule);
    }

    @Test
    void getTodaySchedule_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> statisticsController.getTodaySchedule(BUSINESS_PLACE_ID, 10, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMemberRegistrationTrend_권한이_있으면_정상_반환된다() {
        grantAccess();
        ChartDataDTO.MemberRegistrationTrendDTO trend =
                ChartDataDTO.MemberRegistrationTrendDTO.builder().totalNewMembers(5).build();
        when(statisticsService.getMemberRegistrationTrend(BUSINESS_PLACE_ID, 7)).thenReturn(trend);

        ResponseEntity<ChartDataDTO.MemberRegistrationTrendDTO> response =
                statisticsController.getMemberRegistrationTrend(BUSINESS_PLACE_ID, 7, servletRequest);

        assertThat(response.getBody()).isSameAs(trend);
    }

    @Test
    void getMemberRegistrationTrend_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> statisticsController.getMemberRegistrationTrend(BUSINESS_PLACE_ID, 7, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMemberGradeDistribution_권한이_있으면_정상_반환된다() {
        grantAccess();
        ChartDataDTO.MemberGradeDistributionDTO distribution =
                ChartDataDTO.MemberGradeDistributionDTO.builder().totalMembers(10).build();
        when(statisticsService.getMemberGradeDistribution(BUSINESS_PLACE_ID)).thenReturn(distribution);

        ResponseEntity<ChartDataDTO.MemberGradeDistributionDTO> response =
                statisticsController.getMemberGradeDistribution(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(distribution);
    }

    @Test
    void getMemberGradeDistribution_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> statisticsController.getMemberGradeDistribution(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getReservationTrend_권한이_있으면_정상_반환된다() {
        grantAccess();
        ChartDataDTO.ReservationTrendDTO trend =
                ChartDataDTO.ReservationTrendDTO.builder().totalReservations(3).build();
        when(statisticsService.getReservationTrend(BUSINESS_PLACE_ID, 7)).thenReturn(trend);

        ResponseEntity<ChartDataDTO.ReservationTrendDTO> response =
                statisticsController.getReservationTrend(BUSINESS_PLACE_ID, 7, servletRequest);

        assertThat(response.getBody()).isSameAs(trend);
    }

    @Test
    void getReservationTrend_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> statisticsController.getReservationTrend(BUSINESS_PLACE_ID, 7, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMemoStatistics_권한이_있으면_정상_반환된다() {
        grantAccess();
        ChartDataDTO.MemoStatisticsDTO statistics =
                ChartDataDTO.MemoStatisticsDTO.builder().totalMemos(20).build();
        when(statisticsService.getMemoStatistics(BUSINESS_PLACE_ID, 7)).thenReturn(statistics);

        ResponseEntity<ChartDataDTO.MemoStatisticsDTO> response =
                statisticsController.getMemoStatistics(BUSINESS_PLACE_ID, 7, servletRequest);

        assertThat(response.getBody()).isSameAs(statistics);
    }

    @Test
    void getMemoStatistics_권한이_없으면_AccessDeniedException() {
        denyAccess();

        assertThatThrownBy(() -> statisticsController.getMemoStatistics(BUSINESS_PLACE_ID, 7, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }
}
