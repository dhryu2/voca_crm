import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/input_validators.dart';

/// 내장 검증 유형
enum ValidationType {
  none,       // 검증 없음
  email,      // 이메일 형식
  phone,      // 전화번호 형식
  name,       // 이름 형식
  memberNumber, // 회원번호 형식
}

/// Twitter/Material Design 스타일 글자수 카운터가 포함된 TextField 위젯
///
/// 특징:
/// - Progressive Disclosure: 70% 이상 입력 시에만 카운터 표시
/// - 색상 단계화: 회색(70~80%) → 노란색(80~99%) → 빨간색(100%)
/// - 원형 프로그레스 인디케이터 포함
/// - 내장 형식 검증 (이메일, 전화번호 등)
class CharacterCountTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final int maxLength;
  final TextInputType keyboardType;
  final bool readOnly;
  final bool enabled;
  final int maxLines;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffixIcon;

  /// Form validation 지원
  final String? Function(String?)? validator;

  /// 내장 검증 유형 (email, phone 등)
  final ValidationType validationType;

  /// 필수 입력 여부 (validationType 사용 시 적용)
  final bool isRequired;

  /// 카운터가 표시되기 시작하는 임계값 (기본 70%)
  final double showCounterThreshold;

  /// 경고 색상이 표시되기 시작하는 임계값 (기본 80%)
  final double warningThreshold;

  const CharacterCountTextField({
    super.key,
    required this.controller,
    required this.maxLength,
    this.labelText,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.errorText,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.validationType = ValidationType.none,
    this.isRequired = false,
    this.showCounterThreshold = 0.7,
    this.warningThreshold = 0.8,
  });

  @override
  State<CharacterCountTextField> createState() =>
      _CharacterCountTextFieldState();
}

