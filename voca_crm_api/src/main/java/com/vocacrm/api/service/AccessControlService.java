package com.vocacrm.api.service;

import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.model.Reservation;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.model.Visit;
import com.vocacrm.api.model.User;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.MemoRepository;
import com.vocacrm.api.repository.ReservationRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import com.vocacrm.api.repository.VisitRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * 중앙 인가(Authorization) 컴포넌트.
 *
 * 원칙: 신뢰 가능한 유일 입력은 필터가 검증한 JWT의 userId뿐이다.
 * 대상 사업장은 리소스로부터 서버가 도출하고, userId의 APPROVED 멤버십으로 검증한다.
 * stale JWT defaultBusinessPlaceId나 클라이언트 X-Business-Place-Id 헤더는 인가에 쓰지 않는다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AccessControlService {

    private final UserBusinessPlaceRepository userBusinessPlaceRepository;
    private final MemberRepository memberRepository;
    private final MemoRepository memoRepository;
    private final ReservationRepository reservationRepository;
    private final VisitRepository visitRepository;
    private final UserRepository userRepository;

    /**
     * 요청자의 현재 기본 사업장을 DB에서 조회한다.
     * JWT의 defaultBusinessPlaceId(로그인 시점 박제, 최대 1시간 stale)를 쓰지 않고
     * 항상 최신 값을 반환해 사업장 전환 지연 문제를 없앤다.
     */
    public String currentDefaultBusinessPlace(String userId) {
        if (userId == null || userId.isEmpty()) {
            return null;
        }
        return userRepository.findById(UUID.fromString(userId))
                .map(User::getDefaultBusinessPlaceId)
                .orElse(null);
    }

    // ===== 리소스 → 실제 사업장 도출 (삭제 여부 무관) =====

    public String businessPlaceOfMember(String memberId) {
        Member m = memberRepository.findById(UUID.fromString(memberId))
                .orElseThrow(() -> new ResourceNotFoundException("회원을 찾을 수 없습니다: " + memberId));
        return m.getBusinessPlaceId();
    }

    public String businessPlaceOfMemo(String memoId) {
        Memo memo = memoRepository.findById(UUID.fromString(memoId))
                .orElseThrow(() -> new ResourceNotFoundException("메모를 찾을 수 없습니다: " + memoId));
        Member m = memberRepository.findById(memo.getMemberId())
                .orElseThrow(() -> new ResourceNotFoundException("회원을 찾을 수 없습니다"));
        return m.getBusinessPlaceId();
    }

    public String businessPlaceOfReservation(String reservationId) {
        Reservation r = reservationRepository.findById(UUID.fromString(reservationId))
                .orElseThrow(() -> new ResourceNotFoundException("예약을 찾을 수 없습니다: " + reservationId));
        return r.getBusinessPlaceId();
    }

    public String businessPlaceOfVisit(String visitId) {
        Visit v = visitRepository.findById(UUID.fromString(visitId))
                .orElseThrow(() -> new ResourceNotFoundException("방문 기록을 찾을 수 없습니다: " + visitId));
        Member m = memberRepository.findById(v.getMemberId())
                .orElseThrow(() -> new ResourceNotFoundException("회원을 찾을 수 없습니다"));
        return m.getBusinessPlaceId();
    }

    // ===== 멤버십 / 역할 검증 =====

    /**
     * 요청자가 해당 사업장에 APPROVED 멤버십을 가지는지 검증. 없으면 403.
     */
    public UserBusinessPlace requireApprovedMembership(String userId, String businessPlaceId) {
        if (userId == null || userId.isEmpty()) {
            throw new AccessDeniedException("인증 정보가 없습니다.");
        }
        if (businessPlaceId == null || businessPlaceId.isEmpty()) {
            throw new AccessDeniedException("사업장 정보가 없습니다.");
        }
        return userBusinessPlaceRepository
                .findByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED)
                .orElseThrow(() -> new AccessDeniedException("해당 사업장에 대한 접근 권한이 없습니다."));
    }

    /**
     * 요청자가 해당 사업장에서 허용된 역할 중 하나를 APPROVED로 가지는지 검증. 없으면 403.
     */
    public UserBusinessPlace requireRole(String userId, String businessPlaceId, Role... allowed) {
        UserBusinessPlace ubp = requireApprovedMembership(userId, businessPlaceId);
        for (Role r : allowed) {
            if (ubp.getRole() == r) {
                return ubp;
            }
        }
        throw new AccessDeniedException("이 작업을 수행할 권한이 없습니다.");
    }

    public boolean hasApprovedMembership(String userId, String businessPlaceId) {
        if (userId == null || businessPlaceId == null) return false;
        return userBusinessPlaceRepository
                .existsByUserIdAndBusinessPlaceIdAndStatus(UUID.fromString(userId), businessPlaceId, AccessStatus.APPROVED);
    }
}
