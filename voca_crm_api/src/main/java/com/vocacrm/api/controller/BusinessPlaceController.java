package com.vocacrm.api.controller;

import com.vocacrm.api.dto.AccessRequestWithRequesterDTO;
import com.vocacrm.api.dto.BusinessPlaceDeletionPreviewDTO;
import com.vocacrm.api.dto.BusinessPlaceMemberDTO;
import com.vocacrm.api.dto.BusinessPlaceWithRoleDTO;
import com.vocacrm.api.dto.CreateBusinessPlaceResponse;
import com.vocacrm.api.dto.SetDefaultBusinessPlaceResponse;
import com.vocacrm.api.dto.request.BusinessPlaceCreateRequest;
import com.vocacrm.api.dto.request.BusinessPlaceUpdateRequest;
import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.BusinessPlaceAccessRequest;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.service.BusinessPlaceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/business-places")
@RequiredArgsConstructor
@Tag(name = "사업장", description = "사업장 관리 및 접근 권한 API")
public class BusinessPlaceController {

    private final BusinessPlaceService businessPlaceService;

    @Operation(summary = "사업장 생성", description = "새 사업장 생성 (Owner 권한 자동 부여)")
    @ApiResponse(responseCode = "200", description = "생성 성공")
    @PostMapping
    public ResponseEntity<CreateBusinessPlaceResponse> createBusinessPlace(
            @Valid @RequestBody BusinessPlaceCreateRequest request,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        BusinessPlace businessPlace = new BusinessPlace();
        businessPlace.setName(request.getName());
        businessPlace.setAddress(request.getAddress());
        businessPlace.setPhone(request.getPhone());

        CreateBusinessPlaceResponse response = businessPlaceService.createBusinessPlace(businessPlace, userId);
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "내 사업장 목록", description = "내가 속한 사업장 목록 조회 (역할 정보 포함)")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/my")
    public ResponseEntity<List<BusinessPlaceWithRoleDTO>> getMyBusinessPlaces(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<BusinessPlaceWithRoleDTO> businessPlaces = businessPlaceService.getMyBusinessPlaces(userId);
        return ResponseEntity.ok(businessPlaces);
    }

    /**
     * 사업장 단일 조회
     */
    @Operation(summary = "사업장 상세 조회", description = "사업장 ID로 상세 정보 조회")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/{id}")
    public ResponseEntity<BusinessPlace> getBusinessPlace(@PathVariable String id) {
        BusinessPlace businessPlace = businessPlaceService.getBusinessPlaceById(id);
        return ResponseEntity.ok(businessPlace);
    }

    @Operation(summary = "사업장 수정", description = "사업장 정보 수정 (Owner만 가능)")
    @ApiResponse(responseCode = "200", description = "수정 성공")
    @PutMapping("/{id}")
    public ResponseEntity<BusinessPlace> updateBusinessPlace(
            @PathVariable String id,
            @Valid @RequestBody BusinessPlaceUpdateRequest request,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        BusinessPlace businessPlace = new BusinessPlace();
        businessPlace.setName(request.getName());
        businessPlace.setAddress(request.getAddress());
        businessPlace.setPhone(request.getPhone());

        BusinessPlace updated = businessPlaceService.updateBusinessPlace(id, businessPlace, userId);
        return ResponseEntity.ok(updated);
    }

    @Operation(summary = "기본 사업장 설정", description = "해당 사업장을 기본 사업장으로 설정")
    @ApiResponse(responseCode = "200", description = "설정 성공")
    @PutMapping("/{id}/set-default")
    public ResponseEntity<SetDefaultBusinessPlaceResponse> setDefaultBusinessPlace(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        SetDefaultBusinessPlaceResponse response = businessPlaceService.setDefaultBusinessPlace(userId, id);
        return ResponseEntity.ok(response);
    }

