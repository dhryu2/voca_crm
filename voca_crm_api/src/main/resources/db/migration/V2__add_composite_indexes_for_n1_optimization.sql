-- =====================================================
-- V2: N+1 Query Optimization - Composite Indexes
-- =====================================================
-- 이 마이그레이션은 N+1 쿼리 문제를 해결하기 위해 추가된 배치 쿼리들을
-- 최적화하는 복합 인덱스를 추가합니다.

-- =====================================================
-- 1. UserBusinessPlace - Owner 조회 최적화
-- =====================================================
-- findOwnersByBusinessPlaceId() 쿼리 최적화
-- WHERE ubp.businessPlaceId = ? AND ubp.role = 'OWNER' AND ubp.status = 'APPROVED'
CREATE INDEX idx_ubp_bp_role_status ON user_business_places(business_place_id, role, status);

-- countMembersGroupByBusinessPlaceId() 쿼리 최적화
-- WHERE ubp.businessPlaceId IN ? AND ubp.status = 'APPROVED' GROUP BY ubp.businessPlaceId
CREATE INDEX idx_ubp_bp_status ON user_business_places(business_place_id, status);

-- =====================================================
-- 2. Reservations - 오늘 일정 조회 최적화
-- =====================================================
-- findByBusinessPlaceIdAndReservationDateWithMember() 쿼리 최적화
-- WHERE r.businessPlaceId = ? AND r.reservationDate = ? AND r.status IN ('PENDING', 'CONFIRMED')
CREATE INDEX idx_reservations_bp_date_status ON reservations(business_place_id, reservation_date, status);

-- =====================================================
-- 3. Memos - 메모 조회 최적화
-- =====================================================
-- findOldestByMemberIdAndBusinessPlaceId() 쿼리 최적화 (member_id + is_deleted + created_at)
-- 기존 idx_memos_member_not_deleted가 있지만, created_at 정렬을 위한 인덱스 추가
CREATE INDEX idx_memos_member_not_deleted_created ON memos(member_id, is_deleted, created_at ASC)
    WHERE is_deleted = FALSE;

-- =====================================================
-- 4. Members - 비즈니스 플레이스별 조회 최적화
-- =====================================================
-- Member 조회 시 is_deleted와 함께 필터링하는 경우 최적화
CREATE INDEX idx_members_bp_grade_not_deleted ON members(business_place_id, grade)
    WHERE is_deleted = FALSE;

-- =====================================================
-- Comments
-- =====================================================
COMMENT ON INDEX idx_ubp_bp_role_status IS 'UserBusinessPlace - 사업장별 Owner 조회 최적화 (findOwnersByBusinessPlaceId)';
COMMENT ON INDEX idx_ubp_bp_status IS 'UserBusinessPlace - 사업장별 회원 수 조회 최적화 (countMembersGroupByBusinessPlaceId)';
COMMENT ON INDEX idx_reservations_bp_date_status IS 'Reservations - 오늘 일정 조회 최적화 (getTodaySchedule)';
COMMENT ON INDEX idx_memos_member_not_deleted_created IS 'Memos - 가장 오래된 메모 조회 최적화 (findOldestByMemberIdAndBusinessPlaceId)';
COMMENT ON INDEX idx_members_bp_grade_not_deleted IS 'Members - 등급별 회원 분포 조회 최적화 (getMemberGradeDistribution)';
