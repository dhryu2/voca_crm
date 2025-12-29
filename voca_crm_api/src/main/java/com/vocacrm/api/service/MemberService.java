package com.vocacrm.api.service;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.MemoRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberService {

    private final MemberRepository memberRepository;
    private final MemoRepository memoRepository;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;
    private final UserRepository userRepository;

    public Page<Member> getAllMembers(Pageable pageable) {
        return memberRepository.findAll(pageable);
    }

    /**
     * 페이지네이션 없는 전체 회원 조회 (삭제되지 않은 회원만)
     */
    public List<Member> getAllMembers(int skip, int limit) {
        // 기존 호환성을 위해 유지하지만, soft delete 적용 시 수정 필요
        return memberRepository.findAll().stream()
                .filter(m -> !Boolean.TRUE.equals(m.getIsDeleted()))
                .skip(skip)
                .limit(limit)
                .toList();
    }

    public Member getMemberById(String id) {
        Member member = memberRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new RuntimeException("Member not found with id: " + id));
        // 삭제된 회원은 조회 불가 (단, 관리용으로 조회할 때는 별도 메서드 사용)
        if (Boolean.TRUE.equals(member.getIsDeleted())) {
            throw new RuntimeException("삭제된 회원입니다: " + id);
        }
        return member;
    }

    /**
     * 회원 조회 (사용자 권한 체크 포함)
     * 사용자가 회원의 사업장에 접근 권한이 있는지 확인
     */
    public Member getMemberByIdWithUserCheck(String memberId, String userId) {
        Member member = getMemberById(memberId);

        // 사용자가 해당 회원의 사업장에 접근 권한이 있는지 확인
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(
                        UUID.fromString(userId), member.getBusinessPlaceId(), AccessStatus.APPROVED
                );

        if (!hasAccess) {
            throw new RuntimeException("해당 회원에 대한 접근 권한이 없습니다.");
        }

        return member;
    }

    /**
     * 사용자 ID로 접근 가능한 회원 조회 (페이징)
     */
    public Page<Member> getMembersByUserId(String userId, Pageable pageable) {
        // 사용자가 속한 사업장 목록 조회
        List<UserBusinessPlace> userBusinessPlaces = userBusinessPlaceRepository
                .findByUserIdAndStatus(UUID.fromString(userId), AccessStatus.APPROVED);

        if (userBusinessPlaces.isEmpty()) {
            return Page.empty(pageable);
        }

        List<String> businessPlaceIds = userBusinessPlaces.stream()
                .map(UserBusinessPlace::getBusinessPlaceId)
                .collect(Collectors.toList());

        // 해당 사업장들의 회원만 조회
        return memberRepository.findByBusinessPlaceIdInAndIsDeletedFalse(businessPlaceIds, pageable);
    }

    /**
     * 사업장별 회원 목록 조회 (사용자 권한 체크 포함)
     */
    public List<Member> getMembersByBusinessPlaceWithUserCheck(String businessPlaceId, String userId) {
        // 사업장 접근 권한 검증
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);

        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        return getMembersByBusinessPlace(businessPlaceId);
    }

    /**
     * 삭제 여부와 관계없이 회원 조회 (관리용)
     */
    public Member getMemberByIdIncludeDeleted(String id) {
        return memberRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new RuntimeException("Member not found with id: " + id));
    }

    /**
     * 회원번호와 사업장 ID로 회원 조회 (삭제되지 않은 회원만)
     * ⚠️ businessPlaceId 필수 - 보안상 사업장 필터링 없이 조회 불가
     */
    public List<Member> getMembersByNumber(String memberNumber, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return memberRepository.findByMemberNumberAndBusinessPlaceIdAndIsDeletedFalse(memberNumber, businessPlaceId);
    }

    /**
     * 사업장별 회원 목록 조회 (삭제되지 않은 회원만)
     */
    public List<Member> getMembersByBusinessPlace(String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다");
        }
        return memberRepository.findByBusinessPlaceIdAndIsDeletedFalse(businessPlaceId);
    }

    /**
     * 회원 검색 (사업장 필터 포함 필수, 삭제되지 않은 회원만)
     * ⚠️ businessPlaceId 필수 - 보안상 사업장 필터링 없이 조회 불가
     */
    public List<Member> searchMembers(String memberNumber, String name, String phone, String email, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }

        // 삭제되지 않은 회원만 검색 - 사업장 필터링 포함
        if (memberNumber != null && !memberNumber.isEmpty()) {
            return memberRepository.findByMemberNumberAndBusinessPlaceIdAndIsDeletedFalse(memberNumber, businessPlaceId);
        }
        if (name != null && !name.isEmpty()) {
            return memberRepository.findByNameContainingAndBusinessPlaceIdAndIsDeletedFalse(name, businessPlaceId);
        }
        if (phone != null && !phone.isEmpty()) {
            return memberRepository.findByPhoneContainingAndBusinessPlaceIdAndIsDeletedFalse(phone, businessPlaceId);
        }
        if (email != null && !email.isEmpty()) {
            return memberRepository.findByEmailContainingAndBusinessPlaceIdAndIsDeletedFalse(email, businessPlaceId);
        }
        // 조건 없으면 해당 사업장의 모든 회원 반환
        return memberRepository.findByBusinessPlaceIdAndIsDeletedFalse(businessPlaceId);
    }

    @Transactional(isolation = Isolation.SERIALIZABLE)
    public Member createMember(Member member) {
        // businessPlaceId는 필수입니다
        if (member.getBusinessPlaceId() == null || member.getBusinessPlaceId().isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다");
        }

        // Find owner of the business place
        List<UserBusinessPlace> owners = userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(
                member.getBusinessPlaceId(), AccessStatus.APPROVED);

        UserBusinessPlace owner = owners.stream()
                .filter(ubp -> ubp.getRole() == Role.OWNER)
                .findFirst()
                .orElseThrow(() -> new RuntimeException("Business place owner not found"));

        User ownerUser = userRepository.findById(owner.getUserId())
                .orElseThrow(() -> new RuntimeException("Owner user not found"));

        // Check member limit based on tier
        // Race Condition 방지: SERIALIZABLE 격리 수준 + 비관적 잠금으로 동시성 제어
        int maxMembers = getMaxMembers(ownerUser.getTier());
        long currentCount = memberRepository.countByBusinessPlaceIdWithLock(member.getBusinessPlaceId());

        if (currentCount >= maxMembers) {
            throw new RuntimeException("MEMBER_LIMIT_EXCEEDED:" + maxMembers);
        }

        return memberRepository.save(member);
    }

    private int getMaxMembers(String tier) {
        // Currently same for both FREE and PREMIUM
        // Will be increased for PREMIUM later
        return 500;
    }

    @Transactional
    public Member updateMember(String id, Member memberDetails) {
        Member member = getMemberById(id);
        member.setMemberNumber(memberDetails.getMemberNumber());
        member.setName(memberDetails.getName());
        member.setPhone(memberDetails.getPhone());
        member.setEmail(memberDetails.getEmail());
        if (memberDetails.getGrade() != null) {
            member.setGrade(memberDetails.getGrade());
        }
        // 마지막 수정자 설정 (제공된 경우)
        if (memberDetails.getLastModifiedById() != null) {
            member.setLastModifiedById(memberDetails.getLastModifiedById());
        }
        return memberRepository.save(member);
    }

    /**
     * Ownership 기반 권한 체크 후 회원 수정
     *
     * 수정 권한 규칙:
     * - 소유자: 수정 가능
     * - 같은 Role: 수정 가능 (협업 허용)
     * - 상위 Role: 수정 가능
     */
    @Transactional
    public Member updateMemberWithPermission(String id, Member memberDetails, String requestUserId, String businessPlaceId) {
        Member member = getMemberById(id);

        // 수정 권한 체크 (Ownership 기반)
        checkPermissionForEdit(member.getOwnerId(), requestUserId, businessPlaceId);

        // 필드 업데이트
        member.setMemberNumber(memberDetails.getMemberNumber());
        member.setName(memberDetails.getName());
        member.setPhone(memberDetails.getPhone());
        member.setEmail(memberDetails.getEmail());
        if (memberDetails.getGrade() != null) {
            member.setGrade(memberDetails.getGrade());
        }
        // 마지막 수정자 설정
        member.setLastModifiedById(UUID.fromString(requestUserId));
        return memberRepository.save(member);
    }

    @Transactional
    public void deleteMember(String id) {
        memberRepository.deleteById(UUID.fromString(id));
    }

    /**
     * Ownership 기반 권한 체크 후 회원 삭제 (hard delete)
     * @deprecated Soft Delete 사용 권장 - softDeleteMember 사용
     */
    @Transactional
    @Deprecated
    public void deleteMemberWithPermission(String id, String requestUserId, String businessPlaceId) {
        Member member = getMemberById(id);
        checkPermissionForDelete(member.getOwnerId(), requestUserId, businessPlaceId);
        memberRepository.deleteById(UUID.fromString(id));
    }

    // ===== Soft Delete 관련 메서드 =====

    /**
     * 회원 Soft Delete (삭제 대기 상태로 전환)
     *
     * 삭제 권한 규칙 (Ownership 기반):
     * - 소유자: 삭제 가능
     * - 같은 Role: 삭제 불가 (데이터 보호)
     * - 상위 Role: 삭제 가능
     */
    @Transactional
    public Member softDeleteMember(String id, String requestUserId, String businessPlaceId) {
        Member member = getMemberByIdIncludeDeleted(id);

        if (Boolean.TRUE.equals(member.getIsDeleted())) {
            throw new RuntimeException("이미 삭제 대기 중인 회원입니다.");
        }

        // 삭제 권한 체크 (Ownership 기반)
        checkPermissionForDelete(member.getOwnerId(), requestUserId, businessPlaceId);

        // 회원 soft delete 처리
        UUID requestUserUuid = UUID.fromString(requestUserId);
        member.setIsDeleted(true);
        member.setDeletedAt(LocalDateTime.now());
        member.setDeletedBy(requestUserUuid);
        memberRepository.save(member);

        // 해당 회원의 메모도 함께 soft delete 처리 (배치 저장으로 N+1 방지)
        List<Memo> memos = memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(
                member.getId(), member.getBusinessPlaceId());
        if (!memos.isEmpty()) {
            LocalDateTime now = LocalDateTime.now();
            for (Memo memo : memos) {
                memo.setIsDeleted(true);
                memo.setDeletedAt(now);
                memo.setDeletedBy(requestUserUuid);
            }
            memoRepository.saveAll(memos);
        }

        return member;
    }

    /**
     * 사용자가 접근 가능한 모든 사업장의 삭제 대기 회원 목록 조회
     *
     * UserBusinessPlace를 통해 사용자가 APPROVED 상태로 접근할 수 있는 사업장의
     * 모든 삭제 대기 회원을 조회합니다.
     *
     * @param userId 사용자 ID
     * @return 삭제 대기 중인 회원 목록 (삭제 시간 내림차순)
     */
    public List<Member> getDeletedMembers(String userId) {
        if (userId == null || userId.isEmpty()) {
            throw new IllegalArgumentException("userId는 필수입니다");
        }
        return memberRepository.findDeletedMembersByUserId(UUID.fromString(userId));
    }

    /**
     * 사용자가 접근 가능한 모든 사업장의 삭제 대기 회원 수 조회
     *
     * @param userId 사용자 ID
     * @return 삭제 대기 중인 회원 수
     */
    public long getDeletedMemberCount(String userId) {
        if (userId == null || userId.isEmpty()) {
            throw new IllegalArgumentException("userId는 필수입니다");
        }
        return memberRepository.countDeletedMembersByUserId(UUID.fromString(userId));
    }

    /**
     * 특정 사업장의 삭제 대기 회원 목록 조회
     * 사용자가 해당 사업장에 접근 권한이 있는지 확인합니다.
     *
     * @param userId 사용자 ID
     * @param businessPlaceId 조회할 사업장 ID
     * @return 삭제 대기 중인 회원 목록 (삭제 시간 내림차순)
     */
    public List<Member> getDeletedMembersByBusinessPlace(String userId, String businessPlaceId) {
        if (userId == null || userId.isEmpty()) {
            throw new IllegalArgumentException("userId는 필수입니다");
        }
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다");
        }

        // 사용자가 해당 사업장에 접근 권한이 있는지 확인
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);
        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        return memberRepository.findByBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(businessPlaceId);
    }

    /**
     * 특정 사업장의 삭제 대기 회원 수 조회
     *
     * @param userId 사용자 ID
     * @param businessPlaceId 조회할 사업장 ID
     * @return 삭제 대기 중인 회원 수
     */
    public long getDeletedMemberCountByBusinessPlace(String userId, String businessPlaceId) {
        if (userId == null || userId.isEmpty()) {
            throw new IllegalArgumentException("userId는 필수입니다");
        }
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다");
        }

        // 사용자가 해당 사업장에 접근 권한이 있는지 확인
        boolean hasAccess = userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);
        if (!hasAccess) {
            throw new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다.");
        }

        return memberRepository.countByBusinessPlaceIdAndIsDeletedTrue(businessPlaceId);
    }

    /**
     * 회원 복원 (삭제 대기 상태 취소)
     * MANAGER 이상만 가능
     */
    @Transactional
    public Member restoreMember(String id, String requestUserId, String businessPlaceId) {
        Member member = getMemberByIdIncludeDeleted(id);

        if (!Boolean.TRUE.equals(member.getIsDeleted())) {
            throw new RuntimeException("삭제 대기 상태가 아닌 회원입니다.");
        }

        // MANAGER 이상만 복원 가능
        checkManagerOrAbove(requestUserId, businessPlaceId, "복원");

        // 회원 복원
        member.setIsDeleted(false);
        member.setDeletedAt(null);
        member.setDeletedBy(null);
        memberRepository.save(member);

        // 해당 회원의 메모도 함께 복원 (배치 저장으로 N+1 방지)
        List<Memo> memos = memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(
                member.getId(), member.getBusinessPlaceId());
        if (!memos.isEmpty()) {
            for (Memo memo : memos) {
                memo.setIsDeleted(false);
                memo.setDeletedAt(null);
                memo.setDeletedBy(null);
            }
            memoRepository.saveAll(memos);
        }

        return member;
    }

    /**
     * 회원 영구 삭제 (실제 DB에서 삭제)
     * MANAGER 이상만 가능
     */
    @Transactional
    public void permanentDeleteMember(String id, String requestUserId, String businessPlaceId) {
        Member member = getMemberByIdIncludeDeleted(id);

        if (!Boolean.TRUE.equals(member.getIsDeleted())) {
            throw new RuntimeException("삭제 대기 상태인 회원만 영구 삭제할 수 있습니다.");
        }

        // MANAGER 이상만 영구 삭제 가능
        checkManagerOrAbove(requestUserId, businessPlaceId, "영구 삭제");

        // 메모는 CASCADE로 삭제됨
        memberRepository.deleteById(UUID.fromString(id));
    }

    /**
     * MANAGER 이상 권한 체크
     */
    private void checkManagerOrAbove(String requestUserId, String businessPlaceId, String action) {
        UserBusinessPlace requestUserRole = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(requestUserId), businessPlaceId, AccessStatus.APPROVED)
                .orElseThrow(() -> new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다."));

        Role role = requestUserRole.getRole();
        if (role != Role.OWNER && role != Role.MANAGER) {
            throw new RuntimeException(action + " 권한이 없습니다. MANAGER 이상만 가능합니다.");
        }
    }

    // ===== Ownership 기반 권한 체크 (새로운 방식) =====

    /**
     * 수정 권한 체크 (Ownership 기반)
     *
     * 수정 권한 규칙:
     * - 소유자: 수정 가능
     * - 같은 Role: 수정 가능 (협업 허용)
     * - 상위 Role: 수정 가능
     *
     * @param ownerId 레코드 소유자 ID
     * @param requestUserId 요청자 ID
     * @param businessPlaceId 사업장 ID
     */
    private void checkPermissionForEdit(UUID ownerId, String requestUserId, String businessPlaceId) {
        // 요청자의 role 조회
        UserBusinessPlace requestUserRole = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(requestUserId), businessPlaceId, AccessStatus.APPROVED)
                .orElseThrow(() -> new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다."));

        Role requesterRole = requestUserRole.getRole();

        // 1. OWNER는 모두 수정 가능
        if (requesterRole == Role.OWNER) {
            return;
        }

        // 2. 소유자가 없으면 (기존 데이터 또는 탈퇴한 사용자) 허용
        if (ownerId == null) {
            return;
        }

        // 3. 본인 소유면 수정 가능
        if (requestUserId.equals(ownerId.toString())) {
            return;
        }

        // 4. 소유자의 role 조회
        UserBusinessPlace ownerRole = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceIdAndStatus(ownerId, businessPlaceId, AccessStatus.APPROVED)
                .orElse(null);

        // 소유자가 탈퇴한 경우 (null) → 허용
        if (ownerRole == null) {
            return;
        }

        Role ownerRoleType = ownerRole.getRole();

        // 5. 요청자가 MANAGER인 경우
        if (requesterRole == Role.MANAGER) {
            // OWNER 소유 데이터는 수정 불가
            if (ownerRoleType == Role.OWNER) {
                throw new RuntimeException("OWNER가 소유한 데이터는 수정할 수 없습니다.");
            }
            // MANAGER, STAFF 소유 데이터는 수정 가능 (같은 Role + 하위 Role)
            return;
        }

        // 6. 요청자가 STAFF인 경우
        if (requesterRole == Role.STAFF) {
            // OWNER, MANAGER 소유 데이터는 수정 불가
            if (ownerRoleType == Role.OWNER || ownerRoleType == Role.MANAGER) {
                throw new RuntimeException("상위 권한 사용자가 소유한 데이터는 수정할 수 없습니다.");
            }
            // 같은 STAFF 소유 데이터는 수정 가능 (협업 허용)
            return;
        }

        throw new RuntimeException("수정 권한이 없습니다.");
    }

    /**
     * 삭제 권한 체크 (Ownership 기반)
     *
     * 삭제 권한 규칙:
     * - 소유자: 삭제 가능
     * - 같은 Role: 삭제 불가 (데이터 보호)
     * - 상위 Role: 삭제 가능
     *
     * @param ownerId 레코드 소유자 ID
     * @param requestUserId 요청자 ID
     * @param businessPlaceId 사업장 ID
     */
    private void checkPermissionForDelete(UUID ownerId, String requestUserId, String businessPlaceId) {
        // 요청자의 role 조회
        UserBusinessPlace requestUserRole = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(requestUserId), businessPlaceId, AccessStatus.APPROVED)
                .orElseThrow(() -> new RuntimeException("해당 사업장에 대한 접근 권한이 없습니다."));

        Role requesterRole = requestUserRole.getRole();

        // 1. OWNER는 모두 삭제 가능
        if (requesterRole == Role.OWNER) {
            return;
        }

        // 2. 소유자가 없으면 (기존 데이터 또는 탈퇴한 사용자) 허용
        if (ownerId == null) {
            return;
        }

        // 3. 본인 소유면 삭제 가능
        if (requestUserId.equals(ownerId.toString())) {
            return;
        }

        // 4. 소유자의 role 조회
        UserBusinessPlace ownerRole = userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceIdAndStatus(ownerId, businessPlaceId, AccessStatus.APPROVED)
                .orElse(null);

        // 소유자가 탈퇴한 경우 (null) → 허용
        if (ownerRole == null) {
            return;
        }

        Role ownerRoleType = ownerRole.getRole();

        // 5. 요청자가 MANAGER인 경우
        if (requesterRole == Role.MANAGER) {
            // OWNER 소유 데이터는 삭제 불가
            if (ownerRoleType == Role.OWNER) {
                throw new RuntimeException("OWNER가 소유한 데이터는 삭제할 수 없습니다.");
            }
            // 다른 MANAGER 소유 데이터는 삭제 불가 (같은 Role 보호)
            if (ownerRoleType == Role.MANAGER) {
                throw new RuntimeException("다른 관리자가 소유한 데이터는 삭제할 수 없습니다.");
            }
            // STAFF 소유 데이터는 삭제 가능 (하위 Role)
            return;
        }

        // 6. 요청자가 STAFF인 경우
        if (requesterRole == Role.STAFF) {
            // 다른 사람 소유 데이터는 모두 삭제 불가
            throw new RuntimeException("본인이 소유한 데이터만 삭제할 수 있습니다.");
        }

        throw new RuntimeException("삭제 권한이 없습니다.");
    }
}