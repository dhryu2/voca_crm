package com.vocacrm.api.service.oauth;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.vocacrm.api.enums.Provider;
import com.vocacrm.api.exception.InvalidInputException;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

/**
 * Kakao OAuth2 Provider 구현체
 * Kakao Access Token을 검증하여 사용자 정보 추출
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class KakaoOAuth2Provider implements OAuth2Provider {

    private static final String KAKAO_USER_INFO_URL = "https://kapi.kakao.com/v2/user/me";

    private final WebClient webClient;

    @Override
    public Provider getProviderType() {
        return Provider.KAKAO;
    }

    @Override
    public OAuth2UserInfo verifyToken(String accessToken) {
        try {
            // Kakao API를 통해 사용자 정보 조회
            KakaoUserResponse response = webClient.get()
                    .uri(KAKAO_USER_INFO_URL)
                    .header("Authorization", "Bearer " + accessToken)
                    .retrieve()
                    .bodyToMono(KakaoUserResponse.class)
                    .block();

            if (response == null || response.getId() == null) {
                throw new InvalidInputException("Kakao 사용자 정보를 가져올 수 없습니다");
            }

            // Kakao ID를 문자열로 변환하여 providerId로 사용
            String providerId = "kakao_" + response.getId();
            String email = response.getKakaoAccount() != null ? response.getKakaoAccount().getEmail() : null;
            String displayName = response.getProperties() != null ? response.getProperties().getNickname() : null;

            return new KakaoUserInfo(providerId, email, displayName);

        } catch (WebClientResponseException e) {
            log.error("Kakao token verification failed: status={}, body={}",
                    e.getStatusCode(), e.getResponseBodyAsString());
            throw new InvalidInputException("유효하지 않은 Kakao 인증 토큰입니다");
        } catch (Exception e) {
            log.error("Kakao API call failed", e);
            throw new InvalidInputException("Kakao 사용자 정보 조회 중 오류가 발생했습니다");
        }
    }

    /**
     * Kakao 사용자 정보 DTO
     */
    @Getter
    @AllArgsConstructor
    public static class KakaoUserInfo implements OAuth2UserInfo {
        private final String providerId;
        private final String email;
        private final String displayName;

        @Override
        public Provider getProvider() {
            return Provider.KAKAO;
        }
    }

    /**
     * Kakao API 응답 DTO
     */
    @Getter
    @NoArgsConstructor
    public static class KakaoUserResponse {
        private Long id;

        @JsonProperty("kakao_account")
        private KakaoAccount kakaoAccount;

        private Properties properties;

        @Getter
        @NoArgsConstructor
        public static class KakaoAccount {
            private String email;

            @JsonProperty("email_needs_agreement")
            private Boolean emailNeedsAgreement;
        }

        @Getter
        @NoArgsConstructor
        public static class Properties {
            private String nickname;
        }
    }
}
