import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/core/error/exception_parser.dart';
import 'package:voca_crm/domain/entity/error_log.dart';

/// 오류 로그 서비스
///
/// 클라이언트에서 발생한 오류를 서버로 전송하고 관리합니다.
class ErrorLogService {
  final ApiClient _apiClient;
  static ErrorLogService? _instance;

  // 캐싱된 디바이스 정보
  static String? _cachedDeviceInfo;
  static String? _cachedAppVersion;
  static String? _cachedOsVersion;
  static String? _cachedPlatform;

  ErrorLogService._({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// 싱글톤 인스턴스
  static ErrorLogService get instance {
    _instance ??= ErrorLogService._();
    return _instance!;
  }

  /// 디바이스 정보 초기화 (앱 시작 시 호출)
  static Future<void> initDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      _cachedAppVersion = packageInfo.version;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedDeviceInfo = '${androidInfo.manufacturer} ${androidInfo.model}';
        _cachedOsVersion = 'Android ${androidInfo.version.release}';
        _cachedPlatform = 'Android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedDeviceInfo = '${iosInfo.name} (${iosInfo.model})';
        _cachedOsVersion = 'iOS ${iosInfo.systemVersion}';
        _cachedPlatform = 'iOS';
      }
    } catch (e) {
      // 디바이스 정보 초기화 실패 시 무시
    }
  }

  // ==================== 오류 로그 전송 ====================

  /// 오류 로그 전송
  Future<void> logError({
    String? userId,
    String? username,
    String? businessPlaceId,
    required String screenName,
    String? action,
    String? requestUrl,
    String? requestMethod,
    String? requestBody,
    int? httpStatusCode,
    String? errorCode,
    required String errorMessage,
    String? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
  }) async {
    try {
      final body = {
        'userId': userId,
        'username': username,
        'businessPlaceId': businessPlaceId,
        'screenName': screenName,
        'action': action,
        'requestUrl': requestUrl,
        'requestMethod': requestMethod,
        'requestBody': _sanitizeRequestBody(requestBody),
        'httpStatusCode': httpStatusCode,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'stackTrace': stackTrace,
        'severity': severity.value,
        'deviceInfo': _cachedDeviceInfo,
        'appVersion': _cachedAppVersion,
        'osVersion': _cachedOsVersion,
        'platform': _cachedPlatform,
      };

      // 비동기로 전송 (실패해도 무시)
      _sendLogAsync(body);
    } catch (e) {
      // 로그 전송 중 오류 발생 시 무시
      print('Error in logError: $e');
    }
  }

  /// API 오류 로그 전송 (ApiClient에서 사용)
  Future<void> logApiError({
    String? userId,
    String? username,
    String? businessPlaceId,
    required String screenName,
    required String requestUrl,
    required String requestMethod,
    String? requestBody,
    required int httpStatusCode,
    required String errorMessage,
    String? stackTrace,
  }) async {
    final severity = httpStatusCode >= 500
        ? ErrorSeverity.critical
        : httpStatusCode >= 400
            ? ErrorSeverity.error
            : ErrorSeverity.warning;

    await logError(
      userId: userId,
      username: username,
      businessPlaceId: businessPlaceId,
      screenName: screenName,
      action: 'API 호출',
      requestUrl: requestUrl,
      requestMethod: requestMethod,
      requestBody: requestBody,
      httpStatusCode: httpStatusCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: severity,
    );
  }

  /// 예외 로그 전송
  Future<void> logException({
    String? userId,
    String? username,
    String? businessPlaceId,
    required String screenName,
    String? action,
    required Object exception,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
  }) async {
    await logError(
      userId: userId,
      username: username,
      businessPlaceId: businessPlaceId,
      screenName: screenName,
      action: action,
      errorMessage: exception.toString(),
      stackTrace: stackTrace?.toString(),
      severity: severity,
    );
  }

  // ==================== 관리자용 조회 API ====================

  /// 전체 오류 로그 조회
  Future<ErrorLogPage> getAllLogs({int page = 0, int size = 20}) async {
    final response = await _apiClient.get(
      '/api/error-logs',
      queryParams: {'page': page.toString(), 'size': size.toString()},
    );

    if (response.statusCode == 200) {
      return ErrorLogPage.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  /// 오류 로그 상세 조회
  Future<ErrorLog> getLogById(String id) async {
    final response = await _apiClient.get('/api/error-logs/$id');

    if (response.statusCode == 200) {
      return ErrorLog.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  /// 사업장별 오류 로그 조회
  Future<ErrorLogPage> getLogsByBusinessPlace(
    String businessPlaceId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/error-logs/business-place/$businessPlaceId',
      queryParams: {'page': page.toString(), 'size': size.toString()},
    );

    if (response.statusCode == 200) {
      return ErrorLogPage.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  /// 미해결 오류 로그 조회
  Future<ErrorLogPage> getUnresolvedLogs({int page = 0, int size = 20}) async {
    final response = await _apiClient.get(
      '/api/error-logs/unresolved',
      queryParams: {'page': page.toString(), 'size': size.toString()},
    );

    if (response.statusCode == 200) {
      return ErrorLogPage.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  /// 오류 로그 검색
  Future<ErrorLogPage> searchLogs({
    String? businessPlaceId,
    ErrorSeverity? severity,
    bool? resolved,
    required DateTime startDate,
    required DateTime endDate,
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'page': page.toString(),
      'size': size.toString(),
    };

    if (businessPlaceId != null) queryParams['businessPlaceId'] = businessPlaceId;
    if (severity != null) queryParams['severity'] = severity.value;
    if (resolved != null) queryParams['resolved'] = resolved.toString();

    final response = await _apiClient.get(
      '/api/error-logs/search',
      queryParams: queryParams,
    );

    if (response.statusCode == 200) {
      return ErrorLogPage.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  // ==================== 오류 해결 ====================

  /// 오류 해결 처리
  Future<ErrorLog> resolveError(String id, {String? resolutionNote}) async {
    final response = await _apiClient.patch(
      '/api/error-logs/$id/resolve',
      body: {'resolutionNote': resolutionNote},
    );

    if (response.statusCode == 200) {
      return ErrorLog.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  /// 오류 미해결로 되돌리기
  Future<ErrorLog> unresolveError(String id) async {
    final response = await _apiClient.patch('/api/error-logs/$id/unresolve');

    if (response.statusCode == 200) {
      return ErrorLog.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  // ==================== 통계 ====================

  /// 오류 통계 요약
  Future<ErrorSummary> getErrorSummary({int days = 7}) async {
    final response = await _apiClient.get(
      '/api/error-logs/summary',
      queryParams: {'days': days.toString()},
    );

    if (response.statusCode == 200) {
      return ErrorSummary.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  /// 미해결 오류 개수
  Future<int> getUnresolvedCount({String? businessPlaceId}) async {
    final queryParams = <String, String>{};
    if (businessPlaceId != null) queryParams['businessPlaceId'] = businessPlaceId;

    final response = await _apiClient.get(
      '/api/error-logs/unresolved-count',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['count'] as int;
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  // ==================== 헬퍼 메서드 ====================

  /// 비동기 로그 전송 (fire-and-forget)
  Future<void> _sendLogAsync(Map<String, dynamic> body) async {
    try {
      await _apiClient.post('/api/error-logs', body: body);
    } catch (e) {
      // 오류 로그 전송 실패 시 콘솔에만 출력
      print('Failed to send error log: $e');
    }
  }

  /// 요청 본문에서 민감 정보 제거
  String? _sanitizeRequestBody(String? requestBody) {
    if (requestBody == null) return null;
    return requestBody
        .replaceAll(RegExp(r'"password"\s*:\s*"[^"]*"'), '"password":"***"')
        .replaceAll(RegExp(r'"token"\s*:\s*"[^"]*"'), '"token":"***"')
        .replaceAll(RegExp(r'"accessToken"\s*:\s*"[^"]*"'), '"accessToken":"***"')
        .replaceAll(RegExp(r'"refreshToken"\s*:\s*"[^"]*"'), '"refreshToken":"***"');
  }
}
