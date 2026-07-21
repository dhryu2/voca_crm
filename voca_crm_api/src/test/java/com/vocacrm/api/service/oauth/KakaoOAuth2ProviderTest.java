package com.vocacrm.api.service.oauth;

import com.vocacrm.api.enums.Provider;
import com.vocacrm.api.exception.InvalidInputException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import reactor.core.publisher.Mono;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class KakaoOAuth2ProviderTest {

    @Mock
    private WebClient webClient;

    @Mock
    private WebClient.RequestHeadersUriSpec requestHeadersUriSpec;

    @Mock
    private WebClient.RequestHeadersSpec requestHeadersSpec;

    @Mock
    private WebClient.ResponseSpec responseSpec;

    private KakaoOAuth2Provider provider;

    @BeforeEach
    void setUp() {
        provider = new KakaoOAuth2Provider(webClient);
    }

    @Test
    void getProviderType_KAKAO를_반환한다() {
        assertThat(provider.getProviderType()).isEqualTo(Provider.KAKAO);
    }

    @SuppressWarnings("unchecked")
    @Test
    void verifyToken_정상_케이스면_사용자정보를_반환한다() {
        KakaoOAuth2Provider.KakaoUserResponse.KakaoAccount account =
                new KakaoOAuth2Provider.KakaoUserResponse.KakaoAccount();
        setField(account, "email", "kakao@example.com");

        KakaoOAuth2Provider.KakaoUserResponse.Properties properties =
                new KakaoOAuth2Provider.KakaoUserResponse.Properties();
        setField(properties, "nickname", "카카오테스터");

        KakaoOAuth2Provider.KakaoUserResponse response = new KakaoOAuth2Provider.KakaoUserResponse();
        setField(response, "id", 12345L);
        setField(response, "kakaoAccount", account);
        setField(response, "properties", properties);

        when(webClient.get()).thenReturn(requestHeadersUriSpec);
        when(requestHeadersUriSpec.uri("https://kapi.kakao.com/v2/user/me")).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.header("Authorization", "Bearer access-token")).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.retrieve()).thenReturn(responseSpec);
        when(responseSpec.bodyToMono(KakaoOAuth2Provider.KakaoUserResponse.class))
                .thenReturn(Mono.just(response));

        OAuth2Provider.OAuth2UserInfo result = provider.verifyToken("access-token");

        assertThat(result.getProviderId()).isEqualTo("kakao_12345");
        assertThat(result.getEmail()).isEqualTo("kakao@example.com");
        assertThat(result.getDisplayName()).isEqualTo("카카오테스터");
        assertThat(result.getProvider()).isEqualTo(Provider.KAKAO);
    }

    @SuppressWarnings("unchecked")
    @Test
    void verifyToken_응답이_없으면_예외를_던진다() {
        when(webClient.get()).thenReturn(requestHeadersUriSpec);
        when(requestHeadersUriSpec.uri("https://kapi.kakao.com/v2/user/me")).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.header("Authorization", "Bearer access-token")).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.retrieve()).thenReturn(responseSpec);
        when(responseSpec.bodyToMono(KakaoOAuth2Provider.KakaoUserResponse.class))
                .thenReturn(Mono.empty());

        assertThatThrownBy(() -> provider.verifyToken("access-token"))
                .isInstanceOf(InvalidInputException.class);
    }

    @SuppressWarnings("unchecked")
    @Test
    void verifyToken_WebClientResponseException발생시_InvalidInputException을_던진다() {
        when(webClient.get()).thenReturn(requestHeadersUriSpec);
        when(requestHeadersUriSpec.uri("https://kapi.kakao.com/v2/user/me")).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.header("Authorization", "Bearer access-token")).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.retrieve()).thenReturn(responseSpec);
        when(responseSpec.bodyToMono(KakaoOAuth2Provider.KakaoUserResponse.class))
                .thenThrow(WebClientResponseException.create(
                        HttpStatus.UNAUTHORIZED.value(), "Unauthorized", null, null, null));

        assertThatThrownBy(() -> provider.verifyToken("access-token"))
                .isInstanceOf(InvalidInputException.class);
    }

    @SuppressWarnings("unchecked")
    @Test
    void verifyToken_기타_예외발생시_InvalidInputException을_던진다() {
        when(webClient.get()).thenReturn(requestHeadersUriSpec);
        when(requestHeadersUriSpec.uri("https://kapi.kakao.com/v2/user/me")).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.header("Authorization", "Bearer access-token")).thenReturn(requestHeadersSpec);
        when(requestHeadersSpec.retrieve()).thenReturn(responseSpec);
        when(responseSpec.bodyToMono(KakaoOAuth2Provider.KakaoUserResponse.class))
                .thenThrow(new RuntimeException("network error"));

        assertThatThrownBy(() -> provider.verifyToken("access-token"))
                .isInstanceOf(InvalidInputException.class);
    }

    private void setField(Object target, String fieldName, Object value) {
        try {
            var field = target.getClass().getDeclaredField(fieldName);
            field.setAccessible(true);
            field.set(target, value);
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException(e);
        }
    }
}
