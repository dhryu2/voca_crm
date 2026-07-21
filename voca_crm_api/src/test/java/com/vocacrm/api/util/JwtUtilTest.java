package com.vocacrm.api.util;

import io.jsonwebtoken.ExpiredJwtException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Date;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtUtilTest {

    private JwtUtil jwtUtil;

    @BeforeEach
    void setUp() {
        jwtUtil = new JwtUtil();
        ReflectionTestUtils.setField(jwtUtil, "secret", "test-secret-key-for-jwt-unit-test-1234567890");
        ReflectionTestUtils.setField(jwtUtil, "accessTokenValidity", 3600000L);
        ReflectionTestUtils.setField(jwtUtil, "refreshTokenValidity", 604800000L);
    }

    @Test
    void validateSecretKey_정상_secret이면_예외를_던지지_않는다() {
        jwtUtil.validateSecretKey();
    }

    @Test
    void validateSecretKey_secret이_null이면_예외를_던진다() {
        ReflectionTestUtils.setField(jwtUtil, "secret", null);

        assertThatThrownBy(() -> jwtUtil.validateSecretKey())
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void validateSecretKey_secret이_공백이면_예외를_던진다() {
        ReflectionTestUtils.setField(jwtUtil, "secret", "  ");

        assertThatThrownBy(() -> jwtUtil.validateSecretKey())
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void validateSecretKey_secret이_너무_짧으면_예외를_던진다() {
        ReflectionTestUtils.setField(jwtUtil, "secret", "short");

        assertThatThrownBy(() -> jwtUtil.validateSecretKey())
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void generateAccessToken_토큰을_생성하고_클레임을_추출할_수_있다() {
        String token = jwtUtil.generateAccessToken(
                "user-1", "username1", "010-1234-5678", "test@test.com",
                "홍길동", true, "ABC1234", false
        );

        assertThat(token).isNotBlank();
        assertThat(jwtUtil.extractUserId(token)).isEqualTo("user-1");
        assertThat(jwtUtil.extractUsername(token)).isEqualTo("username1");
        assertThat(jwtUtil.extractEmail(token)).isEqualTo("test@test.com");
        assertThat(jwtUtil.extractDefaultBusinessPlaceId(token)).isEqualTo("ABC1234");
        assertThat(jwtUtil.extractIsSystemAdmin(token)).isFalse();
        assertThat(jwtUtil.extractExpiration(token)).isAfter(new Date());
    }

    @Test
    void generateRefreshToken_토큰을_생성하고_userId를_추출할_수_있다() {
        String token = jwtUtil.generateRefreshToken("user-2", "username2");

        assertThat(token).isNotBlank();
        assertThat(jwtUtil.extractUserId(token)).isEqualTo("user-2");
        assertThat(jwtUtil.extractUsername(token)).isEqualTo("username2");
    }

    @Test
    void validateToken_userId가_일치하고_만료되지_않았으면_true를_반환한다() {
        String token = jwtUtil.generateRefreshToken("user-3", "username3");

        assertThat(jwtUtil.validateToken(token, "user-3")).isTrue();
    }

    @Test
    void validateToken_userId가_불일치하면_false를_반환한다() {
        String token = jwtUtil.generateRefreshToken("user-4", "username4");

        assertThat(jwtUtil.validateToken(token, "other-user")).isFalse();
    }

    @Test
    void validateToken_단일인자_정상토큰이면_true를_반환한다() {
        String token = jwtUtil.generateRefreshToken("user-5", "username5");

        assertThat(jwtUtil.validateToken(token)).isTrue();
    }

    @Test
    void validateToken_단일인자_잘못된토큰이면_false를_반환한다() {
        assertThat(jwtUtil.validateToken("invalid.token.value")).isFalse();
    }

    @Test
    void extractExpiration_만료된_토큰이면_예외를_던진다() {
        ReflectionTestUtils.setField(jwtUtil, "accessTokenValidity", -1000L);
        String token = jwtUtil.generateAccessToken(
                "user-6", "username6", "010-0000-0000", "expired@test.com",
                "만료", false, "XYZ9999", false
        );

        assertThatThrownBy(() -> jwtUtil.extractExpiration(token))
                .isInstanceOf(ExpiredJwtException.class);
    }
}
