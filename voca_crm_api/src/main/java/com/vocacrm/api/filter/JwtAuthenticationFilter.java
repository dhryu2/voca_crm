package com.vocacrm.api.filter;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vocacrm.api.util.JwtUtil;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * JWT 인증 필터
 *
 * 모든 API 요청에 대해 JWT 토큰을 검증합니다.
 * 인증이 필요 없는 엔드포인트(로그인, 회원가입 등)는 제외합니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 인증이 필요 없는 엔드포인트 목록
     */
    private static final List<String> PUBLIC_ENDPOINTS = Arrays.asList(
            "/api/auth/login",
            "/api/auth/signup",
            "/api/auth/refresh",
            "/api/auth/logout"
    );

    /**
     * 인증이 필요 없는 경로 패턴 (prefix 매칭)
     */
    private static final List<String> PUBLIC_PATH_PREFIXES = Arrays.asList(
            "/actuator",
            "/swagger",
            "/v3/api-docs"
    );

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        String requestURI = request.getRequestURI();
        String method = request.getMethod();

        // OPTIONS 요청 (CORS preflight)은 통과
        if ("OPTIONS".equalsIgnoreCase(method)) {
            filterChain.doFilter(request, response);
            return;
        }

        // 공개 엔드포인트는 토큰 검증 없이 통과
        if (isPublicEndpoint(requestURI)) {
            filterChain.doFilter(request, response);
            return;
        }

        // Authorization 헤더 추출
        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            sendUnauthorizedError(response, "인증 토큰이 필요합니다");
            return;
        }

        String token = authHeader.substring(7); // "Bearer " 제거

        try {
            // 토큰 검증
            if (!jwtUtil.validateToken(token)) {
                sendUnauthorizedError(response, "유효하지 않거나 만료된 토큰입니다");
                return;
            }

            // 토큰에서 사용자 정보 추출하여 요청 속성에 저장
            String userId = jwtUtil.extractUserId(token);
            String username = jwtUtil.extractUsername(token);
            String email = jwtUtil.extractEmail(token);
            String defaultBusinessPlaceId = jwtUtil.extractDefaultBusinessPlaceId(token);
            Boolean isSystemAdmin = jwtUtil.extractIsSystemAdmin(token);

            request.setAttribute("userId", userId);
            request.setAttribute("username", username);
            request.setAttribute("email", email);
            request.setAttribute("defaultBusinessPlaceId", defaultBusinessPlaceId);
            request.setAttribute("isSystemAdmin", isSystemAdmin != null ? isSystemAdmin : false);

            filterChain.doFilter(request, response);

        } catch (io.jsonwebtoken.ExpiredJwtException e) {
            log.warn("JWT 토큰 만료: {}", e.getMessage());
            sendUnauthorizedError(response, "토큰이 만료되었습니다. 다시 로그인해주세요.");
        } catch (io.jsonwebtoken.JwtException e) {
            log.warn("JWT 토큰 오류: {}", e.getMessage());
            sendUnauthorizedError(response, "유효하지 않은 토큰입니다");
        } catch (Exception e) {
            log.error("JWT 인증 처리 중 오류 발생", e);
            sendUnauthorizedError(response, "인증 처리 중 오류가 발생했습니다");
        }
    }

    /**
     * 공개 엔드포인트인지 확인
     */
    private boolean isPublicEndpoint(String requestURI) {
        // 정확한 매칭
        if (PUBLIC_ENDPOINTS.contains(requestURI)) {
            return true;
        }

        // prefix 매칭
        for (String prefix : PUBLIC_PATH_PREFIXES) {
            if (requestURI.startsWith(prefix)) {
                return true;
            }
        }

        return false;
    }

    /**
     * 401 Unauthorized 응답 전송
     */
    private void sendUnauthorizedError(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json;charset=UTF-8");

        Map<String, Object> errorResponse = Map.of(
                "error", "UNAUTHORIZED",
                "message", message,
                "status", 401
        );

        response.getWriter().write(objectMapper.writeValueAsString(errorResponse));
    }
}
