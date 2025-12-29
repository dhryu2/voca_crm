package com.vocacrm.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 사업장 삭제 미리보기 DTO
 *
 * 사업장 삭제 시 함께 삭제될 데이터의 개수를 반환합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BusinessPlaceDeletionPreviewDTO {

    /**
     * 사업장 ID
     */
    private String businessPlaceId;

    /**
     * 사업장 이름 (확인용)
     */
    private String businessPlaceName;

    /**
     * 삭제될 고객(Member) 수
     */
    private long memberCount;

    /**
     * 삭제될 메모(Memo) 수
     */
    private long memoCount;

    /**
     * 삭제될 예약(Reservation) 수
     */
    private long reservationCount;

    /**
     * 삭제될 방문 기록(Visit) 수
     */
    private long visitCount;

    /**
     * 삭제될 감사 로그(AuditLog) 수
     */
    private long auditLogCount;

    /**
     * 연결 해제될 직원(User) 수 (Owner 제외)
     */
    private long staffCount;

    /**
     * 삭제될 접근 요청(AccessRequest) 수
     */
    private long accessRequestCount;
}
