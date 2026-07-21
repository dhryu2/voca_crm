package com.vocacrm.api.service;

import com.vocacrm.api.exception.InvalidInputException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Visit;
import com.vocacrm.api.repository.VisitRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
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
class VisitServiceTest {

    @Mock
    private VisitRepository visitRepository;

    @Mock
    private MemberService memberService;

    @InjectMocks
    private VisitService visitService;

    private static final String MEMBER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String USER_ID = "660e8400-e29b-41d4-a716-446655440000";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Test
    void checkInWithUserCheck_정상_케이스면_방문_기록을_저장한다() {
        Member member = new Member();
        member.setId(UUID.fromString(MEMBER_ID));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        member.setIsDeleted(false);
        when(memberService.getMemberByIdWithUserCheckIncludeDeleted(MEMBER_ID, USER_ID)).thenReturn(member);
        when(visitRepository.save(any(Visit.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Visit result = visitService.checkInWithUserCheck(MEMBER_ID, USER_ID, "메모");

        ArgumentCaptor<Visit> captor = ArgumentCaptor.forClass(Visit.class);
        verify(visitRepository).save(captor.capture());
        Visit saved = captor.getValue();
        assertThat(saved.getMemberId()).isEqualTo(UUID.fromString(MEMBER_ID));
        assertThat(saved.getVisitorId()).isEqualTo(UUID.fromString(USER_ID));
        assertThat(saved.getNote()).isEqualTo("메모");
        assertThat(result).isEqualTo(saved);
    }

    @Test
    void checkInWithUserCheck_삭제된_회원이면_InvalidInputException을_던진다() {
        Member member = new Member();
        member.setId(UUID.fromString(MEMBER_ID));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        member.setIsDeleted(true);
        when(memberService.getMemberByIdWithUserCheckIncludeDeleted(MEMBER_ID, USER_ID)).thenReturn(member);

        assertThatThrownBy(() -> visitService.checkInWithUserCheck(MEMBER_ID, USER_ID, "메모"))
                .isInstanceOf(InvalidInputException.class);

        verify(visitRepository, never()).save(any(Visit.class));
    }

    @Test
    void getVisitsByMemberId_정상_목록을_반환한다() {
        Visit visit = Visit.builder().id(UUID.randomUUID()).memberId(UUID.fromString(MEMBER_ID)).build();
        when(visitRepository.findByMemberIdAndBusinessPlaceIdOrderByVisitedAtDesc(
                UUID.fromString(MEMBER_ID), BUSINESS_PLACE_ID))
                .thenReturn(List.of(visit));

        List<Visit> result = visitService.getVisitsByMemberId(MEMBER_ID, BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(visit);
    }

    @Test
    void getVisitsByMemberId_businessPlaceId가_없으면_IllegalArgumentException을_던진다() {
        assertThatThrownBy(() -> visitService.getVisitsByMemberId(MEMBER_ID, ""))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void getTodayVisits_정상_케이스면_오늘_방문_목록을_반환한다() {
        Visit visit = Visit.builder().id(UUID.randomUUID()).memberId(UUID.fromString(MEMBER_ID)).build();
        when(visitRepository.findTodayVisitsByBusinessPlaceId(BUSINESS_PLACE_ID)).thenReturn(List.of(visit));

        List<Visit> result = visitService.getTodayVisits(BUSINESS_PLACE_ID);

        assertThat(result).containsExactly(visit);
    }

    @Test
    void cancelCheckIn_정상_케이스면_방문_기록을_삭제한다() {
        String visitId = UUID.randomUUID().toString();
        Visit visit = Visit.builder().id(UUID.fromString(visitId)).memberId(UUID.fromString(MEMBER_ID)).build();
        when(visitRepository.findByIdAndBusinessPlaceId(UUID.fromString(visitId), BUSINESS_PLACE_ID))
                .thenReturn(Optional.of(visit));

        visitService.cancelCheckIn(visitId, BUSINESS_PLACE_ID);

        verify(visitRepository).delete(visit);
    }

    @Test
    void cancelCheckIn_존재하지_않는_방문_기록이면_ResourceNotFoundException을_던진다() {
        String visitId = UUID.randomUUID().toString();
        when(visitRepository.findByIdAndBusinessPlaceId(UUID.fromString(visitId), BUSINESS_PLACE_ID))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> visitService.cancelCheckIn(visitId, BUSINESS_PLACE_ID))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void createVisit_정상_케이스면_방문_기록을_저장한다() {
        when(visitRepository.save(any(Visit.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Visit result = visitService.createVisit(MEMBER_ID, "메모");

        ArgumentCaptor<Visit> captor = ArgumentCaptor.forClass(Visit.class);
        verify(visitRepository).save(captor.capture());
        assertThat(captor.getValue().getMemberId()).isEqualTo(UUID.fromString(MEMBER_ID));
        assertThat(captor.getValue().getNote()).isEqualTo("메모");
        assertThat(result).isEqualTo(captor.getValue());
    }

    @Test
    void createVisit_note가_없어도_저장된다() {
        when(visitRepository.save(any(Visit.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Visit result = visitService.createVisit(MEMBER_ID, null);

        assertThat(result.getNote()).isNull();
        assertThat(result.getMemberId()).isEqualTo(UUID.fromString(MEMBER_ID));
    }

    @Test
    void checkInWithUserCheck_isDeleted가_null이어도_정상_체크인된다() {
        Member member = new Member();
        member.setId(UUID.fromString(MEMBER_ID));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        member.setIsDeleted(null);
        when(memberService.getMemberByIdWithUserCheckIncludeDeleted(MEMBER_ID, USER_ID)).thenReturn(member);
        when(visitRepository.save(any(Visit.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Visit result = visitService.checkInWithUserCheck(MEMBER_ID, USER_ID, "메모");

        assertThat(result.getMemberId()).isEqualTo(UUID.fromString(MEMBER_ID));
        verify(visitRepository).save(any(Visit.class));
    }

    @Test
    void getVisitsByMemberWithUserCheck_정상_케이스면_회원의_사업장_기준으로_조회한다() {
        Member member = new Member();
        member.setId(UUID.fromString(MEMBER_ID));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        Visit visit = Visit.builder().id(UUID.randomUUID()).memberId(UUID.fromString(MEMBER_ID)).build();

        when(memberService.getMemberByIdWithUserCheckIncludeDeleted(MEMBER_ID, USER_ID)).thenReturn(member);
        when(visitRepository.findByMemberIdAndBusinessPlaceIdOrderByVisitedAtDesc(
                UUID.fromString(MEMBER_ID), BUSINESS_PLACE_ID))
                .thenReturn(List.of(visit));

        List<Visit> result = visitService.getVisitsByMemberWithUserCheck(MEMBER_ID, USER_ID);

        assertThat(result).containsExactly(visit);
    }

    @Test
    void getVisitsByMemberWithUserCheck_삭제_대기_회원도_방문기록을_조회할_수_있다() {
        Member member = new Member();
        member.setId(UUID.fromString(MEMBER_ID));
        member.setBusinessPlaceId(BUSINESS_PLACE_ID);
        member.setIsDeleted(true);

        when(memberService.getMemberByIdWithUserCheckIncludeDeleted(MEMBER_ID, USER_ID)).thenReturn(member);
        when(visitRepository.findByMemberIdAndBusinessPlaceIdOrderByVisitedAtDesc(
                UUID.fromString(MEMBER_ID), BUSINESS_PLACE_ID))
                .thenReturn(List.of());

        List<Visit> result = visitService.getVisitsByMemberWithUserCheck(MEMBER_ID, USER_ID);

        assertThat(result).isEmpty();
    }

    @Test
    void getVisitsByMemberId_businessPlaceId가_null이면_IllegalArgumentException을_던진다() {
        assertThatThrownBy(() -> visitService.getVisitsByMemberId(MEMBER_ID, null))
                .isInstanceOf(IllegalArgumentException.class);

        verify(visitRepository, never()).findByMemberIdAndBusinessPlaceIdOrderByVisitedAtDesc(any(UUID.class), any());
    }

    @Test
    void getTodayVisits_결과가_없으면_빈_목록을_반환한다() {
        when(visitRepository.findTodayVisitsByBusinessPlaceId(BUSINESS_PLACE_ID)).thenReturn(List.of());

        List<Visit> result = visitService.getTodayVisits(BUSINESS_PLACE_ID);

        assertThat(result).isEmpty();
    }
}
