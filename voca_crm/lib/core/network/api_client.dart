import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voca_crm/core/auth/token_manager.dart';
import 'package:voca_crm/core/constants/api_constants.dart';
import 'package:voca_crm/core/error/app_exception.dart';
import 'package:voca_crm/core/error/exception_parser.dart';
import 'package:voca_crm/core/error/result.dart';
import 'package:voca_crm/core/network/network_monitor.dart';
import 'package:voca_crm/core/network/retry_handler.dart';

/// @deprecated Use AppException hierarchy instead
/// 토큰 만료로 인한 인증 실패 예외 (하위 호환성 유지)
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);

  @override
  String toString() => message;
}

/// @deprecated Use AppException hierarchy instead
/// 토큰 갱신 실패 예외 (하위 호환성 유지)
class LegacyTokenRefreshException implements Exception {
  final String message;
  LegacyTokenRefreshException(this.message);

  @override
  String toString() => message;
}

/// @deprecated Use AppException hierarchy instead
/// Rate Limit 초과 예외 (하위 호환성 유지)
class LegacyRateLimitException implements Exception {
  final String message;
  final int retryAfterSeconds;

  LegacyRateLimitException(this.message, {this.retryAfterSeconds = 60});

  @override
  String toString() => message;
}

/// API 클라이언트
///
/// 모든 API 호출에 자동으로 Authorization 헤더를 추가하고,
/// 401 응답 시 자동으로 토큰을 갱신하여 재시도합니다.
///
/// 새로운 기능:
/// - [requestSafe] : Result 패턴으로 에러 반환
/// - [requestWithRetry] : 자동 재시도 기능
/// - 네트워크 상태 확인
/// - 향상된 예외 처리
class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  final String baseUrl;
  final http.Client _httpClient;
  final TokenManager _tokenManager;

  /// 기본 요청 타임아웃
  final Duration defaultTimeout;

  /// 인증 실패 콜백 (로그인 화면으로 이동 등)
  VoidCallback? onAuthenticationFailed;

  /// 네트워크 에러 콜백
  void Function(AppException error)? onNetworkError;

  ApiClient._({
    String? baseUrl,
    http.Client? httpClient,
    Duration? timeout,
    TokenManager? tokenManager,
  })  : baseUrl = baseUrl ?? ApiConstants.apiBaseUrl,
        _httpClient = httpClient ?? http.Client(),
        _tokenManager = tokenManager ?? TokenManager.instance,
        defaultTimeout = timeout ?? const Duration(seconds: 30) {
    // TokenManager 콜백 등록
    _tokenManager.onRefreshFailed = () {
      onAuthenticationFailed?.call();
    };
  }

  /// 싱글톤 인스턴스 리셋 (테스트용)
  static void resetInstance() {
    _instance = null;
  }

  /// 네트워크 연결 확인
  bool get isConnected => NetworkMonitor.instance.isConnected;

  /// 저장된 Access Token 가져오기
  /// @deprecated Use TokenManager.instance.getAccessToken() instead
  Future<String?> getAccessToken() => _tokenManager.getAccessToken();

  /// 저장된 Refresh Token 가져오기
  /// @deprecated Use TokenManager.instance.getRefreshToken() instead
  Future<String?> getRefreshToken() => _tokenManager.getRefreshToken();

  /// 토큰 저장
  /// @deprecated Use TokenManager.instance.saveTokens() instead
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) => _tokenManager.saveTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
  );

  /// 토큰 삭제 (로그아웃)
  /// @deprecated Use TokenManager.instance.clearTokens() instead
  Future<void> clearTokens() => _tokenManager.clearTokens();

  /// Authorization 헤더 생성
  Future<Map<String, String>> _getAuthHeaders() => _tokenManager.getAuthHeaders();

  /// 토큰 갱신
  Future<String?> _refreshAccessToken() => _tokenManager.refreshAccessToken();

  /// 인증이 필요 없는 요청 (로그인, 회원가입 등)
  Future<http.Response> requestWithoutAuth(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final headers = {'Content-Type': 'application/json'};

    switch (method.toUpperCase()) {
      case 'GET':
        return await _httpClient.get(uri, headers: headers);
      case 'POST':
        return await _httpClient.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case 'PUT':
        return await _httpClient.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case 'DELETE':
        return await _httpClient.delete(uri, headers: headers);
      case 'PATCH':
        return await _httpClient.patch(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  /// 인증이 필요한 요청 (자동 토큰 갱신 포함)
  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
    bool retryOnUnauthorized = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final headers = await _getAuthHeaders();
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _httpClient.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await _httpClient.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
        break;
      case 'PATCH':
        response = await _httpClient.patch(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    // 429 Too Many Requests 처리
    if (response.statusCode == 429) {
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '60') ?? 60;
      throw RateLimitException(
        message: '요청 횟수가 너무 많습니다. $retryAfter초 후에 다시 시도해주세요.',
        retryAfterSeconds: retryAfter,
      );
    }

    // 401 Unauthorized 처리
    if (response.statusCode == 401 && retryOnUnauthorized) {
      try {
        // 토큰 갱신 시도
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          // 새 토큰으로 재시도
          return request(
            method,
            path,
            body: body,
            queryParams: queryParams,
            additionalHeaders: additionalHeaders,
            retryOnUnauthorized: false, // 무한 루프 방지
          );
        }
      } on TokenRefreshException {
        // Refresh Token도 만료됨 - 로그아웃 처리 필요
        await clearTokens();
        onAuthenticationFailed?.call();
        throw AuthenticationException('인증이 만료되었습니다. 다시 로그인해주세요.');
      }
    }

    return response;
  }

  // ============ 편의 메서드 ============

  /// GET 요청
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
  }) =>
      request('GET', path, queryParams: queryParams, additionalHeaders: additionalHeaders);

  /// POST 요청
  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
  }) =>
      request('POST', path, body: body, queryParams: queryParams, additionalHeaders: additionalHeaders);

  /// PUT 요청
  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
  }) =>
      request('PUT', path, body: body, queryParams: queryParams, additionalHeaders: additionalHeaders);

  /// DELETE 요청
  Future<http.Response> delete(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
  }) =>
      request('DELETE', path, queryParams: queryParams, additionalHeaders: additionalHeaders);

  /// PATCH 요청
  Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
  }) =>
      request('PATCH', path, body: body, queryParams: queryParams, additionalHeaders: additionalHeaders);

  // ============ 새로운 안전한 요청 메서드 ============

  /// 안전한 요청 (Result 패턴)
  ///
  /// 예외를 던지지 않고 Result로 성공/실패를 반환합니다.
  ///
  /// 사용 예:
  /// ```dart
  /// final result = await apiClient.requestSafe<Member>(
  ///   'GET',
  ///   '/api/members/123',
  ///   parser: (json) => Member.fromJson(json),
  /// );
  ///
  /// result.when(
  ///   success: (member) => print(member.name),
  ///   failure: (error) => showError(error.userMessage),
  /// );
  /// ```
  Future<Result<T>> requestSafe<T>(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
    T Function(Map<String, dynamic> json)? parser,
    T Function(String body)? rawParser,
    Duration? timeout,
  }) async {
    try {
      // 네트워크 연결 확인
      if (!isConnected) {
        return const Failure(NoInternetException());
      }

      final response = await request(
        method,
        path,
        body: body,
        queryParams: queryParams,
        additionalHeaders: additionalHeaders,
      ).timeout(timeout ?? defaultTimeout);

      // 성공 응답 처리
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (parser != null) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return Success(parser(json));
        }
        if (rawParser != null) {
          return Success(rawParser(response.body));
        }
        // parser가 없으면 void로 처리
        return Success(null as T);
      }

      // 에러 응답 처리
      final error = ExceptionParser.fromHttpResponse(response);
      return Failure(error);
    } on SocketException catch (e, stackTrace) {
      final error = ExceptionParser.fromException(e, stackTrace);
      onNetworkError?.call(error);
      return Failure(error);
    } on TimeoutException catch (e, stackTrace) {
      return Failure(ExceptionParser.fromException(e, stackTrace));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, stackTrace) {
      final error = ExceptionParser.fromException(e, stackTrace);
      ErrorLogger.log(error, context: '$method $path');
      return Failure(error);
    }
  }

  /// 재시도를 포함한 안전한 요청
  ///
  /// 실패 시 자동으로 재시도합니다.
  Future<Result<T>> requestWithRetry<T>(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
    T Function(Map<String, dynamic> json)? parser,
    T Function(String body)? rawParser,
    RetryConfig retryConfig = RetryConfig.standard,
    void Function(RetryState state)? onRetry,
  }) async {
    try {
      final result = await RetryHandler.execute<T>(
        () async {
          final response = await request(
            method,
            path,
            body: body,
            queryParams: queryParams,
            additionalHeaders: additionalHeaders,
          ).timeout(defaultTimeout);

          if (response.statusCode >= 200 && response.statusCode < 300) {
            if (parser != null) {
              final json = jsonDecode(response.body) as Map<String, dynamic>;
              return parser(json);
            }
            if (rawParser != null) {
              return rawParser(response.body);
            }
            return null as T;
          }

          // 에러 응답을 AppException으로 변환하여 throw
          throw ExceptionParser.fromHttpResponse(response);
        },
        config: retryConfig,
        onRetry: onRetry,
      );

      return Success(result);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, stackTrace) {
      return Failure(ExceptionParser.fromException(e, stackTrace));
    }
  }

  /// 네트워크 연결 후 요청
  ///
  /// 네트워크가 연결될 때까지 대기한 후 요청을 실행합니다.
  Future<Result<T>> requestWhenOnline<T>(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? additionalHeaders,
    T Function(Map<String, dynamic> json)? parser,
    Duration networkTimeout = const Duration(seconds: 30),
  }) async {
    // 네트워크 연결 대기
    if (!isConnected) {
      final connected = await NetworkMonitor.instance.waitForConnection(
        timeout: networkTimeout,
      );

      if (!connected) {
        return const Failure(NoInternetException());
      }
    }

    return requestSafe<T>(
      method,
      path,
      body: body,
      queryParams: queryParams,
      additionalHeaders: additionalHeaders,
      parser: parser,
    );
  }

  // ============ 안전한 편의 메서드 ============

  /// 안전한 GET 요청
  Future<Result<T>> getSafe<T>(
    String path, {
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic> json)? parser,
  }) =>
      requestSafe('GET', path, queryParams: queryParams, parser: parser);

  /// 안전한 POST 요청
  Future<Result<T>> postSafe<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic> json)? parser,
  }) =>
      requestSafe('POST', path, body: body, queryParams: queryParams, parser: parser);

  /// 안전한 PUT 요청
  Future<Result<T>> putSafe<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic> json)? parser,
  }) =>
      requestSafe('PUT', path, body: body, queryParams: queryParams, parser: parser);

  /// 안전한 DELETE 요청
  Future<Result<T>> deleteSafe<T>(
    String path, {
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic> json)? parser,
  }) =>
      requestSafe('DELETE', path, queryParams: queryParams, parser: parser);

  /// 응답 검증 및 파싱 유틸리티
  ///
  /// HTTP 응답을 검증하고 성공 시 파싱된 데이터를 반환합니다.
  Result<T> parseResponse<T>(
    http.Response response, {
    T Function(Map<String, dynamic> json)? parser,
    T Function(String body)? rawParser,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        if (parser != null) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return Success(parser(json));
        }
        if (rawParser != null) {
          return Success(rawParser(response.body));
        }
        return Success(null as T);
      } catch (e, stackTrace) {
        return Failure(ExceptionParser.fromException(e, stackTrace));
      }
    }

    return Failure(ExceptionParser.fromHttpResponse(response));
  }

  /// 응답 검증 (데이터 없이 성공/실패만 확인)
  Result<void> validateResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return const Success(null);
    }
    return Failure(ExceptionParser.fromHttpResponse(response));
  }
}
