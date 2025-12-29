package com.vocacrm.api.controller;

import com.vocacrm.api.model.Notice;
import com.vocacrm.api.service.NoticeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 공지사항(Notice) REST API 컨트롤러
 *
 * 공지사항 관리 관련 HTTP 요청을 처리하는 컨트롤러입니다.
 * Flutter 앱과 통신하며, JSON 형식으로 데이터를 주고받습니다.
 *
 * 기본 URL: /api/notices
 *
 * 제공하는 API 엔드포인트:
 * - GET /api/notices/active - 사용자용 활성 공지사항 조회
 * - POST /api/notices/{noticeId}/view - 공지사항 열람 기록
 * - GET /api/admin/notices - 관리자용 전체 공지사항 목록
 * - GET /api/admin/notices/{id} - 공지사항 상세 조회
 * - POST /api/admin/notices - 공지사항 생성
 * - PUT /api/admin/notices/{id} - 공지사항 수정
 * - DELETE /api/admin/notices/{id} - 공지사항 삭제
 * - GET /api/admin/notices/{id}/stats - 공지사항 통계
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class NoticeController {

    private final NoticeService noticeService;

    /**
     * 특정 사용자가 볼 수 있는 활성 공지사항 조회 (일반 사용자용)
     *
     * HTTP Method: GET
     * URL: /api/notices/active
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 응답 형식:
     * {
     *   "data": [
     *     {
     *       "id": "...",
     *       "title": "시스템 점검 안내",
     *       "content": "...",
     *       "startDate": "2024-01-01T00:00:00",
     *       "endDate": "2024-12-31T23:59:59",
     *       "priority": 10
     *     }
     *   ]
     * }
     *
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 활성 공지사항 목록 (다시 보지 않기 체크한 것 제외)
     */
    @GetMapping("/notices/active")
    public ResponseEntity<Map<String, Object>> getActiveNotices(jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<Notice> notices = noticeService.getActiveNoticesForUser(userId);
        return ResponseEntity.ok(Map.of("data", notices));
    }

    /**
     * 공지사항 열람 기록 저장
     *
     * HTTP Method: POST
     * URL: /api/notices/{noticeId}/view
     *
     * Path Variable:
     * - noticeId: 공지사항 ID
     *
     * Request Body:
     * {
     *   "userId": "user-001",
     *   "doNotShowAgain": true
     * }
     *
     * @param noticeId 공지사항 ID
     * @param requestBody userId, doNotShowAgain 포함
     * @return 성공 응답 (HTTP 200 OK)
     */
    @PostMapping("/notices/{noticeId}/view")
    public ResponseEntity<Map<String, String>> recordView(
            @PathVariable String noticeId,
            @RequestBody Map<String, Object> requestBody) {

        String userId = (String) requestBody.get("userId");
        Boolean doNotShowAgain = (Boolean) requestBody.get("doNotShowAgain");

        noticeService.recordView(userId, noticeId, doNotShowAgain != null && doNotShowAgain);

        return ResponseEntity.ok(Map.of("message", "View recorded successfully"));
    }

    // ========== 관리자 전용 API ==========

    /**
     * 모든 공지사항 조회 (관리자용)
     *
     * HTTP Method: GET
     * URL: /api/admin/notices
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한: 시스템 관리자만 접근 가능
     *
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 전체 공지사항 목록
     */
    @GetMapping("/admin/notices")
    public ResponseEntity<Map<String, Object>> getAllNotices(jakarta.servlet.http.HttpServletRequest servletRequest) {
        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        List<Notice> notices = noticeService.getAllNotices(isSystemAdmin);
        return ResponseEntity.ok(Map.of("data", notices));
    }

    /**
     * ID로 공지사항 조회 (관리자용)
     *
     * HTTP Method: GET
     * URL: /api/admin/notices/{id}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한: 시스템 관리자만 접근 가능
     *
     * @param id 공지사항 ID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 공지사항 상세 정보
     */
    @GetMapping("/admin/notices/{id}")
    public ResponseEntity<Notice> getNoticeById(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        Notice notice = noticeService.getNoticeByIdForAdmin(id, isSystemAdmin);
        return ResponseEntity.ok(notice);
    }

    /**
     * 공지사항 생성 (관리자용)
     *
     * HTTP Method: POST
     * URL: /api/admin/notices
     * Content-Type: application/json
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한: 시스템 관리자만 접근 가능
     *
     * Request Body:
     * {
     *   "title": "공지사항 제목",
     *   "content": "공지사항 내용",
     *   "startDate": "2024-01-01T00:00:00",
     *   "endDate": "2024-12-31T23:59:59",
     *   "priority": 10,
     *   "isActive": true,
     *   "createdByUserId": "admin-user-001"
     * }
     *
     * @param notice 생성할 공지사항 정보
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 생성된 공지사항 (HTTP 200 OK)
     */
    @PostMapping("/admin/notices")
    public ResponseEntity<Notice> createNotice(
            @RequestBody Notice notice,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        Notice created = noticeService.createNotice(notice, isSystemAdmin);
        return ResponseEntity.ok(created);
    }

    /**
     * 공지사항 수정 (관리자용)
     *
     * HTTP Method: PUT
     * URL: /api/admin/notices/{id}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한: 시스템 관리자만 접근 가능
     *
     * @param id 수정할 공지사항 ID
     * @param noticeDetails 수정할 내용
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 수정된 공지사항 (HTTP 200 OK)
     */
    @PutMapping("/admin/notices/{id}")
    public ResponseEntity<Notice> updateNotice(
            @PathVariable String id,
            @RequestBody Notice noticeDetails,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        Notice updated = noticeService.updateNotice(id, noticeDetails, isSystemAdmin);
        return ResponseEntity.ok(updated);
    }

    /**
     * 공지사항 삭제 (관리자용)
     *
     * HTTP Method: DELETE
     * URL: /api/admin/notices/{id}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한: 시스템 관리자만 접근 가능
     *
     * @param id 삭제할 공지사항 ID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 응답 본문 없음 (HTTP 204 No Content)
     */
    @DeleteMapping("/admin/notices/{id}")
    public ResponseEntity<Void> deleteNotice(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        noticeService.deleteNotice(id, isSystemAdmin);
        return ResponseEntity.noContent().build();
    }

    /**
     * 공지사항 통계 조회 (관리자용)
     *
     * HTTP Method: GET
     * URL: /api/admin/notices/{id}/stats
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한: 시스템 관리자만 접근 가능
     *
     * 응답 예시:
     * {
     *   "viewCount": 150,
     *   "hideCount": 30
     * }
     *
     * @param id 공지사항 ID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 열람 통계 (열람 수, "다시 보지 않기" 수)
     */
    @GetMapping("/admin/notices/{id}/stats")
    public ResponseEntity<Map<String, Long>> getNoticeStats(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        Boolean isSystemAdmin = (Boolean) servletRequest.getAttribute("isSystemAdmin");
        Map<String, Long> stats = noticeService.getNoticeStats(id, isSystemAdmin);
        return ResponseEntity.ok(stats);
    }
}
