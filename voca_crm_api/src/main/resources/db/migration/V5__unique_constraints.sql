-- ============================================
-- V5: 동시성 방어용 부분 유니크 제약
-- 애플리케이션 레벨 TOCTOU 체크를 DB가 최종 방어한다.
-- 기존 중복 데이터를 먼저 정리한 뒤 인덱스를 생성한다.
-- ============================================

-- 1) 중복 예약 방지 (활성 상태 PENDING/CONFIRMED 에서만)
-- 같은 (회원, 사업장, 날짜, 시각) 활성 예약이 여러 건이면 가장 최근 1건만 남긴다.
DELETE FROM reservations a
USING reservations b
WHERE a.status IN ('PENDING', 'CONFIRMED')
  AND b.status IN ('PENDING', 'CONFIRMED')
  AND a.member_id = b.member_id
  AND a.business_place_id = b.business_place_id
  AND a.reservation_date = b.reservation_date
  AND a.reservation_time = b.reservation_time
  AND (a.created_at < b.created_at
       OR (a.created_at = b.created_at AND a.ctid < b.ctid));

CREATE UNIQUE INDEX IF NOT EXISTS ux_reservation_active_slot
    ON reservations (member_id, business_place_id, reservation_date, reservation_time)
    WHERE status IN ('PENDING', 'CONFIRMED');

-- 2) 중복 PENDING 접근요청 방지
DELETE FROM business_place_access_requests a
USING business_place_access_requests b
WHERE a.status = 'PENDING'
  AND b.status = 'PENDING'
  AND a.user_id = b.user_id
  AND a.business_place_id = b.business_place_id
  AND (a.created_at < b.created_at
       OR (a.created_at = b.created_at AND a.ctid < b.ctid));

CREATE UNIQUE INDEX IF NOT EXISTS ux_bpar_pending
    ON business_place_access_requests (user_id, business_place_id)
    WHERE status = 'PENDING';
