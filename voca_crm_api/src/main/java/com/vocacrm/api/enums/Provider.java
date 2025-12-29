package com.vocacrm.api.enums;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * OAuth2 Provider 타입
 */
@Getter
@RequiredArgsConstructor
public enum Provider {
    GOOGLE("google.com", "Google"),
    KAKAO("kakao.com", "Kakao"),
    APPLE("apple.com", "Apple");

    private final String providerId;
    private final String displayName;

    /**
     * providerId로 Provider enum 찾기
     */
    public static Provider fromProviderId(String providerId) {
        for (Provider provider : values()) {
            if (provider.getProviderId().equalsIgnoreCase(providerId)) {
                return provider;
            }
        }
        throw new IllegalArgumentException("지원하지 않는 Provider입니다: " + providerId);
    }

    /**
     * displayName으로 Provider enum 찾기
     */
    public static Provider fromDisplayName(String displayName) {
        for (Provider provider : values()) {
            if (provider.getDisplayName().equalsIgnoreCase(displayName)) {
                return provider;
            }
        }
        throw new IllegalArgumentException("지원하지 않는 Provider입니다: " + displayName);
    }
}