class _CharacterCountTextFieldState extends State<CharacterCountTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  /// 내장 검증 로직
  String? _getBuiltInValidator(String? value) {
    switch (widget.validationType) {
      case ValidationType.email:
        return InputValidators.validateEmail(value, required: widget.isRequired);
      case ValidationType.phone:
        return InputValidators.validatePhone(value, required: widget.isRequired);
      case ValidationType.name:
        return InputValidators.validateName(value, required: widget.isRequired);
      case ValidationType.memberNumber:
        return InputValidators.validateMemberNumber(value, required: widget.isRequired);
      case ValidationType.none:
        if (widget.isRequired && (value == null || value.trim().isEmpty)) {
          return '${widget.labelText ?? '필드'}을(를) 입력해주세요';
        }
        return null;
    }
  }

  /// 커스텀 validator와 내장 validator를 결합
  String? _combinedValidator(String? value) {
    // 내장 검증 먼저 실행
    final builtInError = _getBuiltInValidator(value);
    if (builtInError != null) return builtInError;

    // 커스텀 validator가 있으면 실행
    if (widget.validator != null) {
      return widget.validator!(value);
    }

    return null;
  }

  /// 검증이 필요한지 확인
  bool get _needsValidation =>
      widget.validator != null ||
      widget.validationType != ValidationType.none ||
      widget.isRequired;

  @override
  Widget build(BuildContext context) {
    final hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;

    final inputDecoration = InputDecoration(
      hintText: widget.hintText,
      hintStyle: TextStyle(color: ThemeColor.textTertiary),
      prefixIcon: widget.prefixIcon != null
          ? Icon(
              widget.prefixIcon,
              color: hasError ? ThemeColor.error : ThemeColor.primary,
            )
          : null,
      suffixIcon: widget.suffixIcon,
      errorText: widget.errorText,
      filled: true,
      fillColor: widget.readOnly || !widget.enabled
          ? ThemeColor.backgroundSecondary
          : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? ThemeColor.error : ThemeColor.border,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? ThemeColor.error : ThemeColor.border,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? ThemeColor.error : ThemeColor.primary,
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ThemeColor.error,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ThemeColor.error,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ThemeColor.border,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );

    Widget buildCounter(
      BuildContext context, {
      required int currentLength,
      required bool isFocused,
      int? maxLength,
    }) {
      return _buildTwitterStyleCounter(
        currentLength: currentLength,
        maxLength: maxLength!,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hasError ? ThemeColor.error : ThemeColor.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        // 검증이 필요하면 TextFormField 사용, 아니면 TextField 사용
        _needsValidation
            ? TextFormField(
                controller: widget.controller,
                maxLength: widget.maxLength,
                keyboardType: widget.keyboardType,
                readOnly: widget.readOnly,
                enabled: widget.enabled,
                maxLines: widget.maxLines,
                buildCounter: buildCounter,
                onChanged: widget.onChanged,
                validator: _combinedValidator,
                decoration: inputDecoration,
              )
            : TextField(
                controller: widget.controller,
                maxLength: widget.maxLength,
                keyboardType: widget.keyboardType,
                readOnly: widget.readOnly,
                enabled: widget.enabled,
                maxLines: widget.maxLines,
                buildCounter: buildCounter,
                onChanged: widget.onChanged,
                decoration: inputDecoration,
              ),
      ],
    );
  }

  /// Twitter 스타일 글자수 카운터 위젯
  Widget _buildTwitterStyleCounter({
    required int currentLength,
    required int maxLength,
  }) {
    final double percentage = currentLength / maxLength;
    final int remaining = maxLength - currentLength;

    // 임계값 미만이면 카운터 숨김 (Progressive Disclosure)
    if (percentage < widget.showCounterThreshold) {
      return const SizedBox.shrink();
    }

    // 색상 결정
    Color counterColor;
    Color circleBackgroundColor;

    if (percentage >= 1.0) {
      // 100%: 빨간색
      counterColor = ThemeColor.error;
      circleBackgroundColor = ThemeColor.error.withValues(alpha: 0.15);
    } else if (percentage >= widget.warningThreshold) {
      // 80~99%: 주황색/노란색
      counterColor = ThemeColor.warning;
      circleBackgroundColor = ThemeColor.warning.withValues(alpha: 0.15);
    } else {
      // 70~80%: 회색
      counterColor = ThemeColor.textTertiary;
      circleBackgroundColor = ThemeColor.textTertiary.withValues(alpha: 0.1);
    }

    const double circleSize = 22;
    const double strokeWidth = 2.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 원형 프로그레스 인디케이터
        SizedBox(
          width: circleSize,
          height: circleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 배경 원
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: strokeWidth,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(circleBackgroundColor),
              ),
              // 프로그레스 원
              CircularProgressIndicator(
                value: percentage.clamp(0.0, 1.0),
                strokeWidth: strokeWidth,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(counterColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 남은 글자수 또는 현재/최대 표시
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 12,
            color: counterColor,
            fontWeight: percentage >= 0.9 ? FontWeight.w600 : FontWeight.normal,
          ),
          child: Text(
            percentage >= 0.9 ? '$remaining' : '$currentLength/$maxLength',
          ),
        ),
      ],
    );
  }
}

/// 글자수 제한 상수 (DB 스키마 기반)
/// 사용 예: CharacterCountTextField(maxLength: InputLimits.email, ...)
class InputLimits {
  InputLimits._();

  // Users 테이블
  static const int email = 100;           // VARCHAR(255) → 실용적 100자
  static const int username = 50;         // VARCHAR(100) → 이름 50자
  static const int phone = 20;            // VARCHAR(20)

  // Business Places 테이블
  static const int businessPlaceName = 100;  // VARCHAR(100)
  static const int businessPlaceAddress = 200; // VARCHAR(200)
  static const int businessPlacePhone = 20;  // VARCHAR(20)

  // Members 테이블
  static const int memberNumber = 50;     // VARCHAR(50)
  static const int memberName = 100;      // VARCHAR(100)
  static const int memberPhone = 20;      // VARCHAR(20)
  static const int memberEmail = 100;     // VARCHAR(100)
  static const int memberGrade = 20;      // VARCHAR(20)
  static const int memberType = 20;       // VARCHAR(20)
  static const int memberRemark = 1000;   // TEXT → 실용적 1000자

  // Memos 테이블
  static const int memoContent = 2000;    // TEXT → 실용적 2000자

  // Reservations 테이블
  static const int serviceType = 100;     // VARCHAR(100)
  static const int reservationNotes = 500; // TEXT → 실용적 500자

  // Notices 테이블
  static const int noticeTitle = 200;     // VARCHAR(200)
  static const int noticeContent = 5000;  // TEXT → 실용적 5000자

  // Visit 테이블
  static const int visitNote = 500;       // TEXT → 실용적 500자
}
