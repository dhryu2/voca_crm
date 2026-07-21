package com.vocacrm.api.config;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class RateLimitConfigTest {

    @Test
    void 기본값이_설계된대로_설정된다() {
        RateLimitConfig config = new RateLimitConfig();

        assertThat(config.isEnabled()).isTrue();
        assertThat(config.getAuth().getRequests()).isEqualTo(10);
        assertThat(config.getAuth().getPeriodSeconds()).isEqualTo(60);
        assertThat(config.getApi().getRequests()).isEqualTo(60);
        assertThat(config.getSearch().getRequests()).isEqualTo(30);
        assertThat(config.getVoiceAi().getRequests()).isEqualTo(5);
        assertThat(config.getVoice().getRequests()).isEqualTo(30);
        assertThat(config.getErrorLog().getRequests()).isEqualTo(10);
    }

    @Test
    void EndpointLimit_기본생성자는_60초당60회이다() {
        RateLimitConfig.EndpointLimit limit = new RateLimitConfig.EndpointLimit();

        assertThat(limit.getRequests()).isEqualTo(60);
        assertThat(limit.getPeriodSeconds()).isEqualTo(60);
    }

    @Test
    void EndpointLimit_인자생성자는_전달값을설정한다() {
        RateLimitConfig.EndpointLimit limit = new RateLimitConfig.EndpointLimit(15, 120);

        assertThat(limit.getRequests()).isEqualTo(15);
        assertThat(limit.getPeriodSeconds()).isEqualTo(120);
    }

    @Test
    void 값을_변경하면_반영된다() {
        RateLimitConfig config = new RateLimitConfig();
        config.setEnabled(false);
        config.setApi(new RateLimitConfig.EndpointLimit(100, 30));

        assertThat(config.isEnabled()).isFalse();
        assertThat(config.getApi().getRequests()).isEqualTo(100);
        assertThat(config.getApi().getPeriodSeconds()).isEqualTo(30);
    }
}
