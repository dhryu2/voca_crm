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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserOAuthConnectionRepository oauthConnectionRepository;

    @Mock
    private JwtUtil jwtUtil;

    @Mock
    private OAuth2Provider googleProvider;

    @Mock
    private RefreshTokenService refreshTokenService;

    @Mock
    private SystemAdminService systemAdminService;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(
                userRepository,
                oauthConnectionRepository,
                jwtUtil,
                List.of(googleProvider),
                refreshTokenService,
                systemAdminService
        );
        lenient().when(googleProvider.getProviderType()).thenReturn(Provider.GOOGLE);
    }

    private OAuth2Provider.OAuth2UserInfo googleUserInfo(String providerId) {
        return new OAuth2Provider.OAuth2UserInfo() {
            @Override
            public String getProviderId() {
                return providerId;
            }

            @Override
            public String getEmail() {
                return "user@example.com";
            }

            @Override
            public String getDisplayName() {
                return "테스터";
            }

            @Override
            public Provider getProvider() {
                return Provider.GOOGLE;
            }
        };
    }

    @Test
    void loginWithSocialToken_정상_케이스면_토큰을_반환한다() {
        UUID userId = UUID.randomUUID();
        User user = User.builder().id(userId).username("tester").build();
        UserOAuthConnection connection = UserOAuthConnection.builder().user(user).build();

        when(googleProvider.verifyToken("id-token")).thenReturn(googleUserInfo("provider-1"));
        when(oauthConnectionRepository.findWithUserByProviderAndProviderUserId(Provider.GOOGLE, "provider-1"))
                .thenReturn(Optional.of(connection));
        when(systemAdminService.isSystemAdmin(userId)).thenReturn(false);
        when(jwtUtil.generateAccessToken(any(), any(), any(), any(), any(), any(), any(), eq(false)))
                .thenReturn("access-token");
        when(refreshTokenService.createRefreshToken(anyString(), any(), any()))
                .thenReturn(RefreshToken.builder().tokenId("refresh-token").build());

        Map<String, String> result = authService.loginWithSocialToken(Provider.GOOGLE, "id-token", "device", "1.1.1.1");

        assertThat(result.get("accessToken")).isEqualTo("access-token");
        assertThat(result.get("refreshToken")).isEqualTo("refresh-token");
    }

    @Test
    void loginWithSocialToken_사용자를_찾을수_없으면_예외를_던진다() {
        when(googleProvider.verifyToken("id-token")).thenReturn(googleUserInfo("provider-1"));
        when(oauthConnectionRepository.findWithUserByProviderAndProviderUserId(Provider.GOOGLE, "provider-1"))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.loginWithSocialToken(Provider.GOOGLE, "id-token", null, null))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void loginWithSocialToken_지원하지않는_Provider면_예외를_던진다() {
        assertThatThrownBy(() -> authService.loginWithSocialToken(Provider.APPLE, "id-token", null, null))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void signupWithSocialToken_정상_케이스면_사용자를_생성하고_토큰을_반환한다() {
        when(googleProvider.verifyToken("id-token")).thenReturn(googleUserInfo("provider-1"));
        when(oauthConnectionRepository.existsByProviderAndProviderUserId(Provider.GOOGLE, "provider-1"))
                .thenReturn(false);
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User savedUser = invocation.getArgument(0);
            savedUser.setId(UUID.randomUUID());
            return savedUser;
        });
        when(systemAdminService.isSystemAdmin((UUID) any())).thenReturn(false);
        when(jwtUtil.generateAccessToken(any(), any(), any(), any(), any(), any(), any(), eq(false)))
                .thenReturn("access-token");
        when(refreshTokenService.createRefreshToken(anyString(), any(), any()))
                .thenReturn(RefreshToken.builder().tokenId("refresh-token").build());

        Map<String, String> result = authService.signupWithSocialToken(
                Provider.GOOGLE, "id-token", "홍길동", "010-1234-5678", "user@example.com", "device", "1.1.1.1");

        assertThat(result.get("accessToken")).isEqualTo("access-token");
        assertThat(result.get("refreshToken")).isEqualTo("refresh-token");
        verify(userRepository).save(any(User.class));
        verify(oauthConnectionRepository).save(any(UserOAuthConnection.class));
    }

    @Test
    void signupWithSocialToken_이미_가입된_사용자면_예외를_던진다() {
        when(googleProvider.verifyToken("id-token")).thenReturn(googleUserInfo("provider-1"));
        when(oauthConnectionRepository.existsByProviderAndProviderUserId(Provider.GOOGLE, "provider-1"))
                .thenReturn(true);

        assertThatThrownBy(() -> authService.signupWithSocialToken(
                Provider.GOOGLE, "id-token", "홍길동", "010-1234-5678", null, null, null))
                .isInstanceOf(DuplicateUserException.class);

        verify(userRepository, never()).save(any());
    }

    @Test
    void signupWithSocialToken_이름이_짧으면_예외를_던진다() {
        assertThatThrownBy(() -> authService.signupWithSocialToken(
                Provider.GOOGLE, "id-token", "홍", "010-1234-5678", null, null, null))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void signupWithSocialToken_전화번호가_없으면_예외를_던진다() {
        assertThatThrownBy(() -> authService.signupWithSocialToken(
                Provider.GOOGLE, "id-token", "홍길동", " ", null, null, null))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void linkOAuthProvider_정상_케이스면_연결을_추가한다() {
        UUID userId = UUID.randomUUID();
        User user = User.builder().id(userId).build();

        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(googleProvider.verifyToken("id-token")).thenReturn(googleUserInfo("provider-1"));
        when(oauthConnectionRepository.findByProviderAndProviderUserId(Provider.GOOGLE, "provider-1"))
                .thenReturn(Optional.empty());

        authService.linkOAuthProvider(userId, Provider.GOOGLE, "id-token");

        verify(oauthConnectionRepository).save(any(UserOAuthConnection.class));
    }

    @Test
    void linkOAuthProvider_사용자를_찾을수_없으면_예외를_던진다() {
        UUID userId = UUID.randomUUID();
        when(userRepository.findById(userId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.linkOAuthProvider(userId, Provider.GOOGLE, "id-token"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void linkOAuthProvider_본인에게_이미_연결되어있으면_예외를_던진다() {
        UUID userId = UUID.randomUUID();
        User user = User.builder().id(userId).build();
        UserOAuthConnection existing = UserOAuthConnection.builder().user(user).build();

        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(googleProvider.verifyToken("id-token")).thenReturn(googleUserInfo("provider-1"));
        when(oauthConnectionRepository.findByProviderAndProviderUserId(Provider.GOOGLE, "provider-1"))
                .thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> authService.linkOAuthProvider(userId, Provider.GOOGLE, "id-token"))
                .isInstanceOf(DuplicateUserException.class);
    }

    @Test
    void linkOAuthProvider_다른_사용자에게_연결되어있으면_예외를_던진다() {
        UUID userId = UUID.randomUUID();
        User user = User.builder().id(userId).build();
        User otherUser = User.builder().id(UUID.randomUUID()).build();
        UserOAuthConnection existing = UserOAuthConnection.builder().user(otherUser).build();

        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(googleProvider.verifyToken("id-token")).thenReturn(googleUserInfo("provider-1"));
        when(oauthConnectionRepository.findByProviderAndProviderUserId(Provider.GOOGLE, "provider-1"))
                .thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> authService.linkOAuthProvider(userId, Provider.GOOGLE, "id-token"))
                .isInstanceOf(DuplicateUserException.class);
    }

    @Test
    void refreshAccessToken_정상_케이스면_새_토큰을_반환한다() {
        UUID userId = UUID.randomUUID();
        User user = User.builder().id(userId).build();
        RefreshToken newToken = RefreshToken.builder().tokenId("new-refresh").userId(userId.toString()).build();

        when(refreshTokenService.rotateToken("old-refresh", "device", "1.1.1.1")).thenReturn(newToken);
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(systemAdminService.isSystemAdmin(userId)).thenReturn(false);
        when(jwtUtil.generateAccessToken(any(), any(), any(), any(), any(), any(), any(), eq(false)))
                .thenReturn("new-access");

        Map<String, String> result = authService.refreshAccessToken("old-refresh", "device", "1.1.1.1");

        assertThat(result.get("accessToken")).isEqualTo("new-access");
        assertThat(result.get("refreshToken")).isEqualTo("new-refresh");
    }

    @Test
    void refreshAccessToken_InvalidTokenException은_그대로_전파한다() {
        when(refreshTokenService.rotateToken(anyString(), any(), any()))
                .thenThrow(new InvalidTokenException("유효하지 않은 토큰"));

        assertThatThrownBy(() -> authService.refreshAccessToken("old-refresh", null, null))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void refreshAccessToken_기타_예외는_InvalidInputException으로_변환한다() {
        when(refreshTokenService.rotateToken(anyString(), any(), any()))
                .thenThrow(new RuntimeException("예상치 못한 오류"));

        assertThatThrownBy(() -> authService.refreshAccessToken("old-refresh", null, null))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void logout_호출시_RefreshToken을_폐기한다() {
        authService.logout("refresh-token");

        verify(refreshTokenService).revokeToken("refresh-token");
    }

    @Test
    void logoutAllDevices_호출시_모든_토큰을_폐기한다() {
        authService.logoutAllDevices("user-id");

        verify(refreshTokenService).revokeAllUserTokens("user-id");
    }
}
