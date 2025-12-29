package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.ReservationCreateRequest;
import com.vocacrm.api.dto.request.ReservationUpdateRequest;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Reservation;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.MemberService;
import com.vocacrm.api.service.ReservationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 예약 관리 컨트롤러
 */
@Slf4j
@RestController
@RequestMapping("/api/reservations")
@RequiredArgsConstructor
public class ReservationController {

    private final ReservationService reservationService;
    private final MemberService memberService;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;

    /**
     * 예약 생성
     * POST /api/reservations
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 해당 사업장에 접근 권한이 있는지 확인
     */
    @PostMapping
    public ResponseEntity<Reservation> createReservation(
            @Valid @RequestBody ReservationCreateRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), request.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        Reservation reservation = new Reservation();
        if (request.getMemberId() != null) {
            reservation.setMemberId(UUID.fromString(request.getMemberId()));
        }
        reservation.setBusinessPlaceId(request.getBusinessPlaceId());
        reservation.setReservationDate(request.getReservationDate());
        reservation.setReservationTime(request.getReservationTime());
        reservation.setServiceType(request.getServiceType());
        reservation.setDurationMinutes(request.getDurationMinutes() != null ? request.getDurationMinutes() : 60);
        reservation.setNotes(request.getNotes());
        reservation.setRemark(request.getRemark());
        if (request.getCreatedBy() != null) {
            reservation.setCreatedBy(UUID.fromString(request.getCreatedBy()));
        }
        if (request.getStatus() != null) {
            reservation.setStatus(request.getStatus());
        }

