package com.vocacrm.api.service;

import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.repository.BusinessPlaceAccessRequestRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;

    @Mock
    private BusinessPlaceAccessRequestRepository accessRequestRepository;

    @Mock
    private BusinessPlaceService businessPlaceService;

    @Mock
    private RefreshTokenService refreshTokenService;

    @InjectMocks
    private UserService userService;

    @Test
    void deleteUser_정상_케이스면_참조_정리_후_사용자를_삭제한다() {
        UUID userUuid = UUID.randomUUID();
        String userId = userUuid.toString();
        User user = User.builder().id(userUuid).build();

        when(userRepository.findById(userUuid)).thenReturn(Optional.of(user));
        when(userBusinessPlaceRepository.countByUserIdAndRoleAndStatus(userUuid, Role.OWNER, AccessStatus.APPROVED))
                .thenReturn(0L);
        when(userBusinessPlaceRepository.findByUserId(userUuid)).thenReturn(List.of());

        userService.deleteUser(userId);

        // 모든 정리 메서드 호출 검증
        verify(businessPlaceService).cleanupUserReferencesGlobal(userId);
        verify(userBusinessPlaceRepository).deleteAll(List.of());
        verify(accessRequestRepository).deleteByUserId(userUuid);
        verify(accessRequestRepository).clearProcessedByByUserId(userUuid);
        verify(refreshTokenService).revokeAllUserTokens(userId);
        verify(userRepository).delete(user);

        // 정리가 사용자 삭제보다 먼저 수행되는 순서 검증
        InOrder inOrder = inOrder(
                businessPlaceService, userBusinessPlaceRepository, accessRequestRepository,
                refreshTokenService, userRepository);
        inOrder.verify(businessPlaceService).cleanupUserReferencesGlobal(userId);
        inOrder.verify(userBusinessPlaceRepository).deleteAll(List.of());
        inOrder.verify(accessRequestRepository).deleteByUserId(userUuid);
        inOrder.verify(accessRequestRepository).clearProcessedByByUserId(userUuid);
        inOrder.verify(refreshTokenService).revokeAllUserTokens(userId);
        inOrder.verify(userRepository).delete(user);
    }

    @Test
    void deleteUser_사용자가_없으면_ResourceNotFoundException을_던진다() {
        UUID userUuid = UUID.randomUUID();
        String userId = userUuid.toString();

        when(userRepository.findById(userUuid)).thenReturn(Optional.empty());

        // 404로 매핑되는 예외(ResourceNotFoundException)여야 재시도 시 500이 아닌 404가 나간다
        assertThatThrownBy(() -> userService.deleteUser(userId))
                .isInstanceOf(ResourceNotFoundException.class);

        verify(userRepository, never()).delete(any(User.class));
    }

    @Test
    void deleteUser_소유_사업장이_있으면_예외를_던지고_삭제하지_않는다() {
        UUID userUuid = UUID.randomUUID();
        String userId = userUuid.toString();
        User user = User.builder().id(userUuid).build();

        when(userRepository.findById(userUuid)).thenReturn(Optional.of(user));
        when(userBusinessPlaceRepository.countByUserIdAndRoleAndStatus(userUuid, Role.OWNER, AccessStatus.APPROVED))
                .thenReturn(1L);

        assertThatThrownBy(() -> userService.deleteUser(userId))
                .isInstanceOf(InvalidInputException.class);

        // 차단 시 정리/삭제가 수행되지 않아야 함
        verify(businessPlaceService, never()).cleanupUserReferencesGlobal(userId);
        verify(userRepository, never()).delete(user);
    }
}
