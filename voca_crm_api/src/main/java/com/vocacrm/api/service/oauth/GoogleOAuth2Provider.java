package com.vocacrm.api.service.oauth;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import com.vocacrm.api.enums.Provider;
import com.vocacrm.api.exception.InvalidInputException;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * Google OAuth2 Provider 구현체
 * Firebase ID Token을 검증하여 사용자 정보 추출
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GoogleOAuth2Provider implements OAuth2Provider {

    @Override
    public Provider getProviderType() {
        return Provider.GOOGLE;
    }

    @Override
    public OAuth2UserInfo verifyToken(String idToken) {
        try {
            // Firebase ID Token 검증
            FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(idToken);

            String firebaseUid = decodedToken.getUid();
            String email = decodedToken.getEmail();
            String displayName = decodedToken.getName();

            return new GoogleUserInfo(firebaseUid, email, displayName);
        } catch (FirebaseAuthException e) {
            log.error("Google token verification failed", e);
            throw new InvalidInputException("유효하지 않은 Google 인증 토큰입니다");
        }
    }

    /**
     * Google 사용자 정보 DTO
     */
    @Getter
    @AllArgsConstructor
    public static class GoogleUserInfo implements OAuth2UserInfo {
        private final String providerId;
        private final String email;
        private final String displayName;

        @Override
        public Provider getProvider() {
            return Provider.GOOGLE;
        }
    }
}
