package com.vocacrm.api.controller;

import com.vocacrm.api.enums.Provider;
import com.vocacrm.api.exception.DuplicateUserException;
import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.exception.InvalidTokenException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final Map<String, String> TOKENS = Map.of("accessToken", "a", "refreshToken", "b");

    @Mock
    private AuthService authService;
    @Mock
    private HttpServletRequest httpRequest;

    @InjectMocks
    private AuthController authController;

    private AuthController.SocialLoginRequest loginRequest(String provider, String token) {
        AuthController.SocialLoginRequest r = new AuthController.SocialLoginRequest();
        r.setProvider(provider);
        r.setToken(token);
        return r;
    }

    private AuthController.SocialSignupRequest signupRequest() {
        AuthController.SocialSignupRequest r = new AuthController.SocialSignupRequest();
        r.setProvider("google.com");
        r.setToken("tok");
        r.setUsername("홍길동");
        r.setPhone("010-1234-5678");
        r.setEmail("hong@example.com");
        return r;
    }

    private AuthController.RefreshTokenRequest refreshRequest() {
        AuthController.RefreshTokenRequest r = new AuthController.RefreshTokenRequest();
        r.setRefreshToken("refresh-token-id");
        return r;
    }

    private AuthController.LogoutRequest logoutRequest() {
        AuthController.LogoutRequest r = new AuthController.LogoutRequest();
        r.setRefreshToken("refresh-token-id");
        return r;
    }

    // ===== login =====

    @Test
    void login_성공하면_200과_토큰을_반환한다() {
        when(authService.loginWithSocialToken(any(), any(), any(), any())).thenReturn(TOKENS);

        ResponseEntity<?> response = authController.loginWithSocialToken(loginRequest("google.com", "tok"), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isEqualTo(TOKENS);
    }

    @Test
    void login_사용자가_없으면_404를_반환한다() {
        when(authService.loginWithSocialToken(any(), any(), any(), any()))
                .thenThrow(new ResourceNotFoundException("사용자를 찾을 수 없습니다"));

        ResponseEntity<?> response = authController.loginWithSocialToken(loginRequest("google.com", "tok"), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(404);
    }

    @Test
    void login_지원하지_않는_provider면_400을_반환한다() {
        ResponseEntity<?> response = authController.loginWithSocialToken(loginRequest("naver.com", "tok"), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void login_잘못된_입력이면_400을_반환한다() {
        when(authService.loginWithSocialToken(any(), any(), any(), any()))
                .thenThrow(new InvalidInputException("잘못된 토큰"));

        ResponseEntity<?> response = authController.loginWithSocialToken(loginRequest("google.com", "tok"), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void login_예상하지_못한_오류면_500을_반환한다() {
        when(authService.loginWithSocialToken(any(), any(), any(), any()))
                .thenThrow(new RuntimeException("boom"));

        ResponseEntity<?> response = authController.loginWithSocialToken(loginRequest("google.com", "tok"), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(500);
    }

    // ===== signup =====

    @Test
    void signup_성공하면_201과_토큰을_반환한다() {
        when(authService.signupWithSocialToken(any(), any(), any(), any(), any(), any(), any())).thenReturn(TOKENS);

        ResponseEntity<?> response = authController.signupWithSocialToken(signupRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(201);
        assertThat(response.getBody()).isEqualTo(TOKENS);
    }

    @Test
    void signup_이미_존재하는_사용자면_409를_반환한다() {
        when(authService.signupWithSocialToken(any(), any(), any(), any(), any(), any(), any()))
                .thenThrow(new DuplicateUserException("이미 가입된 사용자입니다"));

        ResponseEntity<?> response = authController.signupWithSocialToken(signupRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(409);
    }

    @Test
    void signup_잘못된_입력이면_400을_반환한다() {
        when(authService.signupWithSocialToken(any(), any(), any(), any(), any(), any(), any()))
                .thenThrow(new InvalidInputException("잘못된 입력"));

        ResponseEntity<?> response = authController.signupWithSocialToken(signupRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void signup_예상하지_못한_오류면_500을_반환한다() {
        when(authService.signupWithSocialToken(any(), any(), any(), any(), any(), any(), any()))
                .thenThrow(new RuntimeException("boom"));

        ResponseEntity<?> response = authController.signupWithSocialToken(signupRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(500);
    }

    // ===== refresh =====

    @Test
    void refresh_성공하면_200과_결과를_반환한다() {
        when(authService.refreshAccessToken(any(), any(), any())).thenReturn(TOKENS);

        ResponseEntity<?> response = authController.refreshToken(refreshRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isEqualTo(TOKENS);
    }

    @Test
    void refresh_토큰이_유효하지_않으면_401을_반환한다() {
        when(authService.refreshAccessToken(any(), any(), any()))
                .thenThrow(new InvalidTokenException("만료된 토큰"));

        ResponseEntity<?> response = authController.refreshToken(refreshRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(401);
    }

    @Test
    void refresh_잘못된_입력이면_401을_반환한다() {
        when(authService.refreshAccessToken(any(), any(), any()))
                .thenThrow(new InvalidInputException("잘못된 토큰"));

        ResponseEntity<?> response = authController.refreshToken(refreshRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(401);
    }

    @Test
    void refresh_사용자가_없으면_404를_반환한다() {
        when(authService.refreshAccessToken(any(), any(), any()))
                .thenThrow(new ResourceNotFoundException("사용자를 찾을 수 없습니다"));

        ResponseEntity<?> response = authController.refreshToken(refreshRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(404);
    }

    @Test
    void refresh_예상하지_못한_오류면_500을_반환한다() {
        when(authService.refreshAccessToken(any(), any(), any()))
                .thenThrow(new RuntimeException("boom"));

        ResponseEntity<?> response = authController.refreshToken(refreshRequest(), httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(500);
    }

    // ===== logout =====

    @Test
    void logout_성공하면_200을_반환한다() {
        ResponseEntity<?> response = authController.logout(logoutRequest());

        verify(authService).logout("refresh-token-id");
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void logout_서비스가_실패해도_200을_반환한다() {
        doThrow(new RuntimeException("boom")).when(authService).logout(any());

        ResponseEntity<?> response = authController.logout(logoutRequest());

        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    // ===== logout-all =====

    @Test
    void logoutAll_인증되지_않으면_401을_반환한다() {
        when(httpRequest.getAttribute("userId")).thenReturn(null);

        ResponseEntity<?> response = authController.logoutAllDevices(httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(401);
    }

    @Test
    void logoutAll_성공하면_200을_반환한다() {
        when(httpRequest.getAttribute("userId")).thenReturn(USER_ID);

        ResponseEntity<?> response = authController.logoutAllDevices(httpRequest);

        verify(authService).logoutAllDevices(USER_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void logoutAll_서비스가_실패하면_500을_반환한다() {
        when(httpRequest.getAttribute("userId")).thenReturn(USER_ID);
        doThrow(new RuntimeException("boom")).when(authService).logoutAllDevices(USER_ID);

        ResponseEntity<?> response = authController.logoutAllDevices(httpRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(500);
    }
}
