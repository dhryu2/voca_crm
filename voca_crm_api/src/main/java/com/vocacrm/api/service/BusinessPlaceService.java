package com.vocacrm.api.service;

import com.vocacrm.api.dto.AccessRequestWithRequesterDTO;
import com.vocacrm.api.dto.BusinessPlaceDeletionPreviewDTO;
import com.vocacrm.api.dto.BusinessPlaceMemberDTO;
import com.vocacrm.api.dto.BusinessPlaceWithRoleDTO;
import com.vocacrm.api.dto.CreateBusinessPlaceResponse;
import com.vocacrm.api.dto.SetDefaultBusinessPlaceResponse;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.exception.BusinessException;
import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.*;
import com.vocacrm.api.repository.*;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BusinessPlaceService {

    private final BusinessPlaceRepository businessPlaceRepository;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;
    private final UserRepository userRepository;
    private final BusinessPlaceAccessRequestRepository accessRequestRepository;
    private final FCMService fcmService;
    private final EntityManager entityManager;

    // 사용자 참조 정리를 위한 Repository
    private final MemberRepository memberRepository;
    private final MemoRepository memoRepository;
    private final ReservationRepository reservationRepository;
    private final VisitRepository visitRepository;
    private final AuditLogRepository auditLogRepository;

    private static final String ID_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    private static final int ID_LENGTH = 7;
    private static final SecureRandom RANDOM = new SecureRandom();

    /**
     * 7자리 영숫자(대문자+숫자) 랜덤 ID 생성
     * 중복 시 재생성 (최대 10회 시도)
     */
    private String generateUniqueBusinessPlaceId() {
        for (int attempt = 0; attempt < 10; attempt++) {
            StringBuilder sb = new StringBuilder(ID_LENGTH);
            for (int i = 0; i < ID_LENGTH; i++) {
                sb.append(ID_CHARACTERS.charAt(RANDOM.nextInt(ID_CHARACTERS.length())));
            }
            String id = sb.toString();

            if (!businessPlaceRepository.existsById(id)) {
                return id;
            }
        }
        throw new BusinessException("사업장 ID 생성 실패: 중복 ID가 너무 많습니다", "ID_GENERATION_FAILED");
    }

    @Transactional
    public CreateBusinessPlaceResponse createBusinessPlace(BusinessPlace businessPlace, String userId) {
        // Get user to check tier
        User user = userRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다: " + userId));

        // Check business place limit based on tier
        int maxBusinessPlaces = getMaxBusinessPlaces(user.getTier());
        UUID userUuid = UUID.fromString(userId);
        long currentCount = userBusinessPlaceRepository.countByUserIdAndRoleAndStatus(
                userUuid, Role.OWNER, AccessStatus.APPROVED);

        log.debug("사업장 생성 시도 - userId: {}, currentCount: {}, maxBusinessPlaces: {}", userId, currentCount, maxBusinessPlaces);

        if (currentCount >= maxBusinessPlaces) {
            log.warn("사업장 생성 제한 초과 - userId: {}, currentCount: {}, maxBusinessPlaces: {}", userId, currentCount, maxBusinessPlaces);
            throw new InvalidInputException("사업장은 최대 " + maxBusinessPlaces + "개까지 생성 가능합니다.");
        }

        // Generate unique 7-character ID
        businessPlace.setId(generateUniqueBusinessPlaceId());

        // Save business place
        BusinessPlace saved = businessPlaceRepository.save(businessPlace);

        // Create owner relationship
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(userUuid)
                .businessPlaceId(saved.getId())
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();
        userBusinessPlaceRepository.save(ubp);

        // Set as default business place if user doesn't have one
        if (user.getDefaultBusinessPlaceId() == null) {
            user.setDefaultBusinessPlaceId(saved.getId());
            userRepository.save(user);
        }

        return CreateBusinessPlaceResponse.from(saved, user);
    }

    private int getMaxBusinessPlaces(String tier) {
        // Currently same for both FREE and PREMIUM
        // Will be increased for PREMIUM later
        return 3;
    }

    public List<BusinessPlaceWithRoleDTO> getMyBusinessPlaces(String userId) {
        List<UserBusinessPlace> ubps = userBusinessPlaceRepository.findByUserIdAndStatus(UUID.fromString(userId), AccessStatus.APPROVED);

        if (ubps.isEmpty()) {
            return List.of();
        }

        // N+1 방지: 모든 사업장 ID를 한 번에 조회
        List<String> businessPlaceIds = ubps.stream()
                .map(UserBusinessPlace::getBusinessPlaceId)
                .toList();

        // 1. 모든 사업장 정보를 한 번에 조회
        Map<String, BusinessPlace> businessPlaceMap = businessPlaceRepository.findAllById(businessPlaceIds)
                .stream()
                .collect(Collectors.toMap(BusinessPlace::getId, bp -> bp));

        // 2. 모든 사업장의 회원 수를 한 번에 조회
        Map<String, Long> memberCountMap = userBusinessPlaceRepository.countMembersGroupByBusinessPlaceId(businessPlaceIds)
                .stream()
                .collect(Collectors.toMap(
                        row -> (String) row[0],
                        row -> (Long) row[1]
                ));

        // 3. DTO 생성 (추가 쿼리 없음)
        return ubps.stream()
                .map(ubp -> {
                    BusinessPlace bp = businessPlaceMap.get(ubp.getBusinessPlaceId());
                    if (bp == null) return null;
                    int memberCount = memberCountMap.getOrDefault(ubp.getBusinessPlaceId(), 0L).intValue();
                    return new BusinessPlaceWithRoleDTO(bp, ubp.getRole(), memberCount);
                })
                .filter(dto -> dto != null)
                .toList();
    }

    /**
     * 사업장 단일 조회
     */
    public BusinessPlace getBusinessPlaceById(String businessPlaceId) {
        return businessPlaceRepository.findById(businessPlaceId)
                .orElseThrow(() -> new ResourceNotFoundException("사업장을 찾을 수 없습니다"));
    }

    /**
     * 사업장 접근 권한 요청
     *
     * @param userId 요청자 ID
     * @param businessPlaceId 사업장 ID
     * @param role 요청할 권한 (MANAGER, STAFF만 가능)
     * @return 생성된 접근 요청
     */
    @Transactional
    public BusinessPlaceAccessRequest requestAccess(String userId, String businessPlaceId, Role role) {
        // Verify business place exists first
        BusinessPlace businessPlace = businessPlaceRepository.findById(businessPlaceId)
                .orElseThrow(() -> new ResourceNotFoundException("사업장을 찾을 수 없습니다"));

        // Check if already has access (이미 등록된 사업장)
        UUID userUuid = UUID.fromString(userId);
        if (userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(userUuid, businessPlaceId).isPresent()) {
            throw new InvalidInputException("이미 등록된 사업장입니다");
        }

        // Check if pending request already exists (이미 보낸 요청이 있음)
        if (accessRequestRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, businessPlaceId, AccessStatus.PENDING)) {
            throw new InvalidInputException("이미 대기중인 요청이 있습니다");
        }

        // Only MANAGER and STAFF can request access
        if (role == Role.OWNER) {
            throw new InvalidInputException("OWNER 권한은 요청할 수 없습니다");
        }

        // Get requester info
        User requester = userRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new ResourceNotFoundException("요청자를 찾을 수 없습니다"));

        BusinessPlaceAccessRequest request = BusinessPlaceAccessRequest.builder()
                .userId(UUID.fromString(userId))
                .businessPlaceId(businessPlaceId)
                .role(role)
                .status(AccessStatus.PENDING)
                .requestedAt(LocalDateTime.now())
                .isReadByRequester(false)
                .build();

        BusinessPlaceAccessRequest savedRequest = accessRequestRepository.save(request);

        // Send push notification to owner (only if push notification is enabled)
        List<UserBusinessPlace> owners = userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(
                businessPlaceId, AccessStatus.APPROVED);
        owners.stream()
                .filter(ubp -> ubp.getRole() == Role.OWNER)
                .forEach(owner -> {
                    userRepository.findById(owner.getUserId()).ifPresent(ownerUser -> {
                        if (ownerUser.getFcmToken() != null && Boolean.TRUE.equals(ownerUser.getPushNotificationEnabled())) {
                            fcmService.sendAccessRequestNotification(
                                    ownerUser.getFcmToken(),
                                    requester.getUsername(),
                                    businessPlace.getName(),
                                    businessPlaceId,
                                    userId
                            );
                        }
                    });
                });

        return savedRequest;
    }

    /**
     * 사용자가 보낸 요청 목록 조회
     *
     * @param userId 사용자 ID
     * @return 요청 목록 (최신순)
     */
    public List<BusinessPlaceAccessRequest> getSentRequests(String userId) {
        return accessRequestRepository.findByUserIdOrderByRequestedAtDesc(UUID.fromString(userId));
    }

    /**
     * Owner가 받은 요청 목록 조회 (PENDING 상태만)
     *
     * @param userId Owner의 사용자 ID
     * @return PENDING 상태의 요청 목록 (최신순)
     */
    public List<BusinessPlaceAccessRequest> getReceivedRequests(String userId) {
        // Get business places where user is owner
        List<UserBusinessPlace> ownerships = userBusinessPlaceRepository.findByUserIdAndStatus(UUID.fromString(userId),
                AccessStatus.APPROVED);

        List<String> ownedBusinessPlaceIds = ownerships.stream()
                .filter(ubp -> ubp.getRole() == Role.OWNER)
                .map(UserBusinessPlace::getBusinessPlaceId)
                .collect(Collectors.toList());

        if (ownedBusinessPlaceIds.isEmpty()) {
            return List.of();
        }

        return accessRequestRepository.findByBusinessPlaceIdsAndStatus(
                ownedBusinessPlaceIds, AccessStatus.PENDING);
    }

    /**
     * Owner가 받은 요청 목록 조회 - 요청자 정보 포함 (PENDING 상태만)
     *
     * @param userId Owner의 사용자 ID
     * @return PENDING 상태의 요청 목록 + 요청자 정보 (최신순)
     */
    public List<AccessRequestWithRequesterDTO> getReceivedRequestsWithRequester(String userId) {
        List<BusinessPlaceAccessRequest> requests = getReceivedRequests(userId);

        if (requests.isEmpty()) {
            return List.of();
        }

        // N+1 방지: 모든 요청자 ID와 사업장 ID를 한 번에 수집
        List<UUID> requesterIds = requests.stream()
                .map(BusinessPlaceAccessRequest::getUserId)
                .distinct()
                .toList();

        List<String> businessPlaceIds = requests.stream()
                .map(BusinessPlaceAccessRequest::getBusinessPlaceId)
                .distinct()
                .toList();

        // 1. 모든 요청자 정보를 한 번에 조회
        Map<UUID, User> requesterMap = userRepository.findAllById(requesterIds)
                .stream()
                .collect(Collectors.toMap(User::getId, user -> user));

        // 2. 모든 사업장 정보를 한 번에 조회
        Map<String, BusinessPlace> businessPlaceMap = businessPlaceRepository.findAllById(businessPlaceIds)
                .stream()
                .collect(Collectors.toMap(BusinessPlace::getId, bp -> bp));

        // 3. DTO 생성 (추가 쿼리 없음)
        return requests.stream()
                .map(request -> {
                    User requester = requesterMap.get(request.getUserId());
                    BusinessPlace businessPlace = businessPlaceMap.get(request.getBusinessPlaceId());
                    return AccessRequestWithRequesterDTO.from(request, requester, businessPlace);
                })
                .collect(Collectors.toList());
    }

    /**
     * 사용자의 미확인 처리 결과 조회
     *
     * @param userId 사용자 ID
     * @return 미확인 상태의 처리된 요청 목록
     */
    public List<BusinessPlaceAccessRequest> getUnreadResults(String userId) {
        return accessRequestRepository.findByUserIdAndIsReadByRequesterFalseAndStatusInOrderByProcessedAtDesc(
                UUID.fromString(userId), List.of(AccessStatus.APPROVED, AccessStatus.REJECTED));
    }

    /**
     * Owner가 받은 PENDING 요청 개수 조회
     *
     * @param userId Owner의 사용자 ID
     * @return PENDING 상태 요청 개수
     */
    public long getPendingRequestCount(String userId) {
        return getReceivedRequests(userId).size();
    }

    /**
     * 사용자의 미확인 처리 결과 개수 조회
     *
     * @param userId 사용자 ID
     * @return 미확인 상태 처리 결과 개수
     */
    public long getUnreadResultCount(String userId) {
        return getUnreadResults(userId).size();
    }

    /**
     * 사업장 접근 요청 승인
     *
     * @param requestId 요청 ID
     * @param ownerId Owner ID
     * @return 승인된 요청
     */
    @Transactional
    public BusinessPlaceAccessRequest approveRequest(String requestId, String ownerId) {
        BusinessPlaceAccessRequest request = accessRequestRepository.findById(UUID.fromString(requestId))
                .orElseThrow(() -> new ResourceNotFoundException("요청자가 요청을 취소했습니다"));

        // Verify requester is owner of the business place
        UserBusinessPlace ownership = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceId(UUID.fromString(ownerId), request.getBusinessPlaceId())
                .orElseThrow(() -> new AccessDeniedException("권한이 없습니다"));

        if (ownership.getRole() != Role.OWNER || ownership.getStatus() != AccessStatus.APPROVED) {
            throw new AccessDeniedException("권한이 없습니다");
        }

        // Check if request is already processed
        if (request.getStatus() != AccessStatus.PENDING) {
            throw new InvalidInputException("이미 처리된 요청입니다");
        }

        // Update request status
        request.setStatus(AccessStatus.APPROVED);
        request.setProcessedAt(LocalDateTime.now());
        request.setProcessedBy(UUID.fromString(ownerId));
        BusinessPlaceAccessRequest savedRequest = accessRequestRepository.save(request);

        // Create UserBusinessPlace record
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(request.getUserId())
                .businessPlaceId(request.getBusinessPlaceId())
                .role(request.getRole())
                .status(AccessStatus.APPROVED)
                .build();
        userBusinessPlaceRepository.save(ubp);

        // Set as default business place if user doesn't have one
        User user = userRepository.findById(request.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다: " + request.getUserId()));
        if (user.getDefaultBusinessPlaceId() == null) {
            user.setDefaultBusinessPlaceId(request.getBusinessPlaceId());
            userRepository.save(user);
        }

        // Send push notification to requester (only if push notification is enabled)
        BusinessPlace businessPlace = businessPlaceRepository.findById(request.getBusinessPlaceId())
                .orElse(null);
        if (businessPlace != null && user.getFcmToken() != null && Boolean.TRUE.equals(user.getPushNotificationEnabled())) {
            fcmService.sendRequestApprovedNotification(
                    user.getFcmToken(),
                    businessPlace.getName(),
                    request.getBusinessPlaceId()
            );
        }

        return savedRequest;
    }

    /**
     * 사업장 접근 요청 거절
     *
     * @param requestId 요청 ID
     * @param ownerId Owner ID
     * @return 거절된 요청
     */
    @Transactional
    public BusinessPlaceAccessRequest rejectRequest(String requestId, String ownerId) {
        BusinessPlaceAccessRequest request = accessRequestRepository.findById(UUID.fromString(requestId))
                .orElseThrow(() -> new ResourceNotFoundException("요청자가 요청을 취소했습니다"));

        // Verify requester is owner of the business place
        UserBusinessPlace ownership = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceId(UUID.fromString(ownerId), request.getBusinessPlaceId())
                .orElseThrow(() -> new AccessDeniedException("권한이 없습니다"));

        if (ownership.getRole() != Role.OWNER || ownership.getStatus() != AccessStatus.APPROVED) {
            throw new AccessDeniedException("권한이 없습니다");
        }

        // Check if request is already processed
        if (request.getStatus() != AccessStatus.PENDING) {
            throw new InvalidInputException("이미 처리된 요청입니다");
        }

        // Update request status
        request.setStatus(AccessStatus.REJECTED);
        request.setProcessedAt(LocalDateTime.now());
        request.setProcessedBy(UUID.fromString(ownerId));
        BusinessPlaceAccessRequest savedRequest = accessRequestRepository.save(request);

        // Send push notification to requester (only if push notification is enabled)
        User requester = userRepository.findById(request.getUserId()).orElse(null);
        BusinessPlace businessPlace = businessPlaceRepository.findById(request.getBusinessPlaceId())
                .orElse(null);
        if (requester != null && businessPlace != null && requester.getFcmToken() != null && Boolean.TRUE.equals(requester.getPushNotificationEnabled())) {
            fcmService.sendRequestRejectedNotification(
                    requester.getFcmToken(),
                    businessPlace.getName(),
                    request.getBusinessPlaceId()
            );
        }

        return savedRequest;
    }

    /**
     * 요청 삭제 (요청자만 가능)
     * - PENDING 상태: 요청 취소
     * - APPROVED/REJECTED 상태: 결과 확인 후 이력 삭제
     *
     * @param requestId 요청 ID
     * @param userId 요청자 ID
     */
    @Transactional
    public void deleteRequest(String requestId, String userId) {
        BusinessPlaceAccessRequest request = accessRequestRepository.findById(UUID.fromString(requestId))
                .orElseThrow(() -> new ResourceNotFoundException("요청을 찾을 수 없습니다"));

        // Only the requester can delete their own request
        if (!request.getUserId().equals(UUID.fromString(userId))) {
            throw new AccessDeniedException("권한이 없습니다");
        }

        accessRequestRepository.delete(request);
    }

    /**
     * 요청 결과 확인 처리
     *
     * @param requestId 요청 ID
     * @param userId 요청자 ID
     * @return 확인 처리된 요청
     */
    @Transactional
    public BusinessPlaceAccessRequest markRequestAsRead(String requestId, String userId) {
        BusinessPlaceAccessRequest request = accessRequestRepository.findById(UUID.fromString(requestId))
                .orElseThrow(() -> new ResourceNotFoundException("요청을 찾을 수 없습니다"));

        // Only the requester can mark as read
        if (!request.getUserId().equals(UUID.fromString(userId))) {
            throw new AccessDeniedException("권한이 없습니다");
        }

        request.setIsReadByRequester(true);
        return accessRequestRepository.save(request);
    }

    @Transactional
    public void removeBusinessPlace(String userId, String businessPlaceId) {
        UserBusinessPlace ubp = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId)
                .orElseThrow(() -> new ResourceNotFoundException("사업장 접근 정보를 찾을 수 없습니다"));

        // Cannot remove if you're the owner
        if (ubp.getRole() == Role.OWNER) {
            throw new InvalidInputException("본인이 소유한 사업장은 탈퇴할 수 없습니다");
        }

        // 사용자 참조 정리 (탈퇴 전 해당 사용자의 모든 참조를 NULL로 설정)
        cleanupUserReferences(businessPlaceId, userId);

        userBusinessPlaceRepository.delete(ubp);

        // Clear default business place if it was the removed one
        User user = userRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다: " + userId));
        if (businessPlaceId.equals(user.getDefaultBusinessPlaceId())) {
            user.setDefaultBusinessPlaceId(null);
            userRepository.save(user);
        }
    }

    /**
     * 사업장에서 사용자가 탈퇴/제거될 때 해당 사용자의 모든 참조를 NULL로 설정
     *
     * 이 메서드는 다음 테이블의 사용자 참조 필드를 정리합니다:
     * - Member: owner_id, last_modified_by_id, deleted_by
     * - Memo: owner_id, last_modified_by_id, deleted_by
     * - Reservation: created_by
     * - Visit: visitor_id
     * - AuditLog: user_id (username은 비정규화 필드로 보존)
     *
     * @param businessPlaceId 사업장 ID
     * @param userId 탈퇴/제거되는 사용자 ID
     */
    @Transactional
    public void cleanupUserReferences(String businessPlaceId, String userId) {
        log.info("Cleaning up user references for userId: {} in businessPlaceId: {}", userId, businessPlaceId);
        UUID userUuid = UUID.fromString(userId);

        // Member 테이블 정리
        int memberOwnerCount = memberRepository.clearOwnerIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        int memberModifiedCount = memberRepository.clearLastModifiedByIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        int memberDeletedByCount = memberRepository.clearDeletedByByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);

        // Memo 테이블 정리
        int memoOwnerCount = memoRepository.clearOwnerIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        int memoModifiedCount = memoRepository.clearLastModifiedByIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);
        int memoDeletedByCount = memoRepository.clearDeletedByByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);

        // Reservation 테이블 정리
        int reservationCount = reservationRepository.clearCreatedByByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);

        // Visit 테이블 정리
        int visitCount = visitRepository.clearVisitorIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);

        // AuditLog 테이블 정리
        int auditLogCount = auditLogRepository.clearUserIdByBusinessPlaceIdAndUserId(businessPlaceId, userUuid);

        log.info("User references cleanup completed - Member: owner={}, modified={}, deletedBy={}, " +
                        "Memo: owner={}, modified={}, deletedBy={}, " +
                        "Reservation: {}, Visit: {}, AuditLog: {}",
                memberOwnerCount, memberModifiedCount, memberDeletedByCount,
                memoOwnerCount, memoModifiedCount, memoDeletedByCount,
                reservationCount, visitCount, auditLogCount);
    }

    @Transactional
    public BusinessPlace updateBusinessPlace(String id, BusinessPlace businessPlace, String userId) {
        UserBusinessPlace ubp = userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), id)
                .orElseThrow(() -> new AccessDeniedException("사업장 접근 권한이 없습니다"));

        if (ubp.getRole() != Role.OWNER) {
            throw new AccessDeniedException("OWNER만 사업장 정보를 수정할 수 있습니다");
        }

        BusinessPlace existing = businessPlaceRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("사업장을 찾을 수 없습니다"));

        if (businessPlace.getName() != null) {
            existing.setName(businessPlace.getName());
        }
        if (businessPlace.getAddress() != null) {
            existing.setAddress(businessPlace.getAddress());
        }
        if (businessPlace.getPhone() != null) {
            existing.setPhone(businessPlace.getPhone());
        }

        return businessPlaceRepository.save(existing);
    }

    @Transactional
    public SetDefaultBusinessPlaceResponse setDefaultBusinessPlace(String userId, String businessPlaceId) {
        userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId)
                .orElseThrow(() -> new AccessDeniedException("사업장 접근 권한이 없습니다"));

        User user = userRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new ResourceNotFoundException("사용자를 찾을 수 없습니다"));

        user.setDefaultBusinessPlaceId(businessPlaceId);
        User updatedUser = userRepository.save(user);

        return SetDefaultBusinessPlaceResponse.from(updatedUser);
    }

    /**
     * 사업장 멤버 목록 조회
     *
     * @param businessPlaceId 사업장 ID
     * @param requesterId 요청자 ID (접근 권한 확인용)
     * @return 멤버 목록 (OWNER가 맨 앞, 나머지는 가입일순)
     */
    public List<BusinessPlaceMemberDTO> getBusinessPlaceMembers(String businessPlaceId, String requesterId) {
        // 요청자가 해당 사업장의 멤버인지 확인
        userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(requesterId), businessPlaceId)
                .orElseThrow(() -> new AccessDeniedException("권한이 없습니다"));

        List<UserBusinessPlace> members = userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(
                businessPlaceId, AccessStatus.APPROVED);

        return members.stream()
                .map(ubp -> {
                    User user = userRepository.findById(ubp.getUserId()).orElse(null);
                    return BusinessPlaceMemberDTO.from(ubp, user);
                })
                .sorted((a, b) -> {
                    // OWNER를 맨 앞으로
                    if (a.getRole() == Role.OWNER && b.getRole() != Role.OWNER) return -1;
                    if (a.getRole() != Role.OWNER && b.getRole() == Role.OWNER) return 1;
                    // 나머지는 가입일순
                    return a.getJoinedAt().compareTo(b.getJoinedAt());
                })
                .collect(Collectors.toList());
    }

    /**
     * 멤버 역할 변경 (Owner만 가능)
     *
     * @param userBusinessPlaceId UserBusinessPlace ID
     * @param newRole 새로운 역할 (MANAGER, STAFF만 가능)
     * @param ownerId 요청자 ID (Owner 확인용)
     * @return 변경된 멤버 정보
     */
    @Transactional
    public BusinessPlaceMemberDTO updateMemberRole(UUID userBusinessPlaceId, Role newRole, String ownerId) {
        UserBusinessPlace targetUbp = userBusinessPlaceRepository.findById(userBusinessPlaceId)
                .orElseThrow(() -> new ResourceNotFoundException("멤버를 찾을 수 없습니다"));

        // 요청자가 Owner인지 확인
        UserBusinessPlace ownerUbp = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceId(UUID.fromString(ownerId), targetUbp.getBusinessPlaceId())
                .orElseThrow(() -> new AccessDeniedException("권한이 없습니다"));

        if (ownerUbp.getRole() != Role.OWNER) {
            throw new AccessDeniedException("Owner만 역할을 변경할 수 있습니다");
        }

        // OWNER 역할로는 변경 불가
        if (newRole == Role.OWNER) {
            throw new InvalidInputException("OWNER 역할로는 변경할 수 없습니다");
        }

        // 본인(Owner)의 역할은 변경 불가
        if (targetUbp.getUserId().equals(UUID.fromString(ownerId))) {
            throw new InvalidInputException("본인의 역할은 변경할 수 없습니다");
        }

        // 대상이 Owner인 경우 변경 불가
        if (targetUbp.getRole() == Role.OWNER) {
            throw new InvalidInputException("Owner의 역할은 변경할 수 없습니다");
        }

        targetUbp.setRole(newRole);
        UserBusinessPlace updated = userBusinessPlaceRepository.save(targetUbp);

        User user = userRepository.findById(updated.getUserId()).orElse(null);
        return BusinessPlaceMemberDTO.from(updated, user);
    }

    /**
     * 멤버 강제 탈퇴 (Owner만 가능)
     * 탈퇴 시 해당 멤버의 사업장 내 모든 참조를 정리합니다.
     *
     * @param userBusinessPlaceId UserBusinessPlace ID
     * @param ownerId 요청자 ID (Owner 확인용)
     */
    @Transactional
    public void removeMember(UUID userBusinessPlaceId, String ownerId) {
        UserBusinessPlace targetUbp = userBusinessPlaceRepository.findById(userBusinessPlaceId)
                .orElseThrow(() -> new ResourceNotFoundException("멤버를 찾을 수 없습니다"));

        UUID ownerUuid = UUID.fromString(ownerId);
        // 요청자가 Owner인지 확인
        UserBusinessPlace ownerUbp = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceId(ownerUuid, targetUbp.getBusinessPlaceId())
                .orElseThrow(() -> new AccessDeniedException("권한이 없습니다"));

        if (ownerUbp.getRole() != Role.OWNER) {
            throw new AccessDeniedException("Owner만 멤버를 삭제할 수 있습니다");
        }

        // 본인(Owner)은 삭제 불가
        if (targetUbp.getUserId().equals(ownerUuid)) {
            throw new InvalidInputException("본인은 삭제할 수 없습니다");
        }

        // Owner 역할인 멤버는 삭제 불가
        if (targetUbp.getRole() == Role.OWNER) {
            throw new InvalidInputException("Owner는 삭제할 수 없습니다");
        }

        UUID targetUserId = targetUbp.getUserId();
        String businessPlaceId = targetUbp.getBusinessPlaceId();

        // 사용자 참조 정리 (탈퇴 로직과 동일)
        cleanupUserReferences(businessPlaceId, targetUserId.toString());

        // UserBusinessPlace 삭제
        userBusinessPlaceRepository.delete(targetUbp);

        // 대상 사용자의 기본 사업장이 이 사업장이었다면 null로 설정
        User targetUser = userRepository.findById(targetUserId).orElse(null);
        if (targetUser != null && businessPlaceId.equals(targetUser.getDefaultBusinessPlaceId())) {
            targetUser.setDefaultBusinessPlaceId(null);
            userRepository.save(targetUser);
        }

        log.info("Member removed from business place - userId: {}, businessPlaceId: {}", targetUserId, businessPlaceId);
    }

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 사업장 삭제 미리보기
     *
     * 사업장 삭제 시 함께 삭제될 데이터의 개수를 조회합니다.
     * Owner만 조회 가능합니다.
     *
     * @param businessPlaceId 사업장 ID
     * @param userId 요청자 ID (Owner 확인용)
     * @return 삭제될 데이터 개수 정보
     */
    public BusinessPlaceDeletionPreviewDTO getDeletionPreview(String businessPlaceId, String userId) {
        // 사업장 존재 여부 확인
        BusinessPlace businessPlace = businessPlaceRepository.findById(businessPlaceId)
                .orElseThrow(() -> new ResourceNotFoundException("사업장을 찾을 수 없습니다"));

        // Owner 권한 확인
        UserBusinessPlace ubp = userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId)
                .orElseThrow(() -> new AccessDeniedException("권한이 없습니다"));

        if (ubp.getRole() != Role.OWNER) {
            throw new AccessDeniedException("Owner만 사업장을 삭제할 수 있습니다");
        }

        // 각 테이블의 데이터 개수 조회
        long memberCount = memberRepository.countByBusinessPlaceId(businessPlaceId);
        long memoCount = memoRepository.countByBusinessPlaceId(businessPlaceId);
        long reservationCount = reservationRepository.countByBusinessPlaceId(businessPlaceId);
        long visitCount = visitRepository.countByBusinessPlaceId(businessPlaceId);
        long auditLogCount = auditLogRepository.countByBusinessPlaceId(businessPlaceId);
        long staffCount = userBusinessPlaceRepository.countStaffByBusinessPlaceId(businessPlaceId);
        long accessRequestCount = accessRequestRepository.countByBusinessPlaceId(businessPlaceId);

        return BusinessPlaceDeletionPreviewDTO.builder()
                .businessPlaceId(businessPlaceId)
                .businessPlaceName(businessPlace.getName())
                .memberCount(memberCount)
                .memoCount(memoCount)
                .reservationCount(reservationCount)
                .visitCount(visitCount)
                .auditLogCount(auditLogCount)
                .staffCount(staffCount)
                .accessRequestCount(accessRequestCount)
                .build();
    }

    /**
     * 사업장 영구 삭제
     *
     * 사업장과 관련된 모든 데이터를 영구적으로 삭제합니다.
     * Owner만 삭제 가능하며, 확인용으로 사업장 이름을 정확히 입력해야 합니다.
     *
     * 삭제 순서 (FK 제약조건 고려):
     * 1. Users.default_business_place_id를 NULL로 설정
     * 2. Memos 삭제 (member_id FK)
     * 3. Visits 삭제 (member_id FK)
     * 4. Reservations 삭제
     * 5. AuditLogs 삭제
     * 6. Members 삭제
     * 7. BusinessPlaceAccessRequests 삭제
     * 8. UserBusinessPlaces 삭제
     * 9. BusinessPlace 삭제
     *
     * @param businessPlaceId 사업장 ID
     * @param userId 요청자 ID (Owner 확인용)
     * @param confirmName 확인용 사업장 이름
     */
    @Transactional(propagation = Propagation.REQUIRED, rollbackFor = Exception.class)
    public void deleteBusinessPlacePermanently(String businessPlaceId, String userId, String confirmName) {
        log.info("Starting permanent deletion of business place - businessPlaceId: {}, userId: {}", businessPlaceId, userId);

        // 사업장 존재 여부 확인
        BusinessPlace businessPlace = businessPlaceRepository.findById(businessPlaceId)
                .orElseThrow(() -> new ResourceNotFoundException("사업장을 찾을 수 없습니다"));

        // Owner 권한 확인
        UserBusinessPlace ubp = userBusinessPlaceRepository.findByUserIdAndBusinessPlaceId(UUID.fromString(userId), businessPlaceId)
                .orElseThrow(() -> new AccessDeniedException("권한이 없습니다"));

        if (ubp.getRole() != Role.OWNER) {
            throw new AccessDeniedException("Owner만 사업장을 삭제할 수 있습니다");
        }

        // 사업장 이름 확인 (Type-to-Confirm)
        if (!businessPlace.getName().equals(confirmName)) {
            throw new InvalidInputException("사업장 이름이 일치하지 않습니다");
        }

        // 삭제할 회원 ID 목록 조회 (메모, 방문 기록 삭제에 필요)
        List<UUID> memberIds = memberRepository.findMemberIdsByBusinessPlaceId(businessPlaceId);

        // 1. Users.default_business_place_id를 NULL로 설정
        int clearedDefaultBpCount = userRepository.clearDefaultBusinessPlaceId(businessPlaceId);
        log.debug("Cleared default_business_place_id for {} users", clearedDefaultBpCount);

        // 2. Memos 삭제 (member_id FK 때문에 Members보다 먼저)
        int deletedMemos = 0;
        if (!memberIds.isEmpty()) {
            deletedMemos = memoRepository.deleteAllByMemberIds(memberIds);
        }
        log.debug("Deleted {} memos", deletedMemos);

        // 3. Visits 삭제 (member_id FK 때문에 Members보다 먼저)
        int deletedVisits = 0;
        if (!memberIds.isEmpty()) {
            deletedVisits = visitRepository.deleteAllByMemberIds(memberIds);
        }
        log.debug("Deleted {} visits", deletedVisits);

        // 4. Reservations 삭제
        int deletedReservations = reservationRepository.deleteAllByBusinessPlaceId(businessPlaceId);
        log.debug("Deleted {} reservations", deletedReservations);

        // 5. AuditLogs 삭제
        int deletedAuditLogs = auditLogRepository.deleteAllByBusinessPlaceId(businessPlaceId);
        log.debug("Deleted {} audit logs", deletedAuditLogs);

        // 6. Members 삭제
        int deletedMembers = memberRepository.deleteAllByBusinessPlaceId(businessPlaceId);
        log.debug("Deleted {} members", deletedMembers);

        // 7. BusinessPlaceAccessRequests 삭제
        int deletedAccessRequests = accessRequestRepository.deleteAllByBusinessPlaceId(businessPlaceId);
        log.debug("Deleted {} access requests", deletedAccessRequests);

        // 8. UserBusinessPlaces 삭제
        int deletedUserBusinessPlaces = userBusinessPlaceRepository.deleteAllByBusinessPlaceId(businessPlaceId);
        log.debug("Deleted {} user-business-place relationships", deletedUserBusinessPlaces);

        // 영속성 컨텍스트 flush & clear
        // bulk delete 쿼리 후 영속성 컨텍스트와 DB 상태를 동기화하고,
        // UserBusinessPlace의 lazy-loaded businessPlace 참조로 인한 문제 방지
        entityManager.flush();
        entityManager.clear();

        // 9. BusinessPlace 삭제 (영속성 컨텍스트가 clear되었으므로 다시 조회)
        BusinessPlace businessPlaceToDelete = businessPlaceRepository.findById(businessPlaceId)
                .orElse(null);
        if (businessPlaceToDelete != null) {
            businessPlaceRepository.delete(businessPlaceToDelete);
        }

        log.info("Business place permanently deleted - businessPlaceId: {}, name: {}, " +
                        "members: {}, memos: {}, visits: {}, reservations: {}, auditLogs: {}, " +
                        "accessRequests: {}, userBusinessPlaces: {}",
                businessPlaceId, businessPlace.getName(),
                deletedMembers, deletedMemos, deletedVisits, deletedReservations,
                deletedAuditLogs, deletedAccessRequests, deletedUserBusinessPlaces);
    }
}
