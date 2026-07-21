package com.vocacrm.api.filter;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class SecurityHeadersFilterTest {

    @Mock
    private FilterChain filterChain;

    private final SecurityHeadersFilter securityHeadersFilter = new SecurityHeadersFilter();

    @Test
    void addsSecurityHeadersAndPassesThrough() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");
        MockHttpServletResponse response = new MockHttpServletResponse();

        securityHeadersFilter.doFilterInternal(request, response, filterChain);

        assertThat(response.getHeader("X-Content-Type-Options")).isEqualTo("nosniff");
        assertThat(response.getHeader("X-Frame-Options")).isEqualTo("DENY");
        assertThat(response.getHeader("Cache-Control")).isEqualTo("no-store, no-cache, must-revalidate, max-age=0");
        assertThat(response.getHeader("Pragma")).isEqualTo("no-cache");
        assertThat(response.getHeader("Expires")).isEqualTo("0");
        assertThat(response.getHeader("Referrer-Policy")).isEqualTo("strict-origin-when-cross-origin");
        assertThat(response.getHeader("Permissions-Policy")).isEqualTo("geolocation=(), microphone=(), camera=()");
        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void shouldNotFilterReturnsTrueForActuatorPaths() {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/actuator/health");

        assertThat(securityHeadersFilter.shouldNotFilter(request)).isTrue();
    }

    @Test
    void shouldNotFilterReturnsFalseForApiPaths() {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/members");

        assertThat(securityHeadersFilter.shouldNotFilter(request)).isFalse();
    }
}
