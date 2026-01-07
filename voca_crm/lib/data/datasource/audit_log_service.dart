import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/domain/entity/audit_log.dart';

class AuditLogService {
  final ApiClient _apiClient;

  AuditLogService({ApiClient? apiClient})
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

  /// 사업장별 감사 로그 목록 조회 (페이징)
  Future<AuditLogPage> getAuditLogs({
    required String businessPlaceId,
    int page = 0,
    int size = 20,
    String? entityType,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{
      'businessPlaceId': businessPlaceId,
      'page': page.toString(),
      'size': size.toString(),
    };

    if (entityType != null) {
      queryParams['entityType'] = entityType;
    }
    // 'action' 파라미터는 API에서 지원하지 않으므로 제외
    if (startDate != null) {
      queryParams['startDate'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['endDate'] = endDate.toIso8601String();
    }

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final response = await _apiClient.get('/api/audit-logs?$queryString');

    if (response.statusCode == 200) {
      return AuditLogPage.fromJson(jsonDecode(response.body));
    } else {
      throw AuditLogServiceException(
        _extractErrorMessage(response.body, '감사 로그를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 특정 엔티티의 변경 이력 조회
  Future<List<AuditLog>> getEntityHistory({
    required String entityType,
    required String entityId,
  }) async {
    final response = await _apiClient.get(
      '/api/audit-logs/entity/$entityType/$entityId',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> history = data['history'];
      return history
          .map((json) => AuditLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw AuditLogServiceException(
        _extractErrorMessage(response.body, '변경 이력을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 특정 사용자의 활동 로그 조회
  Future<AuditLogPage> getUserLogs({
    required String userId,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/audit-logs/user/$userId?page=$page&size=$size',
    );

    if (response.statusCode == 200) {
      return AuditLogPage.fromJson(jsonDecode(response.body));
    } else {
      throw AuditLogServiceException(
        _extractErrorMessage(response.body, '사용자 활동 로그를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 내 활동 로그 조회
  Future<AuditLogPage> getMyLogs({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/audit-logs/my?page=$page&size=$size',
    );

    if (response.statusCode == 200) {
      return AuditLogPage.fromJson(jsonDecode(response.body));
    } else {
      throw AuditLogServiceException(
        _extractErrorMessage(response.body, '내 활동 로그를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 액션별 통계 조회
  Future<ActionStatistics> getActionStatistics({
    required String businessPlaceId,
    int days = 30,
  }) async {
    final response = await _apiClient.get(
      '/api/audit-logs/statistics/actions?businessPlaceId=$businessPlaceId&days=$days',
    );

    if (response.statusCode == 200) {
      return ActionStatistics.fromJson(jsonDecode(response.body));
    } else {
      throw AuditLogServiceException(
        _extractErrorMessage(response.body, '액션 통계를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 사용자별 활동 통계 조회
  Future<UserActivityStatistics> getUserActivityStatistics({
    required String businessPlaceId,
    int days = 30,
  }) async {
    final response = await _apiClient.get(
      '/api/audit-logs/statistics/users?businessPlaceId=$businessPlaceId&days=$days',
    );

    if (response.statusCode == 200) {
      return UserActivityStatistics.fromJson(jsonDecode(response.body));
    } else {
      throw AuditLogServiceException(
        _extractErrorMessage(response.body, '활동 통계를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }
}

/// 감사 로그 서비스 예외
class AuditLogServiceException implements Exception {
  final String message;

  AuditLogServiceException(this.message);

  @override
  String toString() => message;
}
