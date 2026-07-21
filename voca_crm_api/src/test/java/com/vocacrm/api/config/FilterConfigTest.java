package com.vocacrm.api.config;

import com.vocacrm.api.filter.JwtAuthenticationFilter;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.boot.web.servlet.FilterRegistrationBean;

import static org.assertj.core.api.Assertions.assertThat;

@ExtendWith(MockitoExtension.class)
class FilterConfigTest {

    @Mock
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Test
    void jwtFilter는_api경로에_등록된다() {
        FilterConfig filterConfig = new FilterConfig(jwtAuthenticationFilter);

        FilterRegistrationBean<JwtAuthenticationFilter> registrationBean = filterConfig.jwtFilter();

        assertThat(registrationBean.getFilter()).isSameAs(jwtAuthenticationFilter);
        assertThat(registrationBean.getUrlPatterns()).containsExactly("/api/*");
        assertThat(registrationBean.getOrder()).isEqualTo(1);
        assertThat(registrationBean.getFilterName()).isEqualTo("jwtAuthenticationFilter");
    }
}
