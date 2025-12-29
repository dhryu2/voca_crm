package com.vocacrm.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 대화 컨텍스트 DTO
 * 다단계 대화형 명령 처리 시 상태를 유지하기 위한 정보
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConversationContextDto {

    /**
     * 대화 세션 ID (UUID)
     */
    private String conversationId;

    /**
     * 사용자의 기본 사업장 ID
     * 모든 조회 작업의 필터로 사용됨
     */
    private String businessPlaceId;

    /**
     * 요청자 사용자 ID (providerId)
     * 권한 체크 및 작성자 설정에 사용됨
     */
    private String requestUserId;

    /**
     * 원래 의도 (AI가 분석한 원래 명령의 의도)
     * 예: {
     *   "action": "memo_delete",
     *   "memberNumber": "1234",
     *   "dateFilter": "3일 전"
     * }
     */
    private Map<String, Object> originalIntent;

    /**
     * 선택된 엔티티 리스트
     * 다단계 대화에서 각 단계마다 선택된 엔티티를 누적 저장
     * 예: [
     *   { "entityType": "member", "ids": ["uuid1"], "selectAll": false },
     *   { "entityType": "memo", "ids": [], "selectAll": true }
     * ]
     */
    @Builder.Default
    private List<SelectedEntity> selectedEntities = new ArrayList<>();

    /**
     * 대화 히스토리 (이전 단계들)
     */
    @Builder.Default
    private List<ConversationStep> conversationHistory = new ArrayList<>();

    /**
     * 현재 진행 중인 단계
     */
    private ConversationStep currentStep;

    /**
     * 추가 컨텍스트 데이터
     * 동적으로 필요한 정보 저장
     */
    private Map<String, Object> additionalData;

    /**
     * 특정 타입의 선택된 엔티티 가져오기
     */
    public SelectedEntity getSelectedEntityByType(String entityType) {
        return selectedEntities.stream()
                .filter(e -> entityType.equals(e.getEntityType()))
                .findFirst()
                .orElse(null);
    }

    /**
     * 선택된 엔티티 추가
     */
    public void addSelectedEntity(SelectedEntity entity) {
        // 동일 타입의 기존 엔티티는 제거하고 새로 추가
        selectedEntities.removeIf(e -> e.getEntityType().equals(entity.getEntityType()));
        selectedEntities.add(entity);
    }

    /**
     * 대화 단계 진행
     */
    public void advanceStep(ConversationStep newStep) {
        if (currentStep != null) {
            conversationHistory.add(currentStep);
        }
        currentStep = newStep;
    }
}