    /**
     * 사업장 접근 권한 요청
     */
    @Operation(summary = "접근 권한 요청", description = "사업장 접근 권한 요청 (Owner 승인 필요)")
    @ApiResponse(responseCode = "200", description = "요청 성공")
    @PostMapping("/{id}/request-access")
    public ResponseEntity<BusinessPlaceAccessRequest> requestAccess(
            @PathVariable String id,
            @RequestParam Role role,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        BusinessPlaceAccessRequest request = businessPlaceService.requestAccess(userId, id, role);
        return ResponseEntity.ok(request);
    }

    /**
     * 사용자가 보낸 요청 목록 조회
     */
    @Operation(summary = "보낸 요청 목록", description = "내가 보낸 접근 권한 요청 목록")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/requests/sent")
    public ResponseEntity<List<BusinessPlaceAccessRequest>> getSentRequests(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<BusinessPlaceAccessRequest> requests = businessPlaceService.getSentRequests(userId);
        return ResponseEntity.ok(requests);
    }

    /**
     * Owner가 받은 요청 목록 조회 (요청자 정보 포함)
     */
    @Operation(summary = "받은 요청 목록", description = "Owner로서 받은 접근 권한 요청 목록")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/requests/received")
    public ResponseEntity<List<AccessRequestWithRequesterDTO>> getReceivedRequests(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<AccessRequestWithRequesterDTO> requests = businessPlaceService.getReceivedRequestsWithRequester(userId);
        return ResponseEntity.ok(requests);
    }

    /**
     * 미확인 처리 결과 조회
     */
    @Operation(summary = "미확인 결과 조회", description = "아직 확인하지 않은 요청 처리 결과")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/requests/unread")
    public ResponseEntity<List<BusinessPlaceAccessRequest>> getUnreadResults(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<BusinessPlaceAccessRequest> requests = businessPlaceService.getUnreadResults(userId);
        return ResponseEntity.ok(requests);
    }

    /**
     * Owner가 받은 PENDING 요청 개수 조회 (Badge용)
     */
    @Operation(summary = "대기 요청 개수", description = "미처리 요청 개수 (Badge용)")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/requests/pending-count")
    public ResponseEntity<Long> getPendingRequestCount(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        long count = businessPlaceService.getPendingRequestCount(userId);
        return ResponseEntity.ok(count);
    }

    /**
     * 미확인 처리 결과 개수 조회 (Badge용)
     */
    @Operation(summary = "미확인 결과 개수", description = "미확인 처리 결과 개수 (Badge용)")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/requests/unread-count")
    public ResponseEntity<Long> getUnreadResultCount(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        long count = businessPlaceService.getUnreadResultCount(userId);
        return ResponseEntity.ok(count);
    }

    /**
     * 요청 승인
     */
    @Operation(summary = "요청 승인", description = "접근 권한 요청 승인 (Owner만 가능)")
    @ApiResponse(responseCode = "200", description = "승인 성공")
    @PutMapping("/requests/{id}/approve")
    public ResponseEntity<BusinessPlaceAccessRequest> approveRequest(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String ownerId = (String) servletRequest.getAttribute("userId");
        BusinessPlaceAccessRequest request = businessPlaceService.approveRequest(id, ownerId);
        return ResponseEntity.ok(request);
    }

    /**
     * 요청 거절
     */
    @Operation(summary = "요청 거절", description = "접근 권한 요청 거절 (Owner만 가능)")
    @ApiResponse(responseCode = "200", description = "거절 성공")
    @PutMapping("/requests/{id}/reject")
    public ResponseEntity<BusinessPlaceAccessRequest> rejectRequest(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String ownerId = (String) servletRequest.getAttribute("userId");
        BusinessPlaceAccessRequest request = businessPlaceService.rejectRequest(id, ownerId);
        return ResponseEntity.ok(request);
    }

    /**
     * 요청 삭제 (요청자만 가능, PENDING만)
     */
    @Operation(summary = "요청 삭제", description = "내가 보낸 요청 삭제 (PENDING 상태만)")
    @ApiResponse(responseCode = "204", description = "삭제 성공")
    @DeleteMapping("/requests/{id}")
    public ResponseEntity<Void> deleteRequest(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        businessPlaceService.deleteRequest(id, userId);
        return ResponseEntity.noContent().build();
    }

