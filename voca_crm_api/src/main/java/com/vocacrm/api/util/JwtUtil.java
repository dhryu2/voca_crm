package com.vocacrm.api.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.function.Function;

@Component
public class JwtUtil {

    private static final Logger log = LoggerFactory.getLogger(JwtUtil.class);

    /**
     * HMAC-SHA256 알고리즘에 필요한 최소 키 길이 (256비트 = 32바이트)
     */
    private static final int MIN_SECRET_LENGTH = 32;

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.access-token-validity}")
    private Long accessTokenValidity;

    @Value("${jwt.refresh-token-validity}")
    private Long refreshTokenValidity;

    /**
     * 애플리케이션 시작 시 JWT Secret 길이 검증
     * HMAC-SHA256은 최소 256비트(32바이트) 키가 필요합니다.
     */
    @PostConstruct
    public void validateSecretKey() {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException(
                "JWT Secret이 설정되지 않았습니다. JWT_SECRET 환경변수를 설정해주세요.");
        }

        int secretLength = secret.getBytes(StandardCharsets.UTF_8).length;
        if (secretLength < MIN_SECRET_LENGTH) {
            throw new IllegalStateException(
                String.format("JWT Secret 길이가 너무 짧습니다. 현재: %d바이트, 최소: %d바이트 (HMAC-SHA256 요구사항)",
                    secretLength, MIN_SECRET_LENGTH));
        }

        log.info("JWT Secret 검증 완료: {}바이트 (최소 요구사항 충족)", secretLength);
    }

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String generateAccessToken(
            String userId,
            String username,
            String phone,
            String email,
            String defaultBusinessPlaceId,
            boolean isSystemAdmin
    ) {
        return generateToken(
                userId,
                username,
                phone,
                email,
                defaultBusinessPlaceId,
                isSystemAdmin,
                accessTokenValidity
        );
    }

    public String generateRefreshToken(String userId, String username) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + refreshTokenValidity);

        return Jwts.builder()
                .subject(userId)
                .claim("username", username)
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(getSigningKey())
                .compact();
    }

    private String generateToken(
            String userId,
            String username,
            String phone,
            String email,
            String defaultBusinessPlaceId,
            boolean isSystemAdmin,
            Long validity
    ) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + validity);

        return Jwts.builder()
                .subject(userId)
                .claim("username", username)
                .claim("email", email)
                .claim("phone", phone)
                .claim("defaultBusinessPlaceId", defaultBusinessPlaceId)
                .claim("isSystemAdmin", isSystemAdmin)
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(getSigningKey())
                .compact();
    }

    public String extractUserId(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public String extractUsername(String token) {
        return extractClaim(token, claims -> claims.get("username", String.class));
    }

    public String extractEmail(String token) {
        return extractClaim(token, claims -> claims.get("email", String.class));
    }

    public String extractDefaultBusinessPlaceId(String token) {
        return extractClaim(token, claims -> claims.get("defaultBusinessPlaceId", String.class));
    }

    public Boolean extractIsSystemAdmin(String token) {
        return extractClaim(token, claims -> claims.get("isSystemAdmin", Boolean.class));
    }

    public Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }

    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private Boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }

    public Boolean validateToken(String token, String userId) {
        final String tokenUserId = extractUserId(token);
        return (tokenUserId.equals(userId) && !isTokenExpired(token));
    }

    public Boolean validateToken(String token) {
        try {
            return !isTokenExpired(token);
        } catch (Exception e) {
            return false;
        }
    }
}
