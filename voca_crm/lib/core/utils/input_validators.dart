/// 입력값 검증 유틸리티 클래스
/// 이메일, 전화번호, 기타 형식 검증을 제공합니다.
class InputValidators {
  InputValidators._();

  // ============================================================
  // 이메일 검증
  // ============================================================

  /// 이메일 정규식 패턴
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// 이메일 형식이 유효한지 검사
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return true; // 선택 필드일 경우
    return _emailRegex.hasMatch(email.trim());
  }

  /// 이메일 검증 에러 메시지 반환 (유효하면 null)
  static String? validateEmail(String? email, {bool required = false}) {
    if (email == null || email.trim().isEmpty) {
      return required ? '이메일을 입력해주세요' : null;
    }
    if (!_emailRegex.hasMatch(email.trim())) {
      return '올바른 이메일 형식이 아닙니다 (예: example@email.com)';
    }
    return null;
  }

  // ============================================================
  // 전화번호 검증 (한국)
  // ============================================================

  /// 한국 휴대폰 번호 정규식 (01X-XXXX-XXXX 또는 01XXXXXXXXX)
  static final RegExp _mobilePhoneRegex = RegExp(
    r'^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$',
  );

  /// 한국 일반 전화번호 정규식 (02-XXX-XXXX, 0XX-XXX-XXXX 등)
  static final RegExp _landlineRegex = RegExp(
    r'^0[2-6][0-9]?-?[0-9]{3,4}-?[0-9]{4}$',
  );

  /// 전화번호 형식이 유효한지 검사 (휴대폰 + 일반전화)
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.isEmpty) return true; // 선택 필드일 경우
    final cleaned = phone.trim();
    return _mobilePhoneRegex.hasMatch(cleaned) || _landlineRegex.hasMatch(cleaned);
  }

  /// 휴대폰 번호만 검사
  static bool isValidMobilePhone(String? phone) {
    if (phone == null || phone.isEmpty) return true;
    return _mobilePhoneRegex.hasMatch(phone.trim());
  }

  /// 전화번호 검증 에러 메시지 반환 (유효하면 null)
  static String? validatePhone(String? phone, {bool required = false}) {
    if (phone == null || phone.trim().isEmpty) {
      return required ? '전화번호를 입력해주세요' : null;
    }
    if (!isValidPhone(phone)) {
      return '올바른 전화번호 형식이 아닙니다 (예: 010-1234-5678)';
    }
    return null;
  }

  // ============================================================
  // 이름 검증
  // ============================================================

  /// 이름 최소/최대 길이
  static const int nameMinLength = 2;
  static const int nameMaxLength = 50;

  /// 이름 형식이 유효한지 검사 (특수문자 제외)
  static bool isValidName(String? name) {
    if (name == null || name.isEmpty) return false;
    final cleaned = name.trim();
    // 최소 2자, 숫자/특수문자 제외 (한글, 영문, 공백만 허용)
    final regex = RegExp(r'^[가-힣a-zA-Z\s]{2,}$');
    return regex.hasMatch(cleaned) && cleaned.length <= nameMaxLength;
  }

  /// 이름 검증 에러 메시지 반환
  static String? validateName(String? name, {bool required = true}) {
    if (name == null || name.trim().isEmpty) {
      return required ? '이름을 입력해주세요' : null;
    }
    final cleaned = name.trim();
    if (cleaned.length < nameMinLength) {
      return '이름은 최소 ${nameMinLength}자 이상이어야 합니다';
    }
    if (cleaned.length > nameMaxLength) {
      return '이름은 최대 ${nameMaxLength}자까지 입력 가능합니다';
    }
    // 특수문자/숫자 포함 검사
    final regex = RegExp(r'^[가-힣a-zA-Z\s]+$');
    if (!regex.hasMatch(cleaned)) {
      return '이름에는 한글, 영문만 입력할 수 있습니다';
    }
    return null;
  }

  // ============================================================
  // 회원번호 검증
  // ============================================================

  /// 회원번호 형식이 유효한지 검사 (영문, 숫자, 하이픈만 허용)
  static bool isValidMemberNumber(String? memberNumber) {
    if (memberNumber == null || memberNumber.isEmpty) return false;
    final regex = RegExp(r'^[a-zA-Z0-9\-]+$');
    return regex.hasMatch(memberNumber.trim());
  }

  /// 회원번호 검증 에러 메시지 반환
  static String? validateMemberNumber(String? memberNumber, {bool required = true}) {
    if (memberNumber == null || memberNumber.trim().isEmpty) {
      return required ? '회원번호를 입력해주세요' : null;
    }
    final cleaned = memberNumber.trim();
    final regex = RegExp(r'^[a-zA-Z0-9\-]+$');
    if (!regex.hasMatch(cleaned)) {
      return '회원번호는 영문, 숫자, 하이픈(-)만 입력 가능합니다';
    }
    return null;
  }

  // ============================================================
  // 일반 텍스트 검증
  // ============================================================

  /// 필수 입력 검증
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName을(를) 입력해주세요';
    }
    return null;
  }

  /// 최소 길이 검증
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length < minLength) {
      return '$fieldName은(는) 최소 $minLength자 이상이어야 합니다';
    }
    return null;
  }

  /// 최대 길이 검증
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length > maxLength) {
      return '$fieldName은(는) 최대 $maxLength자까지 입력 가능합니다';
    }
    return null;
  }

  // ============================================================
  // 전화번호 포맷팅
  // ============================================================

  /// 전화번호를 하이픈 형식으로 포맷팅
  /// 예: 01012345678 → 010-1234-5678
  static String formatPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length == 11) {
      // 휴대폰: 010-1234-5678
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      if (digits.startsWith('02')) {
        // 서울: 02-1234-5678
        return '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6)}';
      } else {
        // 휴대폰 (구형): 010-123-4567
        return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
      }
    } else if (digits.length == 9) {
      // 서울 (구형): 02-123-4567
      return '${digits.substring(0, 2)}-${digits.substring(2, 5)}-${digits.substring(5)}';
    }

    return phone; // 포맷팅 불가 시 원본 반환
  }

  // ============================================================
  // 복합 검증 (여러 조건 동시 검사)
  // ============================================================

  /// 여러 검증을 순차적으로 실행하고 첫 번째 에러 반환
  static String? validateAll(List<String? Function()> validators) {
    for (final validator in validators) {
      final error = validator();
      if (error != null) return error;
    }
    return null;
  }
}

/// 검증 결과를 나타내는 클래스
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({required this.isValid, this.errorMessage});

  factory ValidationResult.valid() => const ValidationResult(isValid: true);

  factory ValidationResult.invalid(String message) =>
      ValidationResult(isValid: false, errorMessage: message);
}
