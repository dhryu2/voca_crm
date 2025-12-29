package com.vocacrm.api.config;

import com.vocacrm.api.filter.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 필터 설정
 *
 * JWT 인증 필터를 등록하고 적용할 URL 패턴을 지정합니다.
 */
@Configuration
@RequiredArgsConstructor
public class FilterConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    @Bean
    public FilterRegistrationBean<JwtAuthenticationFilter> jwtFilter() {
        FilterRegistrationBean<JwtAuthenticationFilter> registrationBean =
                new FilterRegistrationBean<>();

        registrationBean.setFilter(jwtAuthenticationFilter);
        registrationBean.addUrlPatterns("/api/*");  // /api/** 경로에만 적용
        registrationBean.setOrder(1);  // 필터 순서 (낮을수록 먼저 실행)
        registrationBean.setName("jwtAuthenticationFilter");

        return registrationBean;
    }
}
