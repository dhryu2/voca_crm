package com.vocacrm.api.service;

import com.vocacrm.api.dto.ChartDataDTO;
import com.vocacrm.api.dto.HomeStatisticsDTO;
import com.vocacrm.api.dto.RecentActivityDTO;
import com.vocacrm.api.dto.TodayScheduleDTO;
import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.Reservation;
import com.vocacrm.api.repository.BusinessPlaceRepository;
import com.vocacrm.api.repository.ReservationRepository;
import com.vocacrm.api.repository.StatisticsRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StatisticsServiceTest {

    @Mock
    private StatisticsRepository statisticsRepository;
    @Mock
    private BusinessPlaceRepository businessPlaceRepository;
    @Mock
    private ReservationRepository reservationRepository;
    @Mock
    private JdbcTemplate jdbcTemplate;

    private StatisticsService statisticsService;

    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @BeforeEach
    void setUp() {
        statisticsService = new StatisticsService(
                statisticsRepository, businessPlaceRepository, reservationRepository, jdbcTemplate);
    }

    @Test
    void getHomeStatistics_사업장이_없으면_예외를_던진다() {
        when(businessPlaceRepository.findById(BUSINESS_PLACE_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> statisticsService.getHomeStatistics(BUSINESS_PLACE_ID))
                .isInstanceOf(RuntimeException.class);
    }

    @Test
    void getHomeStatistics_정상적으로_통계를_집계한다() {
        BusinessPlace businessPlace = BusinessPlace.builder().id(BUSINESS_PLACE_ID).name("테스트 사업장").build();
        when(businessPlaceRepository.findById(BUSINESS_PLACE_ID)).thenReturn(Optional.of(businessPlace));
        when(reservationRepository.countTodayReservations(BUSINESS_PLACE_ID)).thenReturn(3L);
        when(statisticsRepository.getTodayVisitCount(BUSINESS_PLACE_ID)).thenReturn(5);
        when(statisticsRepository.getPendingMemosCount(BUSINESS_PLACE_ID)).thenReturn(2);
        when(statisticsRepository.getTotalMembersCount(BUSINESS_PLACE_ID)).thenReturn(100);

        HomeStatisticsDTO result = statisticsService.getHomeStatistics(BUSINESS_PLACE_ID);

        assertThat(result.getBusinessPlaceName()).isEqualTo("테스트 사업장");
        assertThat(result.getTodayReservations()).isEqualTo(3);
        assertThat(result.getTodayVisits()).isEqualTo(5);
        assertThat(result.getPendingMemos()).isEqualTo(2);
        assertThat(result.getTotalMembers()).isEqualTo(100);
    }

    @Test
    void getHomeStatistics_값이_null이면_0으로_대체한다() {
        BusinessPlace businessPlace = BusinessPlace.builder().id(BUSINESS_PLACE_ID).name("테스트 사업장").build();
        when(businessPlaceRepository.findById(BUSINESS_PLACE_ID)).thenReturn(Optional.of(businessPlace));
        when(reservationRepository.countTodayReservations(BUSINESS_PLACE_ID)).thenReturn(null);
        when(statisticsRepository.getTodayVisitCount(BUSINESS_PLACE_ID)).thenReturn(null);
        when(statisticsRepository.getPendingMemosCount(BUSINESS_PLACE_ID)).thenReturn(null);
        when(statisticsRepository.getTotalMembersCount(BUSINESS_PLACE_ID)).thenReturn(null);

        HomeStatisticsDTO result = statisticsService.getHomeStatistics(BUSINESS_PLACE_ID);

        assertThat(result.getTodayReservations()).isEqualTo(0);
        assertThat(result.getTodayVisits()).isEqualTo(0);
        assertThat(result.getPendingMemos()).isEqualTo(0);
        assertThat(result.getTotalMembers()).isEqualTo(0);
    }

    @SuppressWarnings("unchecked")
    @Test
    void getRecentActivities_limit이_없으면_기본값_10을_사용한다() {
        List<RecentActivityDTO> activities = List.of(
                RecentActivityDTO.builder().activityId("1").activityType("MEMO").build());
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), eq(BUSINESS_PLACE_ID), eq(10)))
                .thenReturn(activities);

        List<RecentActivityDTO> result = statisticsService.getRecentActivities(BUSINESS_PLACE_ID, null);

        assertThat(result).hasSize(1);
    }

    @SuppressWarnings("unchecked")
    @Test
    void getRecentActivities_limit이_지정되면_해당값을_사용한다() {
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), eq(BUSINESS_PLACE_ID), eq(5)))
                .thenReturn(Collections.emptyList());

        List<RecentActivityDTO> result = statisticsService.getRecentActivities(BUSINESS_PLACE_ID, 5);

        assertThat(result).isEmpty();
    }

    @Test
    void getTodaySchedule_PENDING과_CONFIRMED만_필터링한다() {
        Reservation pending = Reservation.builder()
                .id(UUID.randomUUID())
                .memberId(UUID.randomUUID())
                .reservationTime(LocalTime.of(10, 0))
                .status(Reservation.ReservationStatus.PENDING)
                .build();
        Reservation cancelled = Reservation.builder()
                .id(UUID.randomUUID())
                .memberId(UUID.randomUUID())
                .reservationTime(LocalTime.of(11, 0))
                .status(Reservation.ReservationStatus.CANCELLED)
                .build();
        when(reservationRepository.findByBusinessPlaceIdAndReservationDateWithMember(eq(BUSINESS_PLACE_ID), any(LocalDate.class)))
                .thenReturn(List.of(pending, cancelled));

        List<TodayScheduleDTO> result = statisticsService.getTodaySchedule(BUSINESS_PLACE_ID, null);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getStatus()).isEqualTo(Reservation.ReservationStatus.PENDING);
        assertThat(result.get(0).getMemberName()).isEqualTo("알 수 없음");
    }

    @SuppressWarnings("unchecked")
    @Test
    void getMemberRegistrationTrend_빈_날짜를_0으로_채운다() {
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), eq(BUSINESS_PLACE_ID), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(Collections.emptyList());

        ChartDataDTO.MemberRegistrationTrendDTO result =
                statisticsService.getMemberRegistrationTrend(BUSINESS_PLACE_ID, 3);

        assertThat(result.getDataPoints()).hasSize(3);
        assertThat(result.getTotalNewMembers()).isEqualTo(0);
    }

    @Test
    void getMemberGradeDistribution_모든_등급을_포함한다() {
        List<Map<String, Object>> rows = List.of(Map.of("grade", "VIP", "count", 5));
        when(jdbcTemplate.queryForList(anyString(), eq(BUSINESS_PLACE_ID))).thenReturn(rows);

        ChartDataDTO.MemberGradeDistributionDTO result =
                statisticsService.getMemberGradeDistribution(BUSINESS_PLACE_ID);

        assertThat(result.getTotalMembers()).isEqualTo(5);
        assertThat(result.getDistribution()).containsEntry("VIP", 5).containsEntry("GENERAL", 0);
    }

    @SuppressWarnings("unchecked")
    @Test
    void getReservationTrend_빈_날짜를_0으로_채운다() {
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), eq(BUSINESS_PLACE_ID), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(Collections.emptyList());

        ChartDataDTO.ReservationTrendDTO result = statisticsService.getReservationTrend(BUSINESS_PLACE_ID, 2);

        assertThat(result.getDataPoints()).hasSize(2);
        assertThat(result.getTotalReservations()).isEqualTo(0);
    }

    @SuppressWarnings("unchecked")
    @Test
    void getMemoStatistics_통계값을_모두_집계한다() {
        when(jdbcTemplate.queryForObject(anyString(), eq(Integer.class), eq(BUSINESS_PLACE_ID)))
                .thenReturn(10, 3, 2);
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), eq(BUSINESS_PLACE_ID), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(Collections.emptyList());

        ChartDataDTO.MemoStatisticsDTO result = statisticsService.getMemoStatistics(BUSINESS_PLACE_ID, 3);

        assertThat(result.getTotalMemos()).isEqualTo(10);
        assertThat(result.getImportantMemos()).isEqualTo(3);
        assertThat(result.getArchivedMemos()).isEqualTo(2);
        assertThat(result.getDailyMemos()).hasSize(3);
    }
}
