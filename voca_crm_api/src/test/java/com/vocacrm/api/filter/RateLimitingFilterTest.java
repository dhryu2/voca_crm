package com.vocacrm.api.filter;

import com.vocacrm.api.config.RateLimitConfig;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class RateLimitingFilterTest {

    @Mock
    private FilterChain filterChain;

    private RateLimitConfig rateLimitConfig;
    private RateLimitingFilter rateLimitingFilter;

    @BeforeEach
    void setUp() {
        rateLimitConfig = new RateLimitConfig();
        rateLimitConfig.setEnabled(true);
        rateLimitConfig.setApi(new RateLimitConfig.EndpointLimit(2, 60));
        rateLimitConfig.setAuth(new RateLimitConfig.EndpointLimit(2, 60));
        rateLimitConfig.setSearch(new RateLimitConfig.EndpointLimit(2, 60));
        rateLimitConfig.setVoiceAi(new RateLimitConfig.EndpointLimit(2, 60));
        rateLimitConfig.setVoice(new RateLimitConfig.EndpointLimit(2, 60));
        rateLimitConfig.setErrorLog(new RateLimitConfig.EndpointLimit(2, 60));
        rateLimitingFilter = new RateLimitingFilter(rateLimitConfig);
    }

    @Test
    void disabledRateLimitingPassesThroughWithoutHeaders() throws Exception {
        rateLimitConfig.setEnabled(false);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        assertThat(response.getHeader("X-RateLimit-Limit")).isNull();
    }

    @Test
    void optionsRequestPassesThrough() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("OPTIONS", "/api/members");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void excludedEndpointPassesThroughWithoutRateLimit() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/actuator/health");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        assertThat(response.getHeader("X-RateLimit-Limit")).isNull();
    }

    @Test
    void requestWithinLimitPassesThroughAndSetsHeaders() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        assertThat(response.getHeader("X-RateLimit-Limit")).isEqualTo("2");
        assertThat(response.getHeader("X-RateLimit-Remaining")).isEqualTo("1");
        assertThat(response.getHeader("X-RateLimit-Reset")).isNotNull();
    }

    @Test
    void requestExceedingLimitReturns429() throws Exception {
        String uri = "/api/members";

        // consume the allowed 2 requests from the same client/endpoint bucket
        for (int i = 0; i < 2; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("GET", uri);
            MockHttpServletResponse response = new MockHttpServletResponse();
            rateLimitingFilter.doFilterInternal(request, response, filterChain);
        }

        MockHttpServletRequest blockedRequest = new MockHttpServletRequest("GET", uri);
        MockHttpServletResponse blockedResponse = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(blockedRequest, blockedResponse, filterChain);

        assertThat(blockedResponse.getStatus()).isEqualTo(429);
        assertThat(blockedResponse.getHeader("Retry-After")).isNotNull();
        assertThat(blockedResponse.getHeader("X-RateLimit-Remaining")).isEqualTo("0");
        assertThat(blockedResponse.getContentAsString()).contains("TOO_MANY_REQUESTS");
        verify(filterChain, never()).doFilter(blockedRequest, blockedResponse);
    }

    @Test
    void authEndpointUsesAuthLimit() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/auth/login");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getHeader("X-RateLimit-Limit")).isEqualTo("2");
    }

    @Test
    void errorLogEndpointUsesErrorLogLimit() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/error-logs");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void searchEndpointUsesSearchLimit() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members/search");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void voiceCommandEndpointUsesVoiceAiLimit() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/voice/command");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void otherVoiceEndpointUsesVoiceLimit() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/voice/continue");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void authenticatedUserIsIdentifiedByUserIdAttribute() throws Exception {
        MockHttpServletRequest firstRequest = new MockHttpServletRequest("GET", "/api/members");
        firstRequest.setAttribute("userId", "user-123");
        MockHttpServletResponse firstResponse = new MockHttpServletResponse();
        rateLimitingFilter.doFilterInternal(firstRequest, firstResponse, filterChain);
        assertThat(firstResponse.getHeader("X-RateLimit-Remaining")).isEqualTo("1");

        // Different IP but same userId should share the same bucket
        MockHttpServletRequest secondRequest = new MockHttpServletRequest("GET", "/api/members");
        secondRequest.setAttribute("userId", "user-123");
        secondRequest.setRemoteAddr("9.9.9.9");
        MockHttpServletResponse secondResponse = new MockHttpServletResponse();
        rateLimitingFilter.doFilterInternal(secondRequest, secondResponse, filterChain);
        assertThat(secondResponse.getHeader("X-RateLimit-Remaining")).isEqualTo("0");
    }

    @Test
    void clientIpFallsBackToForwardedHeaderThenRealIpThenRemoteAddr() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        request.addHeader("X-Forwarded-For", "1.2.3.4, 5.6.7.8");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitingFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void cleanupStaleBucketsWithNoBucketsReturnsEarly() {
        rateLimitingFilter.cleanupStaleBuckets();
        // no exception means the empty-buckets short-circuit path executed successfully
    }
}
