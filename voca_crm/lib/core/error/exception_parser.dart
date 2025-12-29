import 'dart:convert';
import 'dart:io';
import 'dart:async' as async;

import 'package:http/http.dart' as http;

import 'app_exception.dart';

/// 다양한 에러를 [AppException]으로 변환하는 파서
class ExceptionParser {
  const ExceptionParser._();

  /// HTTP 응답을 적절한 [AppException]으로 변환
  static AppException fromHttpResponse(http.Response response) {
    final statusCode = response.statusCode;
    final body = _parseResponseBody(response.body);
    final message = _extractMessage(body) ?? _defaultMessageForStatus(statusCode);

    switch (statusCode) {
      case 400:
        return BadRequestException(
          message: message,
          validationErrors: _extractValidationErrors(body),
          responseBody: response.body,
        );

      case 401:
        return UnauthorizedException(
          message: message,
          responseBody: response.body,
        );

      case 403:
        return ForbiddenException(
          message: message,
          responseBody: response.body,
        );

      case 404:
        return NotFoundException(
          message: message,
          resourceType: body?['resourceType'] as String?,
          resourceId: body?['resourceId'] as String?,
          responseBody: response.body,
        );

      case 409:
        return ConflictException(
          message: message,
          responseBody: response.body,
        );

      case 422:
        return UnprocessableException(
          message: message,
          errors: _extractValidationErrors(body),
          responseBody: response.body,
        );

      case 429:
        final retryAfter = int.tryParse(
          response.headers['retry-after'] ?? '60',
        ) ?? 60;
        return RateLimitException(
          message: message,
          retryAfterSeconds: retryAfter,
          responseBody: response.body,
        );

      case 500:
        return ServerException(
          message: message,
          responseBody: response.body,
        );

      case 502:
        return BadGatewayException(
          message: message,
          responseBody: response.body,
        );

      case 503:
        return ServiceUnavailableException(
          message: message,
          responseBody: response.body,
        );

      case 504:
        return GatewayTimeoutException(
          message: message,
          responseBody: response.body,
        );

      default:
        if (statusCode >= 400 && statusCode < 500) {
          return BadRequestException(
            message: message,
            responseBody: response.body,
            code: 'HTTP_$statusCode',
          );
        }
        if (statusCode >= 500) {
          return ServerException(
            message: message,
            responseBody: response.body,
            code: 'HTTP_$statusCode',
          );
        }
        return UnknownException(
          message: 'HTTP $statusCode: $message',
          code: 'HTTP_$statusCode',
        );
    }
  }

