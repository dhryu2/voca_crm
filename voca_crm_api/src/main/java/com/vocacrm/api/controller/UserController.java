package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.UserUpdateRequest;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.User;
import com.vocacrm.api.repository.UserRepository;
import com.vocacrm.api.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
@Tag(name = "사용자", description = "사용자 프로필 관리 API")
public class UserController {

    private final UserRepository userRepository;
    private final UserService userService;

    @Operation(summary = "사용자 조회", description = "본인 정보만 조회 가능")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "403", description = "본인 정보만 조회 가능"),
            @ApiResponse(responseCode = "404", description = "사용자 없음")
    })
    @GetMapping("/{id}")
    public ResponseEntity<User> getUser(@PathVariable String id, HttpServletRequest servletRequest) {
        String requestUserId = (String) servletRequest.getAttribute("userId");

        // IDOR 방어: 본인의 정보만 조회 가능
        if (!id.equals(requestUserId)) {
            throw new AccessDeniedException("본인의 정보만 조회할 수 있습니다.");
        }

        User user = userRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));
        return ResponseEntity.ok(user);
    }

    @Operation(summary = "사용자 수정", description = "본인 정보만 수정 가능")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "수정 성공"),
            @ApiResponse(responseCode = "403", description = "본인 정보만 수정 가능"),
            @ApiResponse(responseCode = "404", description = "사용자 없음")
    })
    @PutMapping("/{id}")
    public ResponseEntity<User> updateUser(@PathVariable String id, @Valid @RequestBody UserUpdateRequest request, HttpServletRequest servletRequest) {
        String requestUserId = (String) servletRequest.getAttribute("userId");

        // IDOR 방어: 본인의 정보만 수정 가능
        if (!id.equals(requestUserId)) {
            throw new AccessDeniedException("본인의 정보만 수정할 수 있습니다.");
        }

        User user = userRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));

        // 사용자가 변경할 수 있는 필드만 업데이트
        if (request.getUsername() != null && !request.getUsername().isEmpty()) {
            user.setUsername(request.getUsername());
        }
        if (request.getEmail() != null && !request.getEmail().isEmpty()) {
            user.setEmail(request.getEmail());
        }
        if (request.getPhone() != null) {
            user.setPhone(request.getPhone());
        }

        User updated = userRepository.save(user);
        return ResponseEntity.ok(updated);
    }

    /**
     * 현재 로그인한 사용자 정보 수정 (PUT /users/me)
     * JWT에서 userId를 추출하여 본인 정보 수정
     */
    @Operation(summary = "내 정보 수정", description = "JWT 토큰 기반 본인 정보 수정")
    @ApiResponse(responseCode = "200", description = "수정 성공")
    @PutMapping("/me")
    public ResponseEntity<User> updateCurrentUser(@Valid @RequestBody UserUpdateRequest request, HttpServletRequest servletRequest) {
        String userId = (String) servletRequest.getAttribute("userId");

        User user = userRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));

        // 사용자가 변경할 수 있는 필드만 업데이트
        if (request.getUsername() != null && !request.getUsername().isEmpty()) {
            user.setUsername(request.getUsername());
        }
        if (request.getEmail() != null && !request.getEmail().isEmpty()) {
            user.setEmail(request.getEmail());
        }
        if (request.getPhone() != null) {
            user.setPhone(request.getPhone());
        }

        User updated = userRepository.save(user);
        return ResponseEntity.ok(updated);
    }

    @Operation(summary = "기본 사업장 변경", description = "사용자의 기본 사업장 ID 변경")
    @ApiResponse(responseCode = "200", description = "변경 성공")
    @PutMapping("/{id}/default-business-place")
    public ResponseEntity<User> updateDefaultBusinessPlace(
            @PathVariable String id,
            @RequestParam String businessPlaceId,
            HttpServletRequest servletRequest) {
        String requestUserId = (String) servletRequest.getAttribute("userId");

        // IDOR 방어: 본인의 정보만 수정 가능
        if (!id.equals(requestUserId)) {
            throw new AccessDeniedException("본인의 정보만 수정할 수 있습니다.");
        }

        User user = userRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));

        user.setDefaultBusinessPlaceId(businessPlaceId);
        User updated = userRepository.save(user);
        return ResponseEntity.ok(updated);
    }

    @Operation(summary = "FCM 토큰 업데이트", description = "푸시 알림용 FCM 토큰 갱신")
    @ApiResponse(responseCode = "200", description = "업데이트 성공")
    @PutMapping("/{id}/fcm-token")
    public ResponseEntity<User> updateFcmToken(
            @PathVariable String id,
            @RequestParam String fcmToken,
            HttpServletRequest servletRequest) {
        String requestUserId = (String) servletRequest.getAttribute("userId");

        // IDOR 방어: 본인의 정보만 수정 가능
        if (!id.equals(requestUserId)) {
            throw new AccessDeniedException("본인의 정보만 수정할 수 있습니다.");
        }

        User user = userRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));

        user.setFcmToken(fcmToken);
        User updated = userRepository.save(user);
        return ResponseEntity.ok(updated);
    }

    @Operation(summary = "푸시 알림 설정", description = "푸시 알림 on/off 설정")
    @ApiResponse(responseCode = "200", description = "설정 변경 성공")
    @PutMapping("/{id}/push-notification")
    public ResponseEntity<User> updatePushNotificationSetting(
            @PathVariable String id,
            @RequestParam Boolean enabled,
            HttpServletRequest servletRequest) {
        String requestUserId = (String) servletRequest.getAttribute("userId");

        // IDOR 방어: 본인의 정보만 수정 가능
        if (!id.equals(requestUserId)) {
            throw new AccessDeniedException("본인의 정보만 수정할 수 있습니다.");
        }

        User user = userRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));

        user.setPushNotificationEnabled(enabled);
        User updated = userRepository.save(user);
        return ResponseEntity.ok(updated);
    }

    @Operation(summary = "회원 탈퇴", description = "사용자 계정 삭제 (본인만 가능)")
    @ApiResponses({
            @ApiResponse(responseCode = "204", description = "탈퇴 성공"),
            @ApiResponse(responseCode = "403", description = "본인만 탈퇴 가능")
    })
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable String id, HttpServletRequest servletRequest) {
        String requestUserId = (String) servletRequest.getAttribute("userId");

        // IDOR 방어: 본인의 정보만 삭제 가능
        if (!id.equals(requestUserId)) {
            throw new AccessDeniedException("본인의 정보만 삭제할 수 있습니다.");
        }

        // UserService를 통해 회원 탈퇴 처리
        // (모든 사업장에서 사용자 참조 정리 후 삭제)
        userService.deleteUser(id);

        return ResponseEntity.noContent().build();
    }
}
