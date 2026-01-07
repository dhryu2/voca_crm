import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/notice_service.dart';
import 'package:voca_crm/domain/entity/notice.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/presentation/widgets/character_count_text_field.dart';

/// 공지사항 작성/수정 화면 (시스템 관리자 전용)
///
/// 공지사항을 새로 작성하거나 기존 공지사항을 수정하는 화면
class NoticeEditorScreen extends StatefulWidget {
  final User user;
  final Notice? notice; // null이면 생성, 있으면 수정

  const NoticeEditorScreen({
    super.key,
    required this.user,
    this.notice,
  });

  @override
  State<NoticeEditorScreen> createState() => _NoticeEditorScreenState();
}

class _NoticeEditorScreenState extends State<NoticeEditorScreen> {
  final NoticeService _noticeService = NoticeService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late DateTime _startDate;
  late DateTime _endDate;
  late int _priority;
  late bool _isActive;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.notice != null) {
      // 수정 모드
      _titleController = TextEditingController(text: widget.notice!.title);
      _contentController = TextEditingController(text: widget.notice!.content);
      _startDate = widget.notice!.startDate;
      _endDate = widget.notice!.endDate;
      _priority = widget.notice!.priority;
      _isActive = widget.notice!.isActive;
    } else {
      // 생성 모드
      _titleController = TextEditingController();
      _contentController = TextEditingController();
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 30));
      _priority = 0;
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeColor.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = pickedDate;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate.isAfter(_endDate)) {
      AppMessageHandler.showErrorSnackBar(
        context,
        '시작일은 종료일보다 이전이어야 합니다',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notice = Notice(
        id: widget.notice?.id ?? '',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        priority: _priority,
        isActive: _isActive,
        createdByUserId: widget.user.providerId,
        createdAt: widget.notice?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.notice != null) {
        // 수정
        await _noticeService.updateNotice(widget.notice!.id, notice);
        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '공지사항이 수정되었습니다');
        }
      } else {
        // 생성
        await _noticeService.createNotice(notice);
        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '공지사항이 등록되었습니다');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'NoticeEditorScreen',
          action: widget.notice != null ? '공지사항 수정' : '공지사항 저장',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy년 MM월 dd일').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ThemeColor.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeColor.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(screenWidth * 0.05),
          children: [
            // Title
            CharacterCountTextField(
              controller: _titleController,
              labelText: '제목',
              hintText: '공지사항 제목을 입력하세요',
              maxLength: InputLimits.noticeTitle,
              maxLines: 1,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력해주세요';
                }
                return null;
              },
            ),

            SizedBox(height: screenHeight * 0.03),

            // Content
            CharacterCountTextField(
              controller: _contentController,
              labelText: '내용',
              hintText: '공지사항 내용을 입력하세요',
              maxLength: InputLimits.noticeContent,
              maxLines: 10,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '내용을 입력해주세요';
                }
                return null;
              },
            ),

            SizedBox(height: screenHeight * 0.03),

            // Date Range
            _buildSectionTitle('게시 기간', screenWidth),
            SizedBox(height: screenHeight * 0.01),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    context,
                    '시작일',
                    _formatDate(_startDate),
                    () => _selectDate(context, true),
                    screenWidth,
                    screenHeight,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Icon(Icons.arrow_forward, color: ThemeColor.textSecondary),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _buildDateButton(
                    context,
                    '종료일',
                    _formatDate(_endDate),
                    () => _selectDate(context, false),
                    screenWidth,
                    screenHeight,
                  ),
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.03),

            // Priority
            _buildSectionTitle('우선순위', screenWidth),
            SizedBox(height: screenHeight * 0.01),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenHeight * 0.01,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '우선순위: $_priority',
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                        Text(
                          '높을수록 먼저 표시됩니다',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _priority > 0
                            ? () => setState(() => _priority--)
                            : null,
                        color: ThemeColor.primary,
                      ),
                      Text(
                        _priority.toString(),
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: ThemeColor.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _priority < 99
                            ? () => setState(() => _priority++)
                            : null,
                        color: ThemeColor.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: screenHeight * 0.03),

            // Active Status
            _buildSectionTitle('활성화 상태', screenWidth),
            SizedBox(height: screenHeight * 0.01),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenHeight * 0.015,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '공지사항 활성화',
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                        Text(
                          _isActive ? '사용자에게 표시됩니다' : '사용자에게 표시되지 않습니다',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    activeColor: ThemeColor.primary,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
            ),

            SizedBox(height: screenHeight * 0.04),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: screenHeight * 0.07,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColor.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: screenWidth * 0.06,
                        height: screenWidth * 0.06,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: screenWidth * 0.005,
                        ),
                      )
                    : Text(
                        widget.notice != null ? '수정하기' : '등록하기',
                        style: TextStyle(
                          fontSize: screenWidth * 0.042,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, double screenWidth) {
    return Text(
      title,
      style: TextStyle(
        fontSize: screenWidth * 0.042,
        fontWeight: FontWeight.bold,
        color: ThemeColor.textPrimary,
      ),
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    String label,
    String date,
    VoidCallback onTap,
    double screenWidth,
    double screenHeight,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(screenWidth * 0.03),
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: ThemeColor.textSecondary,
              ),
            ),
            SizedBox(height: screenHeight * 0.008),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: screenWidth * 0.04,
                  color: ThemeColor.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
