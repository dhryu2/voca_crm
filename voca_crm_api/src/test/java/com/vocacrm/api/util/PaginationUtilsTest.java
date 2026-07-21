package com.vocacrm.api.util;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class PaginationUtilsTest {

    @Test
    void limitPageSize_음수면_기본값을_반환한다() {
        assertThat(PaginationUtils.limitPageSize(-1)).isEqualTo(PaginationUtils.DEFAULT_PAGE_SIZE);
    }

    @Test
    void limitPageSize_0이면_기본값을_반환한다() {
        assertThat(PaginationUtils.limitPageSize(0)).isEqualTo(PaginationUtils.DEFAULT_PAGE_SIZE);
    }

    @Test
    void limitPageSize_최대값_이하면_그대로_반환한다() {
        assertThat(PaginationUtils.limitPageSize(50)).isEqualTo(50);
    }

    @Test
    void limitPageSize_최대값을_초과하면_최대값으로_제한한다() {
        assertThat(PaginationUtils.limitPageSize(1000)).isEqualTo(PaginationUtils.MAX_PAGE_SIZE);
    }

    @Test
    void validatePage_음수면_0을_반환한다() {
        assertThat(PaginationUtils.validatePage(-5)).isEqualTo(0);
    }

    @Test
    void validatePage_양수면_그대로_반환한다() {
        assertThat(PaginationUtils.validatePage(3)).isEqualTo(3);
    }
}
