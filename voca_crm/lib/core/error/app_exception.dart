/// VocaCRM 앱 전용 예외 계층 구조
///
/// 모든 앱 예외는 [AppException]을 상속받습니다.
/// HTTP 상태 코드별, 네트워크 상태별로 세분화된 예외를 제공합니다.

/// 기본 앱 예외 클래스
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  /// 사용자에게 표시할 메시지
  String get userMessage => message;

  /// 재시도 가능 여부
  bool get isRetryable => false;

  /// 로그인 필요 여부
  bool get requiresLogin => false;

  @override
  String toString() => 'AppException: $message (code: $code)';
}

// ============================================================
// 네트워크 관련 예외
// ============================================================

/// 네트워크 예외 기본 클래스
abstract class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  bool get isRetryable => true;
}

/// 네트워크 연결 없음
class NoInternetException extends NetworkException {
  const NoInternetException({
    super.message = '인터넷에 연결되어 있지 않습니다.',
    super.code = 'NO_INTERNET',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '인터넷 연결을 확인해주세요.';
}

/// 서버 연결 실패
class ConnectionException extends NetworkException {
  const ConnectionException({
    super.message = '서버에 연결할 수 없습니다.',
    super.code = 'CONNECTION_FAILED',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
}

/// 요청 타임아웃
class TimeoutException extends NetworkException {
  final Duration? timeout;

  const TimeoutException({
    super.message = '요청 시간이 초과되었습니다.',
    super.code = 'TIMEOUT',
    this.timeout,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '요청 시간이 초과되었습니다. 다시 시도해주세요.';
}

/// SSL/TLS 인증서 오류
class CertificateException extends NetworkException {
  const CertificateException({
    super.message = '보안 연결에 실패했습니다.',
    super.code = 'CERTIFICATE_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  bool get isRetryable => false;

  @override
  String get userMessage => '보안 연결에 문제가 있습니다. 관리자에게 문의해주세요.';
}

// ============================================================
// HTTP 상태 코드 기반 예외
// ============================================================

/// HTTP 예외 기본 클래스
abstract class HttpException extends AppException {
  final int statusCode;
  final String? responseBody;

  const HttpException({
    required this.statusCode,
    required super.message,
    this.responseBody,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => 'HttpException: $statusCode - $message';
}

/// 400 Bad Request - 잘못된 요청
class BadRequestException extends HttpException {
  final Map<String, dynamic>? validationErrors;

  const BadRequestException({
    super.message = '잘못된 요청입니다.',
    this.validationErrors,
    super.responseBody,
    super.code = 'BAD_REQUEST',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 400);

  @override
  String get userMessage {
    if (validationErrors != null && validationErrors!.isNotEmpty) {
      final errors = validationErrors!.values.join('\n');
      return '입력 정보를 확인해주세요.\n$errors';
    }
    return '요청 정보를 확인해주세요.';
  }
}

/// 401 Unauthorized - 인증 필요
class UnauthorizedException extends HttpException {
  const UnauthorizedException({
    super.message = '인증이 필요합니다.',
    super.responseBody,
    super.code = 'UNAUTHORIZED',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 401);

  @override
  bool get requiresLogin => true;

  @override
  String get userMessage => '로그인이 필요합니다.';
}

/// 403 Forbidden - 권한 없음
class ForbiddenException extends HttpException {
  const ForbiddenException({
    super.message = '접근 권한이 없습니다.',
    super.responseBody,
    super.code = 'FORBIDDEN',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 403);

  @override
  String get userMessage => '이 작업을 수행할 권한이 없습니다.';
}

/// 404 Not Found - 리소스 없음
class NotFoundException extends HttpException {
  final String? resourceType;
  final String? resourceId;

  const NotFoundException({
    super.message = '요청한 정보를 찾을 수 없습니다.',
    this.resourceType,
    this.resourceId,
    super.responseBody,
    super.code = 'NOT_FOUND',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 404);

  @override
  String get userMessage {
    if (resourceType != null) {
      return '$resourceType을(를) 찾을 수 없습니다.';
    }
    return '요청한 정보를 찾을 수 없습니다.';
  }
}

/// 409 Conflict - 충돌
class ConflictException extends HttpException {
  const ConflictException({
    super.message = '데이터 충돌이 발생했습니다.',
    super.responseBody,
    super.code = 'CONFLICT',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 409);

  @override
  String get userMessage => '이미 존재하는 데이터입니다.';
}

/// 422 Unprocessable Entity - 처리 불가
class UnprocessableException extends HttpException {
  final Map<String, dynamic>? errors;

  const UnprocessableException({
    super.message = '요청을 처리할 수 없습니다.',
    this.errors,
    super.responseBody,
    super.code = 'UNPROCESSABLE',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 422);

  @override
  String get userMessage => '요청 데이터를 처리할 수 없습니다. 입력값을 확인해주세요.';
}

/// 429 Too Many Requests - 요청 횟수 초과
class RateLimitException extends HttpException {
  final int retryAfterSeconds;

  const RateLimitException({
    super.message = '요청 횟수가 초과되었습니다.',
    this.retryAfterSeconds = 60,
    super.responseBody,
    super.code = 'RATE_LIMIT',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 429);

  @override
  bool get isRetryable => true;

  @override
  String get userMessage => '요청이 너무 많습니다. $retryAfterSeconds초 후 다시 시도해주세요.';
}

/// 500 Internal Server Error - 서버 오류
class ServerException extends HttpException {
  const ServerException({
    super.message = '서버에 오류가 발생했습니다.',
    super.responseBody,
    super.code = 'SERVER_ERROR',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 500);

  @override
  bool get isRetryable => true;

  @override
  String get userMessage => '서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
}

/// 502 Bad Gateway
class BadGatewayException extends HttpException {
  const BadGatewayException({
    super.message = '서버 게이트웨이 오류입니다.',
    super.responseBody,
    super.code = 'BAD_GATEWAY',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 502);

  @override
  bool get isRetryable => true;

  @override
  String get userMessage => '서버 연결에 문제가 있습니다. 잠시 후 다시 시도해주세요.';
}

/// 503 Service Unavailable - 서비스 이용 불가
class ServiceUnavailableException extends HttpException {
  const ServiceUnavailableException({
    super.message = '서비스를 일시적으로 사용할 수 없습니다.',
    super.responseBody,
    super.code = 'SERVICE_UNAVAILABLE',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 503);

  @override
  bool get isRetryable => true;

  @override
  String get userMessage => '서비스가 일시적으로 중단되었습니다. 잠시 후 다시 시도해주세요.';
}

/// 504 Gateway Timeout
class GatewayTimeoutException extends HttpException {
  const GatewayTimeoutException({
    super.message = '서버 응답 시간이 초과되었습니다.',
    super.responseBody,
    super.code = 'GATEWAY_TIMEOUT',
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: 504);

  @override
  bool get isRetryable => true;

  @override
  String get userMessage => '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.';
}

// ============================================================
// 인증 관련 예외
// ============================================================

/// 인증 예외 기본 클래스
abstract class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  bool get requiresLogin => true;
}

/// 토큰 만료
class TokenExpiredException extends AuthException {
  const TokenExpiredException({
    super.message = '인증이 만료되었습니다.',
    super.code = 'TOKEN_EXPIRED',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '로그인이 만료되었습니다. 다시 로그인해주세요.';
}

/// 토큰 갱신 실패
class TokenRefreshException extends AuthException {
  const TokenRefreshException({
    super.message = '토큰 갱신에 실패했습니다.',
    super.code = 'TOKEN_REFRESH_FAILED',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '로그인 세션을 갱신할 수 없습니다. 다시 로그인해주세요.';
}

/// 잘못된 자격증명
class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException({
    super.message = '잘못된 로그인 정보입니다.',
    super.code = 'INVALID_CREDENTIALS',
    super.originalError,
    super.stackTrace,
  });

  @override
  bool get requiresLogin => false;

  @override
  String get userMessage => '이메일 또는 비밀번호가 올바르지 않습니다.';
}

/// 계정 잠김
class AccountLockedException extends AuthException {
  final DateTime? lockUntil;

  const AccountLockedException({
    super.message = '계정이 잠겼습니다.',
    this.lockUntil,
    super.code = 'ACCOUNT_LOCKED',
    super.originalError,
    super.stackTrace,
  });

  @override
  bool get requiresLogin => false;

  @override
  String get userMessage => '계정이 일시적으로 잠겼습니다. 잠시 후 다시 시도해주세요.';
}

// ============================================================
// 비즈니스 로직 예외
// ============================================================

/// 비즈니스 로직 예외 기본 클래스
abstract class BusinessException extends AppException {
  const BusinessException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// 유효성 검증 실패
class ValidationException extends BusinessException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException({
    super.message = '입력값이 올바르지 않습니다.',
    this.fieldErrors,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      final allErrors = fieldErrors!.values.expand((e) => e).toList();
      if (allErrors.length == 1) {
        return allErrors.first;
      }
      return '입력값을 확인해주세요:\n${allErrors.take(3).join('\n')}';
    }
    return message;
  }
}

/// 중복 데이터
class DuplicateException extends BusinessException {
  final String? fieldName;

  const DuplicateException({
    super.message = '이미 존재하는 데이터입니다.',
    this.fieldName,
    super.code = 'DUPLICATE',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage {
    if (fieldName != null) {
      return '이미 사용 중인 $fieldName입니다.';
    }
    return message;
  }
}

/// 작업 불가 상태
class InvalidStateException extends BusinessException {
  const InvalidStateException({
    super.message = '현재 상태에서는 이 작업을 수행할 수 없습니다.',
    super.code = 'INVALID_STATE',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => message;
}

// ============================================================
// 캐시/저장소 예외
// ============================================================

/// 캐시/저장소 예외 기본 클래스
abstract class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// 캐시 읽기 실패
class CacheReadException extends StorageException {
  const CacheReadException({
    super.message = '캐시 데이터를 읽을 수 없습니다.',
    super.code = 'CACHE_READ_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '데이터를 불러오는 중 오류가 발생했습니다.';
}

/// 캐시 쓰기 실패
class CacheWriteException extends StorageException {
  const CacheWriteException({
    super.message = '캐시 데이터를 저장할 수 없습니다.',
    super.code = 'CACHE_WRITE_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '데이터를 저장하는 중 오류가 발생했습니다.';
}

// ============================================================
// 알 수 없는 예외
// ============================================================

/// 알 수 없는 예외
class UnknownException extends AppException {
  const UnknownException({
    super.message = '알 수 없는 오류가 발생했습니다.',
    super.code = 'UNKNOWN',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '오류가 발생했습니다. 문제가 지속되면 관리자에게 문의해주세요.';
}

/// 취소된 작업
class CancelledException extends AppException {
  const CancelledException({
    super.message = '작업이 취소되었습니다.',
    super.code = 'CANCELLED',
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => '작업이 취소되었습니다.';
}
