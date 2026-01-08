import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/domain/entity/notification.dart';

/// 알림 API 서비스
class NotificationService {
  final ApiClient _apiClient;

  NotificationService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

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

  /// FCM 토큰 등록
  Future<void> registerToken({
    required String userId,
    required String fcmToken,
    required String deviceType,
    String? deviceInfo,
    String? appVersion,
  }) async {
    final response = await _apiClient.post(
      '/api/notifications/token',
      body: {
        'userId': userId,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
        'deviceInfo': deviceInfo,
        'appVersion': appVersion,
      },
    );

    if (response.statusCode != 200) {
      throw NotificationServiceException(
        _extractErrorMessage(response.body, '알림 토큰 등록에 실패했습니다.'),
      );
    }
  }

  /// FCM 토큰 비활성화 (로그아웃 시)
  Future<void> deactivateToken(String fcmToken) async {
    final response = await _apiClient.request(
      'DELETE',
      '/api/notifications/token',
      body: {'fcmToken': fcmToken},
    );

    // 200, 204 모두 성공으로 처리
    if (response.statusCode != 200 && response.statusCode != 204) {
      // 로그아웃 흐름을 방해하지 않기 위해 예외를 throw하지 않음
      // 서버에서 토큰이 이미 삭제되었거나 유효하지 않은 경우도 성공으로 처리
      if (kDebugMode) {
        debugPrint('FCM 토큰 비활성화 실패: ${response.statusCode}');
      }
    }
  }

  /// 모든 토큰 비활성화 (모든 기기 로그아웃)
  Future<void> deactivateAllTokens(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.delete(
      '/api/notifications/token/all',
    );

    // 200, 204 모두 성공으로 처리
    if (response.statusCode != 200 && response.statusCode != 204) {
      // 로그아웃 흐름을 방해하지 않기 위해 예외를 throw하지 않음
      if (kDebugMode) {
        debugPrint('모든 FCM 토큰 비활성화 실패: ${response.statusCode}');
      }
    }
  }

  /// 알림 목록 조회
  Future<NotificationListResponse> getNotifications({
    required String userId,
    int page = 0,
    int size = 20,
  }) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/notifications',
      queryParams: {
        'page': page.toString(),
        'size': size.toString(),
      },
    );

    if (response.statusCode != 200) {
      throw NotificationServiceException(
        _extractErrorMessage(response.body, '알림 목록을 불러오는 중 오류가 발생했습니다.'),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return NotificationListResponse.fromJson(data);
  }

  /// 읽지 않은 알림 목록 조회
  Future<List<AppNotification>> getUnreadNotifications(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/notifications/unread',
    );

    if (response.statusCode != 200) {
      throw NotificationServiceException(
        _extractErrorMessage(response.body, '읽지 않은 알림을 불러오는 중 오류가 발생했습니다.'),
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((json) => AppNotification.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// 읽지 않은 알림 수 조회
  Future<int> getUnreadCount(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/notifications/unread-count',
    );

    if (response.statusCode != 200) {
      throw NotificationServiceException(
        _extractErrorMessage(response.body, '읽지 않은 알림 수를 불러오는 중 오류가 발생했습니다.'),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }

  /// 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    final response = await _apiClient.post('/api/notifications/$notificationId/read');

    if (response.statusCode != 200) {
      throw NotificationServiceException(
        _extractErrorMessage(response.body, '알림 읽음 처리에 실패했습니다.'),
      );
    }
  }

  /// 모든 알림 읽음 처리
  Future<void> markAllAsRead(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.post(
      '/api/notifications/read-all',
    );

    if (response.statusCode != 200) {
      throw NotificationServiceException(
        _extractErrorMessage(response.body, '모든 알림 읽음 처리에 실패했습니다.'),
      );
    }
  }

  /// 디바이스 타입 문자열 반환
  static String getDeviceType() {
    if (kIsWeb) {
      return 'WEB';
    } else if (Platform.isIOS) {
      return 'IOS';
    } else if (Platform.isAndroid) {
      return 'ANDROID';
    } else {
      return 'WEB';
    }
  }
}

/// 알림 목록 응답
class NotificationListResponse {
  final List<AppNotification> content;
  final int totalElements;
  final int totalPages;
  final int page;
  final int size;
  final bool first;
  final bool last;

  NotificationListResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.page,
    required this.size,
    required this.first,
    required this.last,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final contentList = json['content'] as List<dynamic>? ?? [];
    return NotificationListResponse(
      content: contentList.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList(),
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      page: json['number'] as int? ?? 0,
      size: json['size'] as int? ?? 20,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }
}

/// 알림 서비스 예외
class NotificationServiceException implements Exception {
  final String message;

  NotificationServiceException(this.message);

  @override
  String toString() => message;
}
