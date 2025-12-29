package com.vocacrm.api.service;

import com.vocacrm.api.enums.Provider;
import com.vocacrm.api.exception.DuplicateUserException;
import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.exception.InvalidTokenException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.RefreshToken;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserOAuthConnection;
import com.vocacrm.api.repository.UserOAuthConnectionRepository;
import com.vocacrm.api.repository.UserRepository;
import com.vocacrm.api.service.oauth.OAuth2Provider;
import com.vocacrm.api.util.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final UserOAuthConnectionRepository oauthConnectionRepository;
    private final JwtUtil jwtUtil;
    private final List<OAuth2Provider> oAuth2Providers;
    private final RefreshTokenService refreshTokenService;
    private final SystemAdminService systemAdminService;

    /**
     * Provider를 통해 소셜 로그인 처리
     *
     * @param provider   소셜 로그인 제공자 (GOOGLE, KAKAO, APPLE)
     * @param token      ID Token (Google, Apple) 또는 Access Token (Kakao)
     * @param deviceInfo 디바이스 정보 (선택)
     * @param ipAddress  IP 주소 (선택)
     */
    @Transactional
    public Map<String, String> loginWithSocialToken(
            Provider provider,
            String token,
            String deviceInfo,
            String ipAddress
    ) {
        // Provider에 해당하는 OAuth2Provider 구현체 찾기
        OAuth2Provider oAuth2Provider = getOAuth2Provider(provider);

        // 토큰 검증 및 사용자 정보 추출
        OAuth2Provider.OAuth2UserInfo userInfo = oAuth2Provider.verifyToken(token);

        // OAuth 연결 조회 → 사용자 조회
        UserOAuthConnection oauthConnection = oauthConnectionRepository
                .findWithUserByProviderAndProviderUserId(provider, userInfo.getProviderId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "사용자를 찾을 수 없습니다. 회원가입을 진행해주세요."));

        User user = oauthConnection.getUser();

        // JWT 토큰 생성
        return generateTokens(user, deviceInfo, ipAddress);
    }

    /**
     * Provider를 통해 소셜 회원가입 처리
     *
     * @param provider   소셜 로그인 제공자 (GOOGLE, KAKAO, APPLE)
     * @param token      ID Token (Google, Apple) 또는 Access Token (Kakao)
     * @param username   사용자 이름
     * @param phone      전화번호
     * @param email      이메일 (선택, 사용자 입력값 우선)
     * @param deviceInfo 디바이스 정보 (선택)
     * @param ipAddress  IP 주소 (선택)
     */
    @Transactional
    public Map<String, String> signupWithSocialToken(
            Provider provider,
            String token,
            String username,
            String phone,
            String email,
            String deviceInfo,
            String ipAddress
    ) {
        // 입력값 검증
        validateSignupInput(username, phone);

        // Provider에 해당하는 OAuth2Provider 구현체 찾기
        OAuth2Provider oAuth2Provider = getOAuth2Provider(provider);

        // 토큰 검증 및 사용자 정보 추출
        OAuth2Provider.OAuth2UserInfo userInfo = oAuth2Provider.verifyToken(token);

        // 중복 체크 (이미 연결된 OAuth가 있는지)
        if (oauthConnectionRepository.existsByProviderAndProviderUserId(provider, userInfo.getProviderId())) {
            throw new DuplicateUserException("이미 가입된 사용자입니다");
        }

        // 사용자 생성
        User user = User.builder()
                .email(email != null ? email.trim() : null)
                .username(username.trim())
                .phone(phone.trim().replaceAll("-", ""))
                .displayName(userInfo.getDisplayName())
                .build();

        userRepository.save(user);

        // OAuth 연결 생성
        UserOAuthConnection oauthConnection = UserOAuthConnection.create(
                user,
                userInfo.getProvider(),
                userInfo.getProviderId()
        );
        oauthConnectionRepository.save(oauthConnection);

        log.info("New user registered - userId: {}, provider: {}", user.getId(), provider);

        // JWT 토큰 생성
        return generateTokens(user, deviceInfo, ipAddress);
    }

    /**
     * 기존 사용자에 새 OAuth Provider 연결 추가
     *
     * @param userId   사용자 UUID
     * @param provider 연결할 OAuth Provider
     * @param token    OAuth Token
     */
    @Transactional
    public void linkOAuthProvider(UUID userId, Provider provider, String token) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다"));

        OAuth2Provider oAuth2Provider = getOAuth2Provider(provider);
        OAuth2Provider.OAuth2UserInfo userInfo = oAuth2Provider.verifyToken(token);

        // 이미 다른 사용자에게 연결된 OAuth인지 확인
        Optional<UserOAuthConnection> existingConnection = oauthConnectionRepository
                .findByProviderAndProviderUserId(provider, userInfo.getProviderId());

        if (existingConnection.isPresent()) {
            if (existingConnection.get().getUser().getId().equals(userId)) {
                throw new DuplicateUserException("이미 연결된 계정입니다");
            } else {
                throw new DuplicateUserException("해당 소셜 계정은 다른 사용자에게 연결되어 있습니다");
            }
        }

        // OAuth 연결 추가
        UserOAuthConnection oauthConnection = UserOAuthConnection.create(
                user,
                userInfo.getProvider(),
                userInfo.getProviderId()
        );
        oauthConnectionRepository.save(oauthConnection);

        log.info("OAuth provider linked - userId: {}, provider: {}", userId, provider);
    }

    /**
     * Refresh Token으로 새로운 Access Token 발급 (Rotation 적용)
     *
     * @param refreshTokenId Refresh Token ID (UUID)
     * @param deviceInfo     디바이스 정보 (선택)
     * @param ipAddress      IP 주소 (선택)
     * @return 새로운 Access Token과 Refresh Token
     */
    @Transactional
    public Map<String, String> refreshAccessToken(
            String refreshTokenId,
            String deviceInfo,
            String ipAddress
    ) {
        try {
            // Refresh Token 검증 및 Rotation
            RefreshToken newRefreshToken = refreshTokenService.rotateToken(
                    refreshTokenId, deviceInfo, ipAddress);

            // 사용자 조회 (userId는 UUID String)
            UUID userId = UUID.fromString(newRefreshToken.getUserId());
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다"));

            // 시스템 관리자 여부 확인
            boolean isAdmin = systemAdminService.isSystemAdmin(user.getId());

            // 새로운 Access Token 생성
            String newAccessToken = jwtUtil.generateAccessToken(
                    user.getId().toString(),
                    user.getUsername(),
                    user.getPhone(),
                    user.getEmail(),
                    user.getDefaultBusinessPlaceId(),
                    isAdmin);

            Map<String, String> result = new HashMap<>();
            result.put("accessToken", newAccessToken);
            result.put("refreshToken", newRefreshToken.getTokenId()); // 새 Refresh Token

            return result;
        } catch (InvalidTokenException e) {
            log.warn("Failed to refresh token: {}", e.getMessage());
            throw e;
        } catch (Exception e) {
            log.error("Failed to refresh access token", e);
            throw new InvalidInputException("토큰 갱신에 실패했습니다");
        }
    }

    /**
     * 로그아웃 (현재 Refresh Token 폐기)
     */
    public void logout(String refreshTokenId) {
        refreshTokenService.revokeToken(refreshTokenId);
    }

    /**
     * 모든 기기에서 로그아웃 (모든 Refresh Token 폐기)
     */
    public void logoutAllDevices(String userId) {
        refreshTokenService.revokeAllUserTokens(userId);
    }

    /**
     * Provider에 해당하는 OAuth2Provider 구현체 찾기
     */
    private OAuth2Provider getOAuth2Provider(Provider provider) {
        return oAuth2Providers.stream()
                .filter(p -> p.getProviderType() == provider)
                .findFirst()
                .orElseThrow(() -> new InvalidInputException("지원하지 않는 Provider입니다: " + provider));
    }

    /**
     * 회원가입 입력값 검증
     */
    private void validateSignupInput(String username, String phone) {
        if (username == null || username.trim().length() < 2) {
            throw new InvalidInputException("이름은 2자 이상 입력해주세요");
        }

        if (phone == null || phone.trim().isEmpty()) {
            throw new InvalidInputException("전화번호를 입력해주세요");
        }
    }

    /**
     * JWT Access Token과 Refresh Token 생성
     */
    private Map<String, String> generateTokens(User user, String deviceInfo, String ipAddress) {
        String userId = user.getId().toString();

        // 시스템 관리자 여부 확인
        boolean isAdmin = systemAdminService.isSystemAdmin(user.getId());

        // Access Token 생성 (JWT)
        String accessToken = jwtUtil.generateAccessToken(
                userId,
                user.getUsername(),
                user.getPhone(),
                user.getEmail(),
                user.getDefaultBusinessPlaceId(),
                isAdmin);

        // Refresh Token 생성 (Redis 저장, Opaque Token)
        RefreshToken refreshToken = refreshTokenService.createRefreshToken(
                userId,
                deviceInfo,
                ipAddress);

        Map<String, String> tokens = new HashMap<>();
        tokens.put("accessToken", accessToken);
        tokens.put("refreshToken", refreshToken.getTokenId());

        return tokens;
    }
}
