package com.vocacrm.api.service;

import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.exception.BusinessException;
import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.exception.ResourceNotFoundException;
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
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MemoServiceTest {

    @Mock
    private MemoRepository memoRepository;

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private AccessControlService accessControlService;

    @InjectMocks
    private MemoService memoService;

    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Test
    void createMemo_정상_생성한다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        Memo memo = new Memo();
        memo.setMemberId(memberUuid);
        memo.setContent("메모 내용");

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findOwnersByBusinessPlaceId(BUSINESS_PLACE_ID)).thenReturn(List.of());
        when(memoRepository.save(memo)).thenReturn(memo);

        Memo result = memoService.createMemo(memo);

        assertThat(result).isEqualTo(memo);
    }

    @Test
    void getMemoById_정상_조회한다() {
        UUID memoUuid = UUID.randomUUID();
        UUID memberUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setMemberId(memberUuid);
        memo.setIsDeleted(false);

        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        Memo result = memoService.getMemoById(memoUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result).isEqualTo(memo);
    }

    @Test
    void softDeleteMemo_OWNER면_정상_삭제_대기_상태로_전환한다() {
        UUID memoUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setOwnerId(UUID.randomUUID());
        memo.setIsDeleted(false);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memoRepository.save(memo)).thenReturn(memo);

        Memo result = memoService.softDeleteMemo(memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result.getIsDeleted()).isTrue();
        assertThat(result.getDeletedBy()).isEqualTo(requestUserUuid);
    }

    @Test
    void softDeleteMemo_STAFF가_타인_소유_메모를_삭제하려하면_AccessDeniedException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        UUID ownerUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setOwnerId(ownerUuid);
        memo.setIsDeleted(false);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                ownerUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ownerUbp));

        assertThatThrownBy(() -> memoService.softDeleteMemo(memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void softDeleteMemo_MANAGER가_OWNER_소유_메모를_삭제하려하면_AccessDeniedException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        UUID ownerUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setOwnerId(ownerUuid);
        memo.setIsDeleted(false);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER)
                .status(AccessStatus.APPROVED)
                .build();
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                ownerUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ownerUbp));

        assertThatThrownBy(() -> memoService.softDeleteMemo(memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void softDeleteMemo_MANAGER는_STAFF_소유_메모를_삭제할_수_있다() {
        UUID memoUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        UUID ownerUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setOwnerId(ownerUuid);
        memo.setIsDeleted(false);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER)
                .status(AccessStatus.APPROVED)
                .build();
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                ownerUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ownerUbp));
        when(memoRepository.save(memo)).thenReturn(memo);

        Memo result = memoService.softDeleteMemo(memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result.getIsDeleted()).isTrue();
    }

    @Test
    void restoreMemo_정상_복원한다() {
        UUID memoUuid = UUID.randomUUID();
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setMemberId(memberUuid);
        memo.setIsDeleted(true);

        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER)
                .status(AccessStatus.APPROVED)
                .build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(memoRepository.save(memo)).thenReturn(memo);

        Memo result = memoService.restoreMemo(memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result.getIsDeleted()).isFalse();
        assertThat(result.getDeletedAt()).isNull();
    }

    @Test
    void permanentDeleteMemo_MANAGER면_영구_삭제한다() {
        UUID memoUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setIsDeleted(true);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER)
                .status(AccessStatus.APPROVED)
                .build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));

        memoService.permanentDeleteMemo(memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        verify(memoRepository).deleteById(memoUuid);
    }

    @Test
    void getMemoById_삭제된_메모면_ResourceNotFoundException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setIsDeleted(true);
        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));

        assertThatThrownBy(() -> memoService.getMemoById(memoUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getMemoById_다른_사업장_메모면_AccessDeniedException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        UUID memberUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setMemberId(memberUuid);
        memo.setIsDeleted(false);

        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId("OTHER99");

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        assertThatThrownBy(() -> memoService.getMemoById(memoUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMemoByIdIncludeDeleted_삭제된_메모도_조회한다() {
        UUID memoUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setIsDeleted(true);
        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));

        Memo result = memoService.getMemoByIdIncludeDeleted(memoUuid.toString());

        assertThat(result).isEqualTo(memo);
    }

    @Test
    void getMemoByIdIncludeDeleted_없으면_ResourceNotFoundException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        when(memoRepository.findById(memoUuid)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> memoService.getMemoByIdIncludeDeleted(memoUuid.toString()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getMemosByBusinessPlace_businessPlaceId가_null이면_예외를_던진다() {
        assertThatThrownBy(() -> memoService.getMemosByBusinessPlace(null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getMemosByBusinessPlace_정상_목록을_반환한다() {
        Memo memo = new Memo();
        when(memoRepository.findByBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(BUSINESS_PLACE_ID))
                .thenReturn(List.of(memo));

        List<Memo> result = memoService.getMemosByBusinessPlace(BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(memo);
    }

    @Test
    void getMemosByMemberId_businessPlaceId가_비어있으면_예외를_던진다() {
        assertThatThrownBy(() -> memoService.getMemosByMemberId(UUID.randomUUID().toString(), ""))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getMemosByMemberId_정상_목록을_반환한다() {
        UUID memberUuid = UUID.randomUUID();
        Memo memo = new Memo();
        when(memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(List.of(memo));

        List<Memo> result = memoService.getMemosByMemberId(memberUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(memo);
    }

    @Test
    void getLatestMemoByMemberId_businessPlaceId가_비어있으면_예외를_던진다() {
        assertThatThrownBy(() -> memoService.getLatestMemoByMemberId(UUID.randomUUID().toString(), null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getLatestMemoByMemberId_메모가_없으면_null을_반환한다() {
        UUID memberUuid = UUID.randomUUID();
        when(memoRepository.findFirstByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(Optional.empty());

        Memo result = memoService.getLatestMemoByMemberId(memberUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result).isNull();
    }

    @Test
    void getLatestMemoByMemberId_정상_최신_메모를_반환한다() {
        UUID memberUuid = UUID.randomUUID();
        Memo memo = new Memo();
        when(memoRepository.findFirstByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(Optional.of(memo));

        Memo result = memoService.getLatestMemoByMemberId(memberUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result).isEqualTo(memo);
    }

    @Test
    void createMemo_회원이_없으면_ResourceNotFoundException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setMemberId(memberUuid);
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> memoService.createMemo(memo))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void createMemo_메모_개수_제한을_초과하면_BusinessException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        Memo memo = new Memo();
        memo.setMemberId(memberUuid);

        User ownerUser = User.builder().id(UUID.randomUUID()).tier("FREE").build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findOwnersByBusinessPlaceId(BUSINESS_PLACE_ID))
                .thenReturn(List.of(ownerUser));
        when(memoRepository.countByMemberIdAndBusinessPlaceIdAndIsDeletedFalseWithLock(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(100L);

        assertThatThrownBy(() -> memoService.createMemo(memo))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    void createMemo_음성명령용_소유자지정_오버로드가_정상_생성한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID ownerUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findOwnersByBusinessPlaceId(BUSINESS_PLACE_ID)).thenReturn(List.of());
        when(memoRepository.save(any(Memo.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Memo result = memoService.createMemo(memberUuid.toString(), "음성 메모", ownerUuid.toString());

        assertThat(result.getContent()).isEqualTo("음성 메모");
        assertThat(result.getMemberId()).isEqualTo(memberUuid);
        assertThat(result.getOwnerId()).isEqualTo(ownerUuid);
    }

    @Test
    void createMemoWithOldestDeletion_가장_오래된_메모를_삭제하고_새로_생성한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        Memo newMemo = new Memo();
        newMemo.setMemberId(memberUuid);

        Memo oldest = new Memo();
        oldest.setId(UUID.randomUUID());
        oldest.setOwnerId(requestUserUuid);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(memoRepository.findOldestByMemberIdAndBusinessPlaceId(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(Optional.of(oldest));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(userBusinessPlaceRepository.findOwnersByBusinessPlaceId(BUSINESS_PLACE_ID)).thenReturn(List.of());
        when(memoRepository.save(newMemo)).thenReturn(newMemo);

        Memo result = memoService.createMemoWithOldestDeletion(newMemo, requestUserUuid.toString());

        verify(memoRepository).delete(oldest);
        assertThat(result).isEqualTo(newMemo);
    }

    @Test
    void createMemoWithOldestDeletion_삭제할_메모가_없으면_바로_생성한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        Memo newMemo = new Memo();
        newMemo.setMemberId(memberUuid);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(memoRepository.findOldestByMemberIdAndBusinessPlaceId(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(Optional.empty());
        when(userBusinessPlaceRepository.findOwnersByBusinessPlaceId(BUSINESS_PLACE_ID)).thenReturn(List.of());
        when(memoRepository.save(newMemo)).thenReturn(newMemo);

        Memo result = memoService.createMemoWithOldestDeletion(newMemo, requestUserUuid.toString());

        verify(memoRepository, never()).delete(any(Memo.class));
        assertThat(result).isEqualTo(newMemo);
    }

    @Test
    void updateMemoWithPermission_OWNER면_정상_수정한다() {
        UUID memoUuid = UUID.randomUUID();
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setMemberId(memberUuid);
        memo.setIsDeleted(false);
        memo.setOwnerId(UUID.randomUUID());

        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        Memo details = new Memo();
        details.setContent("수정된 내용");

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED)).thenReturn(true);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memoRepository.save(memo)).thenReturn(memo);

        Memo result = memoService.updateMemoWithPermission(
                memoUuid.toString(), details, requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result.getContent()).isEqualTo("수정된 내용");
        assertThat(result.getLastModifiedById()).isEqualTo(requestUserUuid);
    }

    @Test
    void toggleImportant_중요_플래그를_토글한다() {
        UUID memoUuid = UUID.randomUUID();
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setMemberId(memberUuid);
        memo.setIsDeleted(false);
        memo.setIsImportant(false);
        memo.setOwnerId(requestUserUuid);

        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED)).thenReturn(true);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memoRepository.save(memo)).thenReturn(memo);

        Memo result = memoService.toggleImportant(memoUuid.toString(), requestUserUuid.toString());

        assertThat(result.getIsImportant()).isTrue();
    }

    @Test
    void getMemoByIdForUser_userId가_null이면_예외를_던진다() {
        assertThatThrownBy(() -> memoService.getMemoByIdForUser(UUID.randomUUID().toString(), null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getMemoByIdForUser_접근권한이_없으면_AccessDeniedException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setMemberId(memberUuid);
        memo.setIsDeleted(false);

        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED)).thenReturn(false);

        assertThatThrownBy(() -> memoService.getMemoByIdForUser(memoUuid.toString(), requestUserUuid.toString()))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void deleteMemo_리포지토리에_위임한다() {
        UUID memoUuid = UUID.randomUUID();

        memoService.deleteMemo(memoUuid.toString());

        verify(memoRepository).deleteById(memoUuid);
    }

    @Test
    void deleteMemoWithPermission_OWNER면_정상_삭제한다() {
        UUID memoUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setIsDeleted(false);
        memo.setOwnerId(UUID.randomUUID());

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));

        memoService.deleteMemoWithPermission(memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        verify(memoRepository).deleteById(memoUuid);
    }

    @Test
    void softDeleteMemo_이미_삭제_대기중이면_InvalidInputException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setIsDeleted(true);
        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));

        assertThatThrownBy(() -> memoService.softDeleteMemo(
                memoUuid.toString(), UUID.randomUUID().toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void restoreMemo_삭제_대기_상태가_아니면_InvalidInputException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setIsDeleted(false);
        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));

        assertThatThrownBy(() -> memoService.restoreMemo(
                memoUuid.toString(), UUID.randomUUID().toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void restoreMemo_회원이_삭제_대기중이면_InvalidInputException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setMemberId(memberUuid);
        memo.setIsDeleted(true);

        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(true);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER).status(AccessStatus.APPROVED).build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        assertThatThrownBy(() -> memoService.restoreMemo(
                memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void permanentDeleteMemo_삭제_대기_상태가_아니면_InvalidInputException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setIsDeleted(false);
        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));

        assertThatThrownBy(() -> memoService.permanentDeleteMemo(
                memoUuid.toString(), UUID.randomUUID().toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void permanentDeleteMemo_STAFF면_AccessDeniedException을_던진다() {
        UUID memoUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setIsDeleted(true);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(accessControlService.businessPlaceOfMemo(memoUuid.toString())).thenReturn(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));

        assertThatThrownBy(() -> memoService.permanentDeleteMemo(
                memoUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getDeletedMemosByMemberId_businessPlaceId가_비어있으면_예외를_던진다() {
        assertThatThrownBy(() -> memoService.getDeletedMemosByMemberId(UUID.randomUUID().toString(), ""))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getDeletedMemosByMemberId_정상_목록을_반환한다() {
        UUID memberUuid = UUID.randomUUID();
        Memo memo = new Memo();
        when(memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(List.of(memo));

        List<Memo> result = memoService.getDeletedMemosByMemberId(memberUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(memo);
    }

    @Test
    void getDeletedMemosByUserId_userId가_null이면_예외를_던진다() {
        assertThatThrownBy(() -> memoService.getDeletedMemosByUserId(null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getDeletedMemosByUserId_정상_목록을_반환한다() {
        UUID userUuid = UUID.randomUUID();
        Memo memo = new Memo();
        when(memoRepository.findDeletedMemosByUserId(userUuid)).thenReturn(List.of(memo));

        List<Memo> result = memoService.getDeletedMemosByUserId(userUuid.toString());

        assertThat(result).containsExactly(memo);
    }

    @Test
    void getDeletedMemosByBusinessPlace_접근권한이_없으면_AccessDeniedException을_던진다() {
        UUID userUuid = UUID.randomUUID();
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED)).thenReturn(false);

        assertThatThrownBy(() -> memoService.getDeletedMemosByBusinessPlace(userUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getDeletedMemosByBusinessPlace_접근권한이_있으면_목록을_반환한다() {
        UUID userUuid = UUID.randomUUID();
        Memo memo = new Memo();
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED)).thenReturn(true);
        when(memoRepository.findDeletedMemosByBusinessPlaceId(BUSINESS_PLACE_ID)).thenReturn(List.of(memo));

        List<Memo> result = memoService.getDeletedMemosByBusinessPlace(userUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(memo);
    }

    @Test
    void updateMemo_deprecated_정상_수정한다() {
        UUID memoUuid = UUID.randomUUID();
        UUID memberUuid = UUID.randomUUID();
        Memo memo = new Memo();
        memo.setId(memoUuid);
        memo.setMemberId(memberUuid);
        memo.setIsDeleted(false);

        Member member = new Member();
        member.setId(memberUuid);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        Memo details = new Memo();
        details.setContent("변경된 내용");

        when(memoRepository.findById(memoUuid)).thenReturn(Optional.of(memo));
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(memoRepository.save(memo)).thenReturn(memo);

        Memo result = memoService.updateMemo(memoUuid.toString(), details, BUSINESS_PLACE_ID);

        assertThat(result.getContent()).isEqualTo("변경된 내용");
    }
}
