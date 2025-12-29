import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/domain/entity/user.dart';

class UserService {
  final ApiClient _apiClient;

  UserService({ApiClient? apiClient})
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

  Future<User> getUser(String userId) async {
    final response = await _apiClient.get('/api/users/$userId');

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '사용자 정보를 불러오는데 실패했습니다.'));
    }
  }

  Future<User> updateUser({
    required String userId,
    required String username,
    required String phone,
    String? email,
  }) async {
    final response = await _apiClient.put(
      '/api/users/$userId',
      body: {
        'username': username,
        'phone': phone,
        if (email != null) 'email': email,
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '사용자 정보 수정에 실패했습니다.'));
    }
  }

  Future<User> updateDefaultBusinessPlace({
    required String userId,
    required String businessPlaceId,
  }) async {
    final response = await _apiClient.put(
      '/api/users/$userId/default-business-place',
      queryParams: {'businessPlaceId': businessPlaceId},
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '기본 사업장 설정에 실패했습니다.'));
    }
  }

  Future<void> deleteUser(String userId) async {
    final response = await _apiClient.delete('/api/users/$userId');

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body, '사용자 삭제에 실패했습니다.'));
    }
  }

  Future<User> updatePushNotificationSetting({
    required String userId,
    required bool enabled,
  }) async {
    final response = await _apiClient.put(
      '/api/users/$userId/push-notification',
      queryParams: {'enabled': enabled.toString()},
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '푸시 알림 설정 변경에 실패했습니다.'));
    }
  }

  /// FCM 토큰 업데이트
  Future<User> updateFcmToken({
    required String userId,
    required String fcmToken,
  }) async {
    final response = await _apiClient.put(
      '/api/users/$userId/fcm-token',
      queryParams: {'fcmToken': fcmToken},
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, 'FCM 토큰 업데이트에 실패했습니다.'));
    }
  }
}
