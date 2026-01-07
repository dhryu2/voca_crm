package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.MemoCreateRequest;
import com.vocacrm.api.dto.request.MemoUpdateRequest;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.MemberService;
import com.vocacrm.api.service.MemoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * 메모(Memo) REST API 컨트롤러
 *
 * 회원별 메모 관리 관련 HTTP 요청을 처리하는 컨트롤러입니다.
 * Flutter 앱과 통신하며, JSON 형식으로 데이터를 주고받습니다.
 *
 * 기본 URL: /api/memos
 *
 * 제공하는 API 엔드포인트:
 * - GET /api/memos/{id} - 특정 메모 조회
 * - GET /api/memos/member/{memberId} - 특정 회원의 전체 메모 조회
 * - GET /api/memos/member/{memberId}/latest - 특정 회원의 최신 메모 조회
 * - POST /api/memos - 메모 생성
 * - PUT /api/memos/{id} - 메모 수정
 * - DELETE /api/memos/{id} - 메모 삭제
 *
 * CORS 설정: WebConfig에서 모든 origin 허용 설정됨
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@RestController  // @Controller + @ResponseBody (JSON 자동 변환)
@RequestMapping("/api/memos")  // 기본 URL 매핑
@RequiredArgsConstructor  // Lombok: final 필드 생성자 자동 생성 (의존성 주입)
@Tag(name = "메모", description = "회원별 메모 CRUD API")
public class MemoController {

    /**
     * 메모 서비스 (비즈니스 로직 계층)
     * final로 선언하여 불변성 보장 및 생성자 주입 활성화
     */
    private final MemoService memoService;
    private final MemberService memberService;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;

