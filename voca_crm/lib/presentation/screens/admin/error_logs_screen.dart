import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/error_log_service.dart';
import 'package:voca_crm/domain/entity/error_log.dart';
import 'package:voca_crm/domain/entity/user.dart';

/// 관리자용 오류 로그 조회 화면
class ErrorLogsScreen extends StatefulWidget {
  final User user;

  const ErrorLogsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  final _errorLogService = ErrorLogService.instance;

  List<ErrorLog> _logs = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;

  // 필터
  ErrorSeverity? _selectedSeverity;
  bool? _selectedResolved;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
    });

    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));

      final page = await _errorLogService.searchLogs(
        severity: _selectedSeverity,
        resolved: _selectedResolved,
        startDate: startDate,
        endDate: now,
        page: 0,
        size: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _logs = page.content;
        _hasMore = page.content.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppMessageHandler.showErrorSnackBar(
        context,
        '오류 로그를 불러오지 못했습니다: ${AppMessageHandler.parseErrorMessage(e)}',
      );
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));

      final page = await _errorLogService.searchLogs(
        severity: _selectedSeverity,
        resolved: _selectedResolved,
        startDate: startDate,
        endDate: now,
        page: _currentPage + 1,
        size: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _logs.addAll(page.content);
        _currentPage++;
        _hasMore = page.content.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ThemeColor.background,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(screenWidth, screenHeight),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 칩 표시
          if (_selectedSeverity != null || _selectedResolved != null)
            _buildFilterChips(screenWidth),

          // 로그 목록
          Expanded(
            child: _isLoading && _logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? _buildEmptyState(screenWidth, screenHeight)
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          itemCount: _logs.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _logs.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildLogCard(_logs[index], screenWidth, screenHeight);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.02,
      ),
      color: Colors.white,
      child: Wrap(
        spacing: 8,
        children: [
          if (_selectedSeverity != null)
            Chip(
              label: Text(_selectedSeverity!.displayName),
              backgroundColor: _getSeverityColor(_selectedSeverity!).withValues(alpha: 0.2),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() => _selectedSeverity = null);
                _loadLogs();
              },
            ),
          if (_selectedResolved != null)
            Chip(
              label: Text(_selectedResolved! ? '해결됨' : '미해결'),
              backgroundColor: (_selectedResolved! ? ThemeColor.success : ThemeColor.error)
                  .withValues(alpha: 0.2),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() => _selectedResolved = null);
                _loadLogs();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(double screenWidth, double screenHeight) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: screenWidth * 0.2,
            color: ThemeColor.success,
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            '오류 로그가 없습니다',
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w600,
              color: ThemeColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ErrorLog log, double screenWidth, double screenHeight) {
    return Card(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        side: BorderSide(color: ThemeColor.border),
      ),
      child: InkWell(
        onTap: () => _showLogDetail(log, screenWidth, screenHeight),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 심각도, 화면, 시간
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.02,
                      vertical: screenWidth * 0.01,
                    ),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(log.severity).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.severity.displayName,
                      style: TextStyle(
                        fontSize: screenWidth * 0.028,
                        fontWeight: FontWeight.w600,
                        color: _getSeverityColor(log.severity),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  if (log.screenName != null)
                    Expanded(
                      child: Text(
                        log.screenName!,
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          color: ThemeColor.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (log.resolved)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                        vertical: screenWidth * 0.01,
                      ),
                      decoration: BoxDecoration(
                        color: ThemeColor.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '해결됨',
                        style: TextStyle(
                          fontSize: screenWidth * 0.028,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.success,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),

              // 오류 메시지
              Text(
                log.errorMessage,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w500,
                  color: ThemeColor.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: screenHeight * 0.01),

              // 하단: 사용자, 시간
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (log.username != null)
                    Text(
                      log.username!,
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: ThemeColor.textTertiary,
                      ),
                    )
                  else
                    const SizedBox(),
                  Text(
                    _formatDate(log.createdAt),
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      color: ThemeColor.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(double screenWidth, double screenHeight) {
    ErrorSeverity? tempSeverity = _selectedSeverity;
    bool? tempResolved = _selectedResolved;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('필터'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('심각도', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: screenHeight * 0.01),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('전체'),
                        selected: tempSeverity == null,
                        onSelected: (_) => setDialogState(() => tempSeverity = null),
                      ),
                      ...ErrorSeverity.values.map((s) => ChoiceChip(
                            label: Text(s.displayName),
                            selected: tempSeverity == s,
                            selectedColor: _getSeverityColor(s).withValues(alpha: 0.3),
                            onSelected: (_) => setDialogState(() => tempSeverity = s),
                          )),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  const Text('해결 여부', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: screenHeight * 0.01),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('전체'),
                        selected: tempResolved == null,
                        onSelected: (_) => setDialogState(() => tempResolved = null),
                      ),
                      ChoiceChip(
                        label: const Text('미해결'),
                        selected: tempResolved == false,
                        onSelected: (_) => setDialogState(() => tempResolved = false),
                      ),
                      ChoiceChip(
                        label: const Text('해결됨'),
                        selected: tempResolved == true,
                        onSelected: (_) => setDialogState(() => tempResolved = true),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedSeverity = tempSeverity;
                      _selectedResolved = tempResolved;
                    });
                    Navigator.pop(dialogContext);
                    _loadLogs();
                  },
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogDetail(ErrorLog log, double screenWidth, double screenHeight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(screenWidth * 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Container(
                margin: EdgeInsets.only(top: screenHeight * 0.015),
                width: screenWidth * 0.1,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeColor.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 헤더
              Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.03,
                        vertical: screenWidth * 0.015,
                      ),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(log.severity).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        log.severity.displayName,
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w700,
                          color: _getSeverityColor(log.severity),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!log.resolved)
                      ElevatedButton.icon(
                        onPressed: () => _resolveLog(log, sheetContext),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('해결'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeColor.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 내용
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('오류 메시지', log.errorMessage, screenWidth),
                      if (log.screenName != null)
                        _buildDetailSection('화면', log.screenName!, screenWidth),
                      if (log.action != null)
                        _buildDetailSection('행동', log.action!, screenWidth),
                      if (log.username != null)
                        _buildDetailSection('사용자', log.username!, screenWidth),
                      if (log.requestUrl != null)
                        _buildDetailSection(
                          'API',
                          '${log.requestMethod ?? ''} ${log.requestUrl}',
                          screenWidth,
                        ),
                      if (log.httpStatusCode != null)
                        _buildDetailSection(
                          'HTTP 상태',
                          log.httpStatusCode.toString(),
                          screenWidth,
                        ),
                      if (log.deviceInfo != null)
                        _buildDetailSection('디바이스', log.deviceInfo!, screenWidth),
                      if (log.appVersion != null)
                        _buildDetailSection('앱 버전', log.appVersion!, screenWidth),
                      _buildDetailSection('발생 시간', _formatDateTime(log.createdAt), screenWidth),
                      if (log.resolved && log.resolvedAt != null)
                        _buildDetailSection('해결 시간', _formatDateTime(log.resolvedAt!), screenWidth),
                      if (log.resolutionNote != null)
                        _buildDetailSection('해결 메모', log.resolutionNote!, screenWidth),
                      if (log.stackTrace != null) ...[
                        SizedBox(height: screenHeight * 0.02),
                        Text(
                          '스택 트레이스',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.03),
                          decoration: BoxDecoration(
                            color: ThemeColor.neutral50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              log.stackTrace!,
                              style: TextStyle(
                                fontSize: screenWidth * 0.028,
                                fontFamily: 'monospace',
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String label, String value, double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenWidth * 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.032,
              fontWeight: FontWeight.w600,
              color: ThemeColor.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.038,
              color: ThemeColor.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveLog(ErrorLog log, BuildContext sheetContext) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('오류 해결'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: '해결 메모 (선택)',
            hintText: '어떻게 해결했는지 기록',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('해결 완료'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _errorLogService.resolveError(
        log.id,
        resolutionNote: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(sheetContext);
      await _loadLogs();
      AppMessageHandler.showSuccessSnackBar(context, '오류가 해결 처리되었습니다');
    } catch (e) {
      if (!mounted) return;
      AppMessageHandler.showErrorSnackBar(
        context,
        '해결 처리 실패: ${AppMessageHandler.parseErrorMessage(e)}',
      );
    }
  }

  Color _getSeverityColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return ThemeColor.info;
      case ErrorSeverity.warning:
        return ThemeColor.warning;
      case ErrorSeverity.error:
        return ThemeColor.error;
      case ErrorSeverity.critical:
        return Colors.purple;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';

    return '${date.month}/${date.day}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
