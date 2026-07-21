-- ============================================
-- V6: audit_logs.user_id NOT NULL 제약 완화
-- 감사 로그가 있는 사용자가 사업장 탈퇴/강퇴될 때 user_id를 NULL로 정리하므로
-- NOT NULL 제약이 있으면 트랜잭션 롤백(500)이 발생한다.
-- 로그 자체는 보존하고(username은 비정규화 필드로 유지) user_id만 NULL 허용으로 완화한다.
-- ============================================

ALTER TABLE audit_logs ALTER COLUMN user_id DROP NOT NULL;