    /**
     * 요청 결과 확인 처리
     */
    @Operation(summary = "결과 확인", description = "요청 처리 결과 확인 표시")
    @ApiResponse(responseCode = "200", description = "확인 처리 성공")
    @PutMapping("/requests/{id}/mark-read")
    public ResponseEntity<BusinessPlaceAccessRequest> markRequestAsRead(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        BusinessPlaceAccessRequest request = businessPlaceService.markRequestAsRead(id, userId);
        return ResponseEntity.ok(request);
    }

    @Operation(summary = "사업장 나가기", description = "사업장에서 나가기 (Owner 제외)")
    @ApiResponse(responseCode = "204", description = "나가기 성공")
    @DeleteMapping("/{id}/remove")
    public ResponseEntity<Void> removeBusinessPlace(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        businessPlaceService.removeBusinessPlace(userId, id);
        return ResponseEntity.noContent().build();
    }

    /**
     * 사업장 멤버 목록 조회
     */
    @Operation(summary = "멤버 목록 조회", description = "사업장 멤버 목록 조회")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/{id}/members")
    public ResponseEntity<List<BusinessPlaceMemberDTO>> getBusinessPlaceMembers(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<BusinessPlaceMemberDTO> members = businessPlaceService.getBusinessPlaceMembers(id, userId);
        return ResponseEntity.ok(members);
    }

    /**
     * 멤버 역할 변경 (Owner만 가능)
     */
    @Operation(summary = "멤버 역할 변경", description = "멤버 역할 변경 (Owner만 가능)")
    @ApiResponse(responseCode = "200", description = "변경 성공")
    @PutMapping("/members/{userBusinessPlaceId}/role")
    public ResponseEntity<BusinessPlaceMemberDTO> updateMemberRole(
            @PathVariable UUID userBusinessPlaceId,
            @RequestParam Role role,
            HttpServletRequest servletRequest) {
        String ownerId = (String) servletRequest.getAttribute("userId");
        BusinessPlaceMemberDTO member = businessPlaceService.updateMemberRole(userBusinessPlaceId, role, ownerId);
        return ResponseEntity.ok(member);
    }

    /**
     * 멤버 강제 탈퇴 (Owner만 가능)
     */
    @Operation(summary = "멤버 강제 탈퇴", description = "멤버 강제 탈퇴 (Owner만 가능)")
    @ApiResponse(responseCode = "204", description = "탈퇴 처리 성공")
    @DeleteMapping("/members/{userBusinessPlaceId}")
    public ResponseEntity<Void> removeMember(
            @PathVariable UUID userBusinessPlaceId,
            HttpServletRequest servletRequest) {
        String ownerId = (String) servletRequest.getAttribute("userId");
        businessPlaceService.removeMember(userBusinessPlaceId, ownerId);
        return ResponseEntity.noContent().build();
    }

    /**
     * 사업장 삭제 미리보기 (삭제될 데이터 개수 조회)
     * Owner만 조회 가능
     */
    @Operation(summary = "삭제 미리보기", description = "사업장 삭제 시 영향받는 데이터 개수 조회")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/{id}/deletion-preview")
    public ResponseEntity<BusinessPlaceDeletionPreviewDTO> getDeletionPreview(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        BusinessPlaceDeletionPreviewDTO preview = businessPlaceService.getDeletionPreview(id, userId);
        return ResponseEntity.ok(preview);
    }

    /**
     * 사업장 영구 삭제
     * Owner만 삭제 가능, 사업장 이름 입력 확인 필요
     */
    @Operation(summary = "사업장 영구 삭제", description = "사업장 및 모든 데이터 영구 삭제 (Owner만, 이름 확인 필요)")
    @ApiResponse(responseCode = "204", description = "삭제 성공")
    @DeleteMapping("/{id}/permanent")
    public ResponseEntity<Void> deleteBusinessPlacePermanently(
            @PathVariable String id,
            @RequestParam String confirmName,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        businessPlaceService.deleteBusinessPlacePermanently(id, userId, confirmName);
        return ResponseEntity.noContent().build();
    }
}
