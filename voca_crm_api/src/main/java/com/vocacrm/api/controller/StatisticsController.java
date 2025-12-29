package com.vocacrm.api.controller;

import com.vocacrm.api.dto.ChartDataDTO;
import com.vocacrm.api.dto.HomeStatisticsDTO;
import com.vocacrm.api.dto.RecentActivityDTO;
import com.vocacrm.api.dto.TodayScheduleDTO;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.StatisticsService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/statistics")
@RequiredArgsConstructor
public class StatisticsController {

    private final StatisticsService statisticsService;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;

    /**
     * 사업장 접근 권한 검증
     */
    private void validateUserAccessToBusinessPlace(String userId, String businessPlaceId) {
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }
    }

    @GetMapping("/home/{businessPlaceId}")
    public ResponseEntity<HomeStatisticsDTO> getHomeStatistics(
            @PathVariable String businessPlaceId,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        HomeStatisticsDTO statistics = statisticsService.getHomeStatistics(businessPlaceId);
        return ResponseEntity.ok(statistics);
    }

    @GetMapping("/recent-activities/{businessPlaceId}")
    public ResponseEntity<List<RecentActivityDTO>> getRecentActivities(
            @PathVariable String businessPlaceId,
            @RequestParam(required = false, defaultValue = "10") Integer limit,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        List<RecentActivityDTO> activities = statisticsService.getRecentActivities(businessPlaceId, limit);
        return ResponseEntity.ok(activities);
    }

    /**
     * 오늘의 예약 일정 조회
     * GET /api/statistics/today-schedule/{businessPlaceId}?limit=10
     */
    @GetMapping("/today-schedule/{businessPlaceId}")
    public ResponseEntity<List<TodayScheduleDTO>> getTodaySchedule(
            @PathVariable String businessPlaceId,
            @RequestParam(required = false, defaultValue = "10") Integer limit,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        List<TodayScheduleDTO> schedule = statisticsService.getTodaySchedule(businessPlaceId, limit);
        return ResponseEntity.ok(schedule);
    }

    /**
     * 회원 등록 추이 조회
     * GET /api/statistics/member-registration-trend/{businessPlaceId}?days=7
     */
    @GetMapping("/member-registration-trend/{businessPlaceId}")
    public ResponseEntity<ChartDataDTO.MemberRegistrationTrendDTO> getMemberRegistrationTrend(
            @PathVariable String businessPlaceId,
            @RequestParam(required = false, defaultValue = "7") Integer days,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        ChartDataDTO.MemberRegistrationTrendDTO trend =
                statisticsService.getMemberRegistrationTrend(businessPlaceId, days);
        return ResponseEntity.ok(trend);
    }

    /**
     * 회원 등급별 분포 조회
     * GET /api/statistics/member-grade-distribution/{businessPlaceId}
     */
    @GetMapping("/member-grade-distribution/{businessPlaceId}")
    public ResponseEntity<ChartDataDTO.MemberGradeDistributionDTO> getMemberGradeDistribution(
            @PathVariable String businessPlaceId,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        ChartDataDTO.MemberGradeDistributionDTO distribution =
                statisticsService.getMemberGradeDistribution(businessPlaceId);
        return ResponseEntity.ok(distribution);
    }

    /**
     * 예약 추이 조회
     * GET /api/statistics/reservation-trend/{businessPlaceId}?days=7
     */
    @GetMapping("/reservation-trend/{businessPlaceId}")
    public ResponseEntity<ChartDataDTO.ReservationTrendDTO> getReservationTrend(
            @PathVariable String businessPlaceId,
            @RequestParam(required = false, defaultValue = "7") Integer days,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        ChartDataDTO.ReservationTrendDTO trend =
                statisticsService.getReservationTrend(businessPlaceId, days);
        return ResponseEntity.ok(trend);
    }

    /**
     * 메모 작성 통계 조회
     * GET /api/statistics/memo-statistics/{businessPlaceId}?days=7
     */
    @GetMapping("/memo-statistics/{businessPlaceId}")
    public ResponseEntity<ChartDataDTO.MemoStatisticsDTO> getMemoStatistics(
            @PathVariable String businessPlaceId,
            @RequestParam(required = false, defaultValue = "7") Integer days,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        ChartDataDTO.MemoStatisticsDTO statistics =
                statisticsService.getMemoStatistics(businessPlaceId, days);
        return ResponseEntity.ok(statistics);
    }
}
