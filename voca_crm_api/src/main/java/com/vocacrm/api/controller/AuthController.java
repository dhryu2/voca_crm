package com.vocacrm.api.controller;

import com.vocacrm.api.enums.Provider;
import com.vocacrm.api.exception.DuplicateUserException;
import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.exception.InvalidTokenException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /**
     * 소셜 로그인 (Google, Kakao, Apple)
     * Provider별로 Token을 검증하고 JWT 토큰 발급
     */
    @PostMapping("/login")
    public ResponseEntity<?> loginWithSocialToken(
            @Valid @RequestBody SocialLoginRequest request,
            HttpServletRequest httpRequest
    ) {
        try {
            // Provider 문자열을 enum으로 변환
            Provider provider = Provider.fromProviderId(request.getProvider());

            // 디바이스 정보 및 IP 추출
            String deviceInfo = extractDeviceInfo(httpRequest);
            String ipAddress = extractIpAddress(httpRequest);

            Map<String, String> tokens = authService.loginWithSocialToken(
                    provider,
                    request.getToken(),
                    deviceInfo,
                    ipAddress
            );
            return ResponseEntity.ok(tokens);
        } catch (ResourceNotFoundException e) {
            // 사용자가 없는 경우 - 회원가입 필요
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of(
                            "error", "USER_NOT_FOUND",
                            "message", e.getMessage()
                    ));
        } catch (InvalidInputException | IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of(
                            "error", "INVALID_INPUT",
                            "message", e.getMessage()
                    ));
        } catch (Exception e) {
            log.error("Login failed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of(
                            "error", "INTERNAL_ERROR",
                            "message", "로그인 처리 중 오류가 발생했습니다"
                    ));
        }
    }

    /**
     * 소셜 회원가입 (Google, Kakao, Apple)
     * Provider별로 Token을 검증하고 사용자 생성 후 JWT 토큰 발급
     */
    @PostMapping("/signup")
    public ResponseEntity<?> signupWithSocialToken(
            @Valid @RequestBody SocialSignupRequest request,
            HttpServletRequest httpRequest
    ) {
        try {
            // Provider 문자열을 enum으로 변환
            Provider provider = Provider.fromProviderId(request.getProvider());

            // 디바이스 정보 및 IP 추출
            String deviceInfo = extractDeviceInfo(httpRequest);
            String ipAddress = extractIpAddress(httpRequest);

            Map<String, String> tokens = authService.signupWithSocialToken(
                    provider,
                    request.getToken(),
                    request.getUsername(),
                    request.getPhone(),
                    request.getEmail(),
                    deviceInfo,
                    ipAddress
            );
            return ResponseEntity.status(HttpStatus.CREATED).body(tokens);
        } catch (DuplicateUserException e) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of(
                            "error", "USER_ALREADY_EXISTS",
                            "message", e.getMessage()
                    ));
        } catch (InvalidInputException | IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of(
                            "error", "INVALID_INPUT",
                            "message", e.getMessage()
                    ));
        } catch (Exception e) {
            log.error("Signup failed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of(
                            "error", "INTERNAL_ERROR",
                            "message", "회원가입 처리 중 오류가 발생했습니다"
                    ));
        }
    }

    /**
     * Refresh Token으로 새로운 Access Token 발급 (Rotation 적용)
     * 새로운 Refresh Token도 함께 반환됨
     */
    @PostMapping("/refresh")
    public ResponseEntity<?> refreshToken(
            @Valid @RequestBody RefreshTokenRequest request,
            HttpServletRequest httpRequest
    ) {
        try {
            // 디바이스 정보 및 IP 추출
            String deviceInfo = extractDeviceInfo(httpRequest);
            String ipAddress = extractIpAddress(httpRequest);

            Map<String, String> result = authService.refreshAccessToken(
                    request.getRefreshToken(),
                    deviceInfo,
                    ipAddress
            );
            return ResponseEntity.ok(result);
        } catch (InvalidTokenException e) {
            // 토큰 관련 오류 (만료, 폐기, 재사용 감지 등)
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of(
                            "error", "INVALID_REFRESH_TOKEN",
                            "message", e.getMessage()
                    ));
        } catch (InvalidInputException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of(
                            "error", "INVALID_REFRESH_TOKEN",
                            "message", e.getMessage()
                    ));
        } catch (ResourceNotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of(
                            "error", "USER_NOT_FOUND",
                            "message", e.getMessage()
                    ));
        } catch (Exception e) {
            log.error("Token refresh failed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of(
                            "error", "INTERNAL_ERROR",
                            "message", "토큰 갱신 중 오류가 발생했습니다"
                    ));
        }
    }

    /**
     * 로그아웃 (현재 Refresh Token 폐기)
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logout(@Valid @RequestBody LogoutRequest request) {
        try {
            authService.logout(request.getRefreshToken());
            return ResponseEntity.ok(Map.of("message", "로그아웃되었습니다"));
        } catch (Exception e) {
            log.error("Logout failed", e);
            // 로그아웃은 실패해도 클라이언트는 토큰을 삭제해야 하므로 성공 응답
            return ResponseEntity.ok(Map.of("message", "로그아웃되었습니다"));
        }
    }

    /**
     * 모든 기기에서 로그아웃 (모든 Refresh Token 폐기)
     * 인증 필요 (Authorization 헤더에서 userId 추출)
     */
    @PostMapping("/logout-all")
    public ResponseEntity<?> logoutAllDevices(HttpServletRequest httpRequest) {
        try {
            String userId = (String) httpRequest.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("error", "UNAUTHORIZED", "message", "인증이 필요합니다"));
            }

            authService.logoutAllDevices(userId);
            return ResponseEntity.ok(Map.of("message", "모든 기기에서 로그아웃되었습니다"));
        } catch (Exception e) {
            log.error("Logout all devices failed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of(
                            "error", "INTERNAL_ERROR",
                            "message", "로그아웃 처리 중 오류가 발생했습니다"
                    ));
        }
    }

    /**
     * User-Agent에서 디바이스 정보 추출
     */
    private String extractDeviceInfo(HttpServletRequest request) {
        String userAgent = request.getHeader("User-Agent");
        if (userAgent == null) {
            return "Unknown";
        }

        // 간단한 디바이스 정보 파싱
        if (userAgent.contains("iPhone") || userAgent.contains("iPad")) {
            return "iOS";
        } else if (userAgent.contains("Android")) {
            return "Android";
        } else if (userAgent.contains("Windows")) {
            return "Windows";
        } else if (userAgent.contains("Mac")) {
            return "Mac";
        } else if (userAgent.contains("Linux")) {
            return "Linux";
        }

        // 전체 User-Agent 반환 (최대 200자)
        return userAgent.length() > 200 ? userAgent.substring(0, 200) : userAgent;
    }

    /**
     * 클라이언트 IP 주소 추출 (프록시 고려)
     */
    private String extractIpAddress(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("Proxy-Client-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("WL-Proxy-Client-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("HTTP_CLIENT_IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("HTTP_X_FORWARDED_FOR");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }

        // X-Forwarded-For에 여러 IP가 있을 경우 첫 번째 것 사용
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }

        return ip;
    }

    /**
     * 소셜 로그인 요청 DTO
     */
    public static class SocialLoginRequest {
        @NotBlank(message = "Provider는 필수입니다")
        @Pattern(regexp = "^(google\\.com|kakao\\.com|apple\\.com)$",
                 message = "지원하지 않는 로그인 방식입니다")
        private String provider;

        @NotBlank(message = "토큰은 필수입니다")
        private String token;

        public String getProvider() {
            return provider;
        }

        public void setProvider(String provider) {
            this.provider = provider;
        }

        public String getToken() {
            return token;
        }

        public void setToken(String token) {
            this.token = token;
        }
    }

    /**
     * 소셜 회원가입 요청 DTO
     */
    public static class SocialSignupRequest {
        @NotBlank(message = "Provider는 필수입니다")
        @Pattern(regexp = "^(google\\.com|kakao\\.com|apple\\.com)$",
                 message = "지원하지 않는 로그인 방식입니다")
        private String provider;

        @NotBlank(message = "토큰은 필수입니다")
        private String token;

        @NotBlank(message = "이름은 필수입니다")
        @Size(min = 1, max = 100, message = "이름은 1~100자 사이로 입력해주세요")
        private String username;

        @NotBlank(message = "전화번호는 필수입니다")
        @Size(max = 20, message = "전화번호는 20자 이내로 입력해주세요")
        @Pattern(regexp = "^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$",
                 message = "올바른 휴대폰 번호 형식이 아닙니다 (예: 010-1234-5678)")
        private String phone;

        @Size(max = 255, message = "이메일은 255자 이내로 입력해주세요")
        @Email(message = "올바른 이메일 형식이 아닙니다")
        private String email;

        public String getProvider() {
            return provider;
        }

        public void setProvider(String provider) {
            this.provider = provider;
        }

        public String getToken() {
            return token;
        }

        public void setToken(String token) {
            this.token = token;
        }

        public String getUsername() {
            return username;
        }

        public void setUsername(String username) {
            this.username = username;
        }

        public String getPhone() {
            return phone;
        }

        public void setPhone(String phone) {
            this.phone = phone;
        }

        public String getEmail() {
            return email;
        }

        public void setEmail(String email) {
            this.email = email;
        }
    }

    /**
     * Refresh Token 요청 DTO
     */
    public static class RefreshTokenRequest {
        @NotBlank(message = "Refresh 토큰은 필수입니다")
        private String refreshToken;

        public String getRefreshToken() {
            return refreshToken;
        }

        public void setRefreshToken(String refreshToken) {
            this.refreshToken = refreshToken;
        }
    }

    /**
     * 로그아웃 요청 DTO
     */
    public static class LogoutRequest {
        @NotBlank(message = "Refresh 토큰은 필수입니다")
        private String refreshToken;

        public String getRefreshToken() {
            return refreshToken;
        }

        public void setRefreshToken(String refreshToken) {
            this.refreshToken = refreshToken;
        }
    }
}
