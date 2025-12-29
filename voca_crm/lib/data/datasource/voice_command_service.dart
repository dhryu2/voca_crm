import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/domain/entity/conversation_context.dart';
import 'package:voca_crm/domain/entity/voice_command_response.dart';

/// 음성 명령 서비스
/// API 서버와 통신하여 음성 명령을 처리
class VoiceCommandService {
  final ApiClient _apiClient;

  VoiceCommandService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// 음성 명령을 API 서버로 전송
  ///
  /// [text]: STT로 변환된 음성 텍스트
  /// [context]: 대화 컨텍스트 (이전 대화 상태)
  /// [userId]: 사용자 ID (JWT 토큰에서 자동 추출, 파라미터는 무시됨)
  ///
  /// Note: context 유무에 따라 다른 엔드포인트 호출
  /// - context가 없으면: /api/voice/command (AI 분석 필요)
  /// - context가 있으면: /api/voice/continue (대화 이어가기, AI 분석 없음)
  Future<VoiceCommandResponse> sendVoiceCommand({
    required String text,
    ConversationContext? context,
    String? userId, // JWT 토큰에서 추출되므로 무시됨
  }) async {
    final requestBody = <String, dynamic>{
      'text': text,
      if (context != null) 'context': context.toJson(),
      // userId는 JWT 토큰에서 자동 추출되므로 전송하지 않음
    };

    // context 유무에 따라 엔드포인트 분기
    final endpoint = context == null
        ? '/api/voice/command'   // 새 명령 (AI 분석 필요)
        : '/api/voice/continue'; // 대화 이어가기 (AI 분석 없음)

    final response = await _apiClient.post(
      endpoint,
      body: requestBody,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return VoiceCommandResponse.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw VoiceCommandException(
        errorData['message'] ?? '음성 명령 처리 중 오류가 발생했습니다.',
        errorData['errorCode'],
      );
    }
  }

  /// 일일 브리핑 조회
  ///
  /// [userId]: 사용자 ID (JWT 토큰에서 자동 추출, 파라미터는 무시됨)
  /// [businessPlaceId]: 사업장 ID (선택사항, 없으면 기본 사업장 사용)
  Future<VoiceCommandResponse> getDailyBriefing({
    String? userId, // JWT 토큰에서 추출되므로 무시됨
    String? businessPlaceId,
  }) async {
    final queryParams = <String, String>{};
    // userId는 JWT 토큰에서 자동 추출되므로 전송하지 않음
    if (businessPlaceId != null) queryParams['businessPlaceId'] = businessPlaceId;

    final response = await _apiClient.get(
      '/api/voice/daily-briefing',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return VoiceCommandResponse.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw VoiceCommandException(
        errorData['message'] ?? '일일 브리핑 조회 중 오류가 발생했습니다.',
        errorData['errorCode'],
      );
    }
  }
}

/// 음성 명령 예외
class VoiceCommandException implements Exception {
  final String message;
  final String? errorCode;

  VoiceCommandException(this.message, this.errorCode);

  @override
  String toString() => 'VoiceCommandException: $message (code: $errorCode)';
}