        Reservation created = reservationService.createReservation(reservation);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    /**
     * 예약 조회 by ID
     * GET /api/reservations/{id}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 예약의 사업장에 접근 권한이 있는지 확인
     */
    @GetMapping("/{id}")
    public ResponseEntity<Reservation> getReservation(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        Reservation reservation = reservationService.getReservationById(UUID.fromString(id));

        // 예약의 사업장에 대한 접근 권한 확인
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), reservation.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 예약에 대한 접근 권한이 없습니다.");
        }

        return ResponseEntity.ok(reservation);
    }

    /**
     * 회원의 예약 목록 조회
     * GET /api/reservations/member/{memberId}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 회원의 사업장에 접근 권한이 있는지 확인
     */
    @GetMapping("/member/{memberId}")
    public ResponseEntity<List<Reservation>> getReservationsByMember(
            @PathVariable String memberId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 회원이 사용자의 사업장에 속하는지 확인
        Member member = memberService.getMemberById(memberId);

        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), member.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 회원의 예약에 대한 접근 권한이 없습니다.");
        }

        List<Reservation> reservations = reservationService.getReservationsByMemberId(UUID.fromString(memberId), member.getBusinessPlaceId());
        return ResponseEntity.ok(reservations);
    }

    /**
     * 사업장의 예약 목록 조회
     * GET /api/reservations/business-place/{businessPlaceId}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 해당 사업장에 접근 권한이 있는지 확인
     */
    @GetMapping("/business-place/{businessPlaceId}")
    public ResponseEntity<List<Reservation>> getReservationsByBusinessPlace(
            @PathVariable String businessPlaceId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        List<Reservation> reservations = reservationService.getReservationsByBusinessPlaceId(businessPlaceId);
        return ResponseEntity.ok(reservations);
    }

    /**
     * 사업장의 특정 날짜 예약 목록 조회
     * GET /api/reservations/business-place/{businessPlaceId}/date/{date}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 해당 사업장에 접근 권한이 있는지 확인
     */
    @GetMapping("/business-place/{businessPlaceId}/date/{date}")
    public ResponseEntity<List<Reservation>> getReservationsByDate(
            @PathVariable String businessPlaceId,
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        List<Reservation> reservations = reservationService.getReservationsByBusinessPlaceAndDate(businessPlaceId, date);
        return ResponseEntity.ok(reservations);
    }

    /**
     * 사업장의 날짜 범위 예약 목록 조회
     * GET /api/reservations/business-place/{businessPlaceId}/range?startDate={startDate}&endDate={endDate}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 해당 사업장에 접근 권한이 있는지 확인
     */
    @GetMapping("/business-place/{businessPlaceId}/range")
    public ResponseEntity<List<Reservation>> getReservationsByDateRange(
            @PathVariable String businessPlaceId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        List<Reservation> reservations = reservationService.getReservationsByDateRange(businessPlaceId, startDate, endDate);
        return ResponseEntity.ok(reservations);
    }

    /**
     * 사업장의 특정 상태 예약 목록 조회
     * GET /api/reservations/business-place/{businessPlaceId}/status/{status}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 해당 사업장에 접근 권한이 있는지 확인
     */
    @GetMapping("/business-place/{businessPlaceId}/status/{status}")
    public ResponseEntity<List<Reservation>> getReservationsByStatus(
            @PathVariable String businessPlaceId,
            @PathVariable Reservation.ReservationStatus status,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        List<Reservation> reservations = reservationService.getReservationsByStatus(businessPlaceId, status);
        return ResponseEntity.ok(reservations);
    }

    /**
     * 예약 수정
     * PUT /api/reservations/{id}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 예약의 사업장에 접근 권한이 있는지 확인
     */
    @PutMapping("/{id}")
    public ResponseEntity<Reservation> updateReservation(
            @PathVariable String id,
            @Valid @RequestBody ReservationUpdateRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 기존 예약 조회
        Reservation existing = reservationService.getReservationById(UUID.fromString(id));

        // 예약의 사업장에 대한 접근 권한 확인
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), existing.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 예약에 대한 수정 권한이 없습니다.");
        }

        Reservation reservation = new Reservation();
        reservation.setReservationDate(request.getReservationDate());
        reservation.setReservationTime(request.getReservationTime());
        reservation.setServiceType(request.getServiceType());
        reservation.setDurationMinutes(request.getDurationMinutes());
        reservation.setNotes(request.getNotes());
        reservation.setRemark(request.getRemark());
        if (request.getUpdatedBy() != null) {
            reservation.setUpdatedBy(UUID.fromString(request.getUpdatedBy()));
        }
        if (request.getStatus() != null) {
            reservation.setStatus(request.getStatus());
        }

        Reservation updated = reservationService.updateReservation(UUID.fromString(id), reservation);
        return ResponseEntity.ok(updated);
    }

    /**
     * 예약 상태 변경
     * PATCH /api/reservations/{id}/status
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 예약의 사업장에 접근 권한이 있는지 확인
     */
    @PatchMapping("/{id}/status")
    public ResponseEntity<Reservation> updateReservationStatus(
            @PathVariable String id,
            @RequestBody Map<String, String> body,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 기존 예약 조회
        Reservation existing = reservationService.getReservationById(UUID.fromString(id));

        // 예약의 사업장에 대한 접근 권한 확인
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), existing.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 예약에 대한 상태 변경 권한이 없습니다.");
        }

        String statusStr = body.get("status");
        if (statusStr == null) {
            throw new IllegalArgumentException("status 필드가 필요합니다");
        }

        String updatedBy = body.get("updatedBy");

        Reservation.ReservationStatus status = Reservation.ReservationStatus.valueOf(statusStr.toUpperCase());
        Reservation updated = reservationService.updateReservationStatus(
                UUID.fromString(id),
                status,
                updatedBy != null ? UUID.fromString(updatedBy) : null);
        return ResponseEntity.ok(updated);
    }

    // 예약 삭제 API는 의도적으로 제공하지 않음
    // - 고객 취소: 상태를 CANCELLED로 변경
    // - 노쇼: 상태를 NO_SHOW로 변경
    // - 오래된 데이터: 스케줄러가 1년 후 자동 삭제 (ReservationCleanupScheduler)

    /**
     * 특정 날짜의 예약 개수 조회
     * GET /api/reservations/business-place/{businessPlaceId}/count?date={date}
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 해당 사업장에 접근 권한이 있는지 확인
     */
    @GetMapping("/business-place/{businessPlaceId}/count")
    public ResponseEntity<Map<String, Object>> getReservationCount(
            @PathVariable String businessPlaceId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 사업장 접근 권한 검증
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        Long count;
        if (date != null) {
            count = reservationService.getReservationCountByDate(businessPlaceId, date);
        } else {
            count = reservationService.getTodayReservationCount(businessPlaceId);
            date = LocalDate.now();
        }

        Map<String, Object> response = new HashMap<>();
        response.put("businessPlaceId", businessPlaceId);
        response.put("date", date);
        response.put("count", count);

        return ResponseEntity.ok(response);
    }

    /**
     * 회원의 예약 통계 조회
     * GET /api/reservations/member/{memberId}/stats
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * 권한 검증: 사용자가 회원의 사업장에 접근 권한이 있는지 확인
     */
    @GetMapping("/member/{memberId}/stats")
    public ResponseEntity<Map<String, Object>> getMemberReservationStats(
            @PathVariable String memberId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        // 회원이 사용자의 사업장에 속하는지 확인
        Member member = memberService.getMemberById(memberId);

        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), member.getBusinessPlaceId(), AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 회원의 예약에 대한 접근 권한이 없습니다.");
        }

        Long totalCount = reservationService.getMemberReservationCount(UUID.fromString(memberId), member.getBusinessPlaceId());
        Long completedCount = reservationService.getMemberCompletedReservationCount(UUID.fromString(memberId), member.getBusinessPlaceId());

        Map<String, Object> stats = new HashMap<>();
        stats.put("memberId", memberId);
        stats.put("totalReservations", totalCount);
        stats.put("completedReservations", completedCount);

        return ResponseEntity.ok(stats);
    }
}
