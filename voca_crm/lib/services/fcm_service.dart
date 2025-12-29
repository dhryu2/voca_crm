import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:voca_crm/data/datasource/notification_service.dart';

/// 백그라운드 메시지 핸들러 (top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message handler
}

/// Firebase Cloud Messaging 서비스
///
/// Push 알람 수신 및 FCM 토큰 관리를 담당합니다.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService();

  String? _currentUserId;
  String? _currentToken;
  bool _isInitialized = false;

  /// 스트림 구독 (리소스 정리용)
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  /// 알림 클릭 콜백 (화면 이동용)
  Function(RemoteMessage message)? onNotificationTap;

  /// 포그라운드 알림 수신 콜백
  Function(RemoteMessage message)? onForegroundMessage;

  /// FCM 초기화 및 토큰 저장
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      return;
    }

    try {
      _currentUserId = userId;

      // 백그라운드 메시지 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 알람 권한 요청
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // FCM 토큰 획득
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          _currentToken = token;

          // 서버에 토큰 저장
          await _registerTokenToServer(userId, token);
        }

        // 기존 구독 정리
        await _cancelSubscriptions();

        // 토큰 갱신 리스너 (에러 핸들러 포함)
        _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen(
          (newToken) {
            _currentToken = newToken;
            if (_currentUserId != null) {
              _registerTokenToServer(_currentUserId!, newToken);
            }
          },
          onError: (error) {
            // FCM token refresh error - silent fail
          },
        );

        // Foreground 메시지 처리 (에러 핸들러 포함)
        _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
          _handleForegroundMessage,
          onError: (error) {
            // FCM foreground message error - silent fail
          },
        );

        // Background에서 앱 열릴 때 메시지 처리 (에러 핸들러 포함)
        _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
          _handleMessageOpenedApp,
          onError: (error) {
            // FCM message opened error - silent fail
          },
        );

        // 앱이 종료된 상태에서 알림으로 열린 경우
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          // 약간의 딜레이 후 처리 (앱 초기화 완료 대기)
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleMessageOpenedApp(initialMessage);
          });
        }

        _isInitialized = true;
      }
    } catch (e) {
      // FCM initialization failed
    }
  }

  /// Foreground 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    // 콜백 호출 (UI에서 알림 표시용)
    onForegroundMessage?.call(message);
  }

  /// Background/Terminated에서 알림 탭으로 앱 열릴 때 처리
  void _handleMessageOpenedApp(RemoteMessage message) {
    // 콜백 호출 (화면 이동용)
    onNotificationTap?.call(message);
  }

  /// 서버에 FCM 토큰 등록
  Future<void> _registerTokenToServer(String userId, String fcmToken) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final appVersion = await _getAppVersion();

      await _notificationService.registerToken(
        userId: userId,
        fcmToken: fcmToken,
        deviceType: NotificationService.getDeviceType(),
        deviceInfo: deviceInfo,
        appVersion: appVersion,
      );
    } catch (e) {
      // Error registering FCM token
    }
  }

  /// 디바이스 정보 가져오기
  Future<String> _getDeviceInfo() async {
    try {
      if (kIsWeb) {
        return 'Web Browser';
      } else if (Platform.isAndroid) {
        return 'Android';
      } else if (Platform.isIOS) {
        return 'iOS';
      }
    } catch (_) {}
    return 'Unknown';
  }

  /// 앱 버전 가져오기
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  /// FCM 토큰 삭제 및 서버 비활성화 (로그아웃 시)
  Future<void> logout() async {
    try {
      // 서버에서 토큰 비활성화
      if (_currentToken != null) {
        await _notificationService.deactivateToken(_currentToken!);
      }

      // Firebase 토큰 삭제
      await _firebaseMessaging.deleteToken();

      _currentUserId = null;
      _currentToken = null;
      _isInitialized = false;
    } catch (e) {
      // FCM logout failed
    }
  }

  /// 모든 기기에서 로그아웃
  Future<void> logoutAllDevices(String userId) async {
    try {
      await _notificationService.deactivateAllTokens(userId);
      await _firebaseMessaging.deleteToken();

      _currentUserId = null;
      _currentToken = null;
      _isInitialized = false;
    } catch (e) {
      // FCM logout all devices failed
    }
  }

  /// 현재 FCM 토큰 반환
  String? get currentToken => _currentToken;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 스트림 구독 정리
  Future<void> _cancelSubscriptions() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;
  }

  /// 리소스 정리 (앱 종료 시 호출)
  Future<void> dispose() async {
    await _cancelSubscriptions();
  }
}
