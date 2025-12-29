package com.vocacrm.api.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * 보안 헤더 필터
 *
 * 모든 API 응답에 표준 보안 헤더를 추가합니다.
 *
 * 추가되는 헤더:
 * - X-Content-Type-Options: nosniff (MIME 타입 스니핑 방지)
 * - X-Frame-Options: DENY (클릭재킹 방지)
 * - Cache-Control: no-store (민감한 데이터 캐싱 방지)
 * - Pragma: no-cache (HTTP/1.0 호환)
 * - X-XSS-Protection: 0 (최신 브라우저에서 deprecated, CSP 사용 권장)
 * - Referrer-Policy: strict-origin-when-cross-origin
 *
 * 참고: 모바일 앱 전용 API이므로 일부 브라우저 전용 헤더(CSP 등)는 제외
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)  // Rate Limiting 필터 다음에 실행
public class SecurityHeadersFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        // MIME 타입 스니핑 방지
        response.setHeader("X-Content-Type-Options", "nosniff");

        // 클릭재킹 방지 (iframe 삽입 차단)
        response.setHeader("X-Frame-Options", "DENY");

        // API 응답은 캐시하지 않음 (민감한 사용자 데이터 보호)
        response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
        response.setHeader("Pragma", "no-cache");
        response.setHeader("Expires", "0");

        // Referrer 정책 (외부로 전체 URL 노출 방지)
        response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");

        // 권한 정책 (민감한 기능 제한)
        response.setHeader("Permissions-Policy", "geolocation=(), microphone=(), camera=()");

        filterChain.doFilter(request, response);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        // Swagger UI와 API 문서는 필터 제외 (정적 리소스)
        return path.startsWith("/swagger") ||
               path.startsWith("/v3/api-docs") ||
               path.startsWith("/actuator");
    }
}
