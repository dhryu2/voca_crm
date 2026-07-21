package com.vocacrm.api.service;

import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.MemoRepository;
import com.vocacrm.api.repository.ReservationRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import com.vocacrm.api.repository.VisitRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AccessControlServiceTest {

    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;
    @Mock
    private MemberRepository memberRepository;
    @Mock
    private MemoRepository memoRepository;
    @Mock
    private ReservationRepository reservationRepository;
    @Mock
    private VisitRepository visitRepository;
    @Mock
    private UserRepository userRepository;

    private AccessControlService accessControlService;

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @BeforeEach
    void setUp() {
        accessControlService = new AccessControlService(
                userBusinessPlaceRepository,
                memberRepository,
                memoRepository,
                reservationRepository,
                visitRepository,
                userRepository
        );
    }

    @Test
    void requireApprovedMembership_APPROVED_멤버십이_있으면_정상_반환한다() {
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(UUID.fromString(USER_ID))
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ubp));

        UserBusinessPlace result = accessControlService.requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);

        assertThat(result).isEqualTo(ubp);
    }

    @Test
    void requireApprovedMembership_멤버십이_없으면_AccessDeniedException을_던진다() {
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> accessControlService.requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void requireApprovedMembership_조회는_APPROVED_상태로만_수행한다() {
        // 상태 필터가 서비스 계층에서 항상 APPROVED로 위임되는지 검증한다.
        // PENDING·REJECTED 멤버십은 이 쿼리 조건상 조회되지 않으므로 접근이 거부된다.
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(UUID.fromString(USER_ID))
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ubp));

        accessControlService.requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);

        verify(userBusinessPlaceRepository).findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED);
    }

    @Test
    void requireRole_실제_역할이_OWNER면_정상_반환한다() {
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(UUID.fromString(USER_ID))
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ubp));

        UserBusinessPlace result = accessControlService.requireRole(USER_ID, BUSINESS_PLACE_ID, Role.OWNER);

        assertThat(result).isEqualTo(ubp);
    }

    @Test
    void requireRole_실제_역할이_MANAGER면_AccessDeniedException을_던진다() {
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(UUID.fromString(USER_ID))
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER)
                .status(AccessStatus.APPROVED)
                .build();
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ubp));

        assertThatThrownBy(() -> accessControlService.requireRole(USER_ID, BUSINESS_PLACE_ID, Role.OWNER))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void requireRole_실제_역할이_STAFF면_AccessDeniedException을_던진다() {
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(UUID.fromString(USER_ID))
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ubp));

        assertThatThrownBy(() -> accessControlService.requireRole(USER_ID, BUSINESS_PLACE_ID, Role.OWNER))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void currentDefaultBusinessPlace_사용자가_존재하면_기본사업장을_반환한다() {
        User user = User.builder()
                .id(UUID.fromString(USER_ID))
                .defaultBusinessPlaceId(BUSINESS_PLACE_ID)
                .build();
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.of(user));

        String result = accessControlService.currentDefaultBusinessPlace(USER_ID);

        assertThat(result).isEqualTo(BUSINESS_PLACE_ID);
    }

    @Test
    void currentDefaultBusinessPlace_사용자가_없으면_null을_반환한다() {
        when(userRepository.findById(UUID.fromString(USER_ID))).thenReturn(Optional.empty());

        String result = accessControlService.currentDefaultBusinessPlace(USER_ID);

        assertThat(result).isNull();
    }
}
