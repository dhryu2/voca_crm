package com.vocacrm.api.filter;

import com.vocacrm.api.util.JwtUtil;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

    @Mock
    private JwtUtil jwtUtil;

    @Mock
    private FilterChain filterChain;

    private JwtAuthenticationFilter jwtAuthenticationFilter;

    private static final String DUMMY_TOKEN = "dummy.jwt.token";

    @BeforeEach
    void setUp() {
        jwtAuthenticationFilter = new JwtAuthenticationFilter(jwtUtil);
    }

    @Test
    void optionsRequestPassesThroughWithoutTokenCheck() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("OPTIONS", "/api/members");
        MockHttpServletResponse response = new MockHttpServletResponse();

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        verify(jwtUtil, never()).validateToken(anyString());
    }

    @Test
    void exactPublicEndpointPassesThroughWithoutTokenCheck() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/auth/login");
        MockHttpServletResponse response = new MockHttpServletResponse();

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void postErrorLogsIsPublicException() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/error-logs");
        MockHttpServletResponse response = new MockHttpServletResponse();

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void getErrorLogsIsNotPublicRequiresToken() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/error-logs");
        MockHttpServletResponse response = new MockHttpServletResponse();

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getStatus()).isEqualTo(401);
        verify(filterChain, never()).doFilter(request, response);
    }

    @Test
    void publicPathPrefixPassesThroughWithoutTokenCheck() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/actuator/health");
        MockHttpServletResponse response = new MockHttpServletResponse();

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void missingAuthorizationHeaderReturns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        MockHttpServletResponse response = new MockHttpServletResponse();

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getContentAsString()).contains("인증 토큰이 필요합니다");
        verify(filterChain, never()).doFilter(request, response);
    }

    @Test
    void authorizationHeaderWithoutBearerPrefixReturns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        request.addHeader("Authorization", "Basic abcdef");
        MockHttpServletResponse response = new MockHttpServletResponse();

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getStatus()).isEqualTo(401);
        verify(filterChain, never()).doFilter(request, response);
    }

    @Test
    void validTokenSetsRequestAttributesAndPassesThrough() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        request.addHeader("Authorization", "Bearer " + DUMMY_TOKEN);
        MockHttpServletResponse response = new MockHttpServletResponse();

        when(jwtUtil.validateToken(DUMMY_TOKEN)).thenReturn(true);
        when(jwtUtil.extractUserId(DUMMY_TOKEN)).thenReturn("user-1");
        when(jwtUtil.extractUsername(DUMMY_TOKEN)).thenReturn("tester");
        when(jwtUtil.extractEmail(DUMMY_TOKEN)).thenReturn("tester@example.com");
        when(jwtUtil.extractDefaultBusinessPlaceId(DUMMY_TOKEN)).thenReturn("BP1");
        when(jwtUtil.extractIsSystemAdmin(DUMMY_TOKEN)).thenReturn(true);

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(request.getAttribute("userId")).isEqualTo("user-1");
        assertThat(request.getAttribute("username")).isEqualTo("tester");
        assertThat(request.getAttribute("email")).isEqualTo("tester@example.com");
        assertThat(request.getAttribute("defaultBusinessPlaceId")).isEqualTo("BP1");
        assertThat(request.getAttribute("isSystemAdmin")).isEqualTo(true);
        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void validTokenWithNullIsSystemAdminDefaultsToFalse() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        request.addHeader("Authorization", "Bearer " + DUMMY_TOKEN);
        MockHttpServletResponse response = new MockHttpServletResponse();

        when(jwtUtil.validateToken(DUMMY_TOKEN)).thenReturn(true);
        when(jwtUtil.extractUserId(DUMMY_TOKEN)).thenReturn("user-1");
        when(jwtUtil.extractUsername(DUMMY_TOKEN)).thenReturn("tester");
        when(jwtUtil.extractEmail(DUMMY_TOKEN)).thenReturn("tester@example.com");
        when(jwtUtil.extractDefaultBusinessPlaceId(DUMMY_TOKEN)).thenReturn("BP1");
        when(jwtUtil.extractIsSystemAdmin(DUMMY_TOKEN)).thenReturn(null);

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(request.getAttribute("isSystemAdmin")).isEqualTo(false);
        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void invalidTokenReturns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        request.addHeader("Authorization", "Bearer " + DUMMY_TOKEN);
        MockHttpServletResponse response = new MockHttpServletResponse();

        when(jwtUtil.validateToken(DUMMY_TOKEN)).thenReturn(false);

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getContentAsString()).contains("유효하지 않거나 만료된 토큰입니다");
        verify(filterChain, never()).doFilter(request, response);
    }

    @Test
    void expiredJwtExceptionReturns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        request.addHeader("Authorization", "Bearer " + DUMMY_TOKEN);
        MockHttpServletResponse response = new MockHttpServletResponse();

        when(jwtUtil.validateToken(DUMMY_TOKEN))
                .thenThrow(new ExpiredJwtException(null, null, "expired"));

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getContentAsString()).contains("토큰이 만료되었습니다");
        verify(filterChain, never()).doFilter(request, response);
    }

    @Test
    void jwtExceptionReturns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        request.addHeader("Authorization", "Bearer " + DUMMY_TOKEN);
        MockHttpServletResponse response = new MockHttpServletResponse();

        when(jwtUtil.validateToken(DUMMY_TOKEN)).thenThrow(new JwtException("malformed"));

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getContentAsString()).contains("유효하지 않은 토큰입니다");
        verify(filterChain, never()).doFilter(request, response);
    }

    @Test
    void unexpectedExceptionReturns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        request.addHeader("Authorization", "Bearer " + DUMMY_TOKEN);
        MockHttpServletResponse response = new MockHttpServletResponse();

        when(jwtUtil.validateToken(DUMMY_TOKEN)).thenThrow(new RuntimeException("boom"));

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getContentAsString()).contains("인증 처리 중 오류가 발생했습니다");
        verify(filterChain, never()).doFilter(request, response);
    }
}
