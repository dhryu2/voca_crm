-- =====================================================
-- VocaCRM Database Schema - Complete Initial Schema
-- Includes: Business Place, Users, Members, Memos, Visit, Reservations, Notices
-- =====================================================

-- =====================================================
-- 1. Custom Types (ENUMs)
-- =====================================================
CREATE TYPE reservation_status AS ENUM (
    'PENDING',      -- 대기중
    'CONFIRMED',    -- 확정됨
    'CANCELLED',    -- 취소됨
    'COMPLETED',    -- 완료됨
    'NO_SHOW'       -- 노쇼
);

-- =====================================================
-- 2. Business Places (사업장)
-- =====================================================
CREATE TABLE business_places (
    id          VARCHAR(7)      PRIMARY KEY,
    name        VARCHAR(100)    NOT NULL,
    address     VARCHAR(200),
    phone       VARCHAR(20),
    created_at  TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE business_places IS '사업장 정보';

-- =====================================================
-- 3. Users (시스템 사용자)
-- =====================================================
CREATE TABLE users (
    id                          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    email                       VARCHAR(255),
    username                    VARCHAR(100)    NOT NULL,
    display_name                VARCHAR(100),
    phone                       VARCHAR(20),
    default_business_place_id   VARCHAR(7),
    tier                        VARCHAR(20)     NOT NULL    DEFAULT 'FREE',
    fcm_token                   VARCHAR(500),
    push_notification_enabled   BOOLEAN         NOT NULL    DEFAULT TRUE,
    created_at                  TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_users_default_business_place FOREIGN KEY (default_business_place_id) REFERENCES business_places(id)
);

COMMENT ON TABLE users IS '시스템 사용자';
COMMENT ON COLUMN users.id IS '사용자 고유 ID (UUID)';
COMMENT ON COLUMN users.email IS '사용자 이메일';
COMMENT ON COLUMN users.username IS '사용자가 회원가입 시 입력한 이름';
COMMENT ON COLUMN users.phone IS '사용자의 전화번호';
COMMENT ON COLUMN users.display_name IS '표시 이름';
COMMENT ON COLUMN users.default_business_place_id IS '기본 사업장 ID';
COMMENT ON COLUMN users.tier IS '사용자 요금제 (FREE, PREMIUM)';
COMMENT ON COLUMN users.push_notification_enabled IS '푸시 알림 수신 여부';

-- =====================================================
-- 4. User OAuth Connections (사용자 OAuth 연결 정보)
-- =====================================================
CREATE TABLE user_oauth_connections (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL,
    provider            VARCHAR(50)     NOT NULL,
    provider_user_id    VARCHAR(256)    NOT NULL,
    created_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_uoc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uk_provider_user UNIQUE (provider, provider_user_id)
);

COMMENT ON TABLE user_oauth_connections IS '사용자 OAuth 연결 정보 (1:N)';
COMMENT ON COLUMN user_oauth_connections.user_id IS '사용자 ID';
COMMENT ON COLUMN user_oauth_connections.provider IS 'OAuth 제공자 (google, kakao, apple)';
COMMENT ON COLUMN user_oauth_connections.provider_user_id IS 'OAuth 제공자의 사용자 ID';

-- =====================================================
-- 5. User Business Places (사용자-사업장 관계 및 권한)
-- =====================================================
CREATE TABLE user_business_places (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL,
    business_place_id   VARCHAR(7)      NOT NULL,
    role                VARCHAR(20)     NOT NULL,
    status              VARCHAR(20)     NOT NULL    DEFAULT 'PENDING',
    created_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ubp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_ubp_business_place FOREIGN KEY (business_place_id) REFERENCES business_places(id) ON DELETE CASCADE,
    CONSTRAINT uk_user_business_place UNIQUE (user_id, business_place_id)
);

COMMENT ON TABLE user_business_places IS '사용자-사업장 관계 및 권한';
COMMENT ON COLUMN user_business_places.role IS '역할 (OWNER, MANAGER, STAFF)';
COMMENT ON COLUMN user_business_places.status IS '상태 (PENDING, APPROVED, REJECTED)';

-- =====================================================
-- 6. Business Place Access Requests (사업장 접근 요청 이력)
-- =====================================================
CREATE TABLE business_place_access_requests (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID            NOT NULL,
    business_place_id       VARCHAR(7)      NOT NULL,
    role                    VARCHAR(20)     NOT NULL,
    status                  VARCHAR(20)     NOT NULL    DEFAULT 'PENDING',
    requested_at            TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    processed_at            TIMESTAMP,
    processed_by            UUID,
    is_read_by_requester    BOOLEAN         NOT NULL    DEFAULT FALSE,
    created_at              TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bpar_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_bpar_business_place FOREIGN KEY (business_place_id) REFERENCES business_places(id) ON DELETE CASCADE,
    CONSTRAINT fk_bpar_processed_by FOREIGN KEY (processed_by) REFERENCES users(id)
);

COMMENT ON TABLE business_place_access_requests IS '사업장 접근 요청 이력 및 처리 내역';
COMMENT ON COLUMN business_place_access_requests.user_id IS '요청자 ID';
COMMENT ON COLUMN business_place_access_requests.business_place_id IS '요청 대상 사업장 ID';
COMMENT ON COLUMN business_place_access_requests.role IS '요청한 권한 (MANAGER, STAFF)';
COMMENT ON COLUMN business_place_access_requests.status IS '요청 상태 (PENDING: 대기중, APPROVED: 승인됨, REJECTED: 거절됨)';
COMMENT ON COLUMN business_place_access_requests.requested_at IS '요청 시간';
COMMENT ON COLUMN business_place_access_requests.processed_at IS '처리 시간 (승인 또는 거절된 시간)';
COMMENT ON COLUMN business_place_access_requests.processed_by IS '처리자 ID (사업장 owner)';
COMMENT ON COLUMN business_place_access_requests.is_read_by_requester IS '요청자가 처리 결과를 확인했는지 여부';

-- =====================================================
-- 7. Members (고객)
-- =====================================================
CREATE TABLE members (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    business_place_id       VARCHAR(7)      NOT NULL,
    owner_id                UUID,
    last_modified_by_id     UUID,
    member_number           VARCHAR(50)     NOT NULL,
    name                    VARCHAR(100)    NOT NULL,
    phone                   VARCHAR(20),
    email                   VARCHAR(100),
    grade                   VARCHAR(20),
    remark                  TEXT,
    is_deleted              BOOLEAN         NOT NULL    DEFAULT FALSE,
    deleted_at              TIMESTAMP,
    deleted_by              UUID,
    created_at              TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_members_business_place FOREIGN KEY (business_place_id) REFERENCES business_places(id),
    CONSTRAINT fk_members_owner FOREIGN KEY (owner_id) REFERENCES users(id),
    CONSTRAINT fk_members_last_modified_by FOREIGN KEY (last_modified_by_id) REFERENCES users(id),
    CONSTRAINT fk_members_deleted_by FOREIGN KEY (deleted_by) REFERENCES users(id)
);

COMMENT ON TABLE members IS '고객 정보';
COMMENT ON COLUMN members.last_modified_by_id IS '마지막 수정자 ID';
COMMENT ON COLUMN members.remark IS '회원 비고';
COMMENT ON COLUMN members.is_deleted IS 'Soft Delete 여부';
COMMENT ON COLUMN members.deleted_at IS '삭제 요청 시간';
COMMENT ON COLUMN members.deleted_by IS '삭제 요청자 ID';

-- =====================================================
-- 8. Memos (메모)
-- =====================================================
CREATE TABLE memos (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id               UUID            NOT NULL,
    owner_id                UUID,
    last_modified_by_id     UUID,
    content                 TEXT            NOT NULL,
    is_important            BOOLEAN         NOT NULL    DEFAULT FALSE,
    is_deleted              BOOLEAN         NOT NULL    DEFAULT FALSE,
    deleted_at              TIMESTAMP,
    deleted_by              UUID,
    created_at              TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_memos_member FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    CONSTRAINT fk_memos_owner FOREIGN KEY (owner_id) REFERENCES users(id),
    CONSTRAINT fk_memos_last_modified_by FOREIGN KEY (last_modified_by_id) REFERENCES users(id),
    CONSTRAINT fk_memos_deleted_by FOREIGN KEY (deleted_by) REFERENCES users(id)
);

COMMENT ON TABLE memos IS '고객 메모';
COMMENT ON COLUMN memos.last_modified_by_id IS '마지막 수정자 ID';
COMMENT ON COLUMN memos.is_important IS '중요 메모 여부';
COMMENT ON COLUMN memos.is_deleted IS 'Soft Delete 여부';
COMMENT ON COLUMN memos.deleted_at IS '삭제 요청 시간';
COMMENT ON COLUMN memos.deleted_by IS '삭제 요청자 ID';

-- =====================================================
-- 9. Visit (방문 기록)
-- =====================================================
CREATE TABLE visit (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id       UUID            NOT NULL,
    visitor_id      UUID,
    visited_at      TIMESTAMP       NOT NULL,
    note            TEXT,
    created_at      TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_visit_member FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    CONSTRAINT fk_visit_visitor FOREIGN KEY (visitor_id) REFERENCES users(id)
);

COMMENT ON TABLE visit IS '방문 기록';

-- =====================================================
-- 10. Reservations (예약)
-- =====================================================
CREATE TABLE reservations (
    id                  UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id           UUID                NOT NULL,
    business_place_id   VARCHAR(7)          NOT NULL,
    reservation_date    DATE                NOT NULL,
    reservation_time    TIME                NOT NULL,
    status              reservation_status  NOT NULL    DEFAULT 'PENDING',
    service_type        VARCHAR(100),
    duration_minutes    INTEGER             DEFAULT 60,
    notes               TEXT,
    remark              VARCHAR(200),
    created_by          UUID,
    updated_by          UUID,
    created_at          TIMESTAMP           NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP           NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reservation_member FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    CONSTRAINT fk_reservation_business_place FOREIGN KEY (business_place_id) REFERENCES business_places(id) ON DELETE CASCADE,
    CONSTRAINT fk_reservation_created_by FOREIGN KEY (created_by) REFERENCES users(id),
    CONSTRAINT fk_reservation_updated_by FOREIGN KEY (updated_by) REFERENCES users(id)
);

COMMENT ON TABLE reservations IS '예약 정보 테이블';
COMMENT ON COLUMN reservations.remark IS '예약 비고';
COMMENT ON COLUMN reservations.id IS '예약 고유 ID (UUID)';
COMMENT ON COLUMN reservations.member_id IS '회원 ID (외래키)';
COMMENT ON COLUMN reservations.business_place_id IS '사업장 ID (외래키)';
COMMENT ON COLUMN reservations.reservation_date IS '예약 날짜';
COMMENT ON COLUMN reservations.reservation_time IS '예약 시간';
COMMENT ON COLUMN reservations.status IS '예약 상태 (PENDING, CONFIRMED, CANCELLED, COMPLETED, NO_SHOW)';
COMMENT ON COLUMN reservations.service_type IS '서비스 유형 (선택 사항)';
COMMENT ON COLUMN reservations.duration_minutes IS '예약 소요 시간 (분, 기본값 60분)';
COMMENT ON COLUMN reservations.notes IS '예약 메모';
COMMENT ON COLUMN reservations.created_by IS '예약 생성자';
COMMENT ON COLUMN reservations.updated_by IS '예약 수정자';

-- =====================================================
-- 11. Notices (공지사항)
-- =====================================================
CREATE TABLE notices (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    title               VARCHAR(200)    NOT NULL,
    content             TEXT            NOT NULL,
    start_date          TIMESTAMP       NOT NULL,
    end_date            TIMESTAMP       NOT NULL,
    priority            INTEGER         NOT NULL    DEFAULT 0,
    is_active           BOOLEAN         NOT NULL    DEFAULT TRUE,
    created_by_user_id  UUID,
    created_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notices_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

COMMENT ON TABLE notices IS '공지사항';
COMMENT ON COLUMN notices.id IS '공지사항 고유 ID (UUID)';
COMMENT ON COLUMN notices.title IS '공지사항 제목';
COMMENT ON COLUMN notices.content IS '공지사항 내용';
COMMENT ON COLUMN notices.start_date IS '공지 시작일';
COMMENT ON COLUMN notices.end_date IS '공지 종료일';
COMMENT ON COLUMN notices.priority IS '우선순위 (높을수록 먼저 표시)';
COMMENT ON COLUMN notices.is_active IS '활성화 여부';
COMMENT ON COLUMN notices.created_by_user_id IS '작성자 사용자 ID';

-- =====================================================
-- 12. User Notice Views (사용자별 공지사항 열람 기록)
-- =====================================================
CREATE TABLE user_notice_views (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL,
    notice_id           UUID            NOT NULL,
    viewed_at           TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    do_not_show_again   BOOLEAN         NOT NULL    DEFAULT FALSE,

    CONSTRAINT fk_unv_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_unv_notice FOREIGN KEY (notice_id) REFERENCES notices(id) ON DELETE CASCADE,
    CONSTRAINT uk_user_notice UNIQUE (user_id, notice_id)
);

COMMENT ON TABLE user_notice_views IS '사용자별 공지사항 열람 기록';
COMMENT ON COLUMN user_notice_views.user_id IS '사용자 ID';
COMMENT ON COLUMN user_notice_views.notice_id IS '공지사항 ID';
COMMENT ON COLUMN user_notice_views.viewed_at IS '열람 시각';
COMMENT ON COLUMN user_notice_views.do_not_show_again IS '다시 보지 않기 체크 여부';

-- =====================================================
-- 13. Audit Logs (감사 로그)
-- =====================================================
CREATE TABLE audit_logs (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL,
    username            VARCHAR(100),
    business_place_id   VARCHAR(7),
    action              VARCHAR(20)     NOT NULL,
    entity_type         VARCHAR(50)     NOT NULL,
    entity_id           UUID            NOT NULL,
    entity_name         VARCHAR(200),
    changes_before      TEXT,
    changes_after       TEXT,
    description         VARCHAR(500),
    ip_address          VARCHAR(45),
    device_info         VARCHAR(200),
    request_uri         VARCHAR(500),
    http_method         VARCHAR(10),
    created_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE audit_logs IS '시스템 감사 로그 - 모든 중요 변경사항 기록';
COMMENT ON COLUMN audit_logs.user_id IS '작업 수행 사용자 ID';
COMMENT ON COLUMN audit_logs.action IS 'CREATE, UPDATE, DELETE, RESTORE, LOGIN, LOGOUT 등';
COMMENT ON COLUMN audit_logs.entity_type IS 'MEMBER, MEMO, RESERVATION 등';
COMMENT ON COLUMN audit_logs.changes_before IS '변경 전 데이터 (JSON 형식)';
COMMENT ON COLUMN audit_logs.changes_after IS '변경 후 데이터 (JSON 형식)';

-- =====================================================
-- 14. Device Tokens (디바이스 토큰)
-- =====================================================
CREATE TABLE device_tokens (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    fcm_token       VARCHAR(500)    NOT NULL,
    device_type     VARCHAR(20),
    device_info     VARCHAR(200),
    app_version     VARCHAR(20),
    is_active       BOOLEAN         NOT NULL    DEFAULT TRUE,
    last_used_at    TIMESTAMP,
    created_at      TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

COMMENT ON TABLE device_tokens IS '디바이스별 FCM 푸시 토큰 저장';
COMMENT ON COLUMN device_tokens.user_id IS '사용자 ID';
COMMENT ON COLUMN device_tokens.fcm_token IS 'Firebase Cloud Messaging 토큰';
COMMENT ON COLUMN device_tokens.device_type IS '디바이스 타입 (IOS, ANDROID, WEB)';
COMMENT ON COLUMN device_tokens.device_info IS '디바이스 정보 (모델명 등)';
COMMENT ON COLUMN device_tokens.is_active IS '토큰 활성 여부';

-- =====================================================
-- 15. Notification Logs (알림 로그)
-- =====================================================
CREATE TABLE notification_logs (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL,
    notification_type   VARCHAR(30)     NOT NULL,
    title               VARCHAR(200)    NOT NULL,
    body                VARCHAR(1000),
    entity_type         VARCHAR(50),
    entity_id           UUID,
    data                TEXT,
    status              VARCHAR(20)     NOT NULL    DEFAULT 'PENDING',
    fcm_message_id      VARCHAR(200),
    error_message       VARCHAR(500),
    is_read             BOOLEAN         NOT NULL    DEFAULT FALSE,
    read_at             TIMESTAMP,
    created_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_logs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

COMMENT ON TABLE notification_logs IS '푸시 알림 발송 기록';
COMMENT ON COLUMN notification_logs.notification_type IS '알림 타입 (RESERVATION_REMINDER, MEMO_CREATED 등)';
COMMENT ON COLUMN notification_logs.entity_type IS '관련 엔티티 타입 (MEMBER, RESERVATION 등)';
COMMENT ON COLUMN notification_logs.entity_id IS '관련 엔티티 ID';
COMMENT ON COLUMN notification_logs.status IS '발송 상태 (PENDING, SENT, FAILED, CANCELLED)';
COMMENT ON COLUMN notification_logs.fcm_message_id IS 'FCM 응답 메시지 ID';

-- =====================================================
-- 16. Error Logs (오류 로그)
-- =====================================================
CREATE TABLE error_logs (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID,
    username            VARCHAR(100),
    business_place_id   VARCHAR(7),
    screen_name         VARCHAR(100),
    action              VARCHAR(100),
    request_url         VARCHAR(500),
    request_method      VARCHAR(10),
    request_body        TEXT,
    http_status_code    INTEGER,
    error_code          VARCHAR(50),
    error_message       TEXT,
    stack_trace         TEXT,
    severity            VARCHAR(20)     NOT NULL    DEFAULT 'ERROR',
    device_info         VARCHAR(200),
    app_version         VARCHAR(20),
    os_version          VARCHAR(50),
    platform            VARCHAR(20),
    resolved            BOOLEAN         NOT NULL    DEFAULT FALSE,
    resolved_by         UUID,
    resolved_at         TIMESTAMP,
    resolution_note     VARCHAR(500),
    created_at          TIMESTAMP       NOT NULL    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_error_logs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_error_logs_resolved_by FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL
);

COMMENT ON TABLE error_logs IS '클라이언트 오류 로그 - Flutter 앱에서 발생한 오류 기록';
COMMENT ON COLUMN error_logs.user_id IS '오류가 발생한 사용자 ID (비로그인 상태면 NULL)';
COMMENT ON COLUMN error_logs.username IS '사용자 이름 (조회 편의를 위해 비정규화)';
COMMENT ON COLUMN error_logs.business_place_id IS '사업장 ID';
COMMENT ON COLUMN error_logs.screen_name IS '오류가 발생한 화면 이름';
COMMENT ON COLUMN error_logs.action IS '사용자가 수행하던 행동';
COMMENT ON COLUMN error_logs.request_url IS 'API 요청 URL';
COMMENT ON COLUMN error_logs.request_method IS 'HTTP 메서드 (GET, POST, PUT, DELETE 등)';
COMMENT ON COLUMN error_logs.request_body IS '요청 본문 (민감 정보 제외)';
COMMENT ON COLUMN error_logs.http_status_code IS 'HTTP 응답 상태 코드';
COMMENT ON COLUMN error_logs.error_code IS '앱에서 정의한 오류 코드';
COMMENT ON COLUMN error_logs.error_message IS '오류 메시지';
COMMENT ON COLUMN error_logs.stack_trace IS '스택 트레이스';
COMMENT ON COLUMN error_logs.severity IS '심각도 (INFO, WARNING, ERROR, CRITICAL)';
COMMENT ON COLUMN error_logs.device_info IS '디바이스 정보 (모델명 등)';
COMMENT ON COLUMN error_logs.app_version IS '앱 버전';
COMMENT ON COLUMN error_logs.os_version IS 'OS 버전 (예: iOS 17.0, Android 14)';
COMMENT ON COLUMN error_logs.platform IS '플랫폼 (iOS, Android)';
COMMENT ON COLUMN error_logs.resolved IS '해결 여부';
COMMENT ON COLUMN error_logs.resolved_by IS '해결한 관리자 ID';
COMMENT ON COLUMN error_logs.resolved_at IS '해결 시간';
COMMENT ON COLUMN error_logs.resolution_note IS '해결 메모';

-- =====================================================
-- 17. Indexes
-- =====================================================
-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone_username ON users(phone, username);

-- User OAuth Connections
CREATE INDEX idx_uoc_user_id ON user_oauth_connections(user_id);
CREATE INDEX idx_uoc_provider ON user_oauth_connections(provider);
CREATE INDEX idx_uoc_provider_user_id ON user_oauth_connections(provider_user_id);

-- User Business Places
CREATE INDEX idx_ubp_user_id ON user_business_places(user_id);
CREATE INDEX idx_ubp_business_place_id ON user_business_places(business_place_id);
CREATE INDEX idx_ubp_status ON user_business_places(status);

-- Business Place Access Requests
CREATE INDEX idx_bpar_user_id ON business_place_access_requests(user_id);
CREATE INDEX idx_bpar_business_place_id ON business_place_access_requests(business_place_id);
CREATE INDEX idx_bpar_status ON business_place_access_requests(status);
CREATE INDEX idx_bpar_processed_by ON business_place_access_requests(processed_by);
CREATE INDEX idx_bpar_requested_at ON business_place_access_requests(requested_at DESC);
CREATE INDEX idx_bpar_user_status ON business_place_access_requests(user_id, status);
CREATE INDEX idx_bpar_is_read ON business_place_access_requests(is_read_by_requester);

-- Members
CREATE INDEX idx_members_business_place ON members(business_place_id);
CREATE INDEX idx_members_member_number ON members(member_number);
CREATE INDEX idx_members_name ON members(name);
CREATE INDEX idx_members_phone ON members(phone);
CREATE INDEX idx_members_created_at ON members(created_at DESC);
CREATE INDEX idx_members_last_modified_by ON members(last_modified_by_id);
CREATE INDEX idx_members_is_deleted ON members(is_deleted);
CREATE INDEX idx_members_deleted_by ON members(deleted_by);
CREATE INDEX idx_members_business_place_not_deleted ON members(business_place_id, is_deleted) WHERE is_deleted = FALSE;

-- Memos
CREATE INDEX idx_memos_member_id ON memos(member_id);
CREATE INDEX idx_memos_created_at ON memos(created_at DESC);
CREATE INDEX idx_memos_member_created ON memos(member_id, created_at DESC);
CREATE INDEX idx_memos_last_modified_by ON memos(last_modified_by_id);
CREATE INDEX idx_memos_is_important ON memos(is_important);
CREATE INDEX idx_memos_member_important ON memos(member_id, is_important);
CREATE INDEX idx_memos_is_deleted ON memos(is_deleted);
CREATE INDEX idx_memos_deleted_by ON memos(deleted_by);
CREATE INDEX idx_memos_member_not_deleted ON memos(member_id, is_deleted) WHERE is_deleted = FALSE;

-- Visit
CREATE INDEX idx_visit_member_id ON visit(member_id);
CREATE INDEX idx_visit_visited_at ON visit(visited_at);

-- Reservations
CREATE INDEX idx_reservations_member_id ON reservations(member_id);
CREATE INDEX idx_reservations_business_place_id ON reservations(business_place_id);
CREATE INDEX idx_reservations_date ON reservations(reservation_date);
CREATE INDEX idx_reservations_status ON reservations(status);
CREATE INDEX idx_reservations_date_time ON reservations(reservation_date, reservation_time);
CREATE INDEX idx_reservations_business_date ON reservations(business_place_id, reservation_date);

-- Notices
CREATE INDEX idx_notices_start_date ON notices(start_date);
CREATE INDEX idx_notices_end_date ON notices(end_date);
CREATE INDEX idx_notices_is_active ON notices(is_active);
CREATE INDEX idx_notices_priority ON notices(priority DESC);
CREATE INDEX idx_notices_active_period ON notices(is_active, start_date, end_date);

-- User Notice Views
CREATE INDEX idx_unv_user_id ON user_notice_views(user_id);
CREATE INDEX idx_unv_notice_id ON user_notice_views(notice_id);
CREATE INDEX idx_unv_do_not_show ON user_notice_views(user_id, do_not_show_again);

-- Audit Logs
CREATE INDEX idx_audit_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_business_place ON audit_logs(business_place_id);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_bp_created ON audit_logs(business_place_id, created_at DESC);
CREATE INDEX idx_audit_bp_entity_created ON audit_logs(business_place_id, entity_type, created_at DESC);

-- Device Tokens
CREATE INDEX idx_device_user_id ON device_tokens(user_id);
CREATE INDEX idx_device_token ON device_tokens(fcm_token);
CREATE INDEX idx_device_active ON device_tokens(is_active);

-- Notification Logs
CREATE INDEX idx_notif_user_id ON notification_logs(user_id);
CREATE INDEX idx_notif_type ON notification_logs(notification_type);
CREATE INDEX idx_notif_created ON notification_logs(created_at);
CREATE INDEX idx_notif_user_status ON notification_logs(user_id, status);
CREATE INDEX idx_notif_user_read ON notification_logs(user_id, is_read);

-- Error Logs
CREATE INDEX idx_error_user_id ON error_logs(user_id);
CREATE INDEX idx_error_created_at ON error_logs(created_at);
CREATE INDEX idx_error_business_place ON error_logs(business_place_id);
CREATE INDEX idx_error_severity ON error_logs(severity);
CREATE INDEX idx_error_screen ON error_logs(screen_name);
CREATE INDEX idx_error_resolved ON error_logs(resolved);

-- =====================================================
-- 18. Functions & Triggers (Updated_at)
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_business_places_updated_at BEFORE UPDATE ON business_places FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_oauth_connections_updated_at BEFORE UPDATE ON user_oauth_connections FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_business_places_updated_at BEFORE UPDATE ON user_business_places FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_business_place_access_requests_updated_at BEFORE UPDATE ON business_place_access_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_members_updated_at BEFORE UPDATE ON members FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_memos_updated_at BEFORE UPDATE ON memos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_visit_updated_at BEFORE UPDATE ON visit FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_reservations_updated_at BEFORE UPDATE ON reservations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_notices_updated_at BEFORE UPDATE ON notices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_device_tokens_updated_at BEFORE UPDATE ON device_tokens FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 19. Views
-- =====================================================
-- View: Member Summary with Memo Count (excludes soft deleted)
CREATE OR REPLACE VIEW v_members_with_memo_count AS
SELECT
    m.id,
    m.business_place_id,
    m.member_number,
    m.name,
    m.phone,
    m.grade,
    m.created_at,
    m.updated_at,
    COUNT(memo.id) as memo_count,
    MAX(memo.created_at) as latest_memo_date
FROM members m
LEFT JOIN memos memo ON m.id = memo.member_id AND memo.is_deleted = FALSE
WHERE m.is_deleted = FALSE
GROUP BY m.id;

-- View: Deleted Members (for restore/permanent delete screen)
CREATE OR REPLACE VIEW v_deleted_members AS
SELECT
    m.id,
    m.business_place_id,
    m.member_number,
    m.name,
    m.phone,
    m.grade,
    m.deleted_at,
    m.deleted_by,
    u.username as deleted_by_name,
    COUNT(memo.id) as memo_count
FROM members m
LEFT JOIN memos memo ON m.id = memo.member_id
LEFT JOIN users u ON m.deleted_by = u.id
WHERE m.is_deleted = TRUE
GROUP BY m.id, m.business_place_id, m.member_number, m.name, m.phone, m.grade,
         m.deleted_at, m.deleted_by, u.username;

-- View: Business Place Statistics Summary
CREATE OR REPLACE VIEW v_business_place_stats AS
SELECT
    bp.id as business_place_id,
    bp.name as business_place_name,
    COUNT(DISTINCT m.id) as total_members,
    COUNT(DISTINCT memo.id) as total_memos,
    COUNT(DISTINCT v.id) as total_visits
FROM business_places bp
LEFT JOIN members m ON bp.id = m.business_place_id
LEFT JOIN memos memo ON m.id = memo.member_id
LEFT JOIN visit v ON m.id = v.member_id
GROUP BY bp.id, bp.name;

-- =====================================================
-- 20. Helper Functions
-- =====================================================
-- Function: Get Member with Latest Memo (excludes soft deleted)
CREATE OR REPLACE FUNCTION get_member_with_latest_memo(p_member_number VARCHAR)
RETURNS TABLE (
    member_id UUID,
    member_number VARCHAR,
    name VARCHAR,
    phone VARCHAR,
    grade VARCHAR,
    latest_memo_id UUID,
    latest_memo_content TEXT,
    latest_memo_created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id,
        m.member_number,
        m.name,
        m.phone,
        m.grade,
        memo.id,
        memo.content,
        memo.created_at
    FROM members m
    LEFT JOIN LATERAL (
        SELECT id, content, created_at
        FROM memos
        WHERE member_id = m.id AND is_deleted = FALSE
        ORDER BY created_at DESC
        LIMIT 1
    ) memo ON true
    WHERE m.member_number = p_member_number AND m.is_deleted = FALSE
    ORDER BY m.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function: Get today's visit count for a business place
CREATE OR REPLACE FUNCTION get_today_visit_count(p_business_place_id VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    visit_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO visit_count
    FROM visit v
    INNER JOIN members m ON v.member_id = m.id
    WHERE m.business_place_id = p_business_place_id
      AND DATE(v.visited_at) = CURRENT_DATE;

    RETURN COALESCE(visit_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function: Get pending memos count for a business place
CREATE OR REPLACE FUNCTION get_pending_memos_count(p_business_place_id VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    memo_count INTEGER;
BEGIN
    SELECT COUNT(DISTINCT memo.id)
    INTO memo_count
    FROM memos memo
    INNER JOIN members m ON memo.member_id = m.id
    WHERE m.business_place_id = p_business_place_id
      AND DATE(memo.created_at) = CURRENT_DATE;

    RETURN COALESCE(memo_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function: Get recent activities (memos and visits combined)
CREATE OR REPLACE FUNCTION get_recent_activities(
    p_business_place_id VARCHAR,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    activity_id UUID,
    activity_type VARCHAR,
    member_id UUID,
    member_name VARCHAR,
    content TEXT,
    activity_time TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    (
        -- Recent memos
        SELECT
            memo.id as activity_id,
            'MEMO'::VARCHAR as activity_type,
            m.id as member_id,
            m.name as member_name,
            memo.content as content,
            memo.created_at as activity_time
        FROM memos memo
        INNER JOIN members m ON memo.member_id = m.id
        WHERE m.business_place_id = p_business_place_id

        UNION ALL

        -- Recent visits
        SELECT
            v.id as activity_id,
            'VISIT'::VARCHAR as activity_type,
            m.id as member_id,
            m.name as member_name,
            COALESCE(v.note, '방문') as content,
            v.visited_at as activity_time
        FROM visit v
        INNER JOIN members m ON v.member_id = m.id
        WHERE m.business_place_id = p_business_place_id
    )
    ORDER BY activity_time DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Get reservation count by date
CREATE OR REPLACE FUNCTION get_reservation_count_by_date(
    p_business_place_id VARCHAR(7),
    p_date DATE
)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM reservations
        WHERE business_place_id = p_business_place_id
          AND reservation_date = p_date
          AND status IN ('PENDING', 'CONFIRMED')
    );
END;
$$ LANGUAGE plpgsql;

-- Function: Get reservations statistics by date range
CREATE OR REPLACE FUNCTION get_reservations_by_date_range(
    p_business_place_id VARCHAR(7),
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    reservation_date DATE,
    total_count BIGINT,
    pending_count BIGINT,
    confirmed_count BIGINT,
    completed_count BIGINT,
    cancelled_count BIGINT,
    no_show_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.reservation_date,
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE r.status = 'PENDING') as pending_count,
        COUNT(*) FILTER (WHERE r.status = 'CONFIRMED') as confirmed_count,
        COUNT(*) FILTER (WHERE r.status = 'COMPLETED') as completed_count,
        COUNT(*) FILTER (WHERE r.status = 'CANCELLED') as cancelled_count,
        COUNT(*) FILTER (WHERE r.status = 'NO_SHOW') as no_show_count
    FROM reservations r
    WHERE r.business_place_id = p_business_place_id
      AND r.reservation_date BETWEEN p_start_date AND p_end_date
    GROUP BY r.reservation_date
    ORDER BY r.reservation_date;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 21. Function Comments
-- =====================================================
COMMENT ON FUNCTION get_today_visit_count IS '오늘 방문 건수 조회';
COMMENT ON FUNCTION get_pending_memos_count IS '미처리 메모 건수 조회 (오늘 작성된 메모)';
COMMENT ON FUNCTION get_recent_activities IS '최근 활동 목록 조회 (메모 + 방문)';
COMMENT ON VIEW v_business_place_stats IS '사업장 통계 요약';