  /// 일반 예외를 [AppException]으로 변환
  static AppException fromException(
    dynamic error, [
    StackTrace? stackTrace,
  ]) {
    // 이미 AppException인 경우
    if (error is AppException) {
      return error;
    }

    // SocketException - 네트워크 연결 문제
    if (error is SocketException) {
      final message = error.message.toLowerCase();

      if (message.contains('no address') ||
          message.contains('failed host lookup') ||
          message.contains('no route to host')) {
        return NoInternetException(
          originalError: error,
          stackTrace: stackTrace,
        );
      }

      if (message.contains('connection refused') ||
          message.contains('connection reset')) {
        return ConnectionException(
          originalError: error,
          stackTrace: stackTrace,
        );
      }

      return ConnectionException(
        message: '네트워크 연결 오류: ${error.message}',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // TimeoutException - 요청 타임아웃
    if (error is async.TimeoutException) {
      return TimeoutException(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // HandshakeException - SSL/TLS 오류
    if (error is HandshakeException) {
      return CertificateException(
        message: 'SSL 인증서 오류: ${error.message}',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // FormatException - JSON 파싱 등
    if (error is FormatException) {
      return BadRequestException(
        message: '데이터 형식 오류: ${error.message}',
        code: 'FORMAT_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // TypeError - 타입 오류
    if (error is TypeError) {
      return UnknownException(
        message: '데이터 처리 오류',
        code: 'TYPE_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // http.ClientException
    if (error is http.ClientException) {
      return ConnectionException(
        message: error.message,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // String 에러 메시지
    if (error is String) {
      return _parseStringError(error, stackTrace);
    }

    // 기타 예외
    return UnknownException(
      message: error?.toString() ?? '알 수 없는 오류',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// 문자열 에러를 파싱
  static AppException _parseStringError(String error, StackTrace? stackTrace) {
    final lower = error.toLowerCase();

    // 네트워크 관련
    if (lower.contains('socketexception') ||
        lower.contains('no address') ||
        lower.contains('failed host lookup')) {
      return NoInternetException(
        message: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('connection refused') ||
        lower.contains('connection reset')) {
      return ConnectionException(
        message: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('timeout')) {
      return const TimeoutException();
    }

    // HTTP 상태 코드 패턴
    final httpMatch = RegExp(r'(\d{3})').firstMatch(error);
    if (httpMatch != null) {
      final statusCode = int.parse(httpMatch.group(1)!);
      if (statusCode >= 400) {
        return _createExceptionForStatus(statusCode, error, stackTrace);
      }
    }

    return UnknownException(
      message: error,
      stackTrace: stackTrace,
    );
  }

  /// HTTP 상태 코드별 예외 생성
  static AppException _createExceptionForStatus(
    int statusCode,
    String message,
    StackTrace? stackTrace,
  ) {
    switch (statusCode) {
      case 401:
        return UnauthorizedException(message: message, stackTrace: stackTrace);
      case 403:
        return ForbiddenException(message: message, stackTrace: stackTrace);
      case 404:
        return NotFoundException(message: message, stackTrace: stackTrace);
      case 429:
        return RateLimitException(message: message, stackTrace: stackTrace);
      case 500:
        return ServerException(message: message, stackTrace: stackTrace);
      case 503:
        return ServiceUnavailableException(message: message, stackTrace: stackTrace);
      default:
        return UnknownException(
          message: message,
          code: 'HTTP_$statusCode',
          stackTrace: stackTrace,
        );
    }
  }

  /// 응답 본문 파싱
  static Map<String, dynamic>? _parseResponseBody(String body) {
    if (body.isEmpty) return null;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // JSON 파싱 실패 시 null 반환
    }

    return null;
  }

  /// 에러 메시지 추출
  static String? _extractMessage(Map<String, dynamic>? body) {
    if (body == null) return null;

    // 다양한 메시지 필드명 지원
    final messageKeys = ['message', 'error', 'errorMessage', 'msg', 'detail'];

    for (final key in messageKeys) {
      if (body[key] is String && (body[key] as String).isNotEmpty) {
        return body[key] as String;
      }
    }

    // 중첩된 error 객체
    if (body['error'] is Map) {
      final errorMap = body['error'] as Map<String, dynamic>;
      if (errorMap['message'] is String) {
        return errorMap['message'] as String;
      }
    }

    return null;
  }

  /// 유효성 검증 에러 추출
  static Map<String, dynamic>? _extractValidationErrors(
    Map<String, dynamic>? body,
  ) {
    if (body == null) return null;

    // errors 필드가 있는 경우
    if (body['errors'] is Map) {
      return body['errors'] as Map<String, dynamic>;
    }

    // fieldErrors 필드가 있는 경우
    if (body['fieldErrors'] is Map) {
      return body['fieldErrors'] as Map<String, dynamic>;
    }

    // validationErrors 필드가 있는 경우
    if (body['validationErrors'] is Map) {
      return body['validationErrors'] as Map<String, dynamic>;
    }

    return null;
  }

  /// HTTP 상태 코드별 기본 메시지
  static String _defaultMessageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return '잘못된 요청입니다.';
      case 401:
        return '인증이 필요합니다.';
      case 403:
        return '접근 권한이 없습니다.';
      case 404:
        return '요청한 정보를 찾을 수 없습니다.';
      case 409:
        return '데이터 충돌이 발생했습니다.';
      case 422:
        return '요청을 처리할 수 없습니다.';
      case 429:
        return '요청 횟수가 초과되었습니다.';
      case 500:
        return '서버에 오류가 발생했습니다.';
      case 502:
        return '서버 게이트웨이 오류입니다.';
      case 503:
        return '서비스를 일시적으로 사용할 수 없습니다.';
      case 504:
        return '서버 응답 시간이 초과되었습니다.';
      default:
        return '오류가 발생했습니다. (HTTP $statusCode)';
    }
  }
}

/// 에러 로깅을 위한 유틸리티
class ErrorLogger {
  const ErrorLogger._();

  /// 에러 로깅 (디버그 모드에서만)
  static void log(
    AppException error, {
    String? context,
    Map<String, dynamic>? extra,
  }) {
    // 프로덕션에서는 Firebase Crashlytics 등으로 전송
    // 현재는 디버그 출력만
    final buffer = StringBuffer();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('❌ ERROR: ${error.runtimeType}');
    if (context != null) {
      buffer.writeln('📍 Context: $context');
    }
    buffer.writeln('💬 Message: ${error.message}');
    if (error.code != null) {
      buffer.writeln('🏷️ Code: ${error.code}');
    }
    if (error is HttpException) {
      buffer.writeln('📊 Status: ${error.statusCode}');
    }
    if (extra != null && extra.isNotEmpty) {
      buffer.writeln('📎 Extra: $extra');
    }
    if (error.stackTrace != null) {
      buffer.writeln('📚 StackTrace:');
      buffer.writeln(error.stackTrace.toString().split('\n').take(5).join('\n'));
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// 사용자 친화적 메시지 추출
  static String getUserMessage(dynamic error) {
    if (error is AppException) {
      return error.userMessage;
    }

    final parsed = ExceptionParser.fromException(error);
    return parsed.userMessage;
  }
}
