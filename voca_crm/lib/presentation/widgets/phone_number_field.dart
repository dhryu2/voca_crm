import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:voca_crm/core/theme/theme_color.dart';

/// 전화번호 유형
enum PhoneNumberType {
  unknown,    // 아직 판별 불가
  mobile,     // 휴대폰 (010, 011, 016, 017, 018, 019)
  seoul,      // 서울 (02)
  area,       // 지역번호 (031~064)
  special,    // 특수번호 (1588, 1577, 080 등)
}

/// 전화번호 입력 필드
///
/// 특징:
/// - 자동 하이픈 포맷팅 (010-1234-5678, 02-1234-5678, 031-123-4567)
/// - 입력값에 따라 자동으로 전화번호 유형 감지
/// - 백스페이스 시 하이픈 건너뛰고 숫자 삭제
/// - 현재 감지된 번호 유형을 시각적으로 표시
class PhoneNumberField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final bool readOnly;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool isRequired;

  const PhoneNumberField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.readOnly = false,
    this.errorText,
    this.onChanged,
    this.validator,
    this.isRequired = false,
  });

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  PhoneNumberType _detectedType = PhoneNumberType.unknown;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
    // 초기값이 있으면 타입 감지
    if (widget.controller.text.isNotEmpty) {
      _updateDetectedType(widget.controller.text);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChanged() {
    _updateDetectedType(widget.controller.text);
    setState(() {});
  }

  /// 숫자만 추출
  String _extractDigits(String text) {
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// 전화번호 유형 감지
  void _updateDetectedType(String text) {
    final digits = _extractDigits(text);

    if (digits.isEmpty) {
      _detectedType = PhoneNumberType.unknown;
      return;
    }

    // 휴대폰 번호 (010, 011, 016, 017, 018, 019)
    if (digits.startsWith('010') || digits.startsWith('011') ||
        digits.startsWith('016') || digits.startsWith('017') ||
        digits.startsWith('018') || digits.startsWith('019')) {
      _detectedType = PhoneNumberType.mobile;
    }
    // 서울 (02)
    else if (digits.startsWith('02')) {
      _detectedType = PhoneNumberType.seoul;
    }
    // 특수번호 (1588, 1577, 1544, 1600, 1800, 080 등)
    else if (digits.startsWith('15') || digits.startsWith('16') ||
             digits.startsWith('18') || digits.startsWith('080')) {
      _detectedType = PhoneNumberType.special;
    }
    // 지역번호 (031~064)
    else if (digits.startsWith('03') || digits.startsWith('04') ||
             digits.startsWith('05') || digits.startsWith('06')) {
      _detectedType = PhoneNumberType.area;
    }
    // 아직 판별 불가 (0, 01 등)
    else if (digits.startsWith('0')) {
      _detectedType = PhoneNumberType.unknown;
    }
    // 1로 시작하는 경우 (특수번호 가능성)
    else if (digits.startsWith('1')) {
      _detectedType = PhoneNumberType.special;
    }
    else {
      _detectedType = PhoneNumberType.unknown;
    }
  }

  /// 전화번호 유형에 따른 라벨
  String _getTypeLabel() {
    switch (_detectedType) {
      case PhoneNumberType.mobile:
        return '휴대폰';
      case PhoneNumberType.seoul:
        return '서울';
      case PhoneNumberType.area:
        return '지역번호';
      case PhoneNumberType.special:
        return '대표번호';
      case PhoneNumberType.unknown:
        return '';
    }
  }

  /// 힌트 텍스트 결정
  String _getHintText() {
    if (widget.hintText != null) return widget.hintText!;

    switch (_detectedType) {
      case PhoneNumberType.mobile:
        return '010-0000-0000';
      case PhoneNumberType.seoul:
        return '02-0000-0000';
      case PhoneNumberType.area:
        return '031-000-0000';
      case PhoneNumberType.special:
        return '1588-0000';
      case PhoneNumberType.unknown:
        return '전화번호 입력';
    }
  }

  /// 내장 검증 로직
  String? _validatePhone(String? value) {
    if (widget.isRequired && (value == null || value.trim().isEmpty)) {
      return '전화번호를 입력해주세요';
    }

    if (value != null && value.isNotEmpty) {
      final digits = _extractDigits(value);

      // 특수번호는 8자리, 나머지는 9자리 이상
      final minLength = _detectedType == PhoneNumberType.special ? 8 : 9;
      if (digits.length < minLength) {
        return '전화번호를 정확히 입력해주세요';
      }

      // 유효한 시작 번호인지 확인
      if (!digits.startsWith('0') && !digits.startsWith('1')) {
        return '올바른 전화번호 형식이 아닙니다';
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final typeLabel = _getTypeLabel();
    final showTypeLabel = typeLabel.isNotEmpty && widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Row(
            children: [
              Text(
                widget.labelText!,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w600,
                  color: hasError ? ThemeColor.error : ThemeColor.textPrimary,
                ),
              ),
              if (showTypeLabel) ...[
                SizedBox(width: screenWidth * 0.02),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenWidth * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeColor.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(screenWidth * 0.01),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: screenWidth * 0.028,
                      fontWeight: FontWeight.w600,
                      color: ThemeColor.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: screenWidth * 0.02),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            _PhoneNumberInputFormatter(),
          ],
          validator: (value) {
            // 내장 검증 먼저
            final builtInError = _validatePhone(value);
            if (builtInError != null) return builtInError;
            // 커스텀 validator
            return widget.validator?.call(value);
          },
          onChanged: (value) {
            widget.onChanged?.call(_extractDigits(value));
          },
          style: TextStyle(
            fontSize: screenWidth * 0.042,
            fontWeight: FontWeight.w500,
            color: ThemeColor.textPrimary,
            letterSpacing: screenWidth * 0.003,
          ),
          decoration: InputDecoration(
            hintText: _getHintText(),
            hintStyle: TextStyle(
              fontSize: screenWidth * 0.038,
              color: ThemeColor.textTertiary,
              letterSpacing: screenWidth * 0.002,
            ),
            prefixIcon: Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              child: Icon(
                _getIconForType(),
                color: _isFocused
                    ? ThemeColor.primary
                    : hasError
                        ? ThemeColor.error
                        : ThemeColor.textSecondary,
                size: screenWidth * 0.055,
              ),
            ),
            errorText: widget.errorText,
            filled: true,
            fillColor: widget.readOnly || !widget.enabled
                ? ThemeColor.backgroundSecondary
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              borderSide: BorderSide(
                color: hasError ? ThemeColor.error : ThemeColor.border,
                width: screenWidth * 0.004,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              borderSide: BorderSide(
                color: hasError ? ThemeColor.error : ThemeColor.border,
                width: screenWidth * 0.004,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              borderSide: BorderSide(
                color: hasError ? ThemeColor.error : ThemeColor.primary,
                width: screenWidth * 0.005,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              borderSide: BorderSide(
                color: ThemeColor.error,
                width: screenWidth * 0.005,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              borderSide: BorderSide(
                color: ThemeColor.error,
                width: screenWidth * 0.004,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              borderSide: BorderSide(
                color: ThemeColor.border,
                width: screenWidth * 0.004,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenWidth * 0.04,
            ),
          ),
        ),
      ],
    );
  }

  /// 전화번호 유형에 따른 아이콘
  IconData _getIconForType() {
    switch (_detectedType) {
      case PhoneNumberType.mobile:
        return Icons.smartphone_outlined;
      case PhoneNumberType.seoul:
      case PhoneNumberType.area:
        return Icons.phone_outlined;
      case PhoneNumberType.special:
        return Icons.support_agent_outlined;
      case PhoneNumberType.unknown:
        return Icons.dialpad_outlined;
    }
  }
}

/// 전화번호 자동 포맷팅 InputFormatter
class _PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 삭제 동작 감지
    final isDeleting = newValue.text.length < oldValue.text.length;

    if (isDeleting) {
      return _handleDelete(oldValue, newValue);
    } else {
      return _handleInsert(oldValue, newValue);
    }
  }

  /// 삭제 처리: 하이픈 건너뛰고 숫자 삭제
  TextEditingValue _handleDelete(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final oldCursor = oldValue.selection.baseOffset;

    // 커서 앞의 문자가 무엇이었는지 확인
    if (oldCursor > 0 && oldCursor <= oldText.length) {
      final deletedChar = oldText[oldCursor - 1];

      // 삭제된 문자가 하이픈이었다면, 그 앞의 숫자도 삭제
      if (deletedChar == '-') {
        // 하이픈 앞에 숫자가 있다면 그것도 삭제
        String newText = oldText;
        int newCursor = oldCursor;

        // 하이픈 삭제
        newText = newText.substring(0, oldCursor - 1) + newText.substring(oldCursor);
        newCursor--;

        // 하이픈 앞의 숫자 삭제 (있다면)
        if (newCursor > 0) {
          newText = newText.substring(0, newCursor - 1) + newText.substring(newCursor);
          newCursor--;
        }

        // 재포맷팅
        final digits = _extractDigits(newText);
        final formatted = _formatPhoneNumber(digits);
        final formattedCursor = _calculateNewCursorAfterDelete(digits.length, formatted);

        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formattedCursor),
        );
      }
    }

    // 일반 삭제: 숫자 추출 후 재포맷팅
    final digits = _extractDigits(newValue.text);
    final formatted = _formatPhoneNumber(digits);

    // 커서 위치 계산
    final newCursor = _calculateCursorPosition(
      oldValue.text,
      formatted,
      newValue.selection.baseOffset,
      isDeleting: true,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// 입력 처리
  TextEditingValue _handleInsert(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 숫자만 추출
    final digits = _extractDigits(newValue.text);

    // 최대 자릿수 결정
    final maxLength = _getMaxLength(digits);
    final limitedDigits = digits.length > maxLength
        ? digits.substring(0, maxLength)
        : digits;

    // 포맷팅
    final formatted = _formatPhoneNumber(limitedDigits);

    // 커서 위치 계산
    final newCursor = _calculateCursorPosition(
      oldValue.text,
      formatted,
      newValue.selection.baseOffset,
      isDeleting: false,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  String _extractDigits(String text) {
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// 번호 유형에 따른 최대 자릿수
  int _getMaxLength(String digits) {
    if (digits.startsWith('02')) {
      return 10; // 서울: 02-XXXX-XXXX (10자리)
    } else if (digits.startsWith('15') || digits.startsWith('16') ||
               digits.startsWith('18')) {
      return 8; // 대표번호: 1588-XXXX (8자리)
    } else if (digits.startsWith('080')) {
      return 11; // 수신자부담: 080-XXXX-XXXX (11자리)
    } else {
      return 11; // 휴대폰/지역번호: 010-XXXX-XXXX, 031-XXX-XXXX (10~11자리)
    }
  }

  String _formatPhoneNumber(String digits) {
    if (digits.isEmpty) return '';

    // 서울 지역번호 (02)
    if (digits.startsWith('02')) {
      if (digits.length <= 2) return digits;
      if (digits.length <= 5) {
        return '${digits.substring(0, 2)}-${digits.substring(2)}';
      }
      if (digits.length <= 9) {
        return '${digits.substring(0, 2)}-${digits.substring(2, 5)}-${digits.substring(5)}';
      }
      // 02-XXXX-XXXX (10자리)
      return '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6, digits.length.clamp(6, 10))}';
    }

    // 대표번호 (1588, 1577, 1544, 1600, 1800 등)
    if (digits.startsWith('15') || digits.startsWith('16') || digits.startsWith('18')) {
      if (digits.length <= 4) return digits;
      return '${digits.substring(0, 4)}-${digits.substring(4, digits.length.clamp(4, 8))}';
    }

    // 수신자부담 (080)
    if (digits.startsWith('080')) {
      if (digits.length <= 3) return digits;
      if (digits.length <= 7) {
        return '${digits.substring(0, 3)}-${digits.substring(3)}';
      }
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, digits.length.clamp(7, 11))}';
    }

    // 휴대폰 및 기타 지역번호 (010, 031, 032, 033, 041, 042, 043, 044, 051, 052, 053, 054, 055, 061, 062, 063, 064)
    if (digits.length <= 3) return digits;
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    if (digits.length <= 10) {
      // 지역번호: 031-XXX-XXXX (10자리)
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    // 휴대폰: 010-XXXX-XXXX (11자리)
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, digits.length.clamp(7, 11))}';
  }

  int _calculateCursorPosition(
    String oldText,
    String newText,
    int rawCursor,
    {required bool isDeleting}
  ) {
    if (newText.isEmpty) return 0;

    // 새로 입력된 숫자의 개수 계산
    final newDigits = _extractDigits(newText);
    int cursor = 0;
    int digitsSeen = 0;

    // 입력된 숫자 개수만큼 커서 이동
    for (int i = 0; i < newText.length; i++) {
      if (newText[i] != '-') {
        digitsSeen++;
      }
      cursor = i + 1;

      if (digitsSeen >= newDigits.length) break;
    }

    return cursor.clamp(0, newText.length);
  }

  int _calculateNewCursorAfterDelete(int digitCount, String formatted) {
    int cursor = 0;
    int digitsSeen = 0;

    for (int i = 0; i < formatted.length; i++) {
      if (formatted[i] != '-') {
        digitsSeen++;
      }
      if (digitsSeen >= digitCount) {
        cursor = i + 1;
        break;
      }
    }

    return cursor.clamp(0, formatted.length);
  }
}
