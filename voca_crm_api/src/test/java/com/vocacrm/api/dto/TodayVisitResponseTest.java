package com.vocacrm.api.dto;

import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Visit;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class TodayVisitResponseTest {

    @Test
    void from은_회원정보가있으면_MemberSummary를포함한다() {
        UUID memberId = UUID.randomUUID();
        Member member = new Member();
        member.setId(memberId);
        member.setMemberNumber("M0001");
        member.setName("홍길동");
        UUID visitId = UUID.randomUUID();
        LocalDateTime visitedAt = LocalDateTime.now();
        Visit visit = Visit.builder()
                .id(visitId)
                .memberId(memberId)
                .member(member)
                .visitedAt(visitedAt)
                .note("정기 방문")
                .createdAt(visitedAt)
                .updatedAt(visitedAt)
                .build();

        TodayVisitResponse response = TodayVisitResponse.from(visit);

        assertThat(response.getId()).isEqualTo(visitId);
        assertThat(response.getMemberId()).isEqualTo(memberId);
        assertThat(response.getNote()).isEqualTo("정기 방문");
        assertThat(response.getMember()).isNotNull();
        assertThat(response.getMember().getId()).isEqualTo(memberId);
        assertThat(response.getMember().getMemberNumber()).isEqualTo("M0001");
        assertThat(response.getMember().getName()).isEqualTo("홍길동");
    }

    @Test
    void from은_회원정보가없으면_MemberSummary가null이다() {
        Visit visit = Visit.builder()
                .id(UUID.randomUUID())
                .memberId(UUID.randomUUID())
                .visitedAt(LocalDateTime.now())
                .build();

        TodayVisitResponse response = TodayVisitResponse.from(visit);

        assertThat(response.getMember()).isNull();
    }
}
