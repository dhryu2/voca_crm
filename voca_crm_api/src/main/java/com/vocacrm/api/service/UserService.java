package com.vocacrm.api.service;

import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.repository.BusinessPlaceAccessRequestRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * 사용자(User) 서비스
 *
 * 사용자 관련 비즈니스 로직을 처리합니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;
    private final BusinessPlaceAccessRequestRepository accessRequestRepository;
    private final BusinessPlaceService businessPlaceService;
    private final RefreshTokenService refreshTokenService;

    /**
     * 회원 탈퇴 처리
     *
     * 사용자가 등록된 모든 사업장에서 해당 사용자의 참조를 정리하고,
     * 관련 데이터를 삭제한 후 사용자를 삭제합니다.
     *
     * 처리 순서:
     * 1. 모든 등록된 사업장에서 사용자 참조 정리 (cleanupUserReferences)
     * 2. UserBusinessPlace 레코드 삭제
     * 3. 사용자가 보낸 접근 요청 삭제
     * 4. Refresh Token 폐기
     * 5. 사용자 삭제
     *
     * @param userId 탈퇴할 사용자 ID
     */
    @Transactional
    public void deleteUser(String userId) {
        User user = userRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new RuntimeException("User not found"));

        log.info("Starting user deletion process for userId: {}", userId);

        UUID userUuid = UUID.fromString(userId);

        // 0. 소유(OWNER) 중인 사업장이 있으면 삭제 거부 (고아 사업장 방지)
        long ownedBusinessPlaceCount = userBusinessPlaceRepository
                .countByUserIdAndRoleAndStatus(userUuid, Role.OWNER, AccessStatus.APPROVED);
        if (ownedBusinessPlaceCount > 0) {
            throw new InvalidInputException("소유한 사업장이 있어 계정을 삭제할 수 없습니다. 먼저 사업장을 삭제하거나 소유권을 이전한 뒤 다시 시도해주세요.");
        }

        // 1. 사용자가 등록된 모든 사업장에서 참조 정리
        List<UserBusinessPlace> userBusinessPlaces = userBusinessPlaceRepository.findByUserIdAndStatus(
                userUuid, AccessStatus.APPROVED);

        for (UserBusinessPlace ubp : userBusinessPlaces) {
            log.info("Cleaning up user references in businessPlaceId: {}", ubp.getBusinessPlaceId());
            businessPlaceService.cleanupUserReferences(ubp.getBusinessPlaceId(), userId);
        }

        // 2. UserBusinessPlace 레코드 삭제 (모든 상태)
        List<UserBusinessPlace> allUserBusinessPlaces = userBusinessPlaceRepository.findByUserId(userUuid);
        userBusinessPlaceRepository.deleteAll(allUserBusinessPlaces);
        log.info("Deleted {} UserBusinessPlace records", allUserBusinessPlaces.size());

        // 3. 사용자가 보낸 접근 요청 삭제
        accessRequestRepository.deleteByUserId(userUuid);
        log.info("Deleted access requests for userId: {}", userId);

        // 4. 모든 Refresh Token 폐기
        refreshTokenService.revokeAllUserTokens(userId);
        log.info("Revoked all refresh tokens for userId: {}", userId);

        // 5. 사용자 삭제
        userRepository.delete(user);
        log.info("User deleted successfully: {}", userId);
    }
}
