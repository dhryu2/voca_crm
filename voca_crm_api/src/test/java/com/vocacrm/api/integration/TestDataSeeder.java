package com.vocacrm.api.integration;

import org.springframework.jdbc.core.JdbcTemplate;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.UUID;

/**
 * 통합테스트용 시드 헬퍼.
 *
 * <p>실제 스키마(V1~V6)에 맞춰 JdbcTemplate 으로 직접 INSERT 한다. 서비스 계층의 권한/검증을 우회해
 * 정확한 초기 상태를 구성하기 위함이다(예: soft-delete 된 회원의 예약처럼 정상 API 로는 만들기 번거로운 상태).
 *
 * <p>테스트 간 격리는 트랜잭션 롤백이 아니라 <b>사업장 ID 스코프</b>로 한다(각 테스트가 고유 business_place_id 사용).
 * 이렇게 하면 실제 commit/flush 동작(F6 동시성 제약 등)을 그대로 관찰할 수 있다.
 */
final class TestDataSeeder {

    private final JdbcTemplate jdbc;

    TestDataSeeder(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** business_places (id 는 VARCHAR(7)) */
    void businessPlace(String id, String name) {
        jdbc.update("INSERT INTO business_places (id, name) VALUES (?, ?)", id, name);
    }

    /**
     * users — id 반환.
     * default_business_place_id 는 설정하지 않는다(null). 인가 경로는 user_business_places(멤버십)만 참조하므로
     * 불필요하며, 설정하면 business_places 를 먼저 만들어야 하는 FK 순서 제약이 생긴다.
     */
    UUID user(String username) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO users (id, username) VALUES (?, ?)", id, username);
        return id;
    }

    /**
     * 한 사업장 + APPROVED 멤버십 + 회원 1명 + 중요 메모 1개를 한 번에 시드 (테넌트 격리 테스트용).
     * owner 사용자는 이미 생성되어 있어야 한다.
     */
    void businessPlaceMemberWithImportantMemo(String businessPlaceId, UUID owner, String memberName) {
        businessPlace(businessPlaceId, memberName + "-사업장");
        approvedMembership(owner, businessPlaceId, "OWNER");
        UUID m = member(businessPlaceId, owner, "MN-" + businessPlaceId, memberName);
        memo(m, owner, memberName + "의 중요메모", true);
    }

    /** user_business_places — APPROVED 멤버십 (StatisticsController.validateUserAccessToBusinessPlace 통과용) */
    void approvedMembership(UUID userId, String businessPlaceId, String role) {
        jdbc.update("INSERT INTO user_business_places (id, user_id, business_place_id, role, status) " +
                        "VALUES (?, ?, ?, ?, 'APPROVED')",
                UUID.randomUUID(), userId, businessPlaceId, role);
    }

    /** members — id 반환 (is_deleted=false 로 생성) */
    UUID member(String businessPlaceId, UUID ownerId, String memberNumber, String name) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO members (id, business_place_id, owner_id, member_number, name) VALUES (?, ?, ?, ?, ?)",
                id, businessPlaceId, ownerId, memberNumber, name);
        return id;
    }

    /** 회원을 soft-delete 상태로 전환 (실제 softDeleteMember 가 남기는 상태와 동일한 컬럼값) */
    void softDeleteMember(UUID memberId, UUID deletedBy) {
        jdbc.update("UPDATE members SET is_deleted = true, deleted_at = now(), deleted_by = ? WHERE id = ?",
                deletedBy, memberId);
    }

    /** reservations — status 는 커스텀 enum 타입(reservation_status)이라 명시적 캐스팅 필요. id 반환 */
    UUID reservation(UUID memberId, String businessPlaceId, LocalDate date, LocalTime time, String status) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO reservations (id, member_id, business_place_id, reservation_date, reservation_time, status) " +
                        "VALUES (?, ?, ?, ?, ?, CAST(? AS reservation_status))",
                id, memberId, businessPlaceId, date, time, status);
        return id;
    }

    /** visit — id 반환 */
    UUID visit(UUID memberId, UUID visitorId, LocalDateTime visitedAt) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO visit (id, member_id, visitor_id, visited_at) VALUES (?, ?, ?, ?)",
                id, memberId, visitorId, visitedAt);
        return id;
    }

    /** memos — id 반환 */
    UUID memo(UUID memberId, UUID ownerId, String content, boolean important) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO memos (id, member_id, owner_id, content, is_important) VALUES (?, ?, ?, ?, ?)",
                id, memberId, ownerId, content, important);
        return id;
    }

    /** 개별적으로 먼저 soft-delete 된 메모(회원 삭제와 다른 시각/주체) — WB-07 판별자 테스트용 */
    UUID individuallyDeletedMemo(UUID memberId, UUID ownerId, String content, LocalDateTime deletedAt, UUID deletedBy) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO memos (id, member_id, owner_id, content, is_important, is_deleted, deleted_at, deleted_by) " +
                        "VALUES (?, ?, ?, ?, false, true, ?, ?)",
                id, memberId, ownerId, content, deletedAt, deletedBy);
        return id;
    }

    /** notices — id 반환 */
    UUID notice(String title) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO notices (id, title, content, start_date, end_date) " +
                        "VALUES (?, ?, ?, now() - interval '1 day', now() + interval '30 day')",
                id, title, title + " 내용");
        return id;
    }

    /** memos 의 is_deleted 조회 (WB-07 검증용) */
    boolean isMemoDeleted(UUID memoId) {
        Boolean d = jdbc.queryForObject("SELECT is_deleted FROM memos WHERE id = ?", Boolean.class, memoId);
        return Boolean.TRUE.equals(d);
    }
}
