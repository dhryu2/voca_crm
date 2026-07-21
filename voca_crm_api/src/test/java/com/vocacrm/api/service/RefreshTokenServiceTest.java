package com.vocacrm.api.service;

import com.vocacrm.api.exception.InvalidTokenException;
import com.vocacrm.api.model.RefreshToken;
import com.vocacrm.api.repository.RefreshTokenRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RefreshTokenServiceTest {

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @InjectMocks
    private RefreshTokenService refreshTokenService;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(refreshTokenService, "inactivityExpirySeconds", 1_209_600L);
        ReflectionTestUtils.setField(refreshTokenService, "absoluteExpirySeconds", 7_776_000L);
        ReflectionTestUtils.setField(refreshTokenService, "maxTokensPerUser", 5);
    }

    @Test
    void createRefreshToken_정상_케이스면_새_토큰을_저장한다() {
        when(refreshTokenRepository.findByUserIdAndRevokedFalse("user-1")).thenReturn(List.of());

        RefreshToken token = refreshTokenService.createRefreshToken("user-1", "device", "1.1.1.1");

        assertThat(token.getUserId()).isEqualTo("user-1");
        assertThat(token.isRevoked()).isFalse();
        verify(refreshTokenRepository).save(token);
    }

    @Test
    void createRefreshToken_최대_토큰수_초과시_오래된_토큰을_폐기한다() {
        RefreshToken oldest = RefreshToken.builder()
                .tokenId("t1").userId("user-1").revoked(false)
                .lastUsedAt(Instant.now().minusSeconds(100)).absoluteExpiryAt(Instant.now().plusSeconds(1000))
                .build();
        RefreshToken newer = RefreshToken.builder()
                .tokenId("t2").userId("user-1").revoked(false)
                .lastUsedAt(Instant.now()).absoluteExpiryAt(Instant.now().plusSeconds(1000))
                .build();

        when(refreshTokenRepository.findByUserIdAndRevokedFalse("user-1")).thenReturn(List.of(oldest, newer));
        ReflectionTestUtils.setField(refreshTokenService, "maxTokensPerUser", 2);

        refreshTokenService.createRefreshToken("user-1", "device", "1.1.1.1");

        verify(refreshTokenRepository).save(oldest);
        assertThat(oldest.isRevoked()).isTrue();
    }

    @Test
    void rotateToken_정상_케이스면_새_토큰을_반환하고_기존_토큰을_폐기한다() {
        RefreshToken existing = RefreshToken.builder()
                .tokenId("old-token").userId("user-1").revoked(false)
                .lastUsedAt(Instant.now()).absoluteExpiryAt(Instant.now().plusSeconds(1000))
                .inactivityExpirySeconds(1_209_600L)
                .build();

        when(refreshTokenRepository.findByTokenId("old-token")).thenReturn(Optional.of(existing));

        RefreshToken result = refreshTokenService.rotateToken("old-token", "device", "1.1.1.1");

        assertThat(result.getUserId()).isEqualTo("user-1");
        assertThat(existing.isRevoked()).isTrue();
        assertThat(existing.getReplacedByTokenId()).isEqualTo(result.getTokenId());
        verify(refreshTokenRepository, times(2)).save(any(RefreshToken.class));
    }

    @Test
    void rotateToken_존재하지않는_토큰이면_예외를_던진다() {
        when(refreshTokenRepository.findByTokenId("missing")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> refreshTokenService.rotateToken("missing", null, null))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void rotateToken_폐기된_토큰이면_전체_토큰을_폐기하고_예외를_던진다() {
        RefreshToken revoked = RefreshToken.builder()
                .tokenId("revoked-token").userId("user-1").revoked(true)
                .build();

        when(refreshTokenRepository.findByTokenId("revoked-token")).thenReturn(Optional.of(revoked));
        when(refreshTokenRepository.findByUserId("user-1")).thenReturn(List.of(revoked));

        assertThatThrownBy(() -> refreshTokenService.rotateToken("revoked-token", null, null))
                .isInstanceOf(InvalidTokenException.class);

        verify(refreshTokenRepository).save(revoked);
    }

    @Test
    void rotateToken_만료된_토큰이면_삭제하고_예외를_던진다() {
        RefreshToken expired = RefreshToken.builder()
                .tokenId("expired-token").userId("user-1").revoked(false)
                .lastUsedAt(Instant.now().minusSeconds(2_000_000))
                .absoluteExpiryAt(Instant.now().plusSeconds(1000))
                .inactivityExpirySeconds(1_209_600L)
                .build();

        when(refreshTokenRepository.findByTokenId("expired-token")).thenReturn(Optional.of(expired));

        assertThatThrownBy(() -> refreshTokenService.rotateToken("expired-token", null, null))
                .isInstanceOf(InvalidTokenException.class);

        verify(refreshTokenRepository).delete(expired);
    }

    @Test
    void validateToken_정상_케이스면_토큰을_반환한다() {
        RefreshToken token = RefreshToken.builder()
                .tokenId("valid-token").revoked(false)
                .absoluteExpiryAt(Instant.now().plusSeconds(1000))
                .build();

        when(refreshTokenRepository.findByTokenId("valid-token")).thenReturn(Optional.of(token));

        RefreshToken result = refreshTokenService.validateToken("valid-token");

        assertThat(result).isEqualTo(token);
    }

    @Test
    void validateToken_존재하지않으면_예외를_던진다() {
        when(refreshTokenRepository.findByTokenId("missing")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> refreshTokenService.validateToken("missing"))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void validateToken_폐기된_토큰이면_예외를_던진다() {
        RefreshToken token = RefreshToken.builder().tokenId("revoked").revoked(true).build();

        when(refreshTokenRepository.findByTokenId("revoked")).thenReturn(Optional.of(token));

        assertThatThrownBy(() -> refreshTokenService.validateToken("revoked"))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void validateToken_만료된_토큰이면_예외를_던진다() {
        RefreshToken token = RefreshToken.builder()
                .tokenId("expired").revoked(false)
                .absoluteExpiryAt(Instant.now().minusSeconds(10))
                .build();

        when(refreshTokenRepository.findByTokenId("expired")).thenReturn(Optional.of(token));

        assertThatThrownBy(() -> refreshTokenService.validateToken("expired"))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void revokeToken_존재하면_폐기하고_저장한다() {
        RefreshToken token = RefreshToken.builder().tokenId("t1").revoked(false).build();
        when(refreshTokenRepository.findByTokenId("t1")).thenReturn(Optional.of(token));

        refreshTokenService.revokeToken("t1");

        assertThat(token.isRevoked()).isTrue();
        verify(refreshTokenRepository).save(token);
    }

    @Test
    void revokeToken_존재하지않으면_아무것도_하지않는다() {
        when(refreshTokenRepository.findByTokenId("missing")).thenReturn(Optional.empty());

        refreshTokenService.revokeToken("missing");

        verify(refreshTokenRepository, never()).save(any());
    }

    @Test
    void revokeAllUserTokens_사용자의_모든_토큰을_폐기한다() {
        RefreshToken t1 = RefreshToken.builder().tokenId("t1").revoked(false).build();
        RefreshToken t2 = RefreshToken.builder().tokenId("t2").revoked(false).build();
        when(refreshTokenRepository.findByUserId("user-1")).thenReturn(List.of(t1, t2));

        refreshTokenService.revokeAllUserTokens("user-1");

        assertThat(t1.isRevoked()).isTrue();
        assertThat(t2.isRevoked()).isTrue();
        verify(refreshTokenRepository, times(2)).save(any(RefreshToken.class));
    }

    @Test
    void deleteAllUserTokens_사용자의_모든_토큰을_삭제한다() {
        List<RefreshToken> tokens = List.of(RefreshToken.builder().tokenId("t1").build());
        when(refreshTokenRepository.findByUserId("user-1")).thenReturn(tokens);

        refreshTokenService.deleteAllUserTokens("user-1");

        verify(refreshTokenRepository).deleteAll(tokens);
    }

    @Test
    void getActiveTokens_유효한_토큰만_반환한다() {
        RefreshToken valid = RefreshToken.builder()
                .tokenId("valid").revoked(false)
                .absoluteExpiryAt(Instant.now().plusSeconds(1000))
                .build();
        RefreshToken expired = RefreshToken.builder()
                .tokenId("expired").revoked(false)
                .absoluteExpiryAt(Instant.now().minusSeconds(10))
                .build();

        when(refreshTokenRepository.findByUserIdAndRevokedFalse("user-1")).thenReturn(List.of(valid, expired));

        List<RefreshToken> result = refreshTokenService.getActiveTokens("user-1");

        assertThat(result).containsExactly(valid);
    }

    @Test
    void updateLastUsed_유효한_토큰이면_사용시각을_갱신한다() {
        RefreshToken token = RefreshToken.builder()
                .tokenId("t1").revoked(false)
                .lastUsedAt(Instant.now().minusSeconds(100))
                .absoluteExpiryAt(Instant.now().plusSeconds(1000))
                .inactivityExpirySeconds(1_209_600L)
                .build();
        when(refreshTokenRepository.findByTokenId("t1")).thenReturn(Optional.of(token));

        refreshTokenService.updateLastUsed("t1");

        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository).save(captor.capture());
        assertThat(captor.getValue().getTokenId()).isEqualTo("t1");
    }

    @Test
    void updateLastUsed_폐기된_토큰이면_갱신하지않는다() {
        RefreshToken token = RefreshToken.builder().tokenId("t1").revoked(true).build();
        when(refreshTokenRepository.findByTokenId("t1")).thenReturn(Optional.of(token));

        refreshTokenService.updateLastUsed("t1");

        verify(refreshTokenRepository, never()).save(any());
    }
}
