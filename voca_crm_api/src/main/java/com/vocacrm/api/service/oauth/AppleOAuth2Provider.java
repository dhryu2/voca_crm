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
 * Apple OAuth2 Provider 구현체
 * Firebase ID Token을 검증하여 사용자 정보 추출
 * (Apple Sign-In은 Firebase를 통해 처리됨)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AppleOAuth2Provider implements OAuth2Provider {

    @Override
    public Provider getProviderType() {
        return Provider.APPLE;
    }

    @Override
    public OAuth2UserInfo verifyToken(String idToken) {
        try {
            // Firebase ID Token 검증
            FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(idToken);

            String firebaseUid = decodedToken.getUid();
            String email = decodedToken.getEmail();
            String displayName = decodedToken.getName();

            return new AppleUserInfo(firebaseUid, email, displayName);
        } catch (FirebaseAuthException e) {
            log.error("Apple token verification failed", e);
            throw new InvalidInputException("유효하지 않은 Apple 인증 토큰입니다");
        }
    }

    /**
     * Apple 사용자 정보 DTO
     */
    @Getter
    @AllArgsConstructor
    public static class AppleUserInfo implements OAuth2UserInfo {
        private final String providerId;
        private final String email;
        private final String displayName;

        @Override
        public Provider getProvider() {
            return Provider.APPLE;
        }
    }
}
