import 'package:flutter/foundation.dart';
import 'package:voca_crm/data/datasource/error_log_service.dart';
import 'package:voca_crm/domain/entity/error_log.dart';

/// 앱 전역 오류 보고 유틸리티
///
/// 앱 어디서든 오류를 서버로 전송할 수 있습니다.
/// 사용 예:
/// ```dart
/// try {
///   await someOperation();
/// } catch (e, stackTrace) {
///   AppErrorReporter.report(
///     screenName: 'MemberScreen',
///     action: '회원 추가',
///     error: e,
///     stackTrace: stackTrace,
///   );
/// }
/// ```
class AppErrorReporter {
  static String? _currentUserId;
  static String? _currentUsername;
  static String? _currentBusinessPlaceId;
  static String? _currentScreenName;

  /// 현재 사용자 정보 설정 (로그인 시 호출)
  static void setUser({
    required String userId,
    required String username,
    String? businessPlaceId,
  }) {
    _currentUserId = userId;
    _currentUsername = username;
    _currentBusinessPlaceId = businessPlaceId;
  }

  /// 현재 사업장 설정 (사업장 변경 시 호출)
  static void setBusinessPlace(String? businessPlaceId) {
    _currentBusinessPlaceId = businessPlaceId;
  }

  /// 현재 화면 설정 (화면 이동 시 호출)
  static void setCurrentScreen(String screenName) {
    _currentScreenName = screenName;
  }

  /// 사용자 정보 초기화 (로그아웃 시 호출)
  static void clearUser() {
    _currentUserId = null;
    _currentUsername = null;
    _currentBusinessPlaceId = null;
  }

  /// 오류 보고
  static Future<void> report({
    String? screenName,
    String? action,
    required Object error,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
    String? requestUrl,
    String? requestMethod,
    String? requestBody,
    int? httpStatusCode,
  }) async {
    try {
      await ErrorLogService.instance.logError(
        userId: _currentUserId,
        username: _currentUsername,
        businessPlaceId: _currentBusinessPlaceId,
        screenName: screenName ?? _currentScreenName ?? 'Unknown',
        action: action,
        requestUrl: requestUrl,
        requestMethod: requestMethod,
        requestBody: requestBody,
        httpStatusCode: httpStatusCode,
        errorMessage: error.toString(),
        stackTrace: stackTrace?.toString(),
        severity: severity,
      );
    } catch (e) {
      // 오류 보고 실패 시 무시 (무한 루프 방지)
      if (kDebugMode) {
        debugPrint('Failed to report error: $e');
      }
    }
  }

  /// API 오류 보고 (ApiClient 등에서 사용)
  static Future<void> reportApiError({
    String? screenName,
    required String requestUrl,
    required String requestMethod,
    String? requestBody,
    required int httpStatusCode,
    required String errorMessage,
    StackTrace? stackTrace,
  }) async {
    final severity = httpStatusCode >= 500
        ? ErrorSeverity.critical
        : httpStatusCode >= 400
            ? ErrorSeverity.error
            : ErrorSeverity.warning;

    await report(
      screenName: screenName,
      action: 'API 호출',
      error: errorMessage,
      stackTrace: stackTrace,
      severity: severity,
      requestUrl: requestUrl,
      requestMethod: requestMethod,
      requestBody: requestBody,
      httpStatusCode: httpStatusCode,
    );
  }

  /// 예외 보고 (간단한 사용)
  static Future<void> reportException(
    Object exception, {
    StackTrace? stackTrace,
    String? screenName,
    String? action,
    ErrorSeverity severity = ErrorSeverity.error,
  }) async {
    await report(
      screenName: screenName,
      action: action,
      error: exception,
      stackTrace: stackTrace,
      severity: severity,
    );
  }

  /// 경고 보고
  static Future<void> reportWarning({
    String? screenName,
    String? action,
    required String message,
  }) async {
    await report(
      screenName: screenName,
      action: action,
      error: message,
      severity: ErrorSeverity.warning,
    );
  }

  /// 치명적 오류 보고
  static Future<void> reportCritical({
    String? screenName,
    String? action,
    required Object error,
    StackTrace? stackTrace,
  }) async {
    await report(
      screenName: screenName,
      action: action,
      error: error,
      stackTrace: stackTrace,
      severity: ErrorSeverity.critical,
    );
  }
}
