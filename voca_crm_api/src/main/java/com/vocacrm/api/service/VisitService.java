package com.vocacrm.api.service;

import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Visit;
import com.vocacrm.api.repository.VisitRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class VisitService {

    private final VisitRepository visitRepository;
    private final MemberService memberService;

    @Transactional
    public Visit createVisit(String memberId, String note) {
        Visit visit = Visit.builder()
                .memberId(UUID.fromString(memberId))
                .visitedAt(LocalDateTime.now())
                .note(note)
                .build();
        return visitRepository.save(visit);
    }

    /**
     * 체크인 (회원 사업장 권한 체크 포함)
     */
    @Transactional
    public Visit checkInWithUserCheck(String memberId, String userId, String note) {
        // MemberService의 권한 체크 로직 활용 (회원이 사용자의 사업장에 속하는지 확인)
        memberService.getMemberByIdWithUserCheck(memberId, userId);

        Visit visit = Visit.builder()
                .memberId(UUID.fromString(memberId))
                .visitorId(UUID.fromString(userId))
                .visitedAt(LocalDateTime.now())
                .note(note)
                .build();
        return visitRepository.save(visit);
    }

    /**
     * 회원의 방문 기록 조회 (사업장 필터링 포함)
     * 사업장 권한 검증을 위해 businessPlaceId 필수
     */
    public List<Visit> getVisitsByMemberId(String memberId, String businessPlaceId) {
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new IllegalArgumentException("businessPlaceId는 필수입니다 (보안)");
        }
        return visitRepository.findByMemberIdAndBusinessPlaceIdOrderByVisitedAtDesc(UUID.fromString(memberId), businessPlaceId);
    }

    /**
     * 방문 기록 조회 (회원 사업장 권한 체크 포함)
     */
    public List<Visit> getVisitsByMemberWithUserCheck(String memberId, String userId) {
        // 회원이 사용자의 사업장에 속하는지 확인
        Member member = memberService.getMemberByIdWithUserCheck(memberId, userId);

        return visitRepository.findByMemberIdAndBusinessPlaceIdOrderByVisitedAtDesc(
                UUID.fromString(memberId), member.getBusinessPlaceId());
    }

    /**
     * 오늘 방문 기록 조회 (사업장별)
     */
    public List<Visit> getTodayVisits(String businessPlaceId) {
        return visitRepository.findTodayVisitsByBusinessPlaceId(businessPlaceId);
    }

    /**
     * 체크인 취소 (삭제)
     */
    @Transactional
    public void cancelCheckIn(String visitId, String businessPlaceId) {
        Visit visit = visitRepository.findByIdAndBusinessPlaceId(
                UUID.fromString(visitId), businessPlaceId)
                .orElseThrow(() -> new RuntimeException("방문 기록을 찾을 수 없습니다."));

        visitRepository.delete(visit);
    }
}
