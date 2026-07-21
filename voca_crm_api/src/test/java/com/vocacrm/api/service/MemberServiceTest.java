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
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

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
class MemberServiceTest {

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private MemoRepository memoRepository;

    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private MemberService memberService;

    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Test
    void getMemberById_존재하는_회원이면_정상_조회한다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        Member result = memberService.getMemberById(memberUuid.toString());

        assertThat(result).isEqualTo(member);
    }

    @Test
    void getMemberById_존재하지_않으면_ResourceNotFoundException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> memberService.getMemberById(memberUuid.toString()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getMemberById_삭제된_회원이면_ResourceNotFoundException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(true);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        assertThatThrownBy(() -> memberService.getMemberById(memberUuid.toString()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getMemberByIdWithUserCheck_APPROVED_멤버십이면_정상_조회한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID userUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);

        Member result = memberService.getMemberByIdWithUserCheck(memberUuid.toString(), userUuid.toString());

        assertThat(result).isEqualTo(member);
    }

    @Test
    void getMemberByIdWithUserCheck_비APPROVED면_AccessDeniedException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        UUID userUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);

        assertThatThrownBy(() -> memberService.getMemberByIdWithUserCheck(memberUuid.toString(), userUuid.toString()))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void createMember_정상_생성한다() {
        UUID ownerUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();
        User ownerUser = User.builder().id(ownerUserUuid).tier("FREE").build();

        when(userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(List.of(ownerUbp));
        when(userRepository.findById(ownerUserUuid)).thenReturn(Optional.of(ownerUser));
        when(memberRepository.countByBusinessPlaceIdWithLock(BUSINESS_PLACE_ID)).thenReturn(0L);
        when(memberRepository.save(member)).thenReturn(member);

        Member result = memberService.createMember(member);

        assertThat(result).isEqualTo(member);
    }

    @Test
    void updateMemberWithPermission_OWNER면_정상_수정한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        member.setOwnerId(UUID.randomUUID());

        Member details = new Member();
        details.setMemberNumber("M001");
        details.setName("홍길동");
        details.setPhone("010-0000-0000");
        details.setEmail("test@test.com");

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memberRepository.save(member)).thenReturn(member);

        Member result = memberService.updateMemberWithPermission(
                memberUuid.toString(), details, requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result.getName()).isEqualTo("홍길동");
    }

    @Test
    void updateMemberWithPermission_권한없으면_AccessDeniedException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        UUID ownerUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        member.setOwnerId(ownerUuid);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER)
                .status(AccessStatus.APPROVED)
                .build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                ownerUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ownerUbp));

        assertThatThrownBy(() -> memberService.updateMemberWithPermission(
                memberUuid.toString(), new Member(), requestUserUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void softDeleteMember_정상_삭제_대기_상태로_전환한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memberRepository.save(member)).thenReturn(member);
        when(memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(List.<Memo>of());

        Member result = memberService.softDeleteMember(memberUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result.getIsDeleted()).isTrue();
        assertThat(result.getDeletedBy()).isEqualTo(requestUserUuid);
    }

    @Test
    void restoreMember_정상_복원한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(true);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER)
                .status(AccessStatus.APPROVED)
                .build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memberRepository.save(member)).thenReturn(member);
        when(memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(List.<Memo>of());

        Member result = memberService.restoreMember(memberUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result.getIsDeleted()).isFalse();
        assertThat(result.getDeletedAt()).isNull();
    }

    @Test
    void searchMembers_회원번호로_검색하면_정상_목록을_반환한다() {
        Member member = new Member();
        member.setMemberNumber("M001");
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        when(memberRepository.findByMemberNumberAndBusinessPlaceIdAndIsDeletedFalse("M001", BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.searchMembers("M001", null, null, null, BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(member);
    }

    @Test
    void getAllMembers_pageable_리포지토리에_위임한다() {
        Pageable pageable = PageRequest.of(0, 10);
        Page<Member> page = new PageImpl<>(List.of(new Member()));
        when(memberRepository.findAll(pageable)).thenReturn(page);

        Page<Member> result = memberService.getAllMembers(pageable);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void getAllMembers_skipLimit_삭제되지_않은_회원만_반환한다() {
        Member member = new Member();
        when(memberRepository.findByIsDeletedFalse(any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(member)));

        List<Member> result = memberService.getAllMembers(0, 50);

        assertThat(result).containsExactly(member);
    }

    @Test
    void getAllMembers_limit가_최대값을_초과하면_제한된다() {
        when(memberRepository.findByIsDeletedFalse(any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        List<Member> result = memberService.getAllMembers(0, 5000);

        assertThat(result).isEmpty();
    }

    @Test
    void getMembersByUserId_소속_사업장이_없으면_빈_페이지를_반환한다() {
        UUID userUuid = UUID.randomUUID();
        Pageable pageable = PageRequest.of(0, 10);
        when(userBusinessPlaceRepository.findByUserIdAndStatus(userUuid, AccessStatus.APPROVED))
                .thenReturn(List.of());

        Page<Member> result = memberService.getMembersByUserId(userUuid.toString(), pageable);

        assertThat(result.getContent()).isEmpty();
    }

    @Test
    void getMembersByUserId_소속_사업장의_회원을_반환한다() {
        UUID userUuid = UUID.randomUUID();
        Pageable pageable = PageRequest.of(0, 10);
        UserBusinessPlace ubp = UserBusinessPlace.builder()
                .userId(userUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();
        Member member = new Member();
        Page<Member> page = new PageImpl<>(List.of(member));

        when(userBusinessPlaceRepository.findByUserIdAndStatus(userUuid, AccessStatus.APPROVED))
                .thenReturn(List.of(ubp));
        when(memberRepository.findByBusinessPlaceIdInAndIsDeletedFalse(List.of(BUSINESS_PLACE_ID), pageable))
                .thenReturn(page);

        Page<Member> result = memberService.getMembersByUserId(userUuid.toString(), pageable);

        assertThat(result).isEqualTo(page);
    }

    @Test
    void getMembersByBusinessPlace_businessPlaceId가_null이면_예외를_던진다() {
        assertThatThrownBy(() -> memberService.getMembersByBusinessPlace(null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getMembersByBusinessPlace_정상_목록을_반환한다() {
        Member member = new Member();
        when(memberRepository.findByBusinessPlaceIdAndIsDeletedFalse(BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.getMembersByBusinessPlace(BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(member);
    }

    @Test
    void getMembersByBusinessPlaceWithUserCheck_접근권한이_없으면_AccessDeniedException을_던진다() {
        UUID userUuid = UUID.randomUUID();
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);

        assertThatThrownBy(() -> memberService.getMembersByBusinessPlaceWithUserCheck(BUSINESS_PLACE_ID, userUuid.toString()))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMembersByBusinessPlaceWithUserCheck_접근권한이_있으면_목록을_반환한다() {
        UUID userUuid = UUID.randomUUID();
        Member member = new Member();
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
        when(memberRepository.findByBusinessPlaceIdAndIsDeletedFalse(BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.getMembersByBusinessPlaceWithUserCheck(BUSINESS_PLACE_ID, userUuid.toString());

        assertThat(result).containsExactly(member);
    }

    @Test
    void getMembersByNumber_businessPlaceId가_비어있으면_예외를_던진다() {
        assertThatThrownBy(() -> memberService.getMembersByNumber("M001", ""))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getMembersByNumber_정상_목록을_반환한다() {
        Member member = new Member();
        when(memberRepository.findByMemberNumberAndBusinessPlaceIdAndIsDeletedFalse("M001", BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.getMembersByNumber("M001", BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(member);
    }

    @Test
    void searchMembers_businessPlaceId가_null이면_예외를_던진다() {
        assertThatThrownBy(() -> memberService.searchMembers(null, null, null, null, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void searchMembers_이름으로_검색한다() {
        Member member = new Member();
        when(memberRepository.findByNameContainingAndBusinessPlaceIdAndIsDeletedFalse("홍길동", BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(member);
    }

    @Test
    void searchMembers_전화번호로_검색한다() {
        Member member = new Member();
        when(memberRepository.findByPhoneContainingAndBusinessPlaceIdAndIsDeletedFalse("010", BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.searchMembers(null, null, "010", null, BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(member);
    }

    @Test
    void searchMembers_이메일로_검색한다() {
        Member member = new Member();
        when(memberRepository.findByEmailContainingAndBusinessPlaceIdAndIsDeletedFalse("test", BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.searchMembers(null, null, null, "test", BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(member);
    }

    @Test
    void searchMembers_조건이_없으면_사업장_전체_회원을_반환한다() {
        Member member = new Member();
        when(memberRepository.findByBusinessPlaceIdAndIsDeletedFalse(BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.searchMembers(null, null, null, null, BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(member);
    }

    @Test
    void getMemberByIdIncludeDeleted_삭제된_회원도_조회한다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(true);
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        Member result = memberService.getMemberByIdIncludeDeleted(memberUuid.toString());

        assertThat(result).isEqualTo(member);
    }

    @Test
    void getMemberByIdIncludeDeleted_없으면_ResourceNotFoundException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        when(memberRepository.findById(memberUuid)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> memberService.getMemberByIdIncludeDeleted(memberUuid.toString()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void createMember_businessPlaceId가_없으면_예외를_던진다() {
        Member member = new Member();

        assertThatThrownBy(() -> memberService.createMember(member))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createMember_사업장_소유자가_없으면_ResourceNotFoundException을_던진다() {
        Member member = new Member();
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(List.of());

        assertThatThrownBy(() -> memberService.createMember(member))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void createMember_회원수_제한을_초과하면_BusinessException을_던진다() {
        UUID ownerUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER)
                .status(AccessStatus.APPROVED)
                .build();
        User ownerUser = User.builder().id(ownerUserUuid).tier("FREE").build();

        when(userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(List.of(ownerUbp));
        when(userRepository.findById(ownerUserUuid)).thenReturn(Optional.of(ownerUser));
        when(memberRepository.countByBusinessPlaceIdWithLock(BUSINESS_PLACE_ID)).thenReturn(500L);

        assertThatThrownBy(() -> memberService.createMember(member))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    void updateMember_정상_수정한다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);

        Member details = new Member();
        details.setMemberNumber("M002");
        details.setName("김철수");
        details.setPhone("010-1111-2222");
        details.setEmail("kim@test.com");

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(memberRepository.save(member)).thenReturn(member);

        Member result = memberService.updateMember(memberUuid.toString(), details);

        assertThat(result.getName()).isEqualTo("김철수");
        assertThat(result.getMemberNumber()).isEqualTo("M002");
    }

    @Test
    void updateMemberWithPermission_소유자가_없는_데이터는_STAFF도_수정할_수_있다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        member.setOwnerId(null);

        Member details = new Member();
        details.setName("수정됨");

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid)
                .businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF)
                .status(AccessStatus.APPROVED)
                .build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memberRepository.save(member)).thenReturn(member);

        Member result = memberService.updateMemberWithPermission(
                memberUuid.toString(), details, requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result.getName()).isEqualTo("수정됨");
    }

    @Test
    void updateMemberWithPermission_MANAGER가_OWNER_소유_데이터를_수정하면_AccessDeniedException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        UUID ownerUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        member.setOwnerId(ownerUuid);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER).status(AccessStatus.APPROVED).build();
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                ownerUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(ownerUbp));

        assertThatThrownBy(() -> memberService.updateMemberWithPermission(
                memberUuid.toString(), new Member(), requestUserUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void softDeleteMember_이미_삭제_대기중이면_InvalidInputException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(true);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        assertThatThrownBy(() -> memberService.softDeleteMember(
                memberUuid.toString(), UUID.randomUUID().toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void softDeleteMember_연관된_메모도_함께_삭제_처리한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        Memo memo = new Memo();
        memo.setIsDeleted(false);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));
        when(memberRepository.save(member)).thenReturn(member);
        when(memoRepository.findByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(memberUuid, BUSINESS_PLACE_ID))
                .thenReturn(List.of(memo));

        memberService.softDeleteMember(memberUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(memo.getIsDeleted()).isTrue();
        assertThat(memo.getDeletedBy()).isEqualTo(requestUserUuid);
        verify(memoRepository).saveAll(List.of(memo));
    }

    @Test
    void restoreMember_삭제_대기_상태가_아니면_InvalidInputException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        assertThatThrownBy(() -> memberService.restoreMember(
                memberUuid.toString(), UUID.randomUUID().toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(InvalidInputException.class);
    }

    @Test
    void restoreMember_STAFF면_AccessDeniedException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(true);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.STAFF).status(AccessStatus.APPROVED).build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));

        assertThatThrownBy(() -> memberService.restoreMember(
                memberUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void permanentDeleteMember_MANAGER면_영구_삭제한다() {
        UUID memberUuid = UUID.randomUUID();
        UUID requestUserUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(true);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        UserBusinessPlace requesterUbp = UserBusinessPlace.builder()
                .userId(requestUserUuid).businessPlaceId(BUSINESS_PLACE_ID)
                .role(Role.MANAGER).status(AccessStatus.APPROVED).build();

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.findByUserIdAndBusinessPlaceIdAndStatus(
                requestUserUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(Optional.of(requesterUbp));

        memberService.permanentDeleteMember(memberUuid.toString(), requestUserUuid.toString(), BUSINESS_PLACE_ID);

        verify(memberRepository).deleteById(memberUuid);
    }

    @Test
    void permanentDeleteMember_삭제_대기_상태가_아니면_InvalidInputException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(false);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));

        assertThatThrownBy(() -> memberService.permanentDeleteMember(
                memberUuid.toString(), UUID.randomUUID().toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(InvalidInputException.class);
        verify(memberRepository, never()).deleteById(any(UUID.class));
    }

    @Test
    void getDeletedMembers_userId가_null이면_예외를_던진다() {
        assertThatThrownBy(() -> memberService.getDeletedMembers(null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getDeletedMembers_정상_목록을_반환한다() {
        UUID userUuid = UUID.randomUUID();
        Member member = new Member();
        when(memberRepository.findDeletedMembersByUserId(userUuid)).thenReturn(List.of(member));

        List<Member> result = memberService.getDeletedMembers(userUuid.toString());

        assertThat(result).containsExactly(member);
    }

    @Test
    void getDeletedMemberCount_정상_개수를_반환한다() {
        UUID userUuid = UUID.randomUUID();
        when(memberRepository.countDeletedMembersByUserId(userUuid)).thenReturn(3L);

        long result = memberService.getDeletedMemberCount(userUuid.toString());

        assertThat(result).isEqualTo(3L);
    }

    @Test
    void getDeletedMembersByBusinessPlace_접근권한이_없으면_AccessDeniedException을_던진다() {
        UUID userUuid = UUID.randomUUID();
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);

        assertThatThrownBy(() -> memberService.getDeletedMembersByBusinessPlace(userUuid.toString(), BUSINESS_PLACE_ID))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getDeletedMembersByBusinessPlace_접근권한이_있으면_목록을_반환한다() {
        UUID userUuid = UUID.randomUUID();
        Member member = new Member();
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
        when(memberRepository.findByBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        List<Member> result = memberService.getDeletedMembersByBusinessPlace(userUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(member);
    }

    @Test
    void getDeletedMemberCountByBusinessPlace_접근권한이_있으면_개수를_반환한다() {
        UUID userUuid = UUID.randomUUID();
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
        when(memberRepository.countByBusinessPlaceIdAndIsDeletedTrue(BUSINESS_PLACE_ID)).thenReturn(2L);

        long result = memberService.getDeletedMemberCountByBusinessPlace(userUuid.toString(), BUSINESS_PLACE_ID);

        assertThat(result).isEqualTo(2L);
    }

    @Test
    void deleteMember_리포지토리에_위임한다() {
        UUID memberUuid = UUID.randomUUID();

        memberService.deleteMember(memberUuid.toString());

        verify(memberRepository).deleteById(memberUuid);
    }

    @Test
    void getMemberByIdWithUserCheckIncludeDeleted_접근권한이_없으면_AccessDeniedException을_던진다() {
        UUID memberUuid = UUID.randomUUID();
        UUID userUuid = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberUuid);
        member.setIsDeleted(true);
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);

        when(memberRepository.findById(memberUuid)).thenReturn(Optional.of(member));
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                userUuid, BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);

        assertThatThrownBy(() -> memberService.getMemberByIdWithUserCheckIncludeDeleted(
                memberUuid.toString(), userUuid.toString()))
                .isInstanceOf(AccessDeniedException.class);
    }
}
