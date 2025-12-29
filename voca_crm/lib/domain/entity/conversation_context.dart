import 'package:voca_crm/domain/entity/selected_entity.dart';
import 'package:voca_crm/domain/entity/conversation_step.dart';

/// 대화 컨텍스트 엔티티
/// 다단계 대화형 명령 처리 시 상태를 유지하기 위한 정보
class ConversationContext {
  final String? conversationId;
  final String? businessPlaceId; // 사용자의 기본 사업장 ID
  final String? requestUserId; // 요청자 사용자 ID (권한 체크용)
  final Map<String, dynamic>? originalIntent;
  final List<SelectedEntity> selectedEntities;
  final List<ConversationStep> conversationHistory;
  final ConversationStep? currentStep;
  final Map<String, dynamic>? additionalData;

  ConversationContext({
    this.conversationId,
    this.businessPlaceId,
    this.requestUserId,
    this.originalIntent,
    List<SelectedEntity>? selectedEntities,
    List<ConversationStep>? conversationHistory,
    this.currentStep,
    this.additionalData,
  })  : selectedEntities = selectedEntities ?? [],
        conversationHistory = conversationHistory ?? [];

  Map<String, dynamic> toJson() {
    return {
      if (conversationId != null) 'conversationId': conversationId,
      if (businessPlaceId != null) 'businessPlaceId': businessPlaceId,
      if (requestUserId != null) 'requestUserId': requestUserId,
      if (originalIntent != null) 'originalIntent': originalIntent,
      'selectedEntities':
          selectedEntities.map((e) => e.toJson()).toList(),
      'conversationHistory':
          conversationHistory.map((s) => s.toJson()).toList(),
      if (currentStep != null) 'currentStep': currentStep!.toJson(),
      if (additionalData != null) 'additionalData': additionalData,
    };
  }

  factory ConversationContext.fromJson(Map<String, dynamic> json) {
    return ConversationContext(
      conversationId: json['conversationId'] as String?,
      businessPlaceId: json['businessPlaceId'] as String?,
      requestUserId: json['requestUserId'] as String?,
      originalIntent: json['originalIntent'] as Map<String, dynamic>?,
      selectedEntities: (json['selectedEntities'] as List<dynamic>?)
              ?.map((e) => SelectedEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      conversationHistory: (json['conversationHistory'] as List<dynamic>?)
              ?.map((s) => ConversationStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      currentStep: json['currentStep'] != null
          ? ConversationStep.fromJson(
              json['currentStep'] as Map<String, dynamic>)
          : null,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  /// 특정 타입의 선택된 엔티티 가져오기
  SelectedEntity? getSelectedEntityByType(String entityType) {
    try {
      return selectedEntities.firstWhere((e) => e.entityType == entityType);
    } catch (e) {
      return null;
    }
  }

  /// 선택된 엔티티 추가 (동일 타입은 대체)
  ConversationContext addSelectedEntity(SelectedEntity entity) {
    final updated = selectedEntities
        .where((e) => e.entityType != entity.entityType)
        .toList()
      ..add(entity);

    return copyWith(selectedEntities: updated);
  }

  ConversationContext copyWith({
    String? conversationId,
    String? businessPlaceId,
    String? requestUserId,
    Map<String, dynamic>? originalIntent,
    List<SelectedEntity>? selectedEntities,
    List<ConversationStep>? conversationHistory,
    ConversationStep? currentStep,
    Map<String, dynamic>? additionalData,
  }) {
    return ConversationContext(
      conversationId: conversationId ?? this.conversationId,
      businessPlaceId: businessPlaceId ?? this.businessPlaceId,
      requestUserId: requestUserId ?? this.requestUserId,
      originalIntent: originalIntent ?? this.originalIntent,
      selectedEntities: selectedEntities ?? this.selectedEntities,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      currentStep: currentStep ?? this.currentStep,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}
