package com.vocacrm.api.service.oauth;

import com.vocacrm.api.enums.Provider;

/**
 * OAuth2 Provider 인터페이스
 * 각 소셜 로그인 제공자(Google, Kakao, Apple)가 구현해야 하는 메서드 정의
 */
public interface OAuth2Provider {

    /**
     * 이 Provider가 지원하는 Provider 타입 반환
     */
    Provider getProviderType();

    /**
     * ID Token 또는 Access Token을 검증하고 사용자 정보를 추출
     *
     * @param token ID Token (Google, Apple) 또는 Access Token (Kakao)
     * @return 검증된 사용자 정보
     */
    OAuth2UserInfo verifyToken(String token);

    /**
     * OAuth2 사용자 정보 DTO
     */
    interface OAuth2UserInfo {
        String getProviderId();      // Provider 고유 ID (Firebase UID, Kakao ID 등)
        String getEmail();
        String getDisplayName();
        Provider getProvider();
    }
}
