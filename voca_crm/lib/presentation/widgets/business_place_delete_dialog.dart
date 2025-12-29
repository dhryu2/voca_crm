import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/domain/entity/business_place.dart';
import 'package:voca_crm/domain/entity/business_place_deletion_preview.dart';

/// 사업장 삭제 3단계 확인 다이얼로그
///
/// HubSpot, Notion, GitHub 스타일의 삭제 확인 플로우
/// - Step 1: 의사 확인 (정말 삭제하시겠습니까?)
/// - Step 2: 영향 확인 (삭제될 데이터 미리보기)
/// - Step 3: 이름 입력 (Type-to-Confirm)
class BusinessPlaceDeleteDialog extends StatefulWidget {
  final BusinessPlace businessPlace;
  final VoidCallback onDeleted;

  const BusinessPlaceDeleteDialog({
    super.key,
    required this.businessPlace,
    required this.onDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required BusinessPlace businessPlace,
    required VoidCallback onDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BusinessPlaceDeleteDialog(
        businessPlace: businessPlace,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<BusinessPlaceDeleteDialog> createState() =>
      _BusinessPlaceDeleteDialogState();
}

class _BusinessPlaceDeleteDialogState extends State<BusinessPlaceDeleteDialog> {
  final _businessPlaceService = BusinessPlaceService();
  final _confirmController = TextEditingController();

  int _currentStep = 1;
  bool _isLoading = false;
  BusinessPlaceDeletionPreview? _preview;
  String? _error;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final preview = await _businessPlaceService.getDeletionPreview(
        widget.businessPlace.id,
      );
      setState(() {
        _preview = preview;
        _currentStep = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppMessageHandler.parseErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBusinessPlace() async {
    if (_confirmController.text != widget.businessPlace.name) {
      AppMessageHandler.showErrorSnackBar(context, '사업장 이름이 일치하지 않습니다');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _businessPlaceService.deleteBusinessPlacePermanently(
        businessPlaceId: widget.businessPlace.id,
        confirmName: _confirmController.text,
      );

      if (mounted) {
        // Navigator.pop() 완료 후 콜백 실행 (debugLocked 오류 방지)
        Navigator.pop(context);
        // 다음 프레임에서 콜백 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onDeleted();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(
          context,
          AppMessageHandler.parseErrorMessage(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(screenWidth * 0.06),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
            width: screenWidth * 0.1,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeColor.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Step indicator
          _buildStepIndicator(screenWidth),

          Divider(color: ThemeColor.border, height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth * 0.06),
              child: _buildStepContent(screenWidth, screenHeight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.06,
        vertical: screenWidth * 0.03,
      ),
      child: Row(
        children: [
          _buildStepDot(1, screenWidth),
          _buildStepLine(1, screenWidth),
          _buildStepDot(2, screenWidth),
          _buildStepLine(2, screenWidth),
          _buildStepDot(3, screenWidth),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, double screenWidth) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Container(
      width: screenWidth * 0.08,
      height: screenWidth * 0.08,
      decoration: BoxDecoration(
        color: isActive ? ThemeColor.error : ThemeColor.neutral100,
        shape: BoxShape.circle,
        border: isCurrent
            ? Border.all(color: ThemeColor.error, width: 2)
            : null,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: ThemeColor.error.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isActive && !isCurrent
            ? Icon(
                Icons.check,
                color: Colors.white,
                size: screenWidth * 0.045,
              )
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : ThemeColor.textTertiary,
                ),
              ),
      ),
    );
  }

  Widget _buildStepLine(int step, double screenWidth) {
    final isActive = _currentStep > step;

    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
        decoration: BoxDecoration(
          color: isActive ? ThemeColor.error : ThemeColor.neutral200,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildStepContent(double screenWidth, double screenHeight) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(screenWidth, screenHeight);
      case 2:
        return _buildStep2(screenWidth, screenHeight);
      case 3:
        return _buildStep3(screenWidth, screenHeight);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Step 1: 의사 확인
  Widget _buildStep1(double screenWidth, double screenHeight) {
    return Column(
      children: [
        // Warning icon
        Container(
          width: screenWidth * 0.2,
          height: screenWidth * 0.2,
          decoration: BoxDecoration(
            color: ThemeColor.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            size: screenWidth * 0.1,
            color: ThemeColor.error,
          ),
        ),
        SizedBox(height: screenHeight * 0.025),

        // Title
        Text(
          '사업장을 삭제하시겠습니까?',
          style: TextStyle(
            fontSize: screenWidth * 0.055,
            fontWeight: FontWeight.w700,
            color: ThemeColor.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenHeight * 0.015),

        // Business place name
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenWidth * 0.03,
          ),
          decoration: BoxDecoration(
            color: ThemeColor.neutral50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ThemeColor.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.store_rounded,
                color: ThemeColor.primary,
                size: screenWidth * 0.06,
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                widget.businessPlace.name,
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.03),

        // Warning message
        Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: ThemeColor.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ThemeColor.error.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: ThemeColor.error,
                    size: screenWidth * 0.05,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      '이 작업은 되돌릴 수 없습니다',
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.error,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                '사업장을 삭제하면 모든 회원 정보, 메모, 예약, 방문 기록이 영구적으로 삭제됩니다. 삭제된 데이터는 복구할 수 없습니다.',
                style: TextStyle(
                  fontSize: screenWidth * 0.033,
                  color: ThemeColor.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.04),

        // Buttons
        Row(
          children: [
            Expanded(
              child: _buildButton(
                label: '취소',
                onTap: () => Navigator.pop(context),
                isPrimary: false,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: _buildButton(
                label: '다음',
                onTap: _isLoading ? null : _loadPreview,
                isPrimary: true,
                isDestructive: true,
                isLoading: _isLoading,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
          ],
        ),

        if (_error != null) ...[
          SizedBox(height: screenHeight * 0.02),
          Text(
            _error!,
            style: TextStyle(
              color: ThemeColor.error,
              fontSize: screenWidth * 0.032,
            ),
          ),
        ],
      ],
    );
  }

  /// Step 2: 영향 확인 (삭제될 데이터 미리보기)
  Widget _buildStep2(double screenWidth, double screenHeight) {
    if (_preview == null) {
      return Center(child: CircularProgressIndicator(color: ThemeColor.error));
    }

    return Column(
      children: [
        // Title
        Text(
          '삭제될 데이터를 확인하세요',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.w700,
            color: ThemeColor.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenHeight * 0.01),
        Text(
          '아래 데이터가 영구적으로 삭제됩니다',
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            color: ThemeColor.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenHeight * 0.03),

        // Data preview cards
        Container(
          decoration: BoxDecoration(
            color: ThemeColor.neutral50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThemeColor.border),
          ),
          child: Column(
            children: [
              _buildDataRow(
                icon: Icons.people_outline_rounded,
                label: '회원',
                count: _preview!.memberCount,
                color: ThemeColor.primary,
                screenWidth: screenWidth,
              ),
              _buildDivider(),
              _buildDataRow(
                icon: Icons.note_outlined,
                label: '메모',
                count: _preview!.memoCount,
                color: ThemeColor.info,
                screenWidth: screenWidth,
              ),
              _buildDivider(),
              _buildDataRow(
                icon: Icons.calendar_today_outlined,
                label: '예약',
                count: _preview!.reservationCount,
                color: ThemeColor.success,
                screenWidth: screenWidth,
              ),
              _buildDivider(),
              _buildDataRow(
                icon: Icons.how_to_reg_rounded,
                label: '방문 기록',
                count: _preview!.visitCount,
                color: ThemeColor.warning,
                screenWidth: screenWidth,
              ),
              _buildDivider(),
              _buildDataRow(
                icon: Icons.history_rounded,
                label: '활동 로그',
                count: _preview!.auditLogCount,
                color: ThemeColor.textSecondary,
                screenWidth: screenWidth,
              ),
            ],
          ),
        ),

        if (_preview!.hasStaff) ...[
          SizedBox(height: screenHeight * 0.02),
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: ThemeColor.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ThemeColor.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.group_outlined,
                  color: ThemeColor.warning,
                  size: screenWidth * 0.05,
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: Text(
                    '${_preview!.staffCount}명의 직원이 사업장에서 제외됩니다',
                    style: TextStyle(
                      fontSize: screenWidth * 0.033,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: screenHeight * 0.02),

        // Total count
        Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: ThemeColor.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '총 ',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: ThemeColor.textPrimary,
                ),
              ),
              Text(
                '${_preview!.totalDataCount}개',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.error,
                ),
              ),
              Text(
                '의 데이터가 삭제됩니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: ThemeColor.textPrimary,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: screenHeight * 0.04),

        // Buttons
        Row(
          children: [
            Expanded(
              child: _buildButton(
                label: '이전',
                onTap: () => setState(() => _currentStep = 1),
                isPrimary: false,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: _buildButton(
                label: '계속',
                onTap: () => setState(() => _currentStep = 3),
                isPrimary: true,
                isDestructive: true,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Step 3: 이름 입력 (Type-to-Confirm)
  Widget _buildStep3(double screenWidth, double screenHeight) {
    final isNameMatch = _confirmController.text == widget.businessPlace.name;

    return Column(
      children: [
        // Lock icon
        Container(
          width: screenWidth * 0.18,
          height: screenWidth * 0.18,
          decoration: BoxDecoration(
            color: ThemeColor.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_outline_rounded,
            size: screenWidth * 0.09,
            color: ThemeColor.error,
          ),
        ),
        SizedBox(height: screenHeight * 0.025),

        // Title
        Text(
          '최종 확인',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.w700,
            color: ThemeColor.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenHeight * 0.01),
        Text(
          '삭제를 확인하려면 사업장 이름을 입력하세요',
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            color: ThemeColor.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenHeight * 0.03),

        // Name to type
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenWidth * 0.03,
          ),
          decoration: BoxDecoration(
            color: ThemeColor.neutral100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '입력할 이름: ',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: ThemeColor.textSecondary,
                ),
              ),
              Text(
                widget.businessPlace.name,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.02),

        // Input field
        TextField(
          controller: _confirmController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '사업장 이름 입력',
            hintStyle: TextStyle(
              color: ThemeColor.textTertiary,
              fontSize: screenWidth * 0.04,
            ),
            filled: true,
            fillColor: ThemeColor.neutral50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ThemeColor.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isNameMatch ? ThemeColor.error : ThemeColor.border,
                width: isNameMatch ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: ThemeColor.error,
                width: 2,
              ),
            ),
            prefixIcon: Icon(
              isNameMatch ? Icons.check_circle : Icons.edit_outlined,
              color: isNameMatch ? ThemeColor.error : ThemeColor.textTertiary,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.018,
            ),
          ),
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontFamily: 'monospace',
          ),
        ),

        if (isNameMatch) ...[
          SizedBox(height: screenHeight * 0.015),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: ThemeColor.error,
                size: screenWidth * 0.04,
              ),
              SizedBox(width: screenWidth * 0.01),
              Text(
                '이름이 일치합니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.032,
                  color: ThemeColor.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],

        SizedBox(height: screenHeight * 0.04),

        // Buttons
        Row(
          children: [
            Expanded(
              child: _buildButton(
                label: '취소',
                onTap: () => Navigator.pop(context),
                isPrimary: false,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: _buildButton(
                label: '삭제',
                icon: Icons.delete_forever_rounded,
                onTap: isNameMatch && !_isLoading ? _deleteBusinessPlace : null,
                isPrimary: true,
                isDestructive: true,
                isLoading: _isLoading,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required double screenWidth,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.035,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.02),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: screenWidth * 0.05),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.038,
                color: ThemeColor.textPrimary,
              ),
            ),
          ),
          Text(
            '${count}개',
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w700,
              color: count > 0 ? ThemeColor.error : ThemeColor.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: ThemeColor.border,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildButton({
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    required bool isPrimary,
    bool isDestructive = false,
    bool isLoading = false,
    required double screenWidth,
    required double screenHeight,
  }) {
    final backgroundColor = isPrimary
        ? (isDestructive ? ThemeColor.error : ThemeColor.primary)
        : Colors.white;
    final foregroundColor = isPrimary ? Colors.white : ThemeColor.textSecondary;
    final borderColor = isPrimary
        ? Colors.transparent
        : ThemeColor.border;

    return SizedBox(
      height: screenHeight * 0.06,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: isPrimary
              ? (isDestructive
                  ? ThemeColor.error.withValues(alpha: 0.5)
                  : ThemeColor.primary.withValues(alpha: 0.5))
              : ThemeColor.neutral100,
          disabledForegroundColor: isPrimary
              ? Colors.white.withValues(alpha: 0.7)
              : ThemeColor.textTertiary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: screenWidth * 0.05,
                height: screenWidth * 0.05,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(foregroundColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: screenWidth * 0.045),
                    SizedBox(width: screenWidth * 0.015),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
