package com.vocacrm.api.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;

/**
 * AI 분석 일일 사용량 제한 서비스
 *
 * DeepL API 월 50만자 제한을 고려하여 일일 AI 분석 호출 수를 제한합니다.
 * Redis를 사용하여 서버 재시작 및 다중 서버 환경에서도 정확한 카운트를 유지합니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DailyAiUsageLimiter {

    private final StringRedisTemplate redisTemplate;

    private static final String KEY_PREFIX = "ai:daily:";
    private static final ZoneId ZONE_ID = ZoneId.of("Asia/Seoul");

    @Value("${ai.daily-limit.enabled:true}")
    private boolean enabled;

    @Value("${ai.daily-limit.max-requests:500}")
    private int maxDailyRequests;

    /**
     * AI 분석 요청이 허용되는지 확인하고, 허용되면 카운트 증가
     *
     * @return true면 요청 허용, false면 일일 한도 초과
     */
    public boolean tryConsume() {
        if (!enabled) {
            return true;
        }

        String key = getDailyKey();

        try {
            // 현재 카운트 조회
            String currentValue = redisTemplate.opsForValue().get(key);
            long currentCount = currentValue != null ? Long.parseLong(currentValue) : 0;

            if (currentCount >= maxDailyRequests) {
                log.warn("Daily AI usage limit exceeded. Current: {}, Max: {}", currentCount, maxDailyRequests);
                return false;
            }

            // 카운트 증가 (원자적 연산)
            Long newCount = redisTemplate.opsForValue().increment(key);

            // 첫 번째 요청인 경우 TTL 설정 (자정까지)
            if (newCount != null && newCount == 1) {
                Duration ttl = getTimeUntilMidnight();
                redisTemplate.expire(key, ttl);
                log.debug("Daily AI usage key created with TTL: {} seconds", ttl.getSeconds());
            }

            log.debug("Daily AI usage: {}/{}", newCount, maxDailyRequests);
            return true;

        } catch (Exception e) {
            log.error("Error checking daily AI usage limit: {}", e.getMessage());
            // Redis 오류 시 요청 허용 (서비스 가용성 우선)
            return true;
        }
    }

    /**
     * 현재 일일 사용량 조회
     */
    public long getCurrentUsage() {
        try {
            String key = getDailyKey();
            String value = redisTemplate.opsForValue().get(key);
            return value != null ? Long.parseLong(value) : 0;
        } catch (Exception e) {
            log.error("Error getting current AI usage: {}", e.getMessage());
            return 0;
        }
    }

    /**
     * 남은 일일 요청 수 조회
     */
    public long getRemainingRequests() {
        long current = getCurrentUsage();
        return Math.max(0, maxDailyRequests - current);
    }

    /**
     * 일일 한도 초과 여부 확인 (카운트 증가 없이)
     */
    public boolean isLimitExceeded() {
        if (!enabled) {
            return false;
        }
        return getCurrentUsage() >= maxDailyRequests;
    }

    /**
     * 일일 최대 요청 수 반환
     */
    public int getMaxDailyRequests() {
        return maxDailyRequests;
    }

    /**
     * 제한 기능 활성화 여부
     */
    public boolean isEnabled() {
        return enabled;
    }

    /**
     * 오늘 날짜 기반 Redis 키 생성
     */
    private String getDailyKey() {
        LocalDate today = LocalDate.now(ZONE_ID);
        return KEY_PREFIX + today.toString(); // ai:daily:2025-01-15
    }

    /**
     * 자정까지 남은 시간 계산
     */
    private Duration getTimeUntilMidnight() {
        LocalDateTime now = LocalDateTime.now(ZONE_ID);
        LocalDateTime midnight = LocalDateTime.of(now.toLocalDate().plusDays(1), LocalTime.MIDNIGHT);
        return Duration.between(now, midnight);
    }
}
