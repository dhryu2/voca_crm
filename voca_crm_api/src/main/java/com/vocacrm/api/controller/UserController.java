package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.FcmTokenUpdateRequest;
import com.vocacrm.api.dto.request.PushNotificationUpdateRequest;
import com.vocacrm.api.dto.request.UserUpdateRequest;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.User;
import com.vocacrm.api.repository.UserRepository;
import com.vocacrm.api.service.AccessControlService;
import com.vocacrm.api.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;
    private final UserService userService;
    private final AccessControlService accessControlService;

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

        // 멤버십 검증: 실제 APPROVED 멤버십이 있는 사업장만 default로 설정 가능
        accessControlService.requireApprovedMembership(id, businessPlaceId);

        User user = userRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));

        user.setDefaultBusinessPlaceId(businessPlaceId);
        User updated = userRepository.save(user);
        return ResponseEntity.ok(updated);
    }

    @PutMapping("/{id}/fcm-token")
    public ResponseEntity<User> updateFcmToken(
            @PathVariable String id,
            @Valid @RequestBody FcmTokenUpdateRequest request,
            HttpServletRequest servletRequest) {
        String requestUserId = (String) servletRequest.getAttribute("userId");

        // IDOR 방어: 본인의 정보만 수정 가능
        if (!id.equals(requestUserId)) {
            throw new AccessDeniedException("본인의 정보만 수정할 수 있습니다.");
        }

        User user = userRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));

        user.setFcmToken(request.getFcmToken());
        User updated = userRepository.save(user);
        return ResponseEntity.ok(updated);
    }

    @PutMapping("/{id}/push-notification")
    public ResponseEntity<User> updatePushNotificationSetting(
            @PathVariable String id,
            @Valid @RequestBody PushNotificationUpdateRequest request,
            HttpServletRequest servletRequest) {
        String requestUserId = (String) servletRequest.getAttribute("userId");

        // IDOR 방어: 본인의 정보만 수정 가능
        if (!id.equals(requestUserId)) {
            throw new AccessDeniedException("본인의 정보만 수정할 수 있습니다.");
        }

        User user = userRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다."));

        user.setPushNotificationEnabled(request.getEnabled());
        User updated = userRepository.save(user);
        return ResponseEntity.ok(updated);
    }

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
