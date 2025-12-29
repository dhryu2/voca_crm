package com.vocacrm.api.util;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 날짜 필터 파싱 유틸리티
 * 자연어 날짜 표현을 LocalDateTime 범위로 변환
 */
public class DateFilterParser {

    /**
     * 날짜 범위 결과
     */
    @Data
    @AllArgsConstructor
    public static class DateRange {
        private LocalDateTime start;
        private LocalDateTime end;
    }

    /**
     * 자연어 날짜 필터를 LocalDateTime 범위로 파싱
     *
     * @param dateFilter 날짜 필터 문자열
     *                   예: "3일 전", "어제", "최근 일주일", "오늘", "1주일 전"
     * @return DateRange (시작일시, 종료일시)
     */
    public static DateRange parse(String dateFilter) {
        if (dateFilter == null || dateFilter.trim().isEmpty()) {
            return null;
        }

        String normalized = dateFilter.trim().toLowerCase();

        // "오늘" 처리
        if (normalized.contains("오늘")) {
            LocalDate today = LocalDate.now();
            return new DateRange(
                    today.atStartOfDay(),
                    today.atTime(LocalTime.MAX)
            );
        }

        // "어제" 처리
        if (normalized.contains("어제")) {
            LocalDate yesterday = LocalDate.now().minusDays(1);
            return new DateRange(
                    yesterday.atStartOfDay(),
                    yesterday.atTime(LocalTime.MAX)
            );
        }

        // "N일 전" 패턴 처리
        Pattern daysAgoPattern = Pattern.compile("(\\d+)\\s*일\\s*전");
        Matcher daysAgoMatcher = daysAgoPattern.matcher(normalized);
        if (daysAgoMatcher.find()) {
            int days = Integer.parseInt(daysAgoMatcher.group(1));
            LocalDate targetDate = LocalDate.now().minusDays(days);
            return new DateRange(
                    targetDate.atStartOfDay(),
                    targetDate.atTime(LocalTime.MAX)
            );
        }

        // "N주 전" 또는 "N주일 전" 패턴 처리
        Pattern weeksAgoPattern = Pattern.compile("(\\d+)\\s*주(?:일)?\\s*전");
        Matcher weeksAgoMatcher = weeksAgoPattern.matcher(normalized);
        if (weeksAgoMatcher.find()) {
            int weeks = Integer.parseInt(weeksAgoMatcher.group(1));
            LocalDate targetDate = LocalDate.now().minusWeeks(weeks);
            return new DateRange(
                    targetDate.atStartOfDay(),
                    targetDate.atTime(LocalTime.MAX)
            );
        }

        // "N개월 전" 패턴 처리
        Pattern monthsAgoPattern = Pattern.compile("(\\d+)\\s*개월\\s*전");
        Matcher monthsAgoMatcher = monthsAgoPattern.matcher(normalized);
        if (monthsAgoMatcher.find()) {
            int months = Integer.parseInt(monthsAgoMatcher.group(1));
            LocalDate targetDate = LocalDate.now().minusMonths(months);
            return new DateRange(
                    targetDate.atStartOfDay(),
                    targetDate.atTime(LocalTime.MAX)
            );
        }

        // "최근 N일" 패턴 처리
        Pattern recentDaysPattern = Pattern.compile("최근\\s*(\\d+)\\s*일");
        Matcher recentDaysMatcher = recentDaysPattern.matcher(normalized);
        if (recentDaysMatcher.find()) {
            int days = Integer.parseInt(recentDaysMatcher.group(1));
            return new DateRange(
                    LocalDateTime.now().minusDays(days),
                    LocalDateTime.now()
            );
        }

        // "최근 일주일" 또는 "일주일" 처리
        if (normalized.contains("일주일") || normalized.contains("1주")) {
            return new DateRange(
                    LocalDateTime.now().minusWeeks(1),
                    LocalDateTime.now()
            );
        }

        // "이번 주" 처리
        if (normalized.contains("이번") && normalized.contains("주")) {
            LocalDate now = LocalDate.now();
            LocalDate startOfWeek = now.minusDays(now.getDayOfWeek().getValue() - 1);
            return new DateRange(
                    startOfWeek.atStartOfDay(),
                    LocalDateTime.now()
            );
        }

        // "이번 달" 처리
        if (normalized.contains("이번") && normalized.contains("달")) {
            LocalDate now = LocalDate.now();
            LocalDate startOfMonth = now.withDayOfMonth(1);
            return new DateRange(
                    startOfMonth.atStartOfDay(),
                    LocalDateTime.now()
            );
        }

        // 파싱 실패 시 null 반환
        return null;
    }

    /**
     * 특정 날짜만 파싱 (범위가 아닌 단일 날짜)
     */
    public static LocalDate parseSingleDate(String dateFilter) {
        DateRange range = parse(dateFilter);
        if (range != null) {
            return range.getStart().toLocalDate();
        }
        return null;
    }
}
