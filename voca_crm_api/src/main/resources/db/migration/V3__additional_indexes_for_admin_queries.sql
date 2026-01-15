-- =====================================================
-- V3: Admin Query Optimization - Additional Indexes
-- =====================================================
-- Phase 2 Repository Query Audit에서 추가된 쿼리 최적화

-- =====================================================
-- 1. Users - 가입일 기준 통계 조회 최적화
-- =====================================================
-- countByCreatedAtAfter() 쿼리 최적화
CREATE INDEX idx_users_created_at ON users(created_at);

-- =====================================================
-- 2. Users - 검색 쿼리 최적화
-- =====================================================
-- findAllWithOAuthConnectionsAndSearch() 쿼리 최적화
CREATE INDEX idx_users_username_lower ON users(LOWER(username));
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
CREATE INDEX idx_users_phone ON users(phone);

-- =====================================================
-- 3. BusinessPlaces - 검색 쿼리 최적화
-- =====================================================
-- findAllWithSearch() 쿼리 최적화
CREATE INDEX idx_bp_name_lower ON business_places(LOWER(name));
CREATE INDEX idx_bp_address_lower ON business_places(LOWER(address));

-- =====================================================
-- Comments
-- =====================================================
COMMENT ON INDEX idx_users_created_at IS 'Users - 가입일 기준 통계 (countByCreatedAtAfter)';
COMMENT ON INDEX idx_users_username_lower IS 'Users - 이름 검색 최적화';
COMMENT ON INDEX idx_users_email_lower IS 'Users - 이메일 검색 최적화';
COMMENT ON INDEX idx_users_phone IS 'Users - 전화번호 검색 최적화';
COMMENT ON INDEX idx_bp_name_lower IS 'BusinessPlaces - 이름 검색 최적화';
COMMENT ON INDEX idx_bp_address_lower IS 'BusinessPlaces - 주소 검색 최적화';
