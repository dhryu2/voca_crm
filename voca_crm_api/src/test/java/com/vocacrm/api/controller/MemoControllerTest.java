package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.MemoCreateRequest;
import com.vocacrm.api.dto.request.MemoUpdateRequest;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.service.AccessControlService;
import com.vocacrm.api.service.MemberService;
import com.vocacrm.api.service.MemoService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MemoControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String MEMO_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private MemoService memoService;
    @Mock
    private MemberService memberService;
    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;
    @Mock
    private AccessControlService accessControlService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private MemoController memoController;

    @BeforeEach
    void setUp() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
    }

    @Test
    void softDeleteMemo_JWT_userId를_서비스에_전달한다() {
        Memo deleted = new Memo();
        when(memoService.softDeleteMemo(MEMO_ID, USER_ID, BUSINESS_PLACE_ID)).thenReturn(deleted);

        ResponseEntity<Memo> response = memoController.softDeleteMemo(MEMO_ID, BUSINESS_PLACE_ID, servletRequest);

        verify(memoService).softDeleteMemo(MEMO_ID, USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getBody()).isSameAs(deleted);
    }

    @Test
    void softDeleteMemo_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        when(memoService.softDeleteMemo(MEMO_ID, USER_ID, BUSINESS_PLACE_ID))
                .thenThrow(new AccessDeniedException("삭제 권한이 없습니다."));

        assertThatThrownBy(() -> memoController.softDeleteMemo(MEMO_ID, BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void restoreMemo_JWT_userId를_서비스에_전달한다() {
        Memo restored = new Memo();
        when(memoService.restoreMemo(MEMO_ID, USER_ID, BUSINESS_PLACE_ID)).thenReturn(restored);

        ResponseEntity<Memo> response = memoController.restoreMemo(MEMO_ID, BUSINESS_PLACE_ID, servletRequest);

        verify(memoService).restoreMemo(MEMO_ID, USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getBody()).isSameAs(restored);
    }

    @Test
    void restoreMemo_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        when(memoService.restoreMemo(MEMO_ID, USER_ID, BUSINESS_PLACE_ID))
                .thenThrow(new AccessDeniedException("복원 권한이 없습니다."));

        assertThatThrownBy(() -> memoController.restoreMemo(MEMO_ID, BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void permanentDeleteMemo_JWT_userId를_서비스에_전달한다() {
        ResponseEntity<Void> response = memoController.permanentDeleteMemo(MEMO_ID, BUSINESS_PLACE_ID, servletRequest);

        verify(memoService).permanentDeleteMemo(MEMO_ID, USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void permanentDeleteMemo_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        doThrow(new AccessDeniedException("영구 삭제 권한이 없습니다."))
                .when(memoService).permanentDeleteMemo(MEMO_ID, USER_ID, BUSINESS_PLACE_ID);

        assertThatThrownBy(() -> memoController.permanentDeleteMemo(MEMO_ID, BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMemoById_정상적으로_메모를_반환한다() {
        Memo memo = new Memo();
        when(memoService.getMemoByIdForUser(MEMO_ID, USER_ID)).thenReturn(memo);

        ResponseEntity<Memo> response = memoController.getMemoById(MEMO_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(memo);
    }

    @Test
    void getMemoById_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        when(memoService.getMemoByIdForUser(MEMO_ID, USER_ID))
                .thenThrow(new AccessDeniedException("접근 권한이 없습니다."));

        assertThatThrownBy(() -> memoController.getMemoById(MEMO_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMemosByBusinessPlace_권한이_있으면_메모_목록을_반환한다() {
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
        List<Memo> memos = List.of(new Memo());
        when(memoService.getMemosByBusinessPlace(BUSINESS_PLACE_ID)).thenReturn(memos);

        ResponseEntity<List<Memo>> response = memoController.getMemosByBusinessPlace(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(memos);
    }

    @Test
    void getMemosByBusinessPlace_권한이_없으면_AccessDeniedException() {
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);

        assertThatThrownBy(() -> memoController.getMemosByBusinessPlace(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMemosByMemberId_권한이_있으면_메모_목록을_data로_감싸_반환한다() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        Member member = new Member();
        member.setId(UUID.fromString(memberId));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(memberService.getMemberById(memberId)).thenReturn(member);
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
        List<Memo> memos = List.of(new Memo());
        when(memoService.getMemosByMemberId(memberId, BUSINESS_PLACE_ID)).thenReturn(memos);

        ResponseEntity<Map<String, Object>> response = memoController.getMemosByMemberId(memberId, servletRequest);

        assertThat(response.getBody()).containsEntry("data", memos);
    }

    @Test
    void getMemosByMemberId_권한이_없으면_AccessDeniedException() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        Member member = new Member();
        member.setId(UUID.fromString(memberId));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(memberService.getMemberById(memberId)).thenReturn(member);
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);

        assertThatThrownBy(() -> memoController.getMemosByMemberId(memberId, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getLatestMemo_메모가_있으면_반환한다() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        Member member = new Member();
        member.setId(UUID.fromString(memberId));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(memberService.getMemberById(memberId)).thenReturn(member);
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
        Memo memo = new Memo();
        when(memoService.getLatestMemoByMemberId(memberId, BUSINESS_PLACE_ID)).thenReturn(memo);

        ResponseEntity<Memo> response = memoController.getLatestMemo(memberId, servletRequest);

        assertThat(response.getBody()).isSameAs(memo);
    }

    @Test
    void getLatestMemo_메모가_없으면_404를_반환한다() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        Member member = new Member();
        member.setId(UUID.fromString(memberId));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(memberService.getMemberById(memberId)).thenReturn(member);
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
        when(memoService.getLatestMemoByMemberId(memberId, BUSINESS_PLACE_ID)).thenReturn(null);

        ResponseEntity<Memo> response = memoController.getLatestMemo(memberId, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(404);
    }

    @Test
    void getLatestMemo_권한이_없으면_AccessDeniedException() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        Member member = new Member();
        member.setId(UUID.fromString(memberId));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(memberService.getMemberById(memberId)).thenReturn(member);
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);

        assertThatThrownBy(() -> memoController.getLatestMemo(memberId, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void createMemo_memberId가_있으면_멤버십_검증_후_생성된다() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        MemoCreateRequest request = MemoCreateRequest.builder()
                .memberId(memberId)
                .content("새 메모")
                .isImportant(true)
                .build();
        when(accessControlService.businessPlaceOfMember(memberId)).thenReturn(BUSINESS_PLACE_ID);
        Memo created = new Memo();
        when(memoService.createMemo(org.mockito.ArgumentMatchers.any(Memo.class))).thenReturn(created);

        ResponseEntity<Memo> response = memoController.createMemo(request, servletRequest);

        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getBody()).isSameAs(created);
    }

    @Test
    void createMemo_멤버십_검증_실패시_AccessDeniedException_전파() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        MemoCreateRequest request = MemoCreateRequest.builder()
                .memberId(memberId)
                .content("새 메모")
                .build();
        when(accessControlService.businessPlaceOfMember(memberId)).thenReturn(BUSINESS_PLACE_ID);
        doThrow(new AccessDeniedException("접근 권한이 없습니다."))
                .when(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);

        assertThatThrownBy(() -> memoController.createMemo(request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void createMemoWithDeletion_memberId가_있으면_가장_오래된_메모를_삭제하고_생성한다() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        MemoCreateRequest request = MemoCreateRequest.builder()
                .memberId(memberId)
                .content("새 메모")
                .build();
        when(accessControlService.businessPlaceOfMember(memberId)).thenReturn(BUSINESS_PLACE_ID);
        Memo created = new Memo();
        when(memoService.createMemoWithOldestDeletion(org.mockito.ArgumentMatchers.any(Memo.class), org.mockito.ArgumentMatchers.eq(USER_ID)))
                .thenReturn(created);

        ResponseEntity<Memo> response = memoController.createMemoWithDeletion(request, servletRequest);

        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getBody()).isSameAs(created);
    }

    @Test
    void updateMemo_정상적으로_수정된다() {
        MemoUpdateRequest request = MemoUpdateRequest.builder().content("수정된 내용").build();
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(BUSINESS_PLACE_ID);
        Memo updated = new Memo();
        when(memoService.updateMemoWithPermission(
                org.mockito.ArgumentMatchers.eq(MEMO_ID),
                org.mockito.ArgumentMatchers.any(Memo.class),
                org.mockito.ArgumentMatchers.eq(USER_ID),
                org.mockito.ArgumentMatchers.eq(BUSINESS_PLACE_ID)))
                .thenReturn(updated);

        ResponseEntity<Memo> response = memoController.updateMemo(MEMO_ID, request, servletRequest);

        assertThat(response.getBody()).isSameAs(updated);
    }

    @Test
    void updateMemo_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        MemoUpdateRequest request = MemoUpdateRequest.builder().content("수정된 내용").build();
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(BUSINESS_PLACE_ID);
        when(memoService.updateMemoWithPermission(
                org.mockito.ArgumentMatchers.eq(MEMO_ID),
                org.mockito.ArgumentMatchers.any(Memo.class),
                org.mockito.ArgumentMatchers.eq(USER_ID),
                org.mockito.ArgumentMatchers.eq(BUSINESS_PLACE_ID)))
                .thenThrow(new AccessDeniedException("수정 권한이 없습니다."));

        assertThatThrownBy(() -> memoController.updateMemo(MEMO_ID, request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void deleteMemo_정상적으로_삭제된다() {
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(BUSINESS_PLACE_ID);

        ResponseEntity<Void> response = memoController.deleteMemo(MEMO_ID, servletRequest);

        verify(memoService).deleteMemoWithPermission(MEMO_ID, USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void deleteMemo_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(BUSINESS_PLACE_ID);
        doThrow(new AccessDeniedException("삭제 권한이 없습니다."))
                .when(memoService).deleteMemoWithPermission(MEMO_ID, USER_ID, BUSINESS_PLACE_ID);

        assertThatThrownBy(() -> memoController.deleteMemo(MEMO_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getDeletedMemos_삭제_대기_메모_목록을_data로_감싸_반환한다() {
        List<Memo> deleted = List.of(new Memo());
        when(memoService.getDeletedMemosByBusinessPlace(USER_ID, BUSINESS_PLACE_ID)).thenReturn(deleted);

        ResponseEntity<Map<String, Object>> response = memoController.getDeletedMemos(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getBody()).containsEntry("data", deleted);
    }

    @Test
    void getDeletedMemos_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        when(memoService.getDeletedMemosByBusinessPlace(USER_ID, BUSINESS_PLACE_ID))
                .thenThrow(new AccessDeniedException("접근 권한이 없습니다."));

        assertThatThrownBy(() -> memoController.getDeletedMemos(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getDeletedMemosByMember_권한이_있으면_data로_감싸_반환한다() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        Member member = new Member();
        member.setId(UUID.fromString(memberId));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(memberService.getMemberById(memberId)).thenReturn(member);
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(true);
        List<Memo> deleted = List.of(new Memo());
        when(memoService.getDeletedMemosByMemberId(memberId, BUSINESS_PLACE_ID)).thenReturn(deleted);

        ResponseEntity<Map<String, Object>> response = memoController.getDeletedMemosByMember(memberId, servletRequest);

        assertThat(response.getBody()).containsEntry("data", deleted);
    }

    @Test
    void getDeletedMemosByMember_권한이_없으면_AccessDeniedException() {
        String memberId = "cccccccc-dddd-eeee-ffff-000000000000";
        Member member = new Member();
        member.setId(UUID.fromString(memberId));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        when(memberService.getMemberById(memberId)).thenReturn(member);
        when(userBusinessPlaceRepository.existsByUserIdAndBusinessPlaceIdAndStatus(
                UUID.fromString(USER_ID), BUSINESS_PLACE_ID, AccessStatus.APPROVED))
                .thenReturn(false);

        assertThatThrownBy(() -> memoController.getDeletedMemosByMember(memberId, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void toggleImportant_정상적으로_토글된다() {
        Memo updated = new Memo();
        when(memoService.toggleImportant(MEMO_ID, USER_ID)).thenReturn(updated);

        ResponseEntity<Memo> response = memoController.toggleImportant(MEMO_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(updated);
    }

    @Test
    void toggleImportant_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        when(memoService.toggleImportant(MEMO_ID, USER_ID))
                .thenThrow(new AccessDeniedException("수정 권한이 없습니다."));

        assertThatThrownBy(() -> memoController.toggleImportant(MEMO_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }
}
