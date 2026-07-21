package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.MemberCreateRequest;
import com.vocacrm.api.dto.request.MemberUpdateRequest;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.service.AccessControlService;
import com.vocacrm.api.service.MemberService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MemberControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String MEMBER_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private MemberService memberService;
    @Mock
    private AccessControlService accessControlService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private MemberController memberController;

    @BeforeEach
    void setUp() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
    }

    private MemberCreateRequest createRequest() {
        return MemberCreateRequest.builder()
                .memberNumber("789012")
                .name("홍길동")
                .phone("010-1234-5678")
                .email("hong@example.com")
                .businessPlaceId(BUSINESS_PLACE_ID)
                .grade("VIP")
                .remark("비고")
                .build();
    }

    private MemberUpdateRequest updateRequest() {
        return MemberUpdateRequest.builder()
                .memberNumber("789012")
                .name("홍길동")
                .phone("010-9999-8888")
                .email("new@example.com")
                .grade("VIP")
                .remark("비고")
                .build();
    }

    // ===== getAllMembers =====

    @Test
    void getAllMembers_페이지를_반환한다() {
        Page<Member> page = new PageImpl<>(List.of(new Member()));
        when(memberService.getMembersByUserId(eq(USER_ID), any(Pageable.class))).thenReturn(page);

        Page<Member> result = memberController.getAllMembers(0, 100, servletRequest);

        assertThat(result).isSameAs(page);
    }

    @Test
    void getAllMembers_서비스가_예외를_던지면_전파한다() {
        when(memberService.getMembersByUserId(eq(USER_ID), any(Pageable.class)))
                .thenThrow(new AccessDeniedException("권한 없음"));

        assertThatThrownBy(() -> memberController.getAllMembers(0, 100, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getMemberById =====

    @Test
    void getMemberById_회원을_반환한다() {
        Member member = new Member();
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID)).thenReturn(member);

        ResponseEntity<Member> response = memberController.getMemberById(MEMBER_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(member);
    }

    @Test
    void getMemberById_서비스가_예외를_던지면_전파한다() {
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID))
                .thenThrow(new AccessDeniedException("권한 없음"));

        assertThatThrownBy(() -> memberController.getMemberById(MEMBER_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getMembersByNumber =====

    @Test
    void getMembersByNumber_회원목록을_data로_감싸_반환한다() {
        List<Member> members = List.of(new Member());
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        when(memberService.getMembersByNumber("789012", BUSINESS_PLACE_ID)).thenReturn(members);

        ResponseEntity<Map<String, Object>> response = memberController.getMembersByNumber("789012", servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).containsEntry("data", members);
    }

    @Test
    void getMembersByNumber_승인멤버십이_없으면_예외를_전파한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        doThrow(new AccessDeniedException("권한 없음"))
                .when(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);

        assertThatThrownBy(() -> memberController.getMembersByNumber("789012", servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getMembersByBusinessPlace =====

    @Test
    void getMembersByBusinessPlace_회원목록을_반환한다() {
        List<Member> members = List.of(new Member());
        when(memberService.getMembersByBusinessPlaceWithUserCheck(BUSINESS_PLACE_ID, USER_ID)).thenReturn(members);

        ResponseEntity<Map<String, Object>> response =
                memberController.getMembersByBusinessPlace(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).containsEntry("data", members);
    }

    @Test
    void getMembersByBusinessPlace_서비스가_예외를_던지면_전파한다() {
        when(memberService.getMembersByBusinessPlaceWithUserCheck(BUSINESS_PLACE_ID, USER_ID))
                .thenThrow(new AccessDeniedException("권한 없음"));

        assertThatThrownBy(() -> memberController.getMembersByBusinessPlace(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== searchMembers =====

    @Test
    void searchMembers_검색결과를_data로_감싸_반환한다() {
        List<Member> members = List.of(new Member());
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        when(memberService.searchMembers("789012", "홍길동", "010", "hong", BUSINESS_PLACE_ID)).thenReturn(members);

        ResponseEntity<Map<String, Object>> response =
                memberController.searchMembers("789012", "홍길동", "010", "hong", servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).containsEntry("data", members);
    }

    @Test
    void searchMembers_승인멤버십이_없으면_예외를_전파한다() {
        when(accessControlService.currentDefaultBusinessPlace(USER_ID)).thenReturn(BUSINESS_PLACE_ID);
        doThrow(new AccessDeniedException("권한 없음"))
                .when(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);

        assertThatThrownBy(() -> memberController.searchMembers(null, null, null, null, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== createMember =====

    @Test
    void createMember_생성된_회원을_반환한다() {
        Member created = new Member();
        when(memberService.createMember(any(Member.class))).thenReturn(created);

        ResponseEntity<Member> response = memberController.createMember(createRequest(), servletRequest);

        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(created);
    }

    @Test
    void createMember_승인멤버십이_없으면_예외를_전파한다() {
        doThrow(new AccessDeniedException("권한 없음"))
                .when(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);

        assertThatThrownBy(() -> memberController.createMember(createRequest(), servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== updateMember =====

    @Test
    void updateMember_수정된_회원을_반환한다() {
        Member updated = new Member();
        when(memberService.updateMemberWithPermission(eq(MEMBER_ID), any(Member.class), eq(USER_ID), any()))
                .thenReturn(updated);

        ResponseEntity<Member> response = memberController.updateMember(MEMBER_ID, updateRequest(), servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(updated);
    }

    @Test
    void updateMember_서비스가_예외를_던지면_전파한다() {
        when(memberService.updateMemberWithPermission(eq(MEMBER_ID), any(Member.class), eq(USER_ID), any()))
                .thenThrow(new AccessDeniedException("권한 없음"));

        assertThatThrownBy(() -> memberController.updateMember(MEMBER_ID, updateRequest(), servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== softDeleteMember =====

    @Test
    void softDeleteMember_삭제된_회원을_반환한다() {
        Member deleted = new Member();
        when(memberService.softDeleteMember(MEMBER_ID, USER_ID, "")).thenReturn(deleted);

        ResponseEntity<Member> response = memberController.softDeleteMember(MEMBER_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(deleted);
    }

    @Test
    void softDeleteMember_서비스가_예외를_던지면_전파한다() {
        when(memberService.softDeleteMember(MEMBER_ID, USER_ID, ""))
                .thenThrow(new AccessDeniedException("권한 없음"));

        assertThatThrownBy(() -> memberController.softDeleteMember(MEMBER_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    // ===== getDeletedMembers =====

    @Test
    void getDeletedMembers_목록과_개수를_반환한다() {
        List<Member> members = List.of(new Member());
        when(memberService.getDeletedMembersByBusinessPlace(USER_ID, BUSINESS_PLACE_ID)).thenReturn(members);
        when(memberService.getDeletedMemberCountByBusinessPlace(USER_ID, BUSINESS_PLACE_ID)).thenReturn(1L);

        ResponseEntity<Map<String, Object>> response =
                memberController.getDeletedMembers(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).containsEntry("data", members);
        assertThat(response.getBody()).containsEntry("count", 1L);
    }

    // ===== restoreMember =====

    @Test
    void restoreMember_복원된_회원을_반환한다() {
        Member restored = new Member();
        when(memberService.restoreMember(MEMBER_ID, USER_ID, "")).thenReturn(restored);

        ResponseEntity<Member> response = memberController.restoreMember(MEMBER_ID, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(restored);
    }

    // ===== permanentDeleteMember =====

    @Test
    void permanentDeleteMember_204를_반환한다() {
        ResponseEntity<Void> response = memberController.permanentDeleteMember(MEMBER_ID, servletRequest);

        verify(memberService).permanentDeleteMember(MEMBER_ID, USER_ID, "");
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void permanentDeleteMember_서비스가_예외를_던지면_전파한다() {
        doThrow(new AccessDeniedException("권한 없음"))
                .when(memberService).permanentDeleteMember(MEMBER_ID, USER_ID, "");

        assertThatThrownBy(() -> memberController.permanentDeleteMember(MEMBER_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }
}
