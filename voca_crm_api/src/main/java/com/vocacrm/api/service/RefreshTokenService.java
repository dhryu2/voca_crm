package com.vocacrm.api.service;

import com.vocacrm.api.exception.InvalidTokenException;
import com.vocacrm.api.model.RefreshToken;
import com.vocacrm.api.repository.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Refresh Token 서비스
 *
 * Rotation + Sliding Expiration 구현:
 * - Rotation: 토큰 사용 시 새 토큰 발급, 기존 토큰 폐기
 * - Sliding: 토큰 사용 시 비활성 만료 시간 연장
 * - Reuse Detection: 폐기된 토큰 재사용 시 모든 토큰 폐기 (보안)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private final RefreshTokenRepository refreshTokenRepository;

    /**
     * 비활성 만료 시간 (기본 14일)
     */
    @Value("${jwt.refresh-token-inactivity-expiry:1209600}")
    private long inactivityExpirySeconds;

    /**
     * 절대 만료 시간 (기본 90일)
     */
    @Value("${jwt.refresh-token-absolute-expiry:7776000}")
    private long absoluteExpirySeconds;

    /**
     * 사용자당 최대 토큰 수 (디바이스 수 제한)
     */
    @Value("${jwt.max-refresh-tokens-per-user:5}")
    private int maxTokensPerUser;

    /**
     * 새 Refresh Token 생성
     */
    public RefreshToken createRefreshToken(String userId, String deviceInfo, String ipAddress) {
        // 사용자의 기존 토큰 수 확인 및 정리
        cleanupOldTokens(userId);

        Instant now = Instant.now();

        RefreshToken refreshToken = RefreshToken.builder()
                .tokenId(UUID.randomUUID().toString())
                .userId(userId)
                .createdAt(now)
                .lastUsedAt(now)
                .absoluteExpiryAt(now.plusSeconds(absoluteExpirySeconds))
                .inactivityExpirySeconds(inactivityExpirySeconds)
                .revoked(false)
                .deviceInfo(deviceInfo)
                .ipAddress(ipAddress)
                .ttl(calculateInitialTtl())
                .build();

        refreshTokenRepository.save(refreshToken);

        return refreshToken;
    }

    /**
     * Refresh Token 검증 및 Rotation
     *
     * @return 새로 발급된 RefreshToken (Rotation)
     * @throws InvalidTokenException 토큰이 유효하지 않은 경우
     */
    public RefreshToken rotateToken(String tokenId, String deviceInfo, String ipAddress) {
        RefreshToken existingToken = refreshTokenRepository.findByTokenId(tokenId)
                .orElseThrow(() -> {
                    log.warn("Refresh token not found: {}", tokenId);
                    return new InvalidTokenException("유효하지 않은 Refresh Token입니다");
                });

        // 폐기된 토큰 재사용 감지 (보안 위협)
        if (existingToken.isRevoked()) {
            log.warn("Reuse of revoked token detected! tokenId: {}, userId: {}",
                    tokenId, existingToken.getUserId());

            // 보안 조치: 해당 사용자의 모든 토큰 폐기
            revokeAllUserTokens(existingToken.getUserId());

            throw new InvalidTokenException("보안 위협이 감지되었습니다. 다시 로그인해주세요.");
        }

        // 토큰 유효성 검사
        if (!existingToken.isValid()) {
            refreshTokenRepository.delete(existingToken);
            throw new InvalidTokenException("Refresh Token이 만료되었습니다. 다시 로그인해주세요.");
        }

        // 기존 토큰 폐기 (Rotation)
        existingToken.setRevoked(true);
        existingToken.setTtl(3600L); // 1시간 후 Redis에서 삭제 (재사용 감지용)

        // 새 토큰 생성
        Instant now = Instant.now();
        RefreshToken newToken = RefreshToken.builder()
                .tokenId(UUID.randomUUID().toString())
                .userId(existingToken.getUserId())
                .createdAt(now)
                .lastUsedAt(now)
                // 절대 만료는 원본 토큰의 것을 유지 (Sliding은 절대 만료를 연장하지 않음)
                .absoluteExpiryAt(existingToken.getAbsoluteExpiryAt())
                .inactivityExpirySeconds(inactivityExpirySeconds)
                .revoked(false)
                .deviceInfo(deviceInfo != null ? deviceInfo : existingToken.getDeviceInfo())
                .ipAddress(ipAddress != null ? ipAddress : existingToken.getIpAddress())
                .build();

        // TTL 계산 및 설정
        newToken.setTtl(newToken.calculateTtl());

        // 기존 토큰에 대체 토큰 ID 기록
        existingToken.setReplacedByTokenId(newToken.getTokenId());

        // 저장
        refreshTokenRepository.save(existingToken);
        refreshTokenRepository.save(newToken);

        return newToken;
    }

    /**
     * Refresh Token 검증만 (Rotation 없이)
     */
    public RefreshToken validateToken(String tokenId) {
        RefreshToken token = refreshTokenRepository.findByTokenId(tokenId)
                .orElseThrow(() -> new InvalidTokenException("유효하지 않은 Refresh Token입니다"));

        if (token.isRevoked()) {
            throw new InvalidTokenException("폐기된 Refresh Token입니다");
        }

        if (!token.isValid()) {
            throw new InvalidTokenException("Refresh Token이 만료되었습니다");
        }

        return token;
    }

    /**
     * 특정 토큰 폐기
     */
    public void revokeToken(String tokenId) {
        refreshTokenRepository.findByTokenId(tokenId).ifPresent(token -> {
            token.setRevoked(true);
            token.setTtl(3600L); // 1시간 후 삭제
            refreshTokenRepository.save(token);
        });
    }

    /**
     * 사용자의 모든 토큰 폐기 (로그아웃, 보안 위협 감지 시)
     */
    public void revokeAllUserTokens(String userId) {
        List<RefreshToken> tokens = refreshTokenRepository.findByUserId(userId);

        for (RefreshToken token : tokens) {
            token.setRevoked(true);
            token.setTtl(3600L); // 1시간 후 삭제
            refreshTokenRepository.save(token);
        }
    }

    /**
     * 사용자의 모든 토큰 삭제 (계정 삭제 시)
     */
    public void deleteAllUserTokens(String userId) {
        List<RefreshToken> tokens = refreshTokenRepository.findByUserId(userId);
        refreshTokenRepository.deleteAll(tokens);
    }

    /**
     * 사용자의 활성 토큰 목록 조회
     */
    public List<RefreshToken> getActiveTokens(String userId) {
        return refreshTokenRepository.findByUserIdAndRevokedFalse(userId)
                .stream()
                .filter(RefreshToken::isValid)
                .toList();
    }

    /**
     * 오래된 토큰 정리 (사용자당 최대 토큰 수 유지)
     */
    private void cleanupOldTokens(String userId) {
        List<RefreshToken> activeTokens = getActiveTokens(userId);

        if (activeTokens.size() >= maxTokensPerUser) {
            // 가장 오래된 토큰부터 폐기
            activeTokens.stream()
                    .sorted((a, b) -> a.getLastUsedAt().compareTo(b.getLastUsedAt()))
                    .limit(activeTokens.size() - maxTokensPerUser + 1)
                    .forEach(token -> {
                        token.setRevoked(true);
                        token.setTtl(3600L);
                        refreshTokenRepository.save(token);
                    });
        }
    }

    /**
     * 초기 TTL 계산
     */
    private long calculateInitialTtl() {
        // 비활성 만료와 절대 만료 중 더 짧은 것
        return Math.min(inactivityExpirySeconds, absoluteExpirySeconds);
    }

    /**
     * 토큰 사용 기록 업데이트 (Sliding without Rotation - 선택적)
     */
    public void updateLastUsed(String tokenId) {
        refreshTokenRepository.findByTokenId(tokenId).ifPresent(token -> {
            if (!token.isRevoked() && token.isValid()) {
                token.setLastUsedAt(Instant.now());
                token.setTtl(token.calculateTtl());
                refreshTokenRepository.save(token);
            }
        });
    }
}
