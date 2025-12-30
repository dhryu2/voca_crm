package com.vocacrm.api.service;

import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.MemoRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemoService {

    private final MemoRepository memoRepository;
    private final MemberRepository memberRepository;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;
    private final UserRepository userRepository;

    /**
     * 메모 ID로 조회 (사업장 권한 검증 포함)
     * @param id 메모 ID
     * @param businessPlaceId 사업장 ID (권한 검증용)
     */
    public Memo getMemoById(String id, String businessPlaceId) {
        Memo memo = memoRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new RuntimeException("Memo not found with id: " + id));

        if (Boolean.TRUE.equals(memo.getIsDeleted())) {
            throw new RuntimeException("삭제된 메모입니다: " + id);
        }

        // 사업장 권한 검증 - Member를 통해 확인
        Member member = memberRepository.findById(memo.getMemberId())
                .orElseThrow(() -> new RuntimeException("Member not found"));

        if (!member.getBusinessPlaceId().equals(businessPlaceId)) {
            throw new RuntimeException("해당 사업장의 메모가 아닙니다");
        }

        return memo;
    }

    /**
     * 삭제 여부와 관계없이 메모 조회 (관리용)
     */
    public Memo getMemoByIdIncludeDeleted(String id) {
        return memoRepository.findById(UUID.fromString(id))
                .orElseThrow(() -> new RuntimeException("Memo not found with id: " + id));
    }

    /**
     * 사업장별 메모 목록 조회 (삭제되지 않은 메모만)
     * 컨트롤러에서 권한 검증을 먼저 수행해야 합니다.
     * @param businessPlaceId 사업장 ID
     * @return 해당 사업장의 전체 메모 목록 (최근 수정순)
     */
    public List<Memo> getMemosByBusinessPlace(String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다");
        }
        return memoRepository.findByBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(businessPlaceId);
    }

    /**
     * 회원별 메모 목록 조회 (삭제되지 않은 메모만, 사업장 권한 검증 포함)
     * @param memberId 회원 ID
     * @param businessPlaceId 사업장 ID (권한 검증용)
     */
    public List<Memo> getMemosByMemberId(String memberId, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(
                UUID.fromString(memberId), businessPlaceId);
    }

    /**
     * 회원의 최신 메모 조회 (삭제되지 않은 메모만, 사업장 권한 검증 포함)
     * @param memberId 회원 ID
     * @param businessPlaceId 사업장 ID (권한 검증용)
     */
    public Memo getLatestMemoByMemberId(String memberId, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return memoRepository.findFirstByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(
                UUID.fromString(memberId), businessPlaceId)
                .orElse(null);
    }

    @Transactional(isolation = Isolation.SERIALIZABLE)
    public Memo createMemo(Memo memo) {
        // Set default owner if not provided (ownerId is UUID)
        // Note: Default owner handling should be done by caller

        // Check memo limit (삭제되지 않은 메모만 카운트)
        Member member = memberRepository.findById(memo.getMemberId())
                .orElseThrow(() -> new RuntimeException("Member not found"));

        // Get owner of business place to check tier
        if (member.getBusinessPlaceId() != null) {
            List<UserBusinessPlace> owners = userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(
                    member.getBusinessPlaceId(), AccessStatus.APPROVED);

            UserBusinessPlace owner = owners.stream()
                    .filter(ubp -> ubp.getRole() == Role.OWNER)
                    .findFirst()
                    .orElse(null);

            if (owner != null) {
                User ownerUser = userRepository.findById(owner.getUserId()).orElse(null);
                if (ownerUser != null) {
                    // Race Condition 방지: SERIALIZABLE 격리 수준 + 비관적 잠금으로 동시성 제어
                    int maxMemos = getMaxMemos(ownerUser.getTier());
                    long currentCount = memoRepository.countByMemberIdAndBusinessPlaceIdAndIsDeletedFalseWithLock(
                            memo.getMemberId(), member.getBusinessPlaceId());

                    if (currentCount >= maxMemos) {
                        throw new RuntimeException("MEMO_LIMIT_EXCEEDED:" + maxMemos);
                    }
                }
            }
        }

        return memoRepository.save(memo);
    }

    /**
     * 음성 명령용 간편 메모 생성 메서드 (기본 소유자)
     */
    @Transactional
    public Memo createMemo(String memberId, String content) {
        return createMemo(memberId, content, null);
    }

    /**
     * 음성 명령용 메모 생성 메서드 (소유자 지정)
     */
    @Transactional
    public Memo createMemo(String memberId, String content, String ownerId) {
        Memo memo = new Memo();
        memo.setMemberId(UUID.fromString(memberId));
        memo.setContent(content);
        if (ownerId != null) {
            memo.setOwnerId(UUID.fromString(ownerId));
        }
        return createMemo(memo);
    }

    @Transactional
    public Memo createMemoWithOldestDeletion(Memo memo) {
        // Get member to check business place
        Member member = memberRepository.findById(memo.getMemberId())
                .orElseThrow(() -> new RuntimeException("Member not found"));

        // Delete oldest memo first (삭제되지 않은 메모 중)
        List<Memo> memos = memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(
                memo.getMemberId(), member.getBusinessPlaceId());
        if (!memos.isEmpty()) {
            // Delete the oldest (last in DESC order)
            memoRepository.delete(memos.get(memos.size() - 1));
        }

        // Then create new memo
        return createMemo(memo);
    }

    private int getMaxMemos(String tier) {
        // Currently same for both FREE and PREMIUM
        // Will be increased for PREMIUM later
        return 100;
    }

    /**
     * @deprecated 권한 체크가 없으므로 updateMemoWithPermission 사용 권장
     */
    @Transactional
    @Deprecated
    public Memo updateMemo(String id, Memo memoDetails, String businessPlaceId) {
        Memo memo = getMemoById(id, businessPlaceId);
        memo.setContent(memoDetails.getContent());
        // 마지막 수정자 설정 (제공된 경우)
        if (memoDetails.getLastModifiedById() != null) {
            memo.setLastModifiedById(memoDetails.getLastModifiedById());
        }
        return memoRepository.save(memo);
    }

    /**
     * Ownership 기반 권한 체크 후 메모 수정
     *
     * 수정 권한 규칙:
     * - 소유자: 수정 가능
     * - 같은 Role: 수정 가능 (협업 허용)
     * - 상위 Role: 수정 가능
     */
    @Transactional
    public Memo updateMemoWithPermission(String id, Memo memoDetails, String requestUserId, String businessPlaceId) {
        Memo memo = getMemoById(id, businessPlaceId);

        // 수정 권한 체크 (Ownership 기반)
        checkPermissionForEdit(memo.getOwnerId(), requestUserId, businessPlaceId);

        // 필드 업데이트
        memo.setContent(memoDetails.getContent());
        memo.setLastModifiedById(UUID.fromString(requestUserId));
        return memoRepository.save(memo);
    }

    @Transactional
    public void deleteMemo(String id) {
        memoRepository.deleteById(UUID.fromString(id));
    }

    /**
     * Ownership 기반 권한 체크 후 메모 삭제 (hard delete)
     * @deprecated Soft Delete 사용 권장 - softDeleteMemo 사용
     */
    @Transactional
    @Deprecated
    public void deleteMemoWithPermission(String id, String requestUserId, String businessPlaceId) {
        Memo memo = getMemoById(id, businessPlaceId);
        checkPermissionForDelete(memo.getOwnerId(), requestUserId, businessPlaceId);
        memoRepository.deleteById(UUID.fromString(id));
    }

    // ===== Soft Delete 관련 메서드 =====

    /**
     * 메모 Soft Delete (삭제 대기 상태로 전환)
     *
     * 삭제 권한 규칙 (Ownership 기반):
     * - 소유자: 삭제 가능
     * - 같은 Role: 삭제 불가 (데이터 보호)
     * - 상위 Role: 삭제 가능
     */
    @Transactional
    public Memo softDeleteMemo(String id, String requestUserId, String businessPlaceId) {
        Memo memo = getMemoByIdIncludeDeleted(id);

        if (Boolean.TRUE.equals(memo.getIsDeleted())) {
            throw new RuntimeException("이미 삭제 대기 중인 메모입니다.");
        }

        // 삭제 권한 체크 (Ownership 기반)
        checkPermissionForDelete(memo.getOwnerId(), requestUserId, businessPlaceId);

        // 메모 soft delete 처리
        memo.setIsDeleted(true);
        memo.setDeletedAt(LocalDateTime.now());
        memo.setDeletedBy(UUID.fromString(requestUserId));

        return memoRepository.save(memo);
    }

    /**
     * 삭제 대기 메모 목록 조회 (회원별, 사업장 필터링 포함)
     */
    public List<Memo> getDeletedMemosByMemberId(String memberId, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(UUID.fromString(memberId), businessPlaceId);
    }

    /**
     * 사용자가 접근 가능한 모든 사업장의 삭제 대기 메모 목록 조회
     *
     * UserBusinessPlace를 통해 사용자가 APPROVED 상태로 접근할 수 있는 사업장의
     * 모든 회원들의 삭제된 메모를 조회합니다.
     *
     * @param userId 사용자 ID
     * @return 삭제 대기 중인 메모 목록 (삭제 시간 내림차순)
     */
    public List<Memo> getDeletedMemosByUserId(String userId) {
        if (userId == null || userId.isEmpty()) {
            throw new IllegalArgumentException("userId는 필수입니다");
        }
        return memoRepository.findDeletedMemosByUserId(UUID.fromString(userId));
    }

    /**
     * 특정 사업장의 삭제 대기 메모 목록 조회
     * 사용자가 해당 사업장에 접근 권한이 있는지 확인합니다.
     *
     * @param userId 사용자 ID
     * @param businessPlaceId 조회할 사업장 ID
     * @return 삭제 대기 중인 메모 목록 (삭제 시간 내림차순)
     */
    public List<Memo> getDeletedMemosByBusinessPlace(String userId, String businessPlaceId) {
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

        return memoRepository.findDeletedMemosByBusinessPlaceId(businessPlaceId);
    }

    /**
     * 메모 복원 (삭제 대기 상태 취소)
     * MANAGER 이상만 가능
     * 회원이 삭제 대기 중이면 복원 불가
     */
    @Transactional
    public Memo restoreMemo(String id, String requestUserId, String businessPlaceId) {
        Memo memo = getMemoByIdIncludeDeleted(id);

        if (!Boolean.TRUE.equals(memo.getIsDeleted())) {
            throw new RuntimeException("삭제 대기 상태가 아닌 메모입니다.");
        }

        // MANAGER 이상만 복원 가능
        checkManagerOrAbove(requestUserId, businessPlaceId, "복원");

        // 회원 상태 확인 - 회원이 삭제 대기 중이면 메모 복원 불가
        Member member = memberRepository.findById(memo.getMemberId())
                .orElseThrow(() -> new RuntimeException("회원을 찾을 수 없습니다."));

        if (Boolean.TRUE.equals(member.getIsDeleted())) {
            throw new RuntimeException("삭제 대기 중인 회원의 메모는 복원할 수 없습니다. 먼저 회원을 복원해주세요.");
        }

        // 메모 복원
        memo.setIsDeleted(false);
        memo.setDeletedAt(null);
        memo.setDeletedBy(null);

        return memoRepository.save(memo);
    }

    /**
     * 메모 영구 삭제 (실제 DB에서 삭제)
     * MANAGER 이상만 가능
     */
    @Transactional
    public void permanentDeleteMemo(String id, String requestUserId, String businessPlaceId) {
        Memo memo = getMemoByIdIncludeDeleted(id);

        if (!Boolean.TRUE.equals(memo.getIsDeleted())) {
            throw new RuntimeException("삭제 대기 상태인 메모만 영구 삭제할 수 있습니다.");
        }

        // MANAGER 이상만 영구 삭제 가능
        checkManagerOrAbove(requestUserId, businessPlaceId, "영구 삭제");

        memoRepository.deleteById(UUID.fromString(id));
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
     * @param ownerId 레코드 소유자 ID (UUID)
     * @param requestUserId 요청자 ID (String)
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
     * @param ownerId 레코드 소유자 ID (UUID)
     * @param requestUserId 요청자 ID (String)
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
