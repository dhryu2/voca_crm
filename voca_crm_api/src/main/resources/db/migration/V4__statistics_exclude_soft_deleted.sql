-- =====================================================
-- H5: 삭제된 회원/메모가 통계에 혼입되는 문제 수정
-- get_today_visit_count, get_pending_memos_count, get_recent_activities
-- 함수에 members/memos의 is_deleted = false 조건 추가
-- =====================================================

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
      AND m.is_deleted = FALSE
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
      AND m.is_deleted = FALSE
      AND memo.is_deleted = FALSE
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
          AND m.is_deleted = FALSE
          AND memo.is_deleted = FALSE

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
          AND m.is_deleted = FALSE
    )
    ORDER BY activity_time DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;
