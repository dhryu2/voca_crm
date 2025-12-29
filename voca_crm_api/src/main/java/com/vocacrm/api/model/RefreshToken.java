package com.vocacrm.api.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.redis.core.RedisHash;
import org.springframework.data.redis.core.TimeToLive;
import org.springframework.data.redis.core.index.Indexed;

import java.io.Serializable;
import java.time.Instant;
import java.util.concurrent.TimeUnit;

/**
 * Refresh Token 엔티티 (Redis 저장용)
 *
 * Rotation + Sliding Expiration 지원:
 * - Rotation: 사용 시 새 토큰 발급, 기존 토큰 무효화
 * - Sliding: 사용 시 lastUsedAt 갱신, TTL 연장
 * - Absolute: absoluteExpiryAt 이후에는 무조건 만료
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@RedisHash("refresh_token")
public class RefreshToken implements Serializable {

    private static final long serialVersionUID = 1L;

    /**
     * 토큰 ID (UUID, 클라이언트에 전달되는 값)
     */
    @Id
    private String tokenId;

    /**
     * 사용자 Provider ID (토큰 소유자)
     */
    @Indexed
    private String userId;

    /**
     * 토큰 생성 시각
     */
    private Instant createdAt;

    /**
     * 마지막 사용 시각 (Sliding Expiration용)
     */
    private Instant lastUsedAt;

    /**
     * 절대 만료 시각 (이 시점 이후에는 Sliding과 무관하게 만료)
     */
    private Instant absoluteExpiryAt;

    /**
     * 비활성 만료 시간 (초 단위, Sliding Expiration)
     * 마지막 사용 후 이 시간이 지나면 만료
     */
    private long inactivityExpirySeconds;

    /**
     * 토큰 폐기 여부 (Rotation 시 이전 토큰 폐기)
     */
    private boolean revoked;

    /**
     * 이 토큰을 대체한 새 토큰 ID (Rotation 추적용)
     */
    private String replacedByTokenId;

    /**
     * 디바이스 정보 (선택적)
     */
    private String deviceInfo;

    /**
     * IP 주소 (선택적)
     */
    private String ipAddress;

    /**
     * Redis TTL (초 단위)
     * Sliding Expiration에 따라 동적으로 설정됨
     */
    @TimeToLive(unit = TimeUnit.SECONDS)
    private Long ttl;

    /**
     * 토큰이 유효한지 확인
     */
    public boolean isValid() {
        if (revoked) {
            return false;
        }

        Instant now = Instant.now();

        // 절대 만료 체크
        if (absoluteExpiryAt != null && now.isAfter(absoluteExpiryAt)) {
            return false;
        }

        // 비활성 만료 체크 (Sliding)
        if (lastUsedAt != null && inactivityExpirySeconds > 0) {
            Instant inactivityExpiry = lastUsedAt.plusSeconds(inactivityExpirySeconds);
            if (now.isAfter(inactivityExpiry)) {
                return false;
            }
        }

        return true;
    }

    /**
     * 남은 절대 만료 시간 (초)
     */
    public long getRemainingAbsoluteSeconds() {
        if (absoluteExpiryAt == null) {
            return Long.MAX_VALUE;
        }
        long remaining = absoluteExpiryAt.getEpochSecond() - Instant.now().getEpochSecond();
        return Math.max(0, remaining);
    }

    /**
     * 남은 비활성 만료 시간 (초)
     */
    public long getRemainingInactivitySeconds() {
        if (lastUsedAt == null || inactivityExpirySeconds <= 0) {
            return inactivityExpirySeconds;
        }
        Instant inactivityExpiry = lastUsedAt.plusSeconds(inactivityExpirySeconds);
        long remaining = inactivityExpiry.getEpochSecond() - Instant.now().getEpochSecond();
        return Math.max(0, remaining);
    }

    /**
     * TTL 계산 (절대 만료와 비활성 만료 중 더 짧은 것)
     */
    public long calculateTtl() {
        long absoluteRemaining = getRemainingAbsoluteSeconds();
        long inactivityRemaining = getRemainingInactivitySeconds();
        return Math.min(absoluteRemaining, inactivityRemaining);
    }
}
