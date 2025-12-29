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
public class BusinessPlaceController {

    private final BusinessPlaceService businessPlaceService;

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

    @GetMapping("/my")
    public ResponseEntity<List<BusinessPlaceWithRoleDTO>> getMyBusinessPlaces(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<BusinessPlaceWithRoleDTO> businessPlaces = businessPlaceService.getMyBusinessPlaces(userId);
        return ResponseEntity.ok(businessPlaces);
    }

    /**
     * 사업장 단일 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<BusinessPlace> getBusinessPlace(@PathVariable String id) {
        BusinessPlace businessPlace = businessPlaceService.getBusinessPlaceById(id);
        return ResponseEntity.ok(businessPlace);
    }

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
    @GetMapping("/requests/sent")
    public ResponseEntity<List<BusinessPlaceAccessRequest>> getSentRequests(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<BusinessPlaceAccessRequest> requests = businessPlaceService.getSentRequests(userId);
        return ResponseEntity.ok(requests);
    }

    /**
     * Owner가 받은 요청 목록 조회 (요청자 정보 포함)
     */
    @GetMapping("/requests/received")
    public ResponseEntity<List<AccessRequestWithRequesterDTO>> getReceivedRequests(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<AccessRequestWithRequesterDTO> requests = businessPlaceService.getReceivedRequestsWithRequester(userId);
        return ResponseEntity.ok(requests);
    }

    /**
     * 미확인 처리 결과 조회
     */
    @GetMapping("/requests/unread")
    public ResponseEntity<List<BusinessPlaceAccessRequest>> getUnreadResults(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        List<BusinessPlaceAccessRequest> requests = businessPlaceService.getUnreadResults(userId);
        return ResponseEntity.ok(requests);
    }

    /**
     * Owner가 받은 PENDING 요청 개수 조회 (Badge용)
     */
    @GetMapping("/requests/pending-count")
    public ResponseEntity<Long> getPendingRequestCount(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        long count = businessPlaceService.getPendingRequestCount(userId);
        return ResponseEntity.ok(count);
    }

    /**
     * 미확인 처리 결과 개수 조회 (Badge용)
     */
    @GetMapping("/requests/unread-count")
    public ResponseEntity<Long> getUnreadResultCount(HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        long count = businessPlaceService.getUnreadResultCount(userId);
        return ResponseEntity.ok(count);
    }

    /**
     * 요청 승인
     */
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
    @PutMapping("/requests/{id}/mark-read")
    public ResponseEntity<BusinessPlaceAccessRequest> markRequestAsRead(
            @PathVariable String id,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        BusinessPlaceAccessRequest request = businessPlaceService.markRequestAsRead(id, userId);
        return ResponseEntity.ok(request);
    }

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
