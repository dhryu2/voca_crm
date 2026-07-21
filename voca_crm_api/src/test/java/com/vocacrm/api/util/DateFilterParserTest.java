package com.vocacrm.api.util;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalTime;

import static org.assertj.core.api.Assertions.assertThat;

class DateFilterParserTest {

    @Test
    void parse_null이면_null을_반환한다() {
        assertThat(DateFilterParser.parse(null)).isNull();
    }

    @Test
    void parse_빈문자열이면_null을_반환한다() {
        assertThat(DateFilterParser.parse("  ")).isNull();
    }

    @Test
    void parse_오늘을_포함하면_당일_범위를_반환한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("오늘");
        LocalDate today = LocalDate.now();

        assertThat(range.getStart()).isEqualTo(today.atStartOfDay());
        assertThat(range.getEnd()).isEqualTo(today.atTime(LocalTime.MAX));
    }

    @Test
    void parse_어제를_포함하면_전일_범위를_반환한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("어제");
        LocalDate yesterday = LocalDate.now().minusDays(1);

        assertThat(range.getStart()).isEqualTo(yesterday.atStartOfDay());
        assertThat(range.getEnd()).isEqualTo(yesterday.atTime(LocalTime.MAX));
    }

    @Test
    void parse_N일_전_패턴을_처리한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("3일 전");
        LocalDate target = LocalDate.now().minusDays(3);

        assertThat(range.getStart()).isEqualTo(target.atStartOfDay());
        assertThat(range.getEnd()).isEqualTo(target.atTime(LocalTime.MAX));
    }

    @Test
    void parse_N주_전_패턴을_처리한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("2주 전");
        LocalDate target = LocalDate.now().minusWeeks(2);

        assertThat(range.getStart()).isEqualTo(target.atStartOfDay());
        assertThat(range.getEnd()).isEqualTo(target.atTime(LocalTime.MAX));
    }

    @Test
    void parse_N주일_전_패턴을_처리한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("1주일 전");
        LocalDate target = LocalDate.now().minusWeeks(1);

        assertThat(range.getStart()).isEqualTo(target.atStartOfDay());
        assertThat(range.getEnd()).isEqualTo(target.atTime(LocalTime.MAX));
    }

    @Test
    void parse_N개월_전_패턴을_처리한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("1개월 전");
        LocalDate target = LocalDate.now().minusMonths(1);

        assertThat(range.getStart()).isEqualTo(target.atStartOfDay());
        assertThat(range.getEnd()).isEqualTo(target.atTime(LocalTime.MAX));
    }

    @Test
    void parse_최근_N일_패턴을_처리한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("최근 7일");

        assertThat(range.getStart()).isBefore(range.getEnd());
        assertThat(range.getStart()).isBeforeOrEqualTo(java.time.LocalDateTime.now().minusDays(6));
    }

    @Test
    void parse_일주일을_포함하면_1주_범위를_반환한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("최근 일주일");

        assertThat(range.getStart()).isBefore(range.getEnd());
    }

    @Test
    void parse_1주를_포함해도_범위를_반환한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("1주");

        assertThat(range).isNotNull();
    }

    @Test
    void parse_이번_주를_포함하면_이번주_시작일부터_반환한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("이번 주");
        LocalDate now = LocalDate.now();
        LocalDate startOfWeek = now.minusDays(now.getDayOfWeek().getValue() - 1);

        assertThat(range.getStart()).isEqualTo(startOfWeek.atStartOfDay());
    }

    @Test
    void parse_이번_달을_포함하면_이번달_1일부터_반환한다() {
        DateFilterParser.DateRange range = DateFilterParser.parse("이번 달");
        LocalDate startOfMonth = LocalDate.now().withDayOfMonth(1);

        assertThat(range.getStart()).isEqualTo(startOfMonth.atStartOfDay());
    }

    @Test
    void parse_알수없는_문자열이면_null을_반환한다() {
        assertThat(DateFilterParser.parse("전혀_알수없는_문자열")).isNull();
    }

    @Test
    void parseSingleDate_유효한_필터면_날짜를_반환한다() {
        LocalDate result = DateFilterParser.parseSingleDate("오늘");

        assertThat(result).isEqualTo(LocalDate.now());
    }

    @Test
    void parseSingleDate_파싱_실패시_null을_반환한다() {
        assertThat(DateFilterParser.parseSingleDate("알수없음")).isNull();
    }
}
