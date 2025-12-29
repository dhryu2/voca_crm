package com.vocacrm.api.controller;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Visit;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.VisitService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/visits")
@RequiredArgsConstructor
public class VisitController {

    private final VisitService visitService;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;

    /**
     * 사업장 접근 권한 검증
     */
    private void validateUserAccessToBusinessPlace(String userId, String businessPlaceId) {
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }
    }

    /**
     * 체크인 (회원 사업장 권한 체크)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     */
    @PostMapping("/checkin")
    public ResponseEntity<Visit> checkIn(
            @RequestBody Map<String, String> payload,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");
        String memberId = payload.get("memberId");
        String note = payload.get("note");

        if (memberId == null) {
            return ResponseEntity.badRequest().build();
        }

        // 회원이 사용자의 사업장에 속하는지 확인
        Visit visit = visitService.checkInWithUserCheck(memberId, userId, note);
        return ResponseEntity.ok(visit);
    }

    /**
     * 방문 기록 조회 (회원 사업장 권한 체크)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     */
    @GetMapping("/member/{memberId}")
    public ResponseEntity<List<Visit>> getVisitsByMember(
            @PathVariable String memberId,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 회원이 사용자의 사업장에 속하는지 확인
        List<Visit> visits = visitService.getVisitsByMemberWithUserCheck(memberId, userId);
        return ResponseEntity.ok(visits);
    }

    /**
     * 오늘 방문 기록 조회 (사업장별)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     */
    @GetMapping("/today/{businessPlaceId}")
    public ResponseEntity<List<Visit>> getTodayVisits(
            @PathVariable String businessPlaceId,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        List<Visit> visits = visitService.getTodayVisits(businessPlaceId);
        return ResponseEntity.ok(visits);
    }

    /**
     * 체크인 취소 (삭제)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     */
    @DeleteMapping("/{visitId}")
    public ResponseEntity<Void> cancelCheckIn(
            @PathVariable String visitId,
            @RequestParam String businessPlaceId,
            HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        validateUserAccessToBusinessPlace(userId, businessPlaceId);

        visitService.cancelCheckIn(visitId, businessPlaceId);
        return ResponseEntity.noContent().build();
    }
}
