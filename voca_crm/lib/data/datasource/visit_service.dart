import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/domain/entity/visit.dart';

class VisitService {
  final ApiClient _apiClient;

  VisitService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// API 응답에서 사용자 친화적 오류 메시지 추출
  String _extractErrorMessage(String responseBody, String fallbackMessage) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map<String, dynamic>) {
        if (data['fieldErrors'] is Map && (data['fieldErrors'] as Map).isNotEmpty) {
          final fieldErrors = data['fieldErrors'] as Map;
          return fieldErrors.values.first.toString();
        }
        if (data['message'] != null && data['message'].toString().isNotEmpty) {
          return data['message'].toString();
        }
      }
    } catch (_) {}
    return fallbackMessage;
  }

  /// 체크인 (방문 기록 생성)
  Future<Visit> checkIn({
    required String memberId,
    String? note,
  }) async {
    final response = await _apiClient.post(
      '/api/visits/checkin',
      body: {
        'memberId': memberId,
        if (note != null) 'note': note,
      },
    );

    if (response.statusCode == 200) {
      return Visit.fromJson(jsonDecode(response.body));
    } else {
      throw VisitServiceException(
        _extractErrorMessage(response.body, '체크인 처리 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 회원별 방문 기록 조회
  Future<List<Visit>> getVisitsByMemberId(String memberId) async {
    final response = await _apiClient.get('/api/visits/member/$memberId');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Visit.fromJson(json)).toList();
    } else {
      throw VisitServiceException(
        _extractErrorMessage(response.body, '방문 기록을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 오늘 방문 기록 조회 (사업장별)
  Future<List<Visit>> getTodayVisits(String businessPlaceId) async {
    final response = await _apiClient.get('/api/visits/today/$businessPlaceId');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Visit.fromJson(json)).toList();
    } else {
      throw VisitServiceException(
        _extractErrorMessage(response.body, '오늘 방문 기록을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 체크인 취소 (삭제)
  Future<void> cancelCheckIn({
    required String visitId,
    required String businessPlaceId,
  }) async {
    final response = await _apiClient.delete(
      '/api/visits/$visitId?businessPlaceId=$businessPlaceId',
    );

    if (response.statusCode != 204) {
      throw VisitServiceException(
        _extractErrorMessage(response.body, '체크인 취소 중 오류가 발생했습니다.'),
      );
    }
  }
}

/// 방문 서비스 예외
class VisitServiceException implements Exception {
  final String message;

  VisitServiceException(this.message);

  @override
  String toString() => message;
}
