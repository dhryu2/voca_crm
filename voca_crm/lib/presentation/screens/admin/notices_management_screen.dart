import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/notice_service.dart';
import 'package:voca_crm/domain/entity/notice.dart';
import 'package:voca_crm/domain/entity/user.dart';

import 'notice_editor_screen.dart';

/// 공지사항 관리 화면 (시스템 관리자 전용)
///
/// 공지사항 목록 조회, 생성, 수정, 삭제 기능 제공
class NoticesManagementScreen extends StatefulWidget {
  final User user;

  const NoticesManagementScreen({super.key, required this.user});

  @override
  State<NoticesManagementScreen> createState() =>
      _NoticesManagementScreenState();
}

class _NoticesManagementScreenState extends State<NoticesManagementScreen> {
  final NoticeService _noticeService = NoticeService();

  List<Notice> _notices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notices = await _noticeService.getAllNotices();
      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _error = '공지사항을 불러오는 중 오류가 발생했습니다';
          _isLoading = false;
        });
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'NoticesManagementScreen',
          action: '공지사항 목록 조회',
        );
      }
    }
  }

  Future<void> _deleteNotice(Notice notice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: Text('\'${notice.title}\' 공지사항을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: ThemeColor.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _noticeService.deleteNotice(notice.id);
      if (mounted) {
        AppMessageHandler.showSuccessSnackBar(context, '공지사항이 삭제되었습니다');
        _loadNotices();
      }
    } catch (e, stackTrace) {
      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'NoticesManagementScreen',
          action: '공지사항 삭제',
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy.MM.dd').format(date);
  }

  String _getStatusText(Notice notice) {
    final now = DateTime.now();
    if (!notice.isActive) return '비활성';
    if (now.isBefore(notice.startDate)) return '예정';
    if (now.isAfter(notice.endDate)) return '종료';
    return '활성';
  }

  Color _getStatusColor(Notice notice) {
    final now = DateTime.now();
    if (!notice.isActive) return ThemeColor.textTertiary;
    if (now.isBefore(notice.startDate)) return ThemeColor.warning;
    if (now.isAfter(notice.endDate)) return ThemeColor.error;
    return ThemeColor.success;
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(screenWidth, screenHeight)
              : _buildContent(screenWidth, screenHeight),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notices_management_fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoticeEditorScreen(user: widget.user),
            ),
          );
          if (result == true) {
            _loadNotices();
          }
        },
        backgroundColor: ThemeColor.primary,
        icon: const Icon(Icons.add),
        label: const Text('새 공지사항'),
      ),
    );
  }

  Widget _buildErrorView(double screenWidth, double screenHeight) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: screenWidth * 0.16,
              color: ThemeColor.textTertiary,
            ),
            SizedBox(height: screenHeight * 0.03),
            Text(
              _error ?? '오류가 발생했습니다',
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: ThemeColor.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.04),
            ElevatedButton.icon(
              onPressed: _loadNotices,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeColor.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(double screenWidth, double screenHeight) {
    if (_notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: screenWidth * 0.16,
              color: ThemeColor.textTertiary,
            ),
            SizedBox(height: screenHeight * 0.03),
            Text(
              '등록된 공지사항이 없습니다',
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: ThemeColor.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotices,
      color: ThemeColor.primary,
      child: ListView.builder(
        padding: EdgeInsets.all(screenWidth * 0.05),
        itemCount: _notices.length,
        itemBuilder: (context, index) {
          final notice = _notices[index];
          return _buildNoticeCard(notice, screenWidth, screenHeight);
        },
      ),
    );
  }

  Widget _buildNoticeCard(
      Notice notice, double screenWidth, double screenHeight) {
    final statusText = _getStatusText(notice);
    final statusColor = _getStatusColor(notice);

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: screenWidth * 0.025,
            offset: Offset(0, screenHeight * 0.003),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoticeEditorScreen(
                user: widget.user,
                notice: notice,
              ),
            ),
          );
          if (result == true) {
            _loadNotices();
          }
        },
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.045),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.025,
                      vertical: screenHeight * 0.006,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  // Priority
                  if (notice.priority > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.025,
                        vertical: screenHeight * 0.006,
                      ),
                      decoration: BoxDecoration(
                        color: ThemeColor.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.priority_high,
                            size: screenWidth * 0.03,
                            color: ThemeColor.primary,
                          ),
                          Text(
                            ' 우선순위 ${notice.priority}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.bold,
                              color: ThemeColor.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  // Delete button
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: ThemeColor.error),
                    iconSize: screenWidth * 0.05,
                    onPressed: () => _deleteNotice(notice),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.015),

              // Title
              Text(
                notice.title,
                style: TextStyle(
                  fontSize: screenWidth * 0.042,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: screenHeight * 0.01),

              // Content preview
              Text(
                notice.content,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: ThemeColor.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: screenHeight * 0.015),

              // Footer
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: screenWidth * 0.035,
                    color: ThemeColor.textTertiary,
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  Text(
                    '${_formatDate(notice.startDate)} ~ ${_formatDate(notice.endDate)}',
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      color: ThemeColor.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: ThemeColor.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
