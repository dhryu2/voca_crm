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
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StatisticsService {

    private final StatisticsRepository statisticsRepository;
    private final BusinessPlaceRepository businessPlaceRepository;
    private final ReservationRepository reservationRepository;
    private final JdbcTemplate jdbcTemplate;

    public HomeStatisticsDTO getHomeStatistics(String businessPlaceId) {
        BusinessPlace businessPlace = businessPlaceRepository.findById(businessPlaceId)
                .orElseThrow(() -> new RuntimeException("Business place not found"));

        Long todayReservations = reservationRepository.countTodayReservations(businessPlaceId);
        Integer todayVisits = statisticsRepository.getTodayVisitCount(businessPlaceId);
        Integer pendingMemos = statisticsRepository.getPendingMemosCount(businessPlaceId);
        Integer totalMembers = statisticsRepository.getTotalMembersCount(businessPlaceId);

        return HomeStatisticsDTO.builder()
                .businessPlaceId(businessPlaceId)
                .businessPlaceName(businessPlace.getName())
                .todayReservations(todayReservations != null ? todayReservations.intValue() : 0)
                .todayVisits(todayVisits != null ? todayVisits : 0)
                .pendingMemos(pendingMemos != null ? pendingMemos : 0)
                .totalMembers(totalMembers != null ? totalMembers : 0)
                .build();
    }

    public List<RecentActivityDTO> getRecentActivities(String businessPlaceId, Integer limit) {
        if (limit == null || limit <= 0) {
            limit = 10;
        }

        String sql = "SELECT * FROM get_recent_activities(?, ?)";

        return jdbcTemplate.query(sql,
                (rs, rowNum) -> RecentActivityDTO.builder()
                        .activityId(rs.getString("activity_id"))
                        .activityType(rs.getString("activity_type"))
                        .memberId(rs.getString("member_id"))
                        .memberName(rs.getString("member_name"))
                        .content(rs.getString("content"))
                        .activityTime(rs.getTimestamp("activity_time").toLocalDateTime())
                        .build(),
                businessPlaceId, limit);
    }

    /**
     * 오늘의 예약 일정 조회
     */
    public List<TodayScheduleDTO> getTodaySchedule(String businessPlaceId, Integer limit) {
        if (limit == null || limit <= 0) {
            limit = 10;
        }

        LocalDate today = LocalDate.now();
        List<Reservation> reservations = reservationRepository
                .findByBusinessPlaceIdAndReservationDateOrderByReservationTimeAsc(businessPlaceId, today);

        // PENDING, CONFIRMED 상태만 필터링하고 limit 적용
        final int finalLimit = limit;
        return reservations.stream()
                .filter(r -> r.getStatus() == Reservation.ReservationStatus.PENDING ||
                             r.getStatus() == Reservation.ReservationStatus.CONFIRMED)
                .limit(finalLimit)
                .map(r -> TodayScheduleDTO.builder()
                        .reservationId(r.getId())
                        .memberId(r.getMemberId())
                        .memberName(r.getMember() != null ? r.getMember().getName() : "알 수 없음")
                        .reservationTime(r.getReservationTime())
                        .serviceType(r.getServiceType())
                        .durationMinutes(r.getDurationMinutes())
                        .status(r.getStatus())
                        .notes(r.getNotes())
                        .build())
                .collect(Collectors.toList());
    }

    /**
     * 회원 등록 추이 조회
     */
    public ChartDataDTO.MemberRegistrationTrendDTO getMemberRegistrationTrend(
            String businessPlaceId, Integer days) {
        if (days == null || days <= 0) {
            days = 7;
        }

        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(days - 1);

        String sql = "SELECT DATE(created_at) as date, COUNT(*) as count " +
                     "FROM members " +
                     "WHERE business_place_id = ? " +
                     "AND DATE(created_at) BETWEEN ? AND ? " +
                     "GROUP BY DATE(created_at) " +
                     "ORDER BY date";

        List<ChartDataDTO.TimeSeriesDataPoint> dataPoints = jdbcTemplate.query(sql,
                (rs, rowNum) -> ChartDataDTO.TimeSeriesDataPoint.builder()
                        .date(rs.getDate("date").toLocalDate())
                        .count(rs.getInt("count"))
                        .build(),
                businessPlaceId, startDate, endDate);

        // Fill missing dates with 0
        List<ChartDataDTO.TimeSeriesDataPoint> filledDataPoints = new ArrayList<>();
        Map<LocalDate, Integer> dataMap = new HashMap<>();
        for (ChartDataDTO.TimeSeriesDataPoint point : dataPoints) {
            dataMap.put(point.getDate(), point.getCount());
        }

        int totalNewMembers = 0;
        for (LocalDate date = startDate; !date.isAfter(endDate); date = date.plusDays(1)) {
            int count = dataMap.getOrDefault(date, 0);
            totalNewMembers += count;
            filledDataPoints.add(ChartDataDTO.TimeSeriesDataPoint.builder()
                    .date(date)
                    .count(count)
                    .build());
        }

        return ChartDataDTO.MemberRegistrationTrendDTO.builder()
                .dataPoints(filledDataPoints)
                .totalNewMembers(totalNewMembers)
                .build();
    }

    /**
     * 회원 등급별 분포 조회
     */
    public ChartDataDTO.MemberGradeDistributionDTO getMemberGradeDistribution(
            String businessPlaceId) {
        String sql = "SELECT grade, COUNT(*) as count " +
                     "FROM members " +
                     "WHERE business_place_id = ? " +
                     "AND grade IS NOT NULL " +
                     "GROUP BY grade";

        List<Map<String, Object>> results = jdbcTemplate.queryForList(sql, businessPlaceId);

        Map<String, Integer> distribution = new HashMap<>();
        int totalMembers = 0;

        for (Map<String, Object> row : results) {
            String grade = (String) row.get("grade");
            Integer count = ((Number) row.get("count")).intValue();
            distribution.put(grade, count);
            totalMembers += count;
        }

        // Ensure all grades are present
        for (String grade : new String[]{"VIP", "GOLD", "SILVER", "BRONZE", "GENERAL"}) {
            distribution.putIfAbsent(grade, 0);
        }

        return ChartDataDTO.MemberGradeDistributionDTO.builder()
                .distribution(distribution)
                .totalMembers(totalMembers)
                .build();
    }

    /**
     * 예약 추이 조회
     */
    public ChartDataDTO.ReservationTrendDTO getReservationTrend(
            String businessPlaceId, Integer days) {
        if (days == null || days <= 0) {
            days = 7;
        }

        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(days - 1);

        String sql = "SELECT reservation_date as date, COUNT(*) as count " +
                     "FROM reservations " +
                     "WHERE business_place_id = ? " +
                     "AND reservation_date BETWEEN ? AND ? " +
                     "GROUP BY reservation_date " +
                     "ORDER BY reservation_date";

        List<ChartDataDTO.TimeSeriesDataPoint> dataPoints = jdbcTemplate.query(sql,
                (rs, rowNum) -> ChartDataDTO.TimeSeriesDataPoint.builder()
                        .date(rs.getDate("date").toLocalDate())
                        .count(rs.getInt("count"))
                        .build(),
                businessPlaceId, startDate, endDate);

        // Fill missing dates with 0
        List<ChartDataDTO.TimeSeriesDataPoint> filledDataPoints = new ArrayList<>();
        Map<LocalDate, Integer> dataMap = new HashMap<>();
        for (ChartDataDTO.TimeSeriesDataPoint point : dataPoints) {
            dataMap.put(point.getDate(), point.getCount());
        }

        int totalReservations = 0;
        for (LocalDate date = startDate; !date.isAfter(endDate); date = date.plusDays(1)) {
            int count = dataMap.getOrDefault(date, 0);
            totalReservations += count;
            filledDataPoints.add(ChartDataDTO.TimeSeriesDataPoint.builder()
                    .date(date)
                    .count(count)
                    .build());
        }

        return ChartDataDTO.ReservationTrendDTO.builder()
                .dataPoints(filledDataPoints)
                .totalReservations(totalReservations)
                .build();
    }

    /**
     * 메모 작성 통계 조회
     */
    public ChartDataDTO.MemoStatisticsDTO getMemoStatistics(
            String businessPlaceId, Integer days) {
        if (days == null || days <= 0) {
            days = 7;
        }

        // 전체 메모 개수
        String totalSql = "SELECT COUNT(*) FROM memos m " +
                          "JOIN members mb ON m.member_id = mb.id " +
                          "WHERE mb.business_place_id = ?";
        Integer totalMemos = jdbcTemplate.queryForObject(totalSql, Integer.class, businessPlaceId);

        // 중요 메모 개수
        String importantSql = "SELECT COUNT(*) FROM memos m " +
                              "JOIN members mb ON m.member_id = mb.id " +
                              "WHERE mb.business_place_id = ? AND m.is_important = true";
        Integer importantMemos = jdbcTemplate.queryForObject(importantSql, Integer.class, businessPlaceId);

        // 아카이브된 메모 개수
        String archivedSql = "SELECT COUNT(*) FROM memos m " +
                             "JOIN members mb ON m.member_id = mb.id " +
                             "WHERE mb.business_place_id = ? AND m.is_archived = true";
        Integer archivedMemos = jdbcTemplate.queryForObject(archivedSql, Integer.class, businessPlaceId);

        // 일별 메모 작성 추이
        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(days - 1);

        String dailySql = "SELECT DATE(m.created_at) as date, COUNT(*) as count " +
                          "FROM memos m " +
                          "JOIN members mb ON m.member_id = mb.id " +
                          "WHERE mb.business_place_id = ? " +
                          "AND DATE(m.created_at) BETWEEN ? AND ? " +
                          "GROUP BY DATE(m.created_at) " +
                          "ORDER BY date";

        List<ChartDataDTO.TimeSeriesDataPoint> dataPoints = jdbcTemplate.query(dailySql,
                (rs, rowNum) -> ChartDataDTO.TimeSeriesDataPoint.builder()
                        .date(rs.getDate("date").toLocalDate())
                        .count(rs.getInt("count"))
                        .build(),
                businessPlaceId, startDate, endDate);

        // Fill missing dates with 0
        List<ChartDataDTO.TimeSeriesDataPoint> filledDataPoints = new ArrayList<>();
        Map<LocalDate, Integer> dataMap = new HashMap<>();
        for (ChartDataDTO.TimeSeriesDataPoint point : dataPoints) {
            dataMap.put(point.getDate(), point.getCount());
        }

        for (LocalDate date = startDate; !date.isAfter(endDate); date = date.plusDays(1)) {
            int count = dataMap.getOrDefault(date, 0);
            filledDataPoints.add(ChartDataDTO.TimeSeriesDataPoint.builder()
                    .date(date)
                    .count(count)
                    .build());
        }

        return ChartDataDTO.MemoStatisticsDTO.builder()
                .totalMemos(totalMemos != null ? totalMemos : 0)
                .importantMemos(importantMemos != null ? importantMemos : 0)
                .archivedMemos(archivedMemos != null ? archivedMemos : 0)
                .dailyMemos(filledDataPoints)
                .build();
    }
}
