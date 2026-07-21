package com.vocacrm.api.dto;

import com.vocacrm.api.model.Visit;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 오늘 방문 기록 응답 DTO
 *
 * Visit.member는 순환참조/과다직렬화 방지를 위해 @JsonIgnore 처리되어 있어,
 * 오늘 방문 조회 화면에서 필요한 회원 식별 정보만 별도로 포함한다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TodayVisitResponse {

    private UUID id;
    private UUID memberId;
    private MemberSummary member;
    private UUID visitorId;
    private LocalDateTime visitedAt;
    private String note;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    /**
     * Entity에서 Response DTO 생성
     */
    public static TodayVisitResponse from(Visit visit) {
        return TodayVisitResponse.builder()
                .id(visit.getId())
                .memberId(visit.getMemberId())
                .member(MemberSummary.from(visit))
                .visitorId(visit.getVisitorId())
                .visitedAt(visit.getVisitedAt())
                .note(visit.getNote())
                .createdAt(visit.getCreatedAt())
                .updatedAt(visit.getUpdatedAt())
                .build();
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MemberSummary {
        private UUID id;
        private String memberNumber;
        private String name;

        public static MemberSummary from(Visit visit) {
            if (visit.getMember() == null) {
                return null;
            }
            return MemberSummary.builder()
                    .id(visit.getMember().getId())
                    .memberNumber(visit.getMember().getMemberNumber())
                    .name(visit.getMember().getName())
                    .build();
        }
    }
}
