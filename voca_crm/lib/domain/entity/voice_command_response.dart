import 'package:voca_crm/domain/entity/conversation_context.dart';

/// 음성 명령 응답 상태
enum VoiceCommandStatus {
  clarificationNeeded, // 추가 정보 필요 (중복 회원, 메모 선택 등)
  processing, // 처리 중
  completed, // 완료
  error, // 오류
}

/// 선택 옵션 정보
class SelectionOptions {
  final bool allowMultipleSelection; // 다중 선택 허용
  final bool allowSelectAll; // 전체 선택 옵션 제공
  final String? targetEntityType; // 선택해야 할 엔티티 타입
  final int? minSelection; // 최소 선택 개수
  final int? maxSelection; // 최대 선택 개수

  SelectionOptions({
    this.allowMultipleSelection = false,
    this.allowSelectAll = false,
    this.targetEntityType,
    this.minSelection,
    this.maxSelection,
  });

  factory SelectionOptions.fromJson(Map<String, dynamic> json) {
    return SelectionOptions(
      allowMultipleSelection: json['allowMultipleSelection'] as bool? ?? false,
      allowSelectAll: json['allowSelectAll'] as bool? ?? false,
      targetEntityType: json['targetEntityType'] as String?,
      minSelection: json['minSelection'] as int?,
      maxSelection: json['maxSelection'] as int?,
    );
  }
}

/// 음성 명령 응답 엔티티
class VoiceCommandResponse {
  final VoiceCommandStatus status;
  final String? conversationId;
  final String message;
  final Map<String, dynamic>? data;
  final SelectionOptions? selectionOptions;
  final ConversationContext? context;
  final String? errorCode;

  VoiceCommandResponse({
    required this.status,
    this.conversationId,
    required this.message,
    this.data,
    this.selectionOptions,
    this.context,
    this.errorCode,
  });

  factory VoiceCommandResponse.fromJson(Map<String, dynamic> json) {
    return VoiceCommandResponse(
      status: _parseStatus(json['status'] as String?),
      conversationId: json['conversationId'] as String?,
      message: json['message'] as String? ?? '알 수 없는 응답입니다.',
      data: json['data'] as Map<String, dynamic>?,
      selectionOptions: json['selectionOptions'] != null
          ? SelectionOptions.fromJson(
              json['selectionOptions'] as Map<String, dynamic>)
          : null,
      context: json['context'] != null
          ? ConversationContext.fromJson(
              json['context'] as Map<String, dynamic>)
          : null,
      errorCode: json['errorCode'] as String?,
    );
  }

  static VoiceCommandStatus _parseStatus(String? statusStr) {
    switch (statusStr) {
      case 'clarification_needed':
        return VoiceCommandStatus.clarificationNeeded;
      case 'processing':
        return VoiceCommandStatus.processing;
      case 'completed':
        return VoiceCommandStatus.completed;
      case 'error':
        return VoiceCommandStatus.error;
      default:
        return VoiceCommandStatus.error;
    }
  }

  bool get isClarificationNeeded =>
      status == VoiceCommandStatus.clarificationNeeded;
  bool get isCompleted => status == VoiceCommandStatus.completed;
  bool get isError => status == VoiceCommandStatus.error;

  /// 회원 선택이 필요한지 확인
  bool get isMemberSelection =>
      isClarificationNeeded &&
      (selectionOptions?.targetEntityType == 'member' ||
          context?.currentStep?.targetEntityType == 'member');

  /// 메모 선택이 필요한지 확인
  bool get isMemoSelection =>
      isClarificationNeeded &&
      (selectionOptions?.targetEntityType == 'memo' ||
          context?.currentStep?.targetEntityType == 'memo');
}
