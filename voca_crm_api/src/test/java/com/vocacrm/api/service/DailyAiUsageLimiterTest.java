package com.vocacrm.api.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DailyAiUsageLimiterTest {

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    private DailyAiUsageLimiter limiter;

    @BeforeEach
    void setUp() {
        limiter = new DailyAiUsageLimiter(redisTemplate);
        ReflectionTestUtils.setField(limiter, "enabled", true);
        ReflectionTestUtils.setField(limiter, "maxDailyRequests", 500);
    }

    @Test
    void tryConsume_비활성화_상태면_Redis_호출없이_true를_반환한다() {
        ReflectionTestUtils.setField(limiter, "enabled", false);

        boolean result = limiter.tryConsume();

        assertThat(result).isTrue();
        verify(redisTemplate, never()).opsForValue();
    }

    @Test
    void tryConsume_한도_미만이면_카운트를_증가시키고_true를_반환한다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn("10");
        when(valueOperations.increment(anyString())).thenReturn(11L);

        boolean result = limiter.tryConsume();

        assertThat(result).isTrue();
        verify(redisTemplate, never()).expire(anyString(), any(Duration.class));
    }

    @Test
    void tryConsume_첫_요청이면_자정까지의_TTL을_설정한다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn(null);
        when(valueOperations.increment(anyString())).thenReturn(1L);

        boolean result = limiter.tryConsume();

        assertThat(result).isTrue();
        verify(redisTemplate).expire(anyString(), any(Duration.class));
    }

    @Test
    void tryConsume_한도_초과면_false를_반환하고_카운트를_증가시키지_않는다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn("500");

        boolean result = limiter.tryConsume();

        assertThat(result).isFalse();
        verify(valueOperations, never()).increment(anyString());
    }

    @Test
    void tryConsume_Redis_오류시_가용성을_위해_true를_반환한다() {
        when(redisTemplate.opsForValue()).thenThrow(new RuntimeException("connection refused"));

        boolean result = limiter.tryConsume();

        assertThat(result).isTrue();
    }

    @Test
    void getCurrentUsage_정상_케이스면_현재값을_반환한다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn("42");

        assertThat(limiter.getCurrentUsage()).isEqualTo(42L);
    }

    @Test
    void getCurrentUsage_값이_없으면_0을_반환한다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn(null);

        assertThat(limiter.getCurrentUsage()).isEqualTo(0L);
    }

    @Test
    void getCurrentUsage_Redis_오류시_0을_반환한다() {
        when(redisTemplate.opsForValue()).thenThrow(new RuntimeException("connection refused"));

        assertThat(limiter.getCurrentUsage()).isEqualTo(0L);
    }

    @Test
    void getRemainingRequests_남은_요청수를_계산한다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn("450");

        assertThat(limiter.getRemainingRequests()).isEqualTo(50L);
    }

    @Test
    void getRemainingRequests_초과된_경우_음수대신_0을_반환한다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn("600");

        assertThat(limiter.getRemainingRequests()).isEqualTo(0L);
    }

    @Test
    void isLimitExceeded_비활성화_상태면_항상_false를_반환한다() {
        ReflectionTestUtils.setField(limiter, "enabled", false);

        assertThat(limiter.isLimitExceeded()).isFalse();
    }

    @Test
    void isLimitExceeded_한도_도달시_true를_반환한다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn("500");

        assertThat(limiter.isLimitExceeded()).isTrue();
    }

    @Test
    void isLimitExceeded_한도_미만이면_false를_반환한다() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(anyString())).thenReturn("10");

        assertThat(limiter.isLimitExceeded()).isFalse();
    }

    @Test
    void getMaxDailyRequests_설정값을_반환한다() {
        assertThat(limiter.getMaxDailyRequests()).isEqualTo(500);
    }

    @Test
    void isEnabled_설정값을_반환한다() {
        assertThat(limiter.isEnabled()).isTrue();
    }
}
