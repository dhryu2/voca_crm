/// 서버 에러 코드를 한국어 사용자 메시지로 변환
class ErrorCodeMapper {
  ErrorCodeMapper._();

  /// 에러 코드 → 한국어 메시지 매핑
  static const Map<String, String> _errorMessages = {
    // 404 Not Found
    'RESOURCE_NOT_FOUND': '요청한 정보를 찾을 수 없습니다.',
    'MEMBER_NOT_FOUND': '회원을 찾을 수 없습니다.',
    'MEMO_NOT_FOUND': '메모를 찾을 수 없습니다.',
    'USER_NOT_FOUND': '사용자를 찾을 수 없습니다.',

    // 400 Bad Request
    'VALIDATION_ERROR': '입력값이 유효하지 않습니다.',
    'INVALID_REQUEST_FORMAT': '요청 데이터 형식이 올바르지 않습니다.',
    'MISSING_PARAMETER': '필수 파라미터가 누락되었습니다.',
    'TYPE_MISMATCH': '파라미터 형식이 올바르지 않습니다.',
    'INVALID_INPUT': '잘못된 입력값입니다.',
    'INVALID_ARGUMENT': '잘못된 요청입니다.',

    // 401 Unauthorized
    'UNAUTHORIZED': '로그인이 필요합니다.',
    'INVALID_CREDENTIALS': '이메일 또는 비밀번호가 올바르지 않습니다.',
    'INVALID_TOKEN': '인증 토큰이 유효하지 않거나 만료되었습니다.',

    // 403 Forbidden
    'FORBIDDEN': '접근 권한이 없습니다.',
    'ACCESS_DENIED': '접근 권한이 없습니다.',

    // 409 Conflict
    'DUPLICATE': '이미 존재하는 데이터입니다.',
    'DUPLICATE_USER': '이미 존재하는 사용자입니다.',
    'DUPLICATE_USERNAME': '이미 사용 중인 아이디입니다.',
    'DATA_INTEGRITY_VIOLATION': '데이터 처리 중 오류가 발생했습니다.',

    // 500 Internal Server Error
    'SERVER_ERROR': '서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
    'INTERNAL_ERROR': '서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
    'BUSINESS_ERROR': '요청을 처리할 수 없습니다.',
  };

  /// 에러 코드를 한국어 메시지로 변환
  ///
  /// [code] 서버에서 전달된 에러 코드
  /// [fallback] 코드가 매핑되지 않았을 때 사용할 메시지
  /// Returns 한국어 사용자 메시지
  static String getMessage(String? code, {String? fallback}) {
    if (code == null) {
      return fallback ?? '오류가 발생했습니다.';
    }

    return _errorMessages[code] ?? fallback ?? '오류가 발생했습니다.';
  }

  /// 에러 코드가 매핑되어 있는지 확인
  static bool hasMapping(String code) {
    return _errorMessages.containsKey(code);
  }
}