    /**
     * ID로 특정 메모 조회
     *
     * HTTP Method: GET
     * URL: /api/memos/{id}
     *
     * Path Variable:
     * - id: 메모 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 예시 요청: GET /api/memos/123e4567-e89b-12d3-a456-426614174000
     *
     * 응답 예시:
     * {
     *   "id": "123e4567-e89b-12d3-a456-426614174000",
     *   "memberId": "550e8400-e29b-41d4-a716-446655440000",
     *   "content": "고객 상담 내용...",
     *   "createdAt": "2024-01-15T10:30:00",
     *   "updatedAt": "2024-01-15T10:30:00"
     * }
     *
     * 권한 검증: 사용자가 메모의 회원이 속한 사업장에 접근 권한이 있는지 확인
     *
     * @param id 조회할 메모의 UUID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 메모 정보 (HTTP 200 OK)
     * @throws RuntimeException 메모가 존재하지 않거나 권한이 없는 경우 (HTTP 500)
     */
    @Operation(summary = "메모 상세 조회", description = "ID로 특정 메모 조회")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "403", description = "접근 권한 없음"),
            @ApiResponse(responseCode = "404", description = "메모 없음")
    })
    @GetMapping("/{id}")
    public ResponseEntity<Memo> getMemoById(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");

        // 사업장 권한 검증 포함하여 메모 조회
        Memo memo = memoService.getMemoById(id, businessPlaceId);

        return ResponseEntity.ok(memo);
    }

    /**
     * 사업장별 메모 목록 조회 (최신순)
     *
     * HTTP Method: GET
     * URL: /api/memos/by-business-place/{businessPlaceId}
     *
     * Path Variable:
     * - businessPlaceId: 사업장 ID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 해당 사업장에 접근 권한이 있는지 확인
     *
     * @param businessPlaceId 조회할 사업장 ID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 해당 사업장의 전체 메모 목록 (최신순, HTTP 200 OK)
     */
    @Operation(summary = "사업장별 메모 조회", description = "특정 사업장의 전체 메모 목록 조회")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "403", description = "사업장 접근 권한 없음")
    })
    @GetMapping("/by-business-place/{businessPlaceId}")
    public ResponseEntity<List<Memo>> getMemosByBusinessPlace(
            @PathVariable String businessPlaceId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new AccessDeniedException("해당 사업장의 메모에 대한 접근 권한이 없습니다.");
        }

        List<Memo> memos = memoService.getMemosByBusinessPlace(businessPlaceId);
        return ResponseEntity.ok(memos);
    }

    /**
     * 특정 회원의 전체 메모 목록 조회 (최신순)
     *
     * HTTP Method: GET
     * URL: /api/memos/member/{memberId}
     *
     * Path Variable:
     * - memberId: 회원 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 예시 요청: GET /api/memos/member/550e8400-e29b-41d4-a716-446655440000
     *
     * 응답 형식:
     * {
     *   "data": [
     *     {
     *       "id": "...",
     *       "memberId": "550e8400-e29b-41d4-a716-446655440000",
     *       "content": "최근 메모...",
     *       "createdAt": "2024-01-20T14:00:00",
     *       "updatedAt": "2024-01-20T14:00:00"
     *     },
     *     {
     *       "id": "...",
     *       "memberId": "550e8400-e29b-41d4-a716-446655440000",
     *       "content": "이전 메모...",
     *       "createdAt": "2024-01-15T10:30:00",
     *       "updatedAt": "2024-01-15T10:30:00"
     *     }
     *   ]
     * }
     *
     * 사용 예: 회원 상세 페이지에서 전체 메모 이력 표시
     *
     * 권한 검증: 사용자가 회원의 사업장에 접근 권한이 있는지 확인
     *
     * @param memberId 조회할 회원의 UUID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 해당 회원의 전체 메모 목록 (최신순, HTTP 200 OK)
     * @throws RuntimeException 회원이 존재하지 않거나 권한이 없는 경우 (HTTP 500)
     */
    @Operation(summary = "회원별 메모 조회", description = "특정 회원의 전체 메모 목록 조회 (최신순)")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "403", description = "접근 권한 없음"),
            @ApiResponse(responseCode = "404", description = "회원 없음")
    })
    @GetMapping("/member/{memberId}")
    public ResponseEntity<java.util.Map<String, Object>> getMemosByMemberId(
            @PathVariable String memberId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 회원이 사용자의 사업장에 속하는지 확인
        Member member = memberService.getMemberById(memberId);

        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), member.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new AccessDeniedException("해당 회원의 메모에 대한 접근 권한이 없습니다.");
        }

        List<Memo> memos = memoService.getMemosByMemberId(memberId, member.getBusinessPlaceId());
        return ResponseEntity.ok(java.util.Map.of("data", memos));
    }

    /**
     * 특정 회원의 가장 최근 메모 하나만 조회
     *
     * HTTP Method: GET
     * URL: /api/memos/member/{memberId}/latest
     *
     * Path Variable:
     * - memberId: 회원 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 예시 요청: GET /api/memos/member/550e8400-e29b-41d4-a716-446655440000/latest
     *
     * 응답 예시 (메모가 있는 경우):
     * {
     *   "id": "...",
     *   "memberId": "550e8400-e29b-41d4-a716-446655440000",
     *   "content": "최근 상담 내용...",
     *   "createdAt": "2024-01-20T14:00:00",
     *   "updatedAt": "2024-01-20T14:00:00"
     * }
     *
     * 응답 (메모가 없는 경우):
     * HTTP 404 Not Found
     *
     * 사용 예: 회원 목록에서 각 회원의 최신 메모 미리보기 표시
     *
     * 권한 검증: 사용자가 회원의 사업장에 접근 권한이 있는지 확인
     *
     * @param memberId 조회할 회원의 UUID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 가장 최근 메모 (HTTP 200 OK) 또는 메모가 없으면 404
     * @throws RuntimeException 회원이 존재하지 않거나 권한이 없는 경우 (HTTP 500)
     */
    @Operation(summary = "회원 최신 메모 조회", description = "특정 회원의 가장 최근 메모 하나 조회")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "403", description = "접근 권한 없음"),
            @ApiResponse(responseCode = "404", description = "회원 또는 메모 없음")
    })
    @GetMapping("/member/{memberId}/latest")
    public ResponseEntity<Memo> getLatestMemo(
            @PathVariable String memberId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 회원이 사용자의 사업장에 속하는지 확인
        Member member = memberService.getMemberById(memberId);

        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), member.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new AccessDeniedException("해당 회원의 메모에 대한 접근 권한이 없습니다.");
        }

        Memo memo = memoService.getLatestMemoByMemberId(memberId, member.getBusinessPlaceId());
        if (memo == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(memo);
    }

    /**
     * 새로운 메모 생성
     *
     * HTTP Method: POST
     * URL: /api/memos
     * Content-Type: application/json
     *
     * 요청 본문 예시:
     * {
     *   "memberId": "550e8400-e29b-41d4-a716-446655440000",
     *   "content": "고객 상담 내용을 여기에 작성합니다."
     * }
     *
     * 필수 필드:
     * - memberId: 메모가 속할 회원의 UUID (외래키)
     * - content: 메모 내용
     *
     * 자동 생성 필드:
     * - id: UUID 자동 생성
     * - createdAt: 생성 시간 자동 설정
     * - updatedAt: 수정 시간 자동 설정
     *
     * @param memo 생성할 메모 정보 (JSON)
     * @return 생성된 메모 정보 (ID와 타임스탬프 포함, HTTP 200 OK)
     */
    @Operation(summary = "메모 생성", description = "새로운 메모 등록")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "생성 성공"),
            @ApiResponse(responseCode = "400", description = "잘못된 요청")
    })
    @PostMapping
    public ResponseEntity<Memo> createMemo(
            @Valid @RequestBody MemoCreateRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest) {

        // JWT에서 userId 추출하여 ownerId로 사용
        String userId = (String) servletRequest.getAttribute("userId");

        Memo memo = new Memo();
        if (request.getMemberId() != null) {
            memo.setMemberId(UUID.fromString(request.getMemberId()));
        }
        memo.setContent(request.getContent());
        // ownerId가 요청에 있으면 사용, 없으면 JWT userId 사용
        String ownerIdStr = request.getOwnerId() != null ? request.getOwnerId() : userId;
        if (ownerIdStr != null) {
            memo.setOwnerId(UUID.fromString(ownerIdStr));
        }
        if (request.getIsImportant() != null) {
            memo.setIsImportant(request.getIsImportant());
        }

        Memo created = memoService.createMemo(memo);
        return ResponseEntity.ok(created);
    }

    /**
     * 가장 오래된 메모를 삭제하고 새 메모 생성
     *
     * HTTP Method: POST
     * URL: /api/memos/with-deletion
     * Content-Type: application/json
     *
     * 메모 개수 제한(100개)을 초과한 경우 사용합니다.
     * 가장 오래된 메모를 자동으로 삭제한 후 새 메모를 생성합니다.
     *
     * @param memo 생성할 메모 정보 (JSON)
     * @return 생성된 메모 정보 (HTTP 200 OK)
     */
    @Operation(summary = "메모 생성 (자동 삭제)", description = "메모 개수 제한 초과 시 가장 오래된 메모 삭제 후 생성")
    @ApiResponse(responseCode = "200", description = "생성 성공")
    @PostMapping("/with-deletion")
    public ResponseEntity<Memo> createMemoWithDeletion(
            @Valid @RequestBody MemoCreateRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest) {

        // JWT에서 userId 추출하여 ownerId로 사용
        String userId = (String) servletRequest.getAttribute("userId");

        Memo memo = new Memo();
        if (request.getMemberId() != null) {
            memo.setMemberId(UUID.fromString(request.getMemberId()));
        }
        memo.setContent(request.getContent());
        // ownerId가 요청에 있으면 사용, 없으면 JWT userId 사용
        String ownerIdStr = request.getOwnerId() != null ? request.getOwnerId() : userId;
        if (ownerIdStr != null) {
            memo.setOwnerId(UUID.fromString(ownerIdStr));
        }
        if (request.getIsImportant() != null) {
            memo.setIsImportant(request.getIsImportant());
        }

        Memo created = memoService.createMemoWithOldestDeletion(memo);
        return ResponseEntity.ok(created);
    }

    /**
     * 기존 메모 내용 수정
     *
     * HTTP Method: PUT
     * URL: /api/memos/{id}
     * Content-Type: application/json
     *
     * Path Variable:
     * - id: 수정할 메모의 UUID
     *
     * 요청 본문 예시:
     * {
     *   "content": "수정된 메모 내용입니다."
     * }
     *
     * 수정 가능 필드:
     * - content: 메모 내용
     *
     * 수정 불가 필드 (자동 처리):
     * - id: 변경 불가
     * - memberId: 변경 불가 (메모 소유권 변경 불가)
     * - createdAt: 변경 불가
     * - updatedAt: 자동으로 현재 시간으로 갱신
     *
     * @param id 수정할 메모의 UUID
     * @param memoDetails 수정할 메모 정보 (content만 사용)
     * @return 수정된 메모 정보 (HTTP 200 OK)
     * @throws RuntimeException 메모가 존재하지 않는 경우 (HTTP 500)
     */
    /**
     * 기존 메모 내용 수정
     *
     * HTTP Method: PUT
     * URL: /api/memos/{id}
     * Content-Type: application/json
     *
     * Path Variable:
     * - id: 수정할 메모의 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * Request Body:
     * {
     *   "content": "수정된 메모 내용입니다.",
     *   "lastModifiedById": "user-001",
     *   "isImportant": true
     * }
     *
     * 수정 가능 필드:
     * - content: 메모 내용
     * - isImportant: 중요 표시
     *
     * 수정 불가 필드 (자동 처리):
     * - id: 변경 불가
     * - memberId: 변경 불가 (메모 소유권 변경 불가)
     * - createdAt: 변경 불가
     * - updatedAt: 자동으로 현재 시간으로 갱신
     *
     * @param id 수정할 메모의 UUID
     * @param request 수정할 메모 정보
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 수정된 메모 정보 (HTTP 200 OK)
     * @throws RuntimeException 메모가 존재하지 않는 경우 (HTTP 500)
     */
    @Operation(summary = "메모 수정", description = "기존 메모 내용 수정")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "수정 성공"),
            @ApiResponse(responseCode = "403", description = "수정 권한 없음"),
            @ApiResponse(responseCode = "404", description = "메모 없음")
    })
    @PutMapping("/{id}")
    public ResponseEntity<Memo> updateMemo(
            @PathVariable String id,
            @Valid @RequestBody MemoUpdateRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest) {

        // JWT에서 추출한 사용자 정보 가져오기
        String requestUserId = (String) servletRequest.getAttribute("userId");
        String businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");

        Memo memoDetails = new Memo();
        memoDetails.setContent(request.getContent());
        if (request.getLastModifiedById() != null) {
            memoDetails.setLastModifiedById(UUID.fromString(request.getLastModifiedById()));
        }
        if (request.getIsImportant() != null) {
            memoDetails.setIsImportant(request.getIsImportant());
        }

        // 항상 권한 체크 수행
        Memo updated = memoService.updateMemoWithPermission(id, memoDetails, requestUserId, businessPlaceId);
        return ResponseEntity.ok(updated);
    }

    /**
     * 메모 삭제
     *
     * HTTP Method: DELETE
     * URL: /api/memos/{id}
     *
     * Path Variable:
     * - id: 삭제할 메모의 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * @param id 삭제할 메모의 UUID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 응답 본문 없음 (HTTP 204 No Content)
     * @deprecated Soft Delete 사용 권장 - softDeleteMemo 사용
     */
    @Operation(summary = "메모 삭제 (Deprecated)", description = "메모 Hard Delete - softDeleteMemo 사용 권장")
    @ApiResponse(responseCode = "204", description = "삭제 성공")
    @Deprecated
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMemo(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {

        // JWT에서 추출한 사용자 정보 가져오기
        String requestUserId = (String) servletRequest.getAttribute("userId");
        String businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");

        // 항상 권한 체크 수행
        memoService.deleteMemoWithPermission(id, requestUserId, businessPlaceId);

        return ResponseEntity.noContent().build();
    }

    // ===== Soft Delete 관련 엔드포인트 =====

    /**
     * 메모 Soft Delete (삭제 대기 상태로 전환)
     *
     * HTTP Method: DELETE
     * URL: /api/memos/{id}/soft
     *
     * Path Variable:
     * - id: 삭제할 메모의 UUID
     *
     * Required Headers:
     * - X-User-Id: 요청자 사용자 ID
     * - X-Business-Place-Id: 사업장 ID
     *
     * 권한 규칙:
     * - 삭제 권한은 수정자 기준 (수정자 없으면 생성자 기준)
     * - OWNER: 항상 삭제 가능
     * - MANAGER: OWNER가 수정한 메모 삭제 불가
     * - STAFF: MANAGER 이상이 수정한 메모 삭제 불가
     *
     * @param id 삭제할 메모의 UUID
     * @param requestUserId 요청자 사용자 ID
     * @param businessPlaceId 사업장 ID
     * @return 삭제된 메모 정보 (HTTP 200 OK)
     */
    @Operation(summary = "메모 Soft Delete", description = "메모를 삭제 대기 상태로 전환")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "삭제 성공"),
            @ApiResponse(responseCode = "403", description = "삭제 권한 없음"),
            @ApiResponse(responseCode = "404", description = "메모 없음")
    })
    @DeleteMapping("/{id}/soft")
    public ResponseEntity<Memo> softDeleteMemo(
            @PathVariable String id,
            @RequestHeader("X-User-Id") String requestUserId,
            @RequestHeader("X-Business-Place-Id") String businessPlaceId) {

        Memo deleted = memoService.softDeleteMemo(id, requestUserId, businessPlaceId);
        return ResponseEntity.ok(deleted);
    }

    /**
     * 특정 사업장의 삭제 대기 메모 목록 조회
     *
     * HTTP Method: GET
     * URL: /api/memos/deleted?businessPlaceId=xxx
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * Query Parameters:
     * - businessPlaceId: 조회할 사업장 ID (필수)
     *
     * 응답 형식:
     * {
     *   "data": [...]
     * }
     *
     * 설명:
     * 사용자가 선택한 사업장의 회원들의 삭제 대기 메모를 조회합니다.
     * 사용자가 해당 사업장에 APPROVED 상태로 접근 권한이 있어야 합니다.
     *
     * @param businessPlaceId 조회할 사업장 ID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 삭제 대기 중인 메모 목록 (HTTP 200 OK)
     */
    @Operation(summary = "삭제 대기 메모 조회", description = "삭제 대기 상태인 메모 목록 조회")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/deleted")
    public ResponseEntity<java.util.Map<String, Object>> getDeletedMemos(
            @RequestParam String businessPlaceId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        List<Memo> deletedMemos = memoService.getDeletedMemosByBusinessPlace(userId, businessPlaceId);
        return ResponseEntity.ok(java.util.Map.of("data", deletedMemos));
    }

    /**
     * 삭제 대기 중인 메모 목록 조회 (회원별)
     *
     * HTTP Method: GET
     * URL: /api/memos/member/{memberId}/deleted
     *
     * Path Variable:
     * - memberId: 회원 UUID
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 응답 형식:
     * {
     *   "data": [...]
     * }
     *
     * @param memberId 회원 UUID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 삭제 대기 중인 메모 목록 (HTTP 200 OK)
     */
    @Operation(summary = "회원별 삭제 대기 메모 조회", description = "특정 회원의 삭제 대기 메모 목록 조회")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "403", description = "접근 권한 없음")
    })
    @GetMapping("/member/{memberId}/deleted")
    public ResponseEntity<java.util.Map<String, Object>> getDeletedMemosByMember(
            @PathVariable String memberId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 회원이 사용자의 사업장에 속하는지 확인
        Member member = memberService.getMemberById(memberId);

        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), member.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new AccessDeniedException("해당 회원의 메모에 대한 접근 권한이 없습니다.");
        }

        List<Memo> deletedMemos = memoService.getDeletedMemosByMemberId(memberId, member.getBusinessPlaceId());
        return ResponseEntity.ok(java.util.Map.of("data", deletedMemos));
    }

    /**
     * 삭제 대기 메모 복원
     *
     * HTTP Method: POST
     * URL: /api/memos/{id}/restore
     *
     * Path Variable:
     * - id: 복원할 메모의 UUID
     *
     * Required Headers:
     * - X-User-Id: 요청자 사용자 ID
     * - X-Business-Place-Id: 사업장 ID
     *
     * 권한: MANAGER 이상만 복원 가능
     *
     * @param id 복원할 메모의 UUID
     * @param requestUserId 요청자 사용자 ID
     * @param businessPlaceId 사업장 ID
     * @return 복원된 메모 정보 (HTTP 200 OK)
     */
    @Operation(summary = "메모 복원", description = "삭제 대기 메모 복원 (MANAGER 이상)")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "복원 성공"),
            @ApiResponse(responseCode = "403", description = "복원 권한 없음"),
            @ApiResponse(responseCode = "404", description = "메모 없음")
    })
    @PostMapping("/{id}/restore")
    public ResponseEntity<Memo> restoreMemo(
            @PathVariable String id,
            @RequestHeader("X-User-Id") String requestUserId,
            @RequestHeader("X-Business-Place-Id") String businessPlaceId) {

        Memo restored = memoService.restoreMemo(id, requestUserId, businessPlaceId);
        return ResponseEntity.ok(restored);
    }

    /**
     * 메모 영구 삭제
     *
     * HTTP Method: DELETE
     * URL: /api/memos/{id}/permanent
     *
     * Path Variable:
     * - id: 영구 삭제할 메모의 UUID
     *
     * Required Headers:
     * - X-User-Id: 요청자 사용자 ID
     * - X-Business-Place-Id: 사업장 ID
     *
     * 권한: MANAGER 이상만 영구 삭제 가능
     *
     * 주의사항:
     * - 삭제 대기 상태인 메모만 영구 삭제할 수 있습니다
     * - 영구 삭제된 메모는 복구할 수 없습니다
     *
     * @param id 영구 삭제할 메모의 UUID
     * @param requestUserId 요청자 사용자 ID
     * @param businessPlaceId 사업장 ID
     * @return 응답 본문 없음 (HTTP 204 No Content)
     */
    @Operation(summary = "메모 영구 삭제", description = "삭제 대기 메모 영구 삭제 (MANAGER 이상)")
    @ApiResponses({
            @ApiResponse(responseCode = "204", description = "삭제 성공"),
            @ApiResponse(responseCode = "403", description = "삭제 권한 없음"),
            @ApiResponse(responseCode = "404", description = "메모 없음")
    })
    @DeleteMapping("/{id}/permanent")
    public ResponseEntity<Void> permanentDeleteMemo(
            @PathVariable String id,
            @RequestHeader("X-User-Id") String requestUserId,
            @RequestHeader("X-Business-Place-Id") String businessPlaceId) {

        memoService.permanentDeleteMemo(id, requestUserId, businessPlaceId);
        return ResponseEntity.noContent().build();
    }

    /**
     * 메모 중요도 토글
     *
     * HTTP Method: PATCH
     * URL: /api/memos/{id}/toggle-important
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * @param id 메모 UUID
     * @param servletRequest HttpServletRequest (JWT에서 추출한 정보 포함)
     * @return 업데이트된 메모 정보 (HTTP 200 OK)
     */
    @Operation(summary = "메모 중요도 토글", description = "메모의 중요 표시 on/off 전환")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "업데이트 성공"),
            @ApiResponse(responseCode = "403", description = "수정 권한 없음"),
            @ApiResponse(responseCode = "404", description = "메모 없음")
    })
    @PatchMapping("/{id}/toggle-important")
    public ResponseEntity<Memo> toggleImportant(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {

        // JWT에서 추출한 사용자 정보 가져오기
        String requestUserId = (String) servletRequest.getAttribute("userId");
        String businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");

        Memo memo = memoService.getMemoById(id, businessPlaceId);
        memo.setIsImportant(!memo.getIsImportant());
        Memo updated = memoService.updateMemoWithPermission(id, memo, requestUserId, businessPlaceId);
        return ResponseEntity.ok(updated);
    }

}