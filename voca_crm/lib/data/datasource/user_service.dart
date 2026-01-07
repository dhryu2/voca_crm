import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/core/error/exception_parser.dart';
import 'package:voca_crm/domain/entity/user.dart';

class UserService {
  final ApiClient _apiClient;

  UserService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  Future<User> getUser(String userId) async {
    final response = await _apiClient.get('/api/users/$userId');

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<void> deleteUser(String userId) async {
    final response = await _apiClient.delete('/api/users/$userId');

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
    }
  }
}
