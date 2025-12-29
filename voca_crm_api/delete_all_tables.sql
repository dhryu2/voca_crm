-- =====================================================
-- VocaCRM Database - Delete All Objects
-- V1__init_schema.sql에서 생성한 모든 개체 삭제
-- 실행 순서: 의존성 역순 (자식 → 부모)
-- =====================================================

-- =====================================================
-- 1. Drop Views
-- =====================================================
DROP VIEW IF EXISTS v_business_place_stats CASCADE;
DROP VIEW IF EXISTS v_deleted_members CASCADE;
DROP VIEW IF EXISTS v_members_with_memo_count CASCADE;

-- =====================================================
-- 2. Drop Functions
-- =====================================================
DROP FUNCTION IF EXISTS get_reservations_by_date_range(VARCHAR, DATE, DATE) CASCADE;
DROP FUNCTION IF EXISTS get_reservation_count_by_date(VARCHAR, DATE) CASCADE;
DROP FUNCTION IF EXISTS get_recent_activities(VARCHAR, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_pending_memos_count(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS get_today_visit_count(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS get_member_with_latest_memo(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- =====================================================
-- 3. Drop Triggers (함수 삭제 시 CASCADE로 함께 삭제되지만 명시적으로 작성)
-- =====================================================
DROP TRIGGER IF EXISTS update_device_tokens_updated_at ON device_tokens;
DROP TRIGGER IF EXISTS update_notices_updated_at ON notices;
DROP TRIGGER IF EXISTS update_reservations_updated_at ON reservations;
DROP TRIGGER IF EXISTS update_visit_updated_at ON visit;
DROP TRIGGER IF EXISTS update_memos_updated_at ON memos;
DROP TRIGGER IF EXISTS update_members_updated_at ON members;
DROP TRIGGER IF EXISTS update_business_place_access_requests_updated_at ON business_place_access_requests;
DROP TRIGGER IF EXISTS update_user_business_places_updated_at ON user_business_places;
DROP TRIGGER IF EXISTS update_user_oauth_connections_updated_at ON user_oauth_connections;
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
DROP TRIGGER IF EXISTS update_business_places_updated_at ON business_places;

-- =====================================================
-- 4. Drop Indexes (테이블 삭제 시 자동 삭제되지만 명시적으로 작성)
-- =====================================================
-- Notification Logs Indexes
DROP INDEX IF EXISTS idx_notif_user_read;
DROP INDEX IF EXISTS idx_notif_user_status;
DROP INDEX IF EXISTS idx_notif_created;
DROP INDEX IF EXISTS idx_notif_type;
DROP INDEX IF EXISTS idx_notif_user_id;

-- Device Tokens Indexes
DROP INDEX IF EXISTS idx_device_active;
DROP INDEX IF EXISTS idx_device_token;
DROP INDEX IF EXISTS idx_device_user_id;

-- Audit Logs Indexes
DROP INDEX IF EXISTS idx_audit_bp_entity_created;
DROP INDEX IF EXISTS idx_audit_bp_created;
DROP INDEX IF EXISTS idx_audit_action;
DROP INDEX IF EXISTS idx_audit_business_place;
DROP INDEX IF EXISTS idx_audit_created_at;
DROP INDEX IF EXISTS idx_audit_entity;
DROP INDEX IF EXISTS idx_audit_user_id;

-- User Notice Views Indexes
DROP INDEX IF EXISTS idx_unv_do_not_show;
DROP INDEX IF EXISTS idx_unv_notice_id;
DROP INDEX IF EXISTS idx_unv_user_id;

-- Notices Indexes
DROP INDEX IF EXISTS idx_notices_active_period;
DROP INDEX IF EXISTS idx_notices_priority;
DROP INDEX IF EXISTS idx_notices_is_active;
DROP INDEX IF EXISTS idx_notices_end_date;
DROP INDEX IF EXISTS idx_notices_start_date;

-- Reservations Indexes
DROP INDEX IF EXISTS idx_reservations_business_date;
DROP INDEX IF EXISTS idx_reservations_date_time;
DROP INDEX IF EXISTS idx_reservations_status;
DROP INDEX IF EXISTS idx_reservations_date;
DROP INDEX IF EXISTS idx_reservations_business_place_id;
DROP INDEX IF EXISTS idx_reservations_member_id;

-- Visit Indexes
DROP INDEX IF EXISTS idx_visit_visited_at;
DROP INDEX IF EXISTS idx_visit_member_id;

-- Memos Indexes
DROP INDEX IF EXISTS idx_memos_member_not_deleted;
DROP INDEX IF EXISTS idx_memos_deleted_by;
DROP INDEX IF EXISTS idx_memos_is_deleted;
DROP INDEX IF EXISTS idx_memos_member_archived;
DROP INDEX IF EXISTS idx_memos_member_important;
DROP INDEX IF EXISTS idx_memos_is_archived;
DROP INDEX IF EXISTS idx_memos_is_important;
DROP INDEX IF EXISTS idx_memos_last_modified_by;
DROP INDEX IF EXISTS idx_memos_member_created;
DROP INDEX IF EXISTS idx_memos_created_at;
DROP INDEX IF EXISTS idx_memos_member_id;

-- Members Indexes
DROP INDEX IF EXISTS idx_members_business_place_not_deleted;
DROP INDEX IF EXISTS idx_members_deleted_by;
DROP INDEX IF EXISTS idx_members_is_deleted;
DROP INDEX IF EXISTS idx_members_last_modified_by;
DROP INDEX IF EXISTS idx_members_created_at;
DROP INDEX IF EXISTS idx_members_phone;
DROP INDEX IF EXISTS idx_members_name;
DROP INDEX IF EXISTS idx_members_member_number;
DROP INDEX IF EXISTS idx_members_business_place;

-- Business Place Access Requests Indexes
DROP INDEX IF EXISTS idx_bpar_is_read;
DROP INDEX IF EXISTS idx_bpar_user_status;
DROP INDEX IF EXISTS idx_bpar_requested_at;
DROP INDEX IF EXISTS idx_bpar_processed_by;
DROP INDEX IF EXISTS idx_bpar_status;
DROP INDEX IF EXISTS idx_bpar_business_place_id;
DROP INDEX IF EXISTS idx_bpar_user_id;

-- User Business Places Indexes
DROP INDEX IF EXISTS idx_ubp_status;
DROP INDEX IF EXISTS idx_ubp_business_place_id;
DROP INDEX IF EXISTS idx_ubp_user_id;

-- User OAuth Connections Indexes
DROP INDEX IF EXISTS idx_uoc_provider_user_id;
DROP INDEX IF EXISTS idx_uoc_provider;
DROP INDEX IF EXISTS idx_uoc_user_id;

-- Users Indexes
DROP INDEX IF EXISTS idx_users_phone_username;
DROP INDEX IF EXISTS idx_users_email;

-- =====================================================
-- 5. Drop Tables (의존성 역순)
-- =====================================================
-- 자식 테이블 먼저 삭제
DROP TABLE IF EXISTS notification_logs CASCADE;
DROP TABLE IF EXISTS device_tokens CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS user_notice_views CASCADE;
DROP TABLE IF EXISTS notices CASCADE;
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS visit CASCADE;
DROP TABLE IF EXISTS memos CASCADE;
DROP TABLE IF EXISTS members CASCADE;
DROP TABLE IF EXISTS business_place_access_requests CASCADE;
DROP TABLE IF EXISTS user_business_places CASCADE;
DROP TABLE IF EXISTS user_oauth_connections CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS business_places CASCADE;

-- =====================================================
-- 6. Drop Custom Types (ENUMs)
-- =====================================================
DROP TYPE IF EXISTS reservation_status CASCADE;

-- =====================================================
-- 7. Drop Flyway Schema History (선택사항)
-- Flyway 마이그레이션 기록도 삭제하려면 주석 해제
-- =====================================================
-- DROP TABLE IF EXISTS flyway_schema_history CASCADE;

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE 'All VocaCRM database objects have been deleted successfully.';
END $$;
