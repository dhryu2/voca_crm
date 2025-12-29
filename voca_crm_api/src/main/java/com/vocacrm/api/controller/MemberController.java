package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.MemberCreateRequest;
import com.vocacrm.api.dto.request.MemberUpdateRequest;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.service.MemberService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import static com.vocacrm.api.util.PaginationUtils.limitPageSize;
import static com.vocacrm.api.util.PaginationUtils.validatePage;

import java.util.List;
import java.util.UUID;

/**
 * 회원(Member) REST API 컨트롤러
 *
 * 회원 관리 관련 HTTP 요청을 처리하는 컨트롤러입니다.
 * Flutter 앱과 통신하며, JSON 형식으로 데이터를 주고받습니다.
 *
 * 기본 URL: /api/members
 *
 * 제공하는 API 엔드포인트:
 * - GET /api/members - 전체 회원 목록 조회 (페이징)
 * - GET /api/members/{id} - 특정 회원 조회
 * - GET /api/members/by-number/{number} - 회원번호로 조회
 * - GET /api/members/by-business-place/{businessPlaceId} - 사업장별 회원 조회
 * - GET /api/members/search - 다중 조건 검색
 * - POST /api/members - 회원 생성
 * - PUT /api/members/{id} - 회원 수정
 * - DELETE /api/members/{id} - 회원 삭제
 *
 * CORS 설정: WebConfig에서 모든 origin 허용 설정됨
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@RestController  // @Controller + @ResponseBody (JSON 자동 변환)
@RequestMapping("/api/members")  // 기본 URL 매핑
@RequiredArgsConstructor  // Lombok: final 필드 생성자 자동 생성 (의존성 주입)
public class MemberController {

    /**
     * 회원 서비스 (비즈니스 로직 계층)
     * final로 선언하여 불변성 보장 및 생성자 주입 활성화
     */
    private final MemberService memberService;

    /**
     * 전체 회원 목록 조회 (페이징)
     *
     * HTTP Method: GET
     * URL: /api/members?skip=0&limit=100
     *
     * Query Parameters:
     * - skip: 페이지 번호 (기본값: 0)
     * - limit: 페이지 크기 (기본값: 100)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 응답 형식:
     * {
     *   "content": [...],  // 회원 목록
     *   "totalElements": 1000,  // 전체 회원 수
     *   "totalPages": 10,  // 전체 페이지 수
     *   "size": 100,  // 페이지 크기
     *   "number": 0  // 현재 페이지 번호
     * }
     *
     * 권한 검증: 사용자가 접근 가능한 사업장의 회원만 조회
     *
     * @param skip 페이지 번호 (0부터 시작)
     * @param limit 페이지 크기 (한 페이지당 항목 수)
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 페이징된 회원 목록 (HTTP 200 OK)
     */
    @GetMapping
    public Page<Member> getAllMembers(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "100") int limit,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        Pageable pageable = PageRequest.of(validatePage(skip), limitPageSize(limit));
        return memberService.getMembersByUserId(userId, pageable);
    }

    /**
     * ID로 특정 회원 조회
     *
     * HTTP Method: GET
     * URL: /api/members/{id}
     *
     * Path Variable:
     * - id: 회원 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 예시 요청: GET /api/members/550e8400-e29b-41d4-a716-446655440000
     *
     * 권한 검증: 사용자가 해당 회원의 사업장에 접근 권한이 있는지 확인
     *
     * @param id 조회할 회원의 UUID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 회원 정보 (HTTP 200 OK)
     * @throws RuntimeException 회원이 존재하지 않거나 권한이 없는 경우 (HTTP 500)
     */
    @GetMapping("/{id}")
    public ResponseEntity<Member> getMemberById(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        Member member = memberService.getMemberByIdWithUserCheck(id, userId);
        return ResponseEntity.ok(member);
    }

    /**
     * 회원번호로 회원 목록 조회
     *
     * HTTP Method: GET
     * URL: /api/members/by-number/{number}
     *
     * Path Variable:
     * - number: 회원번호
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 예시 요청: GET /api/members/by-number/789012
     *
     * 참고: 회원번호는 중복 가능하므로 List 반환
     * 음성 검색 기능에서 주로 사용됨
     *
     * 응답 형식:
     * {
     *   "data": [...]
     * }
     *
     * 권한 검증: 사용자의 기본 사업장 회원만 조회
     *
     * @param number 검색할 회원번호
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 해당 회원번호를 가진 회원 목록 (HTTP 200 OK)
     */
    @GetMapping("/by-number/{number}")
    public ResponseEntity<java.util.Map<String, Object>> getMembersByNumber(
            @PathVariable String number,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");
        List<Member> members = memberService.getMembersByNumber(number, businessPlaceId);
        return ResponseEntity.ok(java.util.Map.of("data", members));
    }

    /**
     * 사업장별 회원 목록 조회
     *
     * HTTP Method: GET
     * URL: /api/members/by-business-place/{businessPlaceId}
     *
     * Path Variable:
     * - businessPlaceId: 사업장 ID (UUID)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 예시 요청: GET /api/members/by-business-place/550e8400-e29b-41d4-a716-446655440000
     *
     * 응답 형식:
     * {
     *   "data": [...]
     * }
     *
     * 권한 검증: 사용자가 해당 사업장에 접근 권한이 있는지 확인
     *
     * @param businessPlaceId 검색할 사업장 ID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 해당 사업장에 속한 회원 목록 (HTTP 200 OK)
     * @throws IllegalArgumentException businessPlaceId가 null이거나 empty인 경우 (HTTP 400)
     * @throws RuntimeException 사업장 접근 권한이 없는 경우 (HTTP 500)
     */
    @GetMapping("/by-business-place/{businessPlaceId}")
    public ResponseEntity<java.util.Map<String, Object>> getMembersByBusinessPlace(
            @PathVariable String businessPlaceId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        List<Member> members = memberService.getMembersByBusinessPlaceWithUserCheck(businessPlaceId, userId);
        return ResponseEntity.ok(java.util.Map.of("data", members));
    }

    /**
     * 다중 조건으로 회원 검색
     *
     * HTTP Method: GET
     * URL: /api/members/search?memberNumber=xxx&name=xxx&phone=xxx&email=xxx
     *
     * Query Parameters (모두 선택사항):
     * - memberNumber: 회원번호 (정확히 일치)
     * - name: 이름 (부분 일치)
     * - phone: 전화번호 (부분 일치)
     * - email: 이메일 (부분 일치)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 예시 요청:
     * - GET /api/members/search?name=홍길동
     * - GET /api/members/search?phone=010
     * - GET /api/members/search?memberNumber=789012
     *
     * 검색 우선순위: memberNumber > name > phone > email
     * 모든 파라미터가 없으면 기본 사업장의 전체 회원 반환
     *
     * 응답 형식:
     * {
     *   "data": [...]
     * }
     *
     * 권한 검증: 사용자의 기본 사업장 회원만 검색
     *
     * @param memberNumber 회원번호 (선택)
     * @param name 이름 (선택)
     * @param phone 전화번호 (선택)
     * @param email 이메일 (선택)
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 검색된 회원 목록 (HTTP 200 OK)
     */
    @GetMapping("/search")
    public ResponseEntity<java.util.Map<String, Object>> searchMembers(
            @RequestParam(required = false) String memberNumber,
            @RequestParam(required = false) String name,
            @RequestParam(required = false) String phone,
            @RequestParam(required = false) String email,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");
        List<Member> members = memberService.searchMembers(memberNumber, name, phone, email, businessPlaceId);
        return ResponseEntity.ok(java.util.Map.of("data", members));
    }

    /**
     * 새로운 회원 생성
     *
     * HTTP Method: POST
     * URL: /api/members
     * Content-Type: application/json
     *
     * 요청 본문 예시:
     * {
     *   "memberNumber": "789012",
     *   "name": "홍길동",
     *   "phone": "010-1234-5678",
     *   "email": "hong@example.com"
     * }
     *
     * 필수 필드:
     * - memberNumber: 회원번호
     * - name: 이름
     *
     * 선택 필드:
     * - phone: 전화번호
     * - email: 이메일
     *
     * 자동 생성 필드:
     * - id: UUID 자동 생성
     * - createdAt: 생성 시간 자동 설정
     * - updatedAt: 수정 시간 자동 설정
     *
     * @param member 생성할 회원 정보 (JSON)
     * @return 생성된 회원 정보 (ID와 타임스탬프 포함, HTTP 200 OK)
     */
    @PostMapping
    public ResponseEntity<Member> createMember(@Valid @RequestBody MemberCreateRequest request) {
        Member member = new Member();
        member.setMemberNumber(request.getMemberNumber());
        member.setName(request.getName());
        member.setPhone(request.getPhone());
        member.setEmail(request.getEmail());
        member.setBusinessPlaceId(request.getBusinessPlaceId());
        if (request.getOwnerId() != null) {
            member.setOwnerId(UUID.fromString(request.getOwnerId()));
        }
        member.setGrade(request.getGrade());
        member.setRemark(request.getRemark());

        Member created = memberService.createMember(member);
        return ResponseEntity.ok(created);
    }

    /**
     * 기존 회원 정보 수정
     *
     * HTTP Method: PUT
     * URL: /api/members/{id}
     * Content-Type: application/json
     *
     * Path Variable:
     * - id: 수정할 회원의 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 요청 본문 예시:
     * {
     *   "memberNumber": "789012",
     *   "name": "홍길동",
     *   "phone": "010-9999-8888",
     *   "email": "newemail@example.com"
     * }
     *
     * 수정 가능 필드:
     * - memberNumber: 회원번호
     * - name: 이름
     * - phone: 전화번호
     * - email: 이메일
     *
     * 수정 불가 필드 (자동 처리):
     * - id: 변경 불가
     * - createdAt: 변경 불가
     * - updatedAt: 자동으로 현재 시간으로 갱신
     *
     * @param id 수정할 회원의 UUID
     * @param request 수정할 회원 정보 (JSON)
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 수정된 회원 정보 (HTTP 200 OK)
     * @throws RuntimeException 회원이 존재하지 않는 경우 (HTTP 500)
     */
    @PutMapping("/{id}")
    public ResponseEntity<Member> updateMember(
            @PathVariable String id,
            @Valid @RequestBody MemberUpdateRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest) {

        // JWT에서 추출한 사용자 정보 가져오기
        String requestUserId = (String) servletRequest.getAttribute("userId");
        String businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");

        Member memberDetails = new Member();
        memberDetails.setMemberNumber(request.getMemberNumber());
        memberDetails.setName(request.getName());
        memberDetails.setPhone(request.getPhone());
        memberDetails.setEmail(request.getEmail());
        if (request.getLastModifiedById() != null) {
            memberDetails.setLastModifiedById(UUID.fromString(request.getLastModifiedById()));
        }
        memberDetails.setGrade(request.getGrade());
        memberDetails.setRemark(request.getRemark());

        // 항상 권한 체크 수행
        Member updated = memberService.updateMemberWithPermission(id, memberDetails, requestUserId, businessPlaceId);
        return ResponseEntity.ok(updated);
    }

    /**
     * 회원 삭제
     *
     * HTTP Method: DELETE
     * URL: /api/members/{id}
     *
     * Path Variable:
     * - id: 삭제할 회원의 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 예시 요청: DELETE /api/members/550e8400-e29b-41d4-a716-446655440000
     *
     * 주의사항:
     * - 삭제된 회원은 복구할 수 없습니다
     * - 연관된 메모는 자동으로 삭제되지 않습니다 (수동 삭제 필요)
     *
     * @param id 삭제할 회원의 UUID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 응답 본문 없음 (HTTP 204 No Content)
     * @deprecated Soft Delete 사용 권장 - softDeleteMember 사용
     */
    @Deprecated
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMember(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {

        // JWT에서 추출한 사용자 정보 가져오기
        String requestUserId = (String) servletRequest.getAttribute("userId");
        String businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");

        // 항상 권한 체크 수행
        memberService.deleteMemberWithPermission(id, requestUserId, businessPlaceId);

        return ResponseEntity.noContent().build();
    }

    // ===== Soft Delete 관련 엔드포인트 =====

    /**
     * 회원 Soft Delete (삭제 대기 상태로 전환)
     *
     * HTTP Method: DELETE
     * URL: /api/members/{id}/soft
     *
     * Path Variable:
     * - id: 삭제할 회원의 UUID
     *
     * Required Headers:
     * - X-User-Id: 요청자 사용자 ID
     * - X-Business-Place-Id: 사업장 ID
     *
     * 권한 규칙:
     * - 삭제 권한은 수정자 기준 (수정자 없으면 생성자 기준)
     * - OWNER: 항상 삭제 가능
     * - MANAGER: OWNER가 수정한 회원 삭제 불가
     * - STAFF: MANAGER 이상이 수정한 회원 삭제 불가
     *
     * 주의사항:
     * - 회원 삭제 시 해당 회원의 모든 메모도 함께 soft delete 처리됩니다
     *
     * @param id 삭제할 회원의 UUID
     * @param requestUserId 요청자 사용자 ID
     * @param businessPlaceId 사업장 ID
     * @return 삭제된 회원 정보 (HTTP 200 OK)
     */
    @DeleteMapping("/{id}/soft")
    public ResponseEntity<Member> softDeleteMember(
            @PathVariable String id,
            @RequestHeader("X-User-Id") String requestUserId,
            @RequestHeader("X-Business-Place-Id") String businessPlaceId) {

        Member deleted = memberService.softDeleteMember(id, requestUserId, businessPlaceId);
        return ResponseEntity.ok(deleted);
    }

    /**
     * 특정 사업장의 삭제 대기 회원 목록 조회
     *
     * HTTP Method: GET
     * URL: /api/members/deleted?businessPlaceId=xxx
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * Query Parameters:
     * - businessPlaceId: 조회할 사업장 ID (필수)
     *
     * 응답 형식:
     * {
     *   "data": [...],
     *   "count": 10
     * }
     *
     * 설명:
     * 사용자가 선택한 사업장의 삭제 대기 회원을 조회합니다.
     * 사용자가 해당 사업장에 APPROVED 상태로 접근 권한이 있어야 합니다.
     *
     * @param businessPlaceId 조회할 사업장 ID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 삭제 대기 중인 회원 목록 (HTTP 200 OK)
     */
    @GetMapping("/deleted")
    public ResponseEntity<java.util.Map<String, Object>> getDeletedMembers(
            @RequestParam String businessPlaceId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {

        String userId = (String) servletRequest.getAttribute("userId");

        List<Member> deletedMembers = memberService.getDeletedMembersByBusinessPlace(userId, businessPlaceId);
        long count = memberService.getDeletedMemberCountByBusinessPlace(userId, businessPlaceId);

        return ResponseEntity.ok(java.util.Map.of(
                "data", deletedMembers,
                "count", count
        ));
    }

    /**
     * 삭제 대기 회원 복원
     *
     * HTTP Method: POST
     * URL: /api/members/{id}/restore
     *
     * Path Variable:
     * - id: 복원할 회원의 UUID
     *
     * Required Headers:
     * - X-User-Id: 요청자 사용자 ID
     * - X-Business-Place-Id: 사업장 ID
     *
     * 권한: MANAGER 이상만 복원 가능
     *
     * 주의사항:
     * - 회원 복원 시 해당 회원의 모든 메모도 함께 복원됩니다
     *
     * @param id 복원할 회원의 UUID
     * @param requestUserId 요청자 사용자 ID
     * @param businessPlaceId 사업장 ID
     * @return 복원된 회원 정보 (HTTP 200 OK)
     */
    @PostMapping("/{id}/restore")
    public ResponseEntity<Member> restoreMember(
            @PathVariable String id,
            @RequestHeader("X-User-Id") String requestUserId,
            @RequestHeader("X-Business-Place-Id") String businessPlaceId) {

        Member restored = memberService.restoreMember(id, requestUserId, businessPlaceId);
        return ResponseEntity.ok(restored);
    }

    /**
     * 회원 영구 삭제
     *
     * HTTP Method: DELETE
     * URL: /api/members/{id}/permanent
     *
     * Path Variable:
     * - id: 영구 삭제할 회원의 UUID
     *
     * Required Headers:
     * - X-User-Id: 요청자 사용자 ID
     * - X-Business-Place-Id: 사업장 ID
     *
     * 권한: MANAGER 이상만 영구 삭제 가능
     *
     * 주의사항:
     * - 삭제 대기 상태인 회원만 영구 삭제할 수 있습니다
     * - 영구 삭제된 회원은 복구할 수 없습니다
     * - 연관된 메모도 함께 영구 삭제됩니다
     *
     * @param id 영구 삭제할 회원의 UUID
     * @param requestUserId 요청자 사용자 ID
     * @param businessPlaceId 사업장 ID
     * @return 응답 본문 없음 (HTTP 204 No Content)
     */
    @DeleteMapping("/{id}/permanent")
    public ResponseEntity<Void> permanentDeleteMember(
            @PathVariable String id,
            @RequestHeader("X-User-Id") String requestUserId,
            @RequestHeader("X-Business-Place-Id") String businessPlaceId) {

        memberService.permanentDeleteMember(id, requestUserId, businessPlaceId);
        return ResponseEntity.noContent().build();
    }
}