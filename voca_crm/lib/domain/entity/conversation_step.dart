/// 대화 단계 정보
class ConversationStep {
  final String stepType; // "member_selection", "memo_selection", etc.
  final int stepNumber; // 현재 단계 번호
  final Map<String, dynamic>? stepData;
  final String? targetEntityType;
  final bool allowMultipleSelection;
  final bool allowSelectAll;

  ConversationStep({
    required this.stepType,
    required this.stepNumber,
    this.stepData,
    this.targetEntityType,
    this.allowMultipleSelection = false,
    this.allowSelectAll = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'stepType': stepType,
      'stepNumber': stepNumber,
      if (stepData != null) 'stepData': stepData,
      if (targetEntityType != null) 'targetEntityType': targetEntityType,
      'allowMultipleSelection': allowMultipleSelection,
      'allowSelectAll': allowSelectAll,
    };
  }

  factory ConversationStep.fromJson(Map<String, dynamic> json) {
    return ConversationStep(
      stepType: json['stepType'] as String,
      stepNumber: json['stepNumber'] as int,
      stepData: json['stepData'] as Map<String, dynamic>?,
      targetEntityType: json['targetEntityType'] as String?,
      allowMultipleSelection: json['allowMultipleSelection'] as bool? ?? false,
      allowSelectAll: json['allowSelectAll'] as bool? ?? false,
    );
  }
}
