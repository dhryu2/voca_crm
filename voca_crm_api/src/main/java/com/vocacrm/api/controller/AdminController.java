package com.vocacrm.api.controller;

import com.vocacrm.api.dto.admin.AdminBusinessPlaceDTO;
import com.vocacrm.api.dto.admin.AdminUserDTO;
import com.vocacrm.api.dto.admin.SystemStatsDTO;
import com.vocacrm.api.service.AdminService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * 시스템 관리자용 API 컨트롤러
 *
 * 시스템 전체 통계, 사용자 관리, 사업장 관리 등의 기능을 제공합니다.
 * 모든 엔드포인트는 시스템 관리자 권한이 필요합니다.
 *
 * 기본 URL: /api/admin
 *
 * 제공하는 API 엔드포인트:
 * - GET /api/admin/stats - 시스템 전체 통계
 * - GET /api/admin/users - 사용자 목록 조회
 * - GET /api/admin/business-places - 사업장 목록 조회
 */
@Slf4j
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    // ==================== 시스템 통계 ====================

    /**
     * 시스템 전체 통계 조회
     *
     * HTTP Method: GET
     * URL: /api/admin/stats
     *
     * 응답 예시:
     * {
     *   "totalUsers": 150,
     *   "activeUsers": 145,
     *   "newUsersToday": 5,
     *   "newUsersThisWeek": 20,
     *   "totalBusinessPlaces": 30,
     *   "activeBusinessPlaces": 28,
     *   "dau": 50,
     *   "mau": 120
     * }
     *
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 시스템 전체 통계
     */
    @GetMapping("/stats")
    public ResponseEntity<SystemStatsDTO> getSystemStats(HttpServletRequest servletRequest) {
        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        adminService.validateSystemAdmin(isSystemAdmin);

        return ResponseEntity.ok(adminService.getSystemStats());
    }

    // ==================== 사용자 관리 ====================

    /**
     * 전체 사용자 목록 조회 (페이징)
     *
     * HTTP Method: GET
     * URL: /api/admin/users
     *
     * Query Parameters:
     * - page: 페이지 번호 (0부터 시작, 기본값: 0)
     * - size: 페이지 크기 (기본값: 20)
     * - search: 검색어 (이름, 이메일, 전화번호)
     * - status: 상태 필터 (ACTIVE, SUSPENDED, BANNED)
     *
     * 응답: Page<AdminUserDTO>
     *
     * @param page 페이지 번호
     * @param size 페이지 크기
     * @param search 검색어
     * @param status 상태 필터
     * @param servletRequest HttpServletRequest
     * @return 사용자 목록 (페이징)
     */
    @GetMapping("/users")
    public ResponseEntity<Page<AdminUserDTO>> getAllUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String status,
            HttpServletRequest servletRequest) {

        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        adminService.validateSystemAdmin(isSystemAdmin);

        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        return ResponseEntity.ok(adminService.getAllUsers(search, status, pageable));
    }

    // ==================== 사업장 관리 ====================

    /**
     * 전체 사업장 목록 조회 (페이징)
     *
     * HTTP Method: GET
     * URL: /api/admin/business-places
     *
     * Query Parameters:
     * - page: 페이지 번호 (0부터 시작, 기본값: 0)
     * - size: 페이지 크기 (기본값: 20)
     * - search: 검색어 (사업장명, 주소)
     * - status: 상태 필터 (ACTIVE, SUSPENDED, DELETED)
     *
     * 응답: Page<AdminBusinessPlaceDTO>
     *
     * @param page 페이지 번호
     * @param size 페이지 크기
     * @param search 검색어
     * @param status 상태 필터
     * @param servletRequest HttpServletRequest
     * @return 사업장 목록 (페이징)
     */
    @GetMapping("/business-places")
    public ResponseEntity<Page<AdminBusinessPlaceDTO>> getAllBusinessPlaces(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String status,
            HttpServletRequest servletRequest) {

        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        adminService.validateSystemAdmin(isSystemAdmin);

        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        return ResponseEntity.ok(adminService.getAllBusinessPlaces(search, status, pageable));
    }
}
