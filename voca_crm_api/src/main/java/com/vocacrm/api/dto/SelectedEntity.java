package com.vocacrm.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

/**
 * 선택된 엔티티 정보
 * 대화 중 사용자가 선택한 엔티티(회원, 메모 등)를 저장
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SelectedEntity {

    /**
     * 엔티티 타입
     * - member: 회원
     * - memo: 메모
     * - visit: 방문 기록
     */
    private String entityType;

    /**
     * 선택된 엔티티 ID 리스트
     * 단일 선택: ["uuid1"]
     * 다중 선택: ["uuid1", "uuid2", "uuid3"]
     * 전체 선택: [] (selectAll이 true일 때)
     */
    @Builder.Default
    private List<String> ids = new ArrayList<>();

    /**
     * 전체 선택 여부
     * true: 조건에 맞는 모든 엔티티 선택
     * false: ids에 지정된 엔티티만 선택
     */
    @Builder.Default
    private boolean selectAll = false;

    /**
     * 엔티티 선택을 위한 필터 조건
     * 예: {"dateFilter": "3일 전", "status": "active"}
     */
    private java.util.Map<String, Object> filterConditions;

    /**
     * 선택된 엔티티 개수 (참고용)
     */
    private Integer count;
}
