package com.vocacrm.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * 차트 데이터 DTO 모음
 */
public class ChartDataDTO {

    /**
     * 시계열 데이터 포인트
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TimeSeriesDataPoint {
        private LocalDate date;
        private Integer count;
    }

    /**
     * 회원 등록 추이 응답
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MemberRegistrationTrendDTO {
        private List<TimeSeriesDataPoint> dataPoints;
        private Integer totalNewMembers;
    }

    /**
     * 회원 등급별 분포 응답
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MemberGradeDistributionDTO {
        private Map<String, Integer> distribution; // grade -> count
        private Integer totalMembers;
    }

    /**
     * 예약 추이 응답
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ReservationTrendDTO {
        private List<TimeSeriesDataPoint> dataPoints;
        private Integer totalReservations;
    }

    /**
     * 메모 작성 통계 응답
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MemoStatisticsDTO {
        private Integer totalMemos;
        private Integer importantMemos;
        private Integer archivedMemos;
        private List<TimeSeriesDataPoint> dailyMemos;
    }
}
