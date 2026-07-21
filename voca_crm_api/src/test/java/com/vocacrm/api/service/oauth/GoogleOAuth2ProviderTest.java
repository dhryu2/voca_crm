package com.vocacrm.api.service.oauth;

import com.google.firebase.ErrorCode;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import com.vocacrm.api.enums.Provider;
import com.vocacrm.api.exception.InvalidInputException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class GoogleOAuth2ProviderTest {

    @Mock
    private FirebaseAuth firebaseAuth;

    @Mock
    private FirebaseToken firebaseToken;

    private final GoogleOAuth2Provider provider = new GoogleOAuth2Provider();

    @Test
    void getProviderType_GOOGLE를_반환한다() {
        assertThat(provider.getProviderType()).isEqualTo(Provider.GOOGLE);
    }

    @Test
    void verifyToken_정상_케이스면_사용자정보를_반환한다() {
        try (MockedStatic<FirebaseAuth> mockedStatic = mockStatic(FirebaseAuth.class)) {
            mockedStatic.when(FirebaseAuth::getInstance).thenReturn(firebaseAuth);
            when(firebaseToken.getUid()).thenReturn("firebase-uid-1");
            when(firebaseToken.getEmail()).thenReturn("user@example.com");
            when(firebaseToken.getName()).thenReturn("테스터");

            try {
                when(firebaseAuth.verifyIdToken("id-token")).thenReturn(firebaseToken);
            } catch (FirebaseAuthException e) {
                throw new IllegalStateException(e);
            }

            OAuth2Provider.OAuth2UserInfo result = provider.verifyToken("id-token");

            assertThat(result.getProviderId()).isEqualTo("firebase-uid-1");
            assertThat(result.getEmail()).isEqualTo("user@example.com");
            assertThat(result.getDisplayName()).isEqualTo("테스터");
            assertThat(result.getProvider()).isEqualTo(Provider.GOOGLE);
        }
    }

    @Test
    void verifyToken_토큰검증_실패시_InvalidInputException을_던진다() {
        try (MockedStatic<FirebaseAuth> mockedStatic = mockStatic(FirebaseAuth.class)) {
            mockedStatic.when(FirebaseAuth::getInstance).thenReturn(firebaseAuth);

            try {
                when(firebaseAuth.verifyIdToken("bad-token"))
                        .thenThrow(new FirebaseAuthException(
                                ErrorCode.UNAUTHENTICATED, "invalid token", null, null, null));
            } catch (FirebaseAuthException e) {
                throw new IllegalStateException(e);
            }

            assertThatThrownBy(() -> provider.verifyToken("bad-token"))
                    .isInstanceOf(InvalidInputException.class);
        }
    }
}
