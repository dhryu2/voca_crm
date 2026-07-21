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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String OTHER_USER_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private UserRepository userRepository;
    @Mock
    private UserService userService;
    @Mock
    private AccessControlService accessControlService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private UserController userController;

    @BeforeEach
    void setUp() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
    }

    @Test
    void getUser_본인_조회는_정상적으로_반환된다() {
        User user = User.builder().id(UUID.fromString(USER_ID)).username("홍길동").build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.of(user));

        ResponseEntity<User> response = userController.getUser(USER_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(user);
    }

    @Test
    void getUser_타인_조회시_AccessDeniedException() {
        assertThatThrownBy(() -> userController.getUser(OTHER_USER_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getUser_존재하지_않는_사용자면_ResourceNotFoundException() {
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userController.getUser(USER_ID, servletRequest))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void updateUser_본인_수정은_정상적으로_반영된다() {
        User user = User.builder().id(UUID.fromString(USER_ID)).username("old").build();
        UserUpdateRequest request = UserUpdateRequest.builder()
                .username("new")
                .email("new@test.com")
                .phone("010-1234-5678")
                .build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.of(user));
        when(userRepository.save(user)).thenReturn(user);

        ResponseEntity<User> response = userController.updateUser(USER_ID, request, servletRequest);

        assertThat(user.getUsername()).isEqualTo("new");
        assertThat(user.getEmail()).isEqualTo("new@test.com");
        assertThat(user.getPhone()).isEqualTo("010-1234-5678");
        assertThat(response.getBody()).isSameAs(user);
    }

    @Test
    void updateUser_타인_수정시_AccessDeniedException() {
        UserUpdateRequest request = UserUpdateRequest.builder().username("new").build();

        assertThatThrownBy(() -> userController.updateUser(OTHER_USER_ID, request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void updateUser_존재하지_않는_사용자면_ResourceNotFoundException() {
        UserUpdateRequest request = UserUpdateRequest.builder().username("new").build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userController.updateUser(USER_ID, request, servletRequest))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void updateCurrentUser_JWT_userId로_본인_정보를_수정한다() {
        User user = User.builder().id(UUID.fromString(USER_ID)).username("old").build();
        UserUpdateRequest request = UserUpdateRequest.builder()
                .username("new")
                .phone("010-9999-9999")
                .build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.of(user));
        when(userRepository.save(user)).thenReturn(user);

        ResponseEntity<User> response = userController.updateCurrentUser(request, servletRequest);

        assertThat(user.getUsername()).isEqualTo("new");
        assertThat(user.getPhone()).isEqualTo("010-9999-9999");
        assertThat(response.getBody()).isSameAs(user);
    }

    @Test
    void updateCurrentUser_존재하지_않는_사용자면_ResourceNotFoundException() {
        UserUpdateRequest request = UserUpdateRequest.builder().username("new").build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userController.updateCurrentUser(request, servletRequest))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void updateDefaultBusinessPlace_본인이고_멤버십이_있으면_정상_반영된다() {
        User user = User.builder().id(UUID.fromString(USER_ID)).build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.of(user));
        when(userRepository.save(user)).thenReturn(user);

        ResponseEntity<User> response = userController.updateDefaultBusinessPlace(USER_ID, BUSINESS_PLACE_ID, servletRequest);

        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        assertThat(user.getDefaultBusinessPlaceId()).isEqualTo(BUSINESS_PLACE_ID);
        assertThat(response.getBody()).isSameAs(user);
    }

    @Test
    void updateDefaultBusinessPlace_타인이면_AccessDeniedException() {
        assertThatThrownBy(() -> userController.updateDefaultBusinessPlace(OTHER_USER_ID, BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void updateDefaultBusinessPlace_멤버십_검증_실패시_AccessDeniedException_전파() {
        when(accessControlService.requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID))
                .thenThrow(new AccessDeniedException("해당 사업장에 대한 접근 권한이 없습니다."));

        assertThatThrownBy(() -> userController.updateDefaultBusinessPlace(USER_ID, BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void updateFcmToken_본인이면_토큰이_갱신된다() {
        User user = User.builder().id(UUID.fromString(USER_ID)).build();
        FcmTokenUpdateRequest request = FcmTokenUpdateRequest.builder().fcmToken("fcm-token-abc").build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.of(user));
        when(userRepository.save(user)).thenReturn(user);

        ResponseEntity<User> response = userController.updateFcmToken(USER_ID, request, servletRequest);

        assertThat(user.getFcmToken()).isEqualTo("fcm-token-abc");
        assertThat(response.getBody()).isSameAs(user);
    }

    @Test
    void updateFcmToken_타인이면_AccessDeniedException() {
        FcmTokenUpdateRequest request = FcmTokenUpdateRequest.builder().fcmToken("fcm-token-abc").build();

        assertThatThrownBy(() -> userController.updateFcmToken(OTHER_USER_ID, request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void updatePushNotificationSetting_본인이면_설정이_갱신된다() {
        User user = User.builder().id(UUID.fromString(USER_ID)).build();
        PushNotificationUpdateRequest request = PushNotificationUpdateRequest.builder().enabled(false).build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.of(user));
        when(userRepository.save(user)).thenReturn(user);

        ResponseEntity<User> response = userController.updatePushNotificationSetting(USER_ID, request, servletRequest);

        assertThat(user.getPushNotificationEnabled()).isFalse();
        assertThat(response.getBody()).isSameAs(user);
    }

    @Test
    void updatePushNotificationSetting_타인이면_AccessDeniedException() {
        PushNotificationUpdateRequest request = PushNotificationUpdateRequest.builder().enabled(false).build();

        assertThatThrownBy(() -> userController.updatePushNotificationSetting(OTHER_USER_ID, request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void deleteUser_본인이면_회원탈퇴가_수행된다() {
        ResponseEntity<Void> response = userController.deleteUser(USER_ID, servletRequest);

        verify(userService).deleteUser(USER_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void deleteUser_타인이면_AccessDeniedException() {
        assertThatThrownBy(() -> userController.deleteUser(OTHER_USER_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }
}
