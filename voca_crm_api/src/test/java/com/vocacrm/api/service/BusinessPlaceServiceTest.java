package com.vocacrm.api.service;

import com.vocacrm.api.dto.AccessRequestWithRequesterDTO;
import com.vocacrm.api.dto.BusinessPlaceDeletionPreviewDTO;
import com.vocacrm.api.dto.BusinessPlaceMemberDTO;
import com.vocacrm.api.dto.BusinessPlaceWithRoleDTO;
import com.vocacrm.api.dto.CreateBusinessPlaceResponse;
import com.vocacrm.api.dto.SetDefaultBusinessPlaceResponse;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.BusinessPlaceAccessRequest;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.repository.AuditLogRepository;
import com.vocacrm.api.repository.BusinessPlaceAccessRequestRepository;
import com.vocacrm.api.repository.BusinessPlaceRepository;
import com.vocacrm.api.repository.ErrorLogRepository;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.MemoRepository;
import com.vocacrm.api.repository.ReservationRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import com.vocacrm.api.repository.VisitRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BusinessPlaceServiceTest {

    @Mock
    private BusinessPlaceRepository businessPlaceRepository;

    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private BusinessPlaceAccessRequestRepository accessRequestRepository;

    @Mock
    private EntityManager entityManager;

    @Mock
    private AccessControlService accessControlService;

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private MemoRepository memoRepository;

    @Mock
    private ReservationRepository reservationRepository;

    @Mock
    private VisitRepository visitRepository;

    @Mock
    private AuditLogRepository auditLogRepository;

    @Mock
    private ErrorLogRepository errorLogRepository;

    @Mock
    private FCMService fcmService;

    @InjectMocks
    private BusinessPlaceService businessPlaceService;

    @Test
    void cleanupUserReferencesGlobal_모든_참조_정리_메서드를_해당_userId로_한번씩_호출한다() {
        UUID userUuid = UUID.randomUUID();
        String userId = userUuid.toString();

        businessPlaceService.cleanupUserReferencesGlobal(userId);

        // Member 테이블 정리 3종
        verify(memberRepository).clearOwnerIdByUserId(userUuid);
        verify(memberRepository).clearLastModifiedByIdByUserId(userUuid);
        verify(memberRepository).clearDeletedByByUserId(userUuid);

        // Memo 테이블 정리 3종
        verify(memoRepository).clearOwnerIdByUserId(userUuid);
        verify(memoRepository).clearLastModifiedByIdByUserId(userUuid);
        verify(memoRepository).clearDeletedByByUserId(userUuid);

        // Reservation 테이블 정리 2종
        verify(reservationRepository).clearCreatedByByUserId(userUuid);
        verify(reservationRepository).clearUpdatedByByUserId(userUuid);

        // Visit 테이블 정리
        verify(visitRepository).clearVisitorIdByUserId(userUuid);

        // AuditLog 테이블 정리
        verify(auditLogRepository).clearUserIdByUserId(userUuid);
    }

    @Test
    void createBusinessPlace_정상_생성된다() {
        String userId = UUID.randomUUID().toString();
        User user = User.builder()
                .id(UUID.fromString(userId))
                .username("tester")
                .displayName("테스터")
                .email("tester@example.com")
                .tier("FREE")
                .defaultBusinessPlaceId(null)
                .build();
        BusinessPlace newPlace = BusinessPlace.builder()
                .name("테스트 사업장")
                .address("서울시")
                .phone("010-1234-5678")
                .build();

        when(userRepository.findById(UUID.fromString(userId))).thenReturn(Optional.of(user));
        when(userBusinessPlaceRepository.countByUserIdAndRoleAndStatus(
                UUID.fromString(userId), Role.OWNER, AccessStatus.APPROVED)).thenReturn(0L);
        when(businessPlaceRepository.existsById(anyString())).thenReturn(false);
        when(businessPlaceRepository.save(any(BusinessPlace.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        CreateBusinessPlaceResponse response = businessPlaceService.createBusinessPlace(newPlace, userId);

        assertThat(response.getBusinessPlaceName()).isEqualTo("테스트 사업장");
        assertThat(response.getBusinessPlaceId()).isNotNull();
        assertThat(response.getDefaultBusinessPlaceId()).isEqualTo(response.getBusinessPlaceId());
        verify(userBusinessPlaceRepository).save(any(UserBusinessPlace.class));
    }

    @Test
    void updateBusinessPlace_requireRole이_정상_통과하면_수정된다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlace existing = BusinessPlace.builder()
                .id(businessPlaceId)
                .name("기존이름")
                .address("기존주소")
                .phone("010-0000-0000")
                .build();
        BusinessPlace updateRequest = BusinessPlace.builder()
                .name("새이름")
                .address("새주소")
                .phone("010-9999-9999")
                .build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(existing));
        when(businessPlaceRepository.save(any(BusinessPlace.class))).thenAnswer(invocation -> invocation.getArgument(0));

        BusinessPlace result = businessPlaceService.updateBusinessPlace(businessPlaceId, updateRequest, userId);

        verify(accessControlService).requireRole(userId, businessPlaceId, Role.OWNER);
        assertThat(result.getName()).isEqualTo("새이름");
        assertThat(result.getAddress()).isEqualTo("새주소");
        assertThat(result.getPhone()).isEqualTo("010-9999-9999");
    }

    @Test
    void updateBusinessPlace_requireRole이_AccessDeniedException을_던지면_전파된다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlace updateRequest = BusinessPlace.builder().name("새이름").build();

        doThrow(new AccessDeniedException("이 작업을 수행할 권한이 없습니다."))
                .when(accessControlService).requireRole(userId, businessPlaceId, Role.OWNER);

        assertThatThrownBy(() -> businessPlaceService.updateBusinessPlace(businessPlaceId, updateRequest, userId))
                .isInstanceOf(AccessDeniedException.class);

        verify(businessPlaceRepository, never()).save(any());
    }

    @Test
    void setDefaultBusinessPlace_requireApprovedMembership이_정상_통과하면_정상_처리된다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        User user = User.builder()
                .id(UUID.fromString(userId))
                .username("tester")
                .build();

        when(userRepository.findById(UUID.fromString(userId))).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        SetDefaultBusinessPlaceResponse response = businessPlaceService.setDefaultBusinessPlace(userId, businessPlaceId);

        verify(accessControlService).requireApprovedMembership(userId, businessPlaceId);
        assertThat(response.getDefaultBusinessPlaceId()).isEqualTo(businessPlaceId);
    }

    @Test
    void setDefaultBusinessPlace_requireApprovedMembership이_예외를_던지면_전파된다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";

        doThrow(new AccessDeniedException("해당 사업장에 대한 접근 권한이 없습니다."))
                .when(accessControlService).requireApprovedMembership(userId, businessPlaceId);

        assertThatThrownBy(() -> businessPlaceService.setDefaultBusinessPlace(userId, businessPlaceId))
                .isInstanceOf(AccessDeniedException.class);

        verify(userRepository, never()).save(any());
    }

    @Test
    void getBusinessPlaceMembers_requireApprovedMembership이_정상_통과하면_멤버목록을_반환한다() {
        String requesterId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UUID memberUserId = UUID.randomUUID();
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .id(UUID.randomUUID())
                .userId(memberUserId)
                .businessPlaceId(businessPlaceId)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .createdAt(LocalDateTime.now())
                .build();
        User memberUser = User.builder()
                .id(memberUserId)
                .username("owner")
                .build();

        when(userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(businessPlaceId, AccessStatus.APPROVED))
                .thenReturn(List.of(ubp));
        when(userRepository.findById(memberUserId)).thenReturn(Optional.of(memberUser));

        List<BusinessPlaceMemberDTO> result = businessPlaceService.getBusinessPlaceMembers(businessPlaceId, requesterId);

        verify(accessControlService).requireApprovedMembership(requesterId, businessPlaceId);
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getUsername()).isEqualTo("owner");
    }

    @Test
    void removeMember_requireRole이_정상_통과하면_정상_처리된다() {
        String ownerId = UUID.randomUUID().toString();
        UUID targetUbpId = UUID.randomUUID();
        UUID targetUserId = UUID.randomUUID();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace targetUbp = UserBusinessPlace.builder()
                .id(targetUbpId)
                .userId(targetUserId)
                .businessPlaceId(businessPlaceId)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();
        User targetUser = User.builder()
                .id(targetUserId)
                .defaultBusinessPlaceId(businessPlaceId)
                .build();

        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.of(targetUbp));
        when(userRepository.findById(targetUserId)).thenReturn(Optional.of(targetUser));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        businessPlaceService.removeMember(targetUbpId, ownerId);

        verify(accessControlService).requireRole(ownerId, businessPlaceId, Role.OWNER);
        verify(userBusinessPlaceRepository).delete(targetUbp);
        verify(memberRepository).clearOwnerIdByBusinessPlaceIdAndUserId(businessPlaceId, targetUserId);
    }

    @Test
    void deleteBusinessPlacePermanently_requireRole이_정상_통과하면_관련_리포지토리_삭제_메서드가_호출된다() {
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        String confirmName = "테스트 사업장";
        BusinessPlace businessPlace = BusinessPlace.builder()
                .id(businessPlaceId)
                .name(confirmName)
                .build();
        List<UUID> memberIds = List.of(UUID.randomUUID());

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(businessPlace));
        when(memberRepository.findMemberIdsByBusinessPlaceId(businessPlaceId)).thenReturn(memberIds);

        businessPlaceService.deleteBusinessPlacePermanently(businessPlaceId, ownerId, confirmName);

        verify(accessControlService).requireRole(ownerId, businessPlaceId, Role.OWNER);
        verify(userRepository).clearDefaultBusinessPlaceId(businessPlaceId);
        verify(memoRepository).deleteAllByMemberIds(memberIds);
        verify(visitRepository).deleteAllByMemberIds(memberIds);
        verify(reservationRepository).deleteAllByBusinessPlaceId(businessPlaceId);
        verify(auditLogRepository).deleteAllByBusinessPlaceId(businessPlaceId);
        verify(errorLogRepository).deleteAllByBusinessPlaceId(businessPlaceId);
        verify(memberRepository).deleteAllByBusinessPlaceId(businessPlaceId);
        verify(accessRequestRepository).deleteAllByBusinessPlaceId(businessPlaceId);
        verify(userBusinessPlaceRepository).deleteAllByBusinessPlaceId(businessPlaceId);
        verify(businessPlaceRepository).delete(businessPlace);
    }

    @Test
    void createBusinessPlace_사용자가_없으면_ResourceNotFoundException을_던진다() {
        String userId = UUID.randomUUID().toString();
        BusinessPlace newPlace = BusinessPlace.builder().name("사업장").build();

        when(userRepository.findById(UUID.fromString(userId))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> businessPlaceService.createBusinessPlace(newPlace, userId))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void createBusinessPlace_사업장_생성_한도를_초과하면_InvalidInputException을_던진다() {
        String userId = UUID.randomUUID().toString();
        User user = User.builder()
                .id(UUID.fromString(userId))
                .tier("FREE")
                .build();
        BusinessPlace newPlace = BusinessPlace.builder().name("사업장").build();

        when(userRepository.findById(UUID.fromString(userId))).thenReturn(Optional.of(user));
        when(userBusinessPlaceRepository.countByUserIdAndRoleAndStatus(
                UUID.fromString(userId), Role.OWNER, AccessStatus.APPROVED)).thenReturn(3L);

        assertThatThrownBy(() -> businessPlaceService.createBusinessPlace(newPlace, userId))
                .isInstanceOf(InvalidInputException.class);

        verify(businessPlaceRepository, never()).save(any());
    }

    @Test
    void createBusinessPlace_기본_사업장이_이미_있으면_사용자를_저장하지_않는다() {
        String userId = UUID.randomUUID().toString();
        User user = User.builder()
                .id(UUID.fromString(userId))
                .tier("FREE")
                .defaultBusinessPlaceId("EXIST99")
                .build();
        BusinessPlace newPlace = BusinessPlace.builder().name("사업장").build();

        when(userRepository.findById(UUID.fromString(userId))).thenReturn(Optional.of(user));
        when(userBusinessPlaceRepository.countByUserIdAndRoleAndStatus(
                UUID.fromString(userId), Role.OWNER, AccessStatus.APPROVED)).thenReturn(0L);
        when(businessPlaceRepository.existsById(anyString())).thenReturn(false);
        when(businessPlaceRepository.save(any(BusinessPlace.class))).thenAnswer(invocation -> invocation.getArgument(0));

        businessPlaceService.createBusinessPlace(newPlace, userId);

        verify(userRepository, never()).save(any());
    }

    @Test
    void getMyBusinessPlaces_소속_사업장이_없으면_빈_리스트를_반환한다() {
        String userId = UUID.randomUUID().toString();
        when(userBusinessPlaceRepository.findByUserIdAndStatus(UUID.fromString(userId), AccessStatus.APPROVED))
                .thenReturn(List.of());

        List<BusinessPlaceWithRoleDTO> result = businessPlaceService.getMyBusinessPlaces(userId);

        assertThat(result).isEmpty();
    }

    @Test
    void getMyBusinessPlaces_사업장_목록과_멤버수를_반환한다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(UUID.fromString(userId))
                .businessPlaceId(businessPlaceId)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("사업장").build();

        when(userBusinessPlaceRepository.findByUserIdAndStatus(UUID.fromString(userId), AccessStatus.APPROVED))
                .thenReturn(List.of(ubp));
        when(businessPlaceRepository.findAllById(List.of(businessPlaceId))).thenReturn(List.of(bp));
        List<Object[]> memberCountRows = new java.util.ArrayList<>();
        memberCountRows.add(new Object[]{businessPlaceId, 5L});
        when(userBusinessPlaceRepository.countMembersGroupByBusinessPlaceId(List.of(businessPlaceId)))
                .thenReturn(memberCountRows);

        List<BusinessPlaceWithRoleDTO> result = businessPlaceService.getMyBusinessPlaces(userId);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getMemberCount()).isEqualTo(5);
        assertThat(result.get(0).getUserRole()).isEqualTo(Role.OWNER);
    }

    @Test
    void getBusinessPlaceById_없으면_ResourceNotFoundException을_던진다() {
        when(businessPlaceRepository.findById("NONE999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> businessPlaceService.getBusinessPlaceById("NONE999"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void requestAccess_정상_요청을_생성한다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("사업장").build();
        User requester = User.builder().id(UUID.fromString(userId)).username("req").build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(bp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId))
                .thenReturn(Optional.empty());
        when(accessRequestRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(userId), businessPlaceId, AccessStatus.PENDING)).thenReturn(false);
        when(userRepository.findById(UUID.fromString(userId))).thenReturn(Optional.of(requester));
        when(accessRequestRepository.saveAndFlush(any(BusinessPlaceAccessRequest.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(businessPlaceId, AccessStatus.APPROVED))
                .thenReturn(List.of());

        BusinessPlaceAccessRequest result = businessPlaceService.requestAccess(userId, businessPlaceId, Role.STAFF);

        assertThat(result.getRole()).isEqualTo(Role.STAFF);
        assertThat(result.getStatus()).isEqualTo(AccessStatus.PENDING);
    }

    @Test
    void requestAccess_동시요청으로_DB_유니크_제약을_위반하면_InvalidInputException을_던진다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("사업장").build();
        User requester = User.builder().id(UUID.fromString(userId)).username("req").build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(bp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId))
                .thenReturn(Optional.empty());
        when(accessRequestRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(userId), businessPlaceId, AccessStatus.PENDING)).thenReturn(false);
        when(userRepository.findById(UUID.fromString(userId))).thenReturn(Optional.of(requester));
        // 부분 유니크 제약(ux_bpar_pending) 위반을 시뮬레이션
        when(accessRequestRepository.saveAndFlush(any(BusinessPlaceAccessRequest.class)))
                .thenThrow(new DataIntegrityViolationException("ux_bpar_pending violation"));

        // 500이 아닌 400(InvalidInputException)으로 변환되어야 한다
        assertThatThrownBy(() -> businessPlaceService.requestAccess(userId, businessPlaceId, Role.STAFF))
                .isInstanceOf(InvalidInputException.class)
                .hasMessage("이미 대기중인 요청이 있습니다");
    }

    @Test
    void requestAccess_이미_등록된_사업장이면_InvalidInputException을_던진다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("사업장").build();
        UserBusinessPlace existing = UserBusinessPlace.builder()
                .userId(UUID.fromString(userId)).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(bp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId))
                .thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> businessPlaceService.requestAccess(userId, businessPlaceId, Role.STAFF))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void requestAccess_이미_대기중인_요청이_있으면_InvalidInputException을_던진다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("사업장").build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(bp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId))
                .thenReturn(Optional.empty());
        when(accessRequestRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(userId), businessPlaceId, AccessStatus.PENDING)).thenReturn(true);

        assertThatThrownBy(() -> businessPlaceService.requestAccess(userId, businessPlaceId, Role.STAFF))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void requestAccess_OWNER_권한을_요청하면_InvalidInputException을_던진다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("사업장").build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(bp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId))
                .thenReturn(Optional.empty());
        when(accessRequestRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(userId), businessPlaceId, AccessStatus.PENDING)).thenReturn(false);

        assertThatThrownBy(() -> businessPlaceService.requestAccess(userId, businessPlaceId, Role.OWNER))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void requestAccess_사업장이_없으면_ResourceNotFoundException을_던진다() {
        String userId = UUID.randomUUID().toString();
        when(businessPlaceRepository.findById("NONE999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> businessPlaceService.requestAccess(userId, "NONE999", Role.STAFF))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getSentRequests_요청_목록을_반환한다() {
        String userId = UUID.randomUUID().toString();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.randomUUID()).userId(UUID.fromString(userId)).build();
        when(accessRequestRepository.findByUserIdOrderByRequestedAtDesc(UUID.fromString(userId)))
                .thenReturn(List.of(request));

        List<BusinessPlaceAccessRequest> result = businessPlaceService.getSentRequests(userId);

        assertThat(result).containsExactly(request);
    }

    @Test
    void getReceivedRequests_소유_사업장이_없으면_빈_리스트를_반환한다() {
        String userId = UUID.randomUUID().toString();
        UserBusinessPlace staffUbp = UserBusinessPlace.builder()
                .userId(UUID.fromString(userId)).businessPlaceId("ABC1234")
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();
        when(userBusinessPlaceRepository.findByUserIdAndStatus(UUID.fromString(userId), AccessStatus.APPROVED))
                .thenReturn(List.of(staffUbp));

        List<BusinessPlaceAccessRequest> result = businessPlaceService.getReceivedRequests(userId);

        assertThat(result).isEmpty();
    }

    @Test
    void getReceivedRequests_소유_사업장의_PENDING_요청을_반환한다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(UUID.fromString(userId)).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.randomUUID()).businessPlaceId(businessPlaceId).status(AccessStatus.PENDING).build();

        when(userBusinessPlaceRepository.findByUserIdAndStatus(UUID.fromString(userId), AccessStatus.APPROVED))
                .thenReturn(List.of(ownerUbp));
        when(accessRequestRepository.findByBusinessPlaceIdsAndStatus(List.of(businessPlaceId), AccessStatus.PENDING))
                .thenReturn(List.of(request));

        List<BusinessPlaceAccessRequest> result = businessPlaceService.getReceivedRequests(userId);

        assertThat(result).containsExactly(request);
    }

    @Test
    void getReceivedRequestsWithRequester_요청자와_사업장_정보를_포함해_반환한다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UUID requesterUuid = UUID.randomUUID();
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(UUID.fromString(userId)).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.randomUUID()).userId(requesterUuid).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.PENDING).requestedAt(LocalDateTime.now()).build();
        User requester = User.builder().id(requesterUuid).username("req").build();
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("사업장").build();

        when(userBusinessPlaceRepository.findByUserIdAndStatus(UUID.fromString(userId), AccessStatus.APPROVED))
                .thenReturn(List.of(ownerUbp));
        when(accessRequestRepository.findByBusinessPlaceIdsAndStatus(List.of(businessPlaceId), AccessStatus.PENDING))
                .thenReturn(List.of(request));
        when(userRepository.findAllById(List.of(requesterUuid))).thenReturn(List.of(requester));
        when(businessPlaceRepository.findAllById(List.of(businessPlaceId))).thenReturn(List.of(bp));

        List<AccessRequestWithRequesterDTO> result = businessPlaceService.getReceivedRequestsWithRequester(userId);

        assertThat(result).hasSize(1);
    }

    @Test
    void getPendingRequestCount_PENDING_요청_개수를_반환한다() {
        String userId = UUID.randomUUID().toString();
        when(userBusinessPlaceRepository.findByUserIdAndStatus(UUID.fromString(userId), AccessStatus.APPROVED))
                .thenReturn(List.of());

        long result = businessPlaceService.getPendingRequestCount(userId);

        assertThat(result).isZero();
    }

    @Test
    void getUnreadResults_미확인_처리결과를_반환한다() {
        String userId = UUID.randomUUID().toString();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder().id(UUID.randomUUID()).build();
        when(accessRequestRepository.findByUserIdAndIsReadByRequesterFalseAndStatusInOrderByProcessedAtDesc(
                UUID.fromString(userId), List.of(AccessStatus.APPROVED, AccessStatus.REJECTED)))
                .thenReturn(List.of(request));

        assertThat(businessPlaceService.getUnreadResults(userId)).containsExactly(request);
        assertThat(businessPlaceService.getUnreadResultCount(userId)).isEqualTo(1L);
    }

    @Test
    void approveRequest_정상_승인한다() {
        String requestId = UUID.randomUUID().toString();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UUID requesterUuid = UUID.randomUUID();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).userId(requesterUuid).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.PENDING).build();
        UserBusinessPlace ownership = UserBusinessPlace.builder()
                .userId(UUID.fromString(ownerId)).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();
        User requesterUser = User.builder().id(requesterUuid).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(ownerId), businessPlaceId))
                .thenReturn(Optional.of(ownership));
        when(accessRequestRepository.save(request)).thenReturn(request);
        when(userRepository.findById(requesterUuid)).thenReturn(Optional.of(requesterUser));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.empty());

        BusinessPlaceAccessRequest result = businessPlaceService.approveRequest(requestId, ownerId);

        assertThat(result.getStatus()).isEqualTo(AccessStatus.APPROVED);
        // 멤버십 생성은 uk_user_business_place 위반을 400 으로 변환하기 위해 saveAndFlush 사용(WB-10)
        verify(userBusinessPlaceRepository).saveAndFlush(any(UserBusinessPlace.class));
    }

    @Test
    void approveRequest_요청이_없으면_ResourceNotFoundException을_던진다() {
        String requestId = UUID.randomUUID().toString();
        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> businessPlaceService.approveRequest(requestId, UUID.randomUUID().toString()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void approveRequest_소유자가_아니면_AccessDeniedException을_던진다() {
        String requestId = UUID.randomUUID().toString();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).businessPlaceId(businessPlaceId).status(AccessStatus.PENDING).build();
        UserBusinessPlace ownership = UserBusinessPlace.builder()
                .userId(UUID.fromString(ownerId)).businessPlaceId(businessPlaceId)
                .role(Role.MANAGER).status(AccessStatus.APPROVED).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(ownerId), businessPlaceId))
                .thenReturn(Optional.of(ownership));

        assertThatThrownBy(() -> businessPlaceService.approveRequest(requestId, ownerId))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void approveRequest_이미_처리된_요청이면_InvalidInputException을_던진다() {
        String requestId = UUID.randomUUID().toString();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).businessPlaceId(businessPlaceId).status(AccessStatus.APPROVED).build();
        UserBusinessPlace ownership = UserBusinessPlace.builder()
                .userId(UUID.fromString(ownerId)).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(ownerId), businessPlaceId))
                .thenReturn(Optional.of(ownership));

        assertThatThrownBy(() -> businessPlaceService.approveRequest(requestId, ownerId))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void rejectRequest_정상_거절한다() {
        String requestId = UUID.randomUUID().toString();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UUID requesterUuid = UUID.randomUUID();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).userId(requesterUuid).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.PENDING).build();
        UserBusinessPlace ownership = UserBusinessPlace.builder()
                .userId(UUID.fromString(ownerId)).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(ownerId), businessPlaceId))
                .thenReturn(Optional.of(ownership));
        when(accessRequestRepository.save(request)).thenReturn(request);
        when(userRepository.findById(requesterUuid)).thenReturn(Optional.empty());
        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.empty());

        BusinessPlaceAccessRequest result = businessPlaceService.rejectRequest(requestId, ownerId);

        assertThat(result.getStatus()).isEqualTo(AccessStatus.REJECTED);
    }

    @Test
    void rejectRequest_이미_처리된_요청이면_InvalidInputException을_던진다() {
        String requestId = UUID.randomUUID().toString();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).businessPlaceId(businessPlaceId).status(AccessStatus.REJECTED).build();
        UserBusinessPlace ownership = UserBusinessPlace.builder()
                .userId(UUID.fromString(ownerId)).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(ownerId), businessPlaceId))
                .thenReturn(Optional.of(ownership));

        assertThatThrownBy(() -> businessPlaceService.rejectRequest(requestId, ownerId))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void deleteRequest_요청자_본인이면_삭제한다() {
        String requestId = UUID.randomUUID().toString();
        UUID userUuid = UUID.randomUUID();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).userId(userUuid).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));

        businessPlaceService.deleteRequest(requestId, userUuid.toString());

        verify(accessRequestRepository).delete(request);
    }

    @Test
    void deleteRequest_요청자가_아니면_AccessDeniedException을_던진다() {
        String requestId = UUID.randomUUID().toString();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).userId(UUID.randomUUID()).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));

        assertThatThrownBy(() -> businessPlaceService.deleteRequest(requestId, UUID.randomUUID().toString()))
                .isInstanceOf(AccessDeniedException.class);
        verify(accessRequestRepository, never()).delete(any());
    }

    @Test
    void markRequestAsRead_요청자_본인이면_읽음_처리한다() {
        String requestId = UUID.randomUUID().toString();
        UUID userUuid = UUID.randomUUID();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).userId(userUuid).isReadByRequester(false).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));
        when(accessRequestRepository.save(request)).thenReturn(request);

        BusinessPlaceAccessRequest result = businessPlaceService.markRequestAsRead(requestId, userUuid.toString());

        assertThat(result.getIsReadByRequester()).isTrue();
    }

    @Test
    void markRequestAsRead_요청자가_아니면_AccessDeniedException을_던진다() {
        String requestId = UUID.randomUUID().toString();
        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .id(UUID.fromString(requestId)).userId(UUID.randomUUID()).build();

        when(accessRequestRepository.findById(UUID.fromString(requestId))).thenReturn(Optional.of(request));

        assertThatThrownBy(() -> businessPlaceService.markRequestAsRead(requestId, UUID.randomUUID().toString()))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void removeBusinessPlace_OWNER는_탈퇴할_수_없어_InvalidInputException을_던진다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(UUID.fromString(userId)).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId))
                .thenReturn(Optional.of(ubp));

        assertThatThrownBy(() -> businessPlaceService.removeBusinessPlace(userId, businessPlaceId))
                .isInstanceOf(InvalidInputException.class);
        verify(userBusinessPlaceRepository, never()).delete(any());
    }

    @Test
    void removeBusinessPlace_STAFF는_정상_탈퇴한다() {
        String userId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(UUID.fromString(userId)).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();
        User user = User.builder().id(UUID.fromString(userId)).defaultBusinessPlaceId(businessPlaceId).build();

        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId))
                .thenReturn(Optional.of(ubp));
        when(userRepository.findById(UUID.fromString(userId))).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        businessPlaceService.removeBusinessPlace(userId, businessPlaceId);

        verify(userBusinessPlaceRepository).delete(ubp);
        assertThat(user.getDefaultBusinessPlaceId()).isNull();
    }

    @Test
    void updateMemberRole_정상_역할을_변경한다() {
        UUID targetUbpId = UUID.randomUUID();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UUID targetUserId = UUID.randomUUID();
        UserBusinessPlace targetUbp = UserBusinessPlace.builder()
                .id(targetUbpId).userId(targetUserId).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();
        User targetUser = User.builder().id(targetUserId).build();

        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.of(targetUbp));
        when(userBusinessPlaceRepository.save(targetUbp)).thenReturn(targetUbp);
        when(userRepository.findById(targetUserId)).thenReturn(Optional.of(targetUser));

        BusinessPlaceMemberDTO result = businessPlaceService.updateMemberRole(targetUbpId, Role.MANAGER, ownerId);

        verify(accessControlService).requireRole(ownerId, businessPlaceId, Role.OWNER);
        assertThat(result.getRole()).isEqualTo(Role.MANAGER);
    }

    @Test
    void updateMemberRole_OWNER로_변경하면_InvalidInputException을_던진다() {
        UUID targetUbpId = UUID.randomUUID();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace targetUbp = UserBusinessPlace.builder()
                .id(targetUbpId).userId(UUID.randomUUID()).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();

        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.of(targetUbp));

        assertThatThrownBy(() -> businessPlaceService.updateMemberRole(targetUbpId, Role.OWNER, ownerId))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void updateMemberRole_본인의_역할은_변경할_수_없어_InvalidInputException을_던진다() {
        UUID targetUbpId = UUID.randomUUID();
        UUID ownerUuid = UUID.randomUUID();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace targetUbp = UserBusinessPlace.builder()
                .id(targetUbpId).userId(ownerUuid).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();

        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.of(targetUbp));

        assertThatThrownBy(() -> businessPlaceService.updateMemberRole(targetUbpId, Role.MANAGER, ownerUuid.toString()))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void updateMemberRole_대상이_OWNER면_InvalidInputException을_던진다() {
        UUID targetUbpId = UUID.randomUUID();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace targetUbp = UserBusinessPlace.builder()
                .id(targetUbpId).userId(UUID.randomUUID()).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.of(targetUbp));

        assertThatThrownBy(() -> businessPlaceService.updateMemberRole(targetUbpId, Role.MANAGER, ownerId))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void updateMemberRole_멤버가_없으면_ResourceNotFoundException을_던진다() {
        UUID targetUbpId = UUID.randomUUID();
        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> businessPlaceService.updateMemberRole(targetUbpId, Role.MANAGER, UUID.randomUUID().toString()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void removeMember_본인은_삭제할_수_없어_InvalidInputException을_던진다() {
        UUID targetUbpId = UUID.randomUUID();
        UUID ownerUuid = UUID.randomUUID();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace targetUbp = UserBusinessPlace.builder()
                .id(targetUbpId).userId(ownerUuid).businessPlaceId(businessPlaceId)
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();

        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.of(targetUbp));

        assertThatThrownBy(() -> businessPlaceService.removeMember(targetUbpId, ownerUuid.toString()))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void removeMember_대상이_OWNER면_InvalidInputException을_던진다() {
        UUID targetUbpId = UUID.randomUUID();
        String ownerId = UUID.randomUUID().toString();
        String businessPlaceId = "ABC1234";
        UserBusinessPlace targetUbp = UserBusinessPlace.builder()
                .id(targetUbpId).userId(UUID.randomUUID()).businessPlaceId(businessPlaceId)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.of(targetUbp));

        assertThatThrownBy(() -> businessPlaceService.removeMember(targetUbpId, ownerId))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void removeMember_멤버가_없으면_ResourceNotFoundException을_던진다() {
        UUID targetUbpId = UUID.randomUUID();
        when(userBusinessPlaceRepository.findById(targetUbpId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> businessPlaceService.removeMember(targetUbpId, UUID.randomUUID().toString()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getDeletionPreview_삭제될_데이터_개수를_반환한다() {
        String businessPlaceId = "ABC1234";
        String userId = UUID.randomUUID().toString();
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("사업장").build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(bp));
        when(memberRepository.countByBusinessPlaceId(businessPlaceId)).thenReturn(10L);
        when(memoRepository.countByBusinessPlaceId(businessPlaceId)).thenReturn(20L);
        when(reservationRepository.countByBusinessPlaceId(businessPlaceId)).thenReturn(3L);
        when(visitRepository.countByBusinessPlaceId(businessPlaceId)).thenReturn(4L);
        when(auditLogRepository.countByBusinessPlaceId(businessPlaceId)).thenReturn(5L);
        when(userBusinessPlaceRepository.countStaffByBusinessPlaceId(businessPlaceId)).thenReturn(2L);
        when(accessRequestRepository.countByBusinessPlaceId(businessPlaceId)).thenReturn(1L);

        BusinessPlaceDeletionPreviewDTO result = businessPlaceService.getDeletionPreview(businessPlaceId, userId);

        verify(accessControlService).requireRole(userId, businessPlaceId, Role.OWNER);
        assertThat(result.getMemberCount()).isEqualTo(10L);
        assertThat(result.getMemoCount()).isEqualTo(20L);
        assertThat(result.getBusinessPlaceName()).isEqualTo("사업장");
    }

    @Test
    void getDeletionPreview_사업장이_없으면_ResourceNotFoundException을_던진다() {
        when(businessPlaceRepository.findById("NONE999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> businessPlaceService.getDeletionPreview("NONE999", UUID.randomUUID().toString()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void deleteBusinessPlacePermanently_이름이_일치하지_않으면_InvalidInputException을_던진다() {
        String businessPlaceId = "ABC1234";
        String userId = UUID.randomUUID().toString();
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name("진짜이름").build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(bp));

        assertThatThrownBy(() -> businessPlaceService.deleteBusinessPlacePermanently(businessPlaceId, userId, "틀린이름"))
                .isInstanceOf(InvalidInputException.class);
        verify(userRepository, never()).clearDefaultBusinessPlaceId(any());
    }

    @Test
    void deleteBusinessPlacePermanently_사업장이_없으면_ResourceNotFoundException을_던진다() {
        when(businessPlaceRepository.findById("NONE999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> businessPlaceService.deleteBusinessPlacePermanently(
                "NONE999", UUID.randomUUID().toString(), "이름"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void deleteBusinessPlacePermanently_회원이_없으면_메모_방문삭제를_건너뛴다() {
        String businessPlaceId = "ABC1234";
        String userId = UUID.randomUUID().toString();
        String confirmName = "사업장";
        BusinessPlace bp = BusinessPlace.builder().id(businessPlaceId).name(confirmName).build();

        when(businessPlaceRepository.findById(businessPlaceId)).thenReturn(Optional.of(bp));
        when(memberRepository.findMemberIdsByBusinessPlaceId(businessPlaceId)).thenReturn(List.of());

        businessPlaceService.deleteBusinessPlacePermanently(businessPlaceId, userId, confirmName);

        verify(memoRepository, never()).deleteAllByMemberIds(any());
        verify(visitRepository, never()).deleteAllByMemberIds(any());
        verify(reservationRepository).deleteAllByBusinessPlaceId(businessPlaceId);
    }

    @Test
    void cleanupUserReferences_사업장_단위로_모든_참조를_정리한다() {
        String businessPlaceId = "ABC1234";
        UUID userUuid = UUID.randomUUID();

        businessPlaceService.cleanupUserReferences(businessPlaceId, userUuid.toString());

        verify(memberRepository).clearOwnerIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        verify(memberRepository).clearLastModifiedByIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        verify(memberRepository).clearDeletedByByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        verify(memoRepository).clearOwnerIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        verify(reservationRepository).clearCreatedByByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        verify(visitRepository).clearVisitorIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        verify(auditLogRepository).clearUserIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
    }
}
