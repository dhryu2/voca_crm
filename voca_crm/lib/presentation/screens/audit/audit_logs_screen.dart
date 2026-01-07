import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voca_crm/core/notification/business_place_change_notifier.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/audit_log_service.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/data/repository/audit_log_repository_impl.dart';
import 'package:voca_crm/domain/entity/audit_log.dart';
import 'package:voca_crm/domain/entity/business_place_with_role.dart';
import 'package:voca_crm/domain/entity/user.dart';

class AuditLogsScreen extends StatefulWidget {
  final User user;

  const AuditLogsScreen({super.key, required this.user});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen>
    with SingleTickerProviderStateMixin {
  final _auditLogRepository = AuditLogRepositoryImpl(AuditLogService());
  final _businessPlaceService = BusinessPlaceService();

  late TabController _tabController;

  // 로그 목록 상태
  List<AuditLog> _logs = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _hasMore = true;
  int _totalElements = 0;

  // 통계 상태
  ActionStatistics? _actionStats;
  UserActivityStatistics? _userStats;
  bool _isStatsLoading = true;

  // 사업장 상태
  List<BusinessPlaceWithRole> _businessPlaces = [];
  String? _selectedBusinessPlaceId;
  StreamSubscription<BusinessPlaceChangeEvent>? _businessPlaceChangeSubscription;

  // 필터 상태
  String? _selectedEntityType;
  AuditAction? _selectedAction;
  final List<String> _entityTypes = [
    'MEMBER',
    'MEMO',
    'RESERVATION',
    'VISIT',
    'BUSINESS_PLACE',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedBusinessPlaceId = widget.user.defaultBusinessPlaceId;
    _initializeData();

    // 사업장 변경 이벤트 구독
    _businessPlaceChangeSubscription = BusinessPlaceChangeNotifier().stream
        .listen((event) {
      _loadBusinessPlaces();
    });
  }

  Future<void> _initializeData() async {
    await _loadBusinessPlaces();
    // defaultBusinessPlaceId가 없으면 첫 번째 사업장 사용
    if (_selectedBusinessPlaceId == null && _businessPlaces.isNotEmpty) {
      setState(() {
        _selectedBusinessPlaceId = _businessPlaces.first.businessPlace.id;
      });
    }
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _businessPlaceChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBusinessPlaces() async {
    try {
      final businessPlaces = await _businessPlaceService.getMyBusinessPlaces(
        widget.user.id,
      );
      setState(() {
        _businessPlaces = businessPlaces;
      });
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadLogs(refresh: true),
      _loadStatistics(),
    ]);
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (_selectedBusinessPlaceId == null || _selectedBusinessPlaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '사업장을 선택해주세요';
      });
      return;
    }

    if (refresh) {
      setState(() {
        _currentPage = 0;
        _logs = [];
        _hasMore = true;
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final page = await _auditLogRepository.getAuditLogs(
        businessPlaceId: _selectedBusinessPlaceId!,
        page: _currentPage,
        size: 20,
        entityType: _selectedEntityType,
        action: _selectedAction?.name,
      );

      setState(() {
        if (refresh) {
          _logs = page.data;
        } else {
          _logs.addAll(page.data);
        }
        _totalPages = page.totalPages;
        _totalElements = page.totalElements;
        _hasMore = _currentPage < _totalPages - 1;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
        _error = AppMessageHandler.parseErrorMessage(e);
      });
      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'AuditLogsScreen',
          action: '활동 로그 조회',
          userId: widget.user.id,
        );
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    if (!_hasMore || _isLoading) return;

    setState(() {
      _currentPage++;
    });

    await _loadLogs();
  }

  Future<void> _loadStatistics() async {
    if (_selectedBusinessPlaceId == null || _selectedBusinessPlaceId!.isEmpty) {
      setState(() {
        _isStatsLoading = false;
      });
      return;
    }

    setState(() {
      _isStatsLoading = true;
    });

    try {
      final results = await Future.wait([
        _auditLogRepository.getActionStatistics(
          businessPlaceId: _selectedBusinessPlaceId!,
          days: 30,
        ),
        _auditLogRepository.getUserActivityStatistics(
          businessPlaceId: _selectedBusinessPlaceId!,
          days: 30,
        ),
      ]);

      setState(() {
        _actionStats = results[0] as ActionStatistics;
        _userStats = results[1] as UserActivityStatistics;
        _isStatsLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _isStatsLoading = false;
      });
      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'AuditLogsScreen',
          action: '활동 통계 조회',
          userId: widget.user.id,
        );
      }
    }
  }

  void _onFilterChanged({String? entityType, AuditAction? action}) {
    setState(() {
      _selectedEntityType = entityType;
      _selectedAction = action;
    });
    _loadLogs(refresh: true);
  }

  void _showFilterBottomSheet() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    String? tempEntityType = _selectedEntityType;
    AuditAction? tempAction = _selectedAction;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
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

              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '필터',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.w700,
                        color: ThemeColor.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempEntityType = null;
                          tempAction = null;
                        });
                      },
                      child: Text(
                        '초기화',
                        style: TextStyle(
                          color: ThemeColor.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: ThemeColor.border),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Entity Type Section
                      Text(
                        '대상 유형',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.012),
                      Wrap(
                        spacing: screenWidth * 0.02,
                        runSpacing: screenHeight * 0.01,
                        children: [
                          _buildFilterOption(
                            label: '전체',
                            isSelected: tempEntityType == null,
                            onTap: () =>
                                setSheetState(() => tempEntityType = null),
                          ),
                          ..._entityTypes.map((type) => _buildFilterOption(
                                label: _getEntityTypeDisplayName(type),
                                isSelected: tempEntityType == type,
                                onTap: () =>
                                    setSheetState(() => tempEntityType = type),
                              )),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Action Type Section
                      Text(
                        '액션 유형',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.012),
                      Wrap(
                        spacing: screenWidth * 0.02,
                        runSpacing: screenHeight * 0.01,
                        children: [
                          _buildFilterOption(
                            label: '전체',
                            isSelected: tempAction == null,
                            onTap: () => setSheetState(() => tempAction = null),
                          ),
                          ...AuditAction.values.map((action) =>
                              _buildFilterOption(
                                label: action.displayName,
                                isSelected: tempAction == action,
                                onTap: () =>
                                    setSheetState(() => tempAction = action),
                                color: _getActionColor(action),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Apply Button
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  child: SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.06,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _onFilterChanged(
                          entityType: tempEntityType,
                          action: tempAction,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeColor.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(screenWidth * 0.03),
                        ),
                      ),
                      child: Text(
                        '적용하기',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.035,
          vertical: screenWidth * 0.02,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? ThemeColor.primary).withValues(alpha: 0.15)
              : ThemeColor.neutral50,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          border: Border.all(
            color: isSelected
                ? (color ?? ThemeColor.primary)
                : ThemeColor.neutral200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.032,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (color ?? ThemeColor.primary)
                : ThemeColor.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: ThemeColor.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: MediaQuery.of(context).size.height * 0.04,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ThemeColor.textSecondary),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(screenWidth * 0.12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: ThemeColor.border),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: ThemeColor.primary,
              unselectedLabelColor: ThemeColor.textTertiary,
              indicatorColor: ThemeColor.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: TextStyle(
                fontSize: screenWidth * 0.038,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: '타임라인'),
                Tab(text: '분석'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimelineTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        // Business Place Selector
        _buildBusinessPlaceSelector(screenWidth, screenHeight),

        // Summary Cards (Salesforce style)
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.history_rounded,
                      iconColor: ThemeColor.primary,
                      title: '전체 활동',
                      value: '$_totalElements',
                      subtitle: '전체 기간',
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.today_rounded,
                      iconColor: ThemeColor.success,
                      title: '오늘 활동',
                      value: _getTodayActivityCount().toString(),
                      subtitle: '오늘',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Filter Bar (HubSpot style)
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.01,
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedEntityType != null ||
                          _selectedAction != null) ...[
                        _buildActiveFilterChip(
                          label: _selectedEntityType != null
                              ? _getEntityTypeDisplayName(_selectedEntityType!)
                              : _selectedAction!.displayName,
                          onRemove: () {
                            _onFilterChanged();
                          },
                        ),
                        SizedBox(width: screenWidth * 0.02),
                      ],
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showFilterBottomSheet,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenWidth * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: (_selectedEntityType != null ||
                            _selectedAction != null)
                        ? ThemeColor.primary.withValues(alpha: 0.1)
                        : ThemeColor.neutral50,
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    border: Border.all(
                      color: (_selectedEntityType != null ||
                              _selectedAction != null)
                          ? ThemeColor.primary
                          : ThemeColor.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: screenWidth * 0.045,
                        color: (_selectedEntityType != null ||
                                _selectedAction != null)
                            ? ThemeColor.primary
                            : ThemeColor.textSecondary,
                      ),
                      SizedBox(width: screenWidth * 0.01),
                      Text(
                        '필터',
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          fontWeight: FontWeight.w600,
                          color: (_selectedEntityType != null ||
                                  _selectedAction != null)
                              ? ThemeColor.primary
                              : ThemeColor.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: ThemeColor.border),

        // Timeline List
        Expanded(
          child: _isLoading && _logs.isEmpty
              ? Center(
                  child: CircularProgressIndicator(color: ThemeColor.primary),
                )
              : _error != null && _logs.isEmpty
                  ? _buildErrorView()
                  : _logs.isEmpty
                      ? _buildEmptyView()
                      : RefreshIndicator(
                          onRefresh: () => _loadLogs(refresh: true),
                          color: ThemeColor.primary,
                          child: _buildTimelineList(),
                        ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.035),
      decoration: BoxDecoration(
        color: ThemeColor.neutral50,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        border: Border.all(color: ThemeColor.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.025),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: screenWidth * 0.05,
            ),
          ),
          SizedBox(width: screenWidth * 0.025),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.002),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: screenWidth * 0.028,
                    color: ThemeColor.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenWidth * 0.015,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        border: Border.all(color: ThemeColor.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.03,
              fontWeight: FontWeight.w600,
              color: ThemeColor.primary,
            ),
          ),
          SizedBox(width: screenWidth * 0.01),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: screenWidth * 0.035,
              color: ThemeColor.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Group logs by date
    final groupedLogs = <String, List<AuditLog>>{};
    for (final log in _logs) {
      final dateKey = _getDateKey(log.createdAt);
      groupedLogs.putIfAbsent(dateKey, () => []).add(log);
    }

    final dateKeys = groupedLogs.keys.toList();

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.015,
      ),
      itemCount: dateKeys.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == dateKeys.length) {
          _loadMoreLogs();
          return Center(
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: CircularProgressIndicator(
                color: ThemeColor.primary,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final dateKey = dateKeys[index];
        final logs = groupedLogs[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header (Notion style sticky header)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: screenHeight * 0.008,
              ),
              margin: EdgeInsets.only(
                top: index == 0 ? 0 : screenHeight * 0.015,
                bottom: screenHeight * 0.01,
              ),
              decoration: BoxDecoration(
                color: ThemeColor.neutral100,
                borderRadius: BorderRadius.circular(screenWidth * 0.015),
              ),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: screenWidth * 0.032,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.textSecondary,
                ),
              ),
            ),
            // Timeline items
            ...logs.asMap().entries.map((entry) {
              final isLast = entry.key == logs.length - 1;
              return _buildTimelineItem(entry.value, isLast);
            }),
          ],
        );
      },
    );
  }

  Widget _buildTimelineItem(AuditLog log, bool isLast) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: screenWidth * 0.08,
            child: Column(
              children: [
                Container(
                  width: screenWidth * 0.025,
                  height: screenWidth * 0.025,
                  decoration: BoxDecoration(
                    color: _getActionColor(log.action),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getActionColor(log.action).withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: ThemeColor.neutral200,
                    ),
                  ),
              ],
            ),
          ),

          // Content Card
          Expanded(
            child: GestureDetector(
              onTap: () => _showLogDetail(log),
              child: Container(
                margin: EdgeInsets.only(bottom: screenHeight * 0.012),
                padding: EdgeInsets.all(screenWidth * 0.035),
                decoration: BoxDecoration(
                  color: ThemeColor.surface,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  border: Border.all(color: ThemeColor.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.02,
                            vertical: screenWidth * 0.01,
                          ),
                          decoration: BoxDecoration(
                            color: _getActionColor(log.action)
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.01),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getActionIcon(log.action),
                                size: screenWidth * 0.032,
                                color: _getActionColor(log.action),
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                log.action.displayName,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.028,
                                  fontWeight: FontWeight.w600,
                                  color: _getActionColor(log.action),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.02,
                            vertical: screenWidth * 0.01,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColor.neutral100,
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.01),
                          ),
                          child: Text(
                            _getEntityTypeDisplayName(log.entityType),
                            style: TextStyle(
                              fontSize: screenWidth * 0.026,
                              color: ThemeColor.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(log.createdAt),
                          style: TextStyle(
                            fontSize: screenWidth * 0.028,
                            color: ThemeColor.textTertiary,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.01),

                    // Entity name
                    Text(
                      log.entityName ?? log.entityId,
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Description
                    if (log.description != null &&
                        log.description!.isNotEmpty) ...[
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        log.description!,
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: ThemeColor.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    SizedBox(height: screenHeight * 0.008),

                    // Footer
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: screenWidth * 0.035,
                          color: ThemeColor.textTertiary,
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Expanded(
                          child: Text(
                            log.username ?? '알 수 없음',
                            style: TextStyle(
                              fontSize: screenWidth * 0.028,
                              color: ThemeColor.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: screenWidth * 0.04,
                          color: ThemeColor.textTertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isStatsLoading) {
      return Center(
        child: CircularProgressIndicator(color: ThemeColor.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      color: ThemeColor.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Statistics Card (Salesforce style)
            _buildAnalyticsCard(
              title: '액션별 활동',
              subtitle: '최근 30일',
              icon: Icons.analytics_outlined,
              child: _actionStats != null
                  ? Column(
                      children: _actionStats!.statistics.entries.map((entry) {
                        final total = _actionStats!.statistics.values
                            .fold<int>(0, (sum, v) => sum + v);
                        final percentage =
                            total > 0 ? (entry.value / total * 100) : 0.0;

                        return Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: screenHeight * 0.008),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(screenWidth * 0.015),
                                    decoration: BoxDecoration(
                                      color: _getActionColorByName(entry.key)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      _getActionIconByName(entry.key),
                                      color: _getActionColorByName(entry.key),
                                      size: screenWidth * 0.04,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.025),
                                  Expanded(
                                    child: Text(
                                      _getActionDisplayName(entry.key),
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.034,
                                        color: ThemeColor.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${entry.value}건',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.034,
                                      fontWeight: FontWeight.w700,
                                      color: ThemeColor.textPrimary,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.02),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.028,
                                      color: ThemeColor.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: screenHeight * 0.006),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: ThemeColor.neutral100,
                                  valueColor: AlwaysStoppedAnimation(
                                    _getActionColorByName(entry.key),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : _buildNoDataWidget(),
            ),

            SizedBox(height: screenHeight * 0.02),

            // User Activity Card
            _buildAnalyticsCard(
              title: '활동 순위',
              subtitle: '최근 30일',
              icon: Icons.leaderboard_outlined,
              child: _userStats != null && _userStats!.statistics.isNotEmpty
                  ? Column(
                      children:
                          _userStats!.statistics.asMap().entries.map((entry) {
                        final index = entry.key;
                        final stat = entry.value;

                        return Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                          child: Row(
                            children: [
                              // Rank Badge
                              Container(
                                width: screenWidth * 0.09,
                                height: screenWidth * 0.09,
                                decoration: BoxDecoration(
                                  gradient: index < 3
                                      ? LinearGradient(
                                          colors: _getRankColors(index),
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: index >= 3 ? ThemeColor.neutral100 : null,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: index < 3
                                      ? Icon(
                                          Icons.emoji_events_rounded,
                                          size: screenWidth * 0.045,
                                          color: Colors.white,
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.035,
                                            fontWeight: FontWeight.w700,
                                            color: ThemeColor.textSecondary,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              // User info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stat.username ?? '알 수 없음',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.038,
                                        fontWeight: FontWeight.w600,
                                        color: ThemeColor.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${stat.activityCount}건의 활동',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.03,
                                        color: ThemeColor.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Activity count
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.025,
                                  vertical: screenWidth * 0.012,
                                ),
                                decoration: BoxDecoration(
                                  color: ThemeColor.primary.withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(screenWidth * 0.02),
                                ),
                                child: Text(
                                  '${stat.activityCount}',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    fontWeight: FontWeight.w700,
                                    color: ThemeColor.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : _buildNoDataWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        border: Border.all(color: ThemeColor.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                decoration: BoxDecoration(
                  color: ThemeColor.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                ),
                child: Icon(
                  icon,
                  size: screenWidth * 0.05,
                  color: ThemeColor.primary,
                ),
              ),
              SizedBox(width: screenWidth * 0.025),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.042,
                        fontWeight: FontWeight.w700,
                        color: ThemeColor.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: screenWidth * 0.028,
                        color: ThemeColor.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          child,
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.04),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: screenWidth * 0.12,
            color: ThemeColor.textTertiary,
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            '데이터가 없습니다',
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: ThemeColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getRankColors(int rank) {
    switch (rank) {
      case 0:
        return [const Color(0xFFFFD700), const Color(0xFFFFA500)]; // Gold
      case 1:
        return [const Color(0xFFC0C0C0), const Color(0xFF808080)]; // Silver
      case 2:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)]; // Bronze
      default:
        return [ThemeColor.neutral300, ThemeColor.neutral400];
    }
  }

  void _showLogDetail(AuditLog log) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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

            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color:
                          _getActionColor(log.action).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getActionIcon(log.action),
                      color: _getActionColor(log.action),
                      size: screenWidth * 0.06,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${log.action.displayName} - ${_getEntityTypeDisplayName(log.entityType)}',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w700,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                        Text(
                          _formatDateTime(log.createdAt),
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: ThemeColor.textSecondary),
                  ),
                ],
              ),
            ),

            Divider(color: ThemeColor.border),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(screenWidth * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem('대상', log.entityName ?? log.entityId),
                    _buildDetailItem('수행자', log.username ?? '알 수 없음'),
                    if (log.description != null)
                      _buildDetailItem('설명', log.description!),
                    if (log.ipAddress != null)
                      _buildDetailItem('IP 주소', log.ipAddress!),
                    if (log.deviceInfo != null)
                      _buildDetailItem('기기 정보', log.deviceInfo!),
                    if (log.requestUri != null)
                      _buildDetailItem(
                        '요청',
                        '${log.httpMethod ?? ''} ${log.requestUri}',
                      ),
                    if (log.changesBefore != null) ...[
                      SizedBox(height: screenHeight * 0.02),
                      Text(
                        '변경 전',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        decoration: BoxDecoration(
                          color: ThemeColor.neutral50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ThemeColor.border),
                        ),
                        child: Text(
                          log.changesBefore!,
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            fontFamily: 'monospace',
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    if (log.changesAfter != null) ...[
                      SizedBox(height: screenHeight * 0.02),
                      Text(
                        '변경 후',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        decoration: BoxDecoration(
                          color: ThemeColor.neutral50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ThemeColor.border),
                        ),
                        child: Text(
                          log.changesAfter!,
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            fontFamily: 'monospace',
                            color: ThemeColor.textSecondary,
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
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.015),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: screenWidth * 0.22,
            child: Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: ThemeColor.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: ThemeColor.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.06),
              decoration: BoxDecoration(
                color: ThemeColor.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: screenWidth * 0.12,
                color: ThemeColor.error,
              ),
            ),
            SizedBox(height: screenHeight * 0.025),
            Text(
              '오류가 발생했습니다',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w600,
                color: ThemeColor.textPrimary,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: ThemeColor.textSecondary,
              ),
            ),
            SizedBox(height: screenHeight * 0.03),
            ElevatedButton.icon(
              onPressed: () => _loadLogs(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeColor.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenHeight * 0.015,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(screenWidth * 0.025),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: screenHeight * 0.15),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.06),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: screenWidth * 0.12,
                  color: ThemeColor.textTertiary,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),
              Text(
                '활동 로그가 없습니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.008),
              Text(
                '새로운 활동이 기록되면 여기에 표시됩니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: ThemeColor.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper methods
  int _getTodayActivityCount() {
    final now = DateTime.now();
    return _logs
        .where((log) =>
            log.createdAt.year == now.year &&
            log.createdAt.month == now.month &&
            log.createdAt.day == now.day)
        .length;
  }

  String _getDateKey(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = today.difference(logDate).inDays;

    if (difference == 0) {
      return '오늘';
    } else if (difference == 1) {
      return '어제';
    } else if (difference < 7) {
      return '$difference일 전';
    } else {
      return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getEntityTypeDisplayName(String entityType) {
    switch (entityType.toUpperCase()) {
      case 'MEMBER':
        return '회원';
      case 'MEMO':
        return '메모';
      case 'RESERVATION':
        return '예약';
      case 'VISIT':
        return '방문';
      case 'BUSINESS_PLACE':
        return '사업장';
      case 'USER':
        return '사용자';
      default:
        return entityType;
    }
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return ThemeColor.success;
      case AuditAction.update:
        return ThemeColor.info;
      case AuditAction.delete:
        return ThemeColor.warning;
      case AuditAction.restore:
        return ThemeColor.primary;
      case AuditAction.permanentDelete:
        return ThemeColor.error;
      case AuditAction.login:
      case AuditAction.logout:
        return ThemeColor.primary;
      case AuditAction.loginFailed:
        return ThemeColor.error;
      case AuditAction.export_:
      case AuditAction.import_:
        return ThemeColor.info;
      case AuditAction.view:
        return ThemeColor.textSecondary;
    }
  }

  Color _getActionColorByName(String actionName) {
    return _getActionColor(AuditAction.fromString(actionName));
  }

  IconData _getActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return Icons.add_circle_outline_rounded;
      case AuditAction.update:
        return Icons.edit_outlined;
      case AuditAction.delete:
        return Icons.delete_outline_rounded;
      case AuditAction.restore:
        return Icons.restore_rounded;
      case AuditAction.permanentDelete:
        return Icons.delete_forever_rounded;
      case AuditAction.login:
        return Icons.login_rounded;
      case AuditAction.logout:
        return Icons.logout_rounded;
      case AuditAction.loginFailed:
        return Icons.error_outline_rounded;
      case AuditAction.export_:
        return Icons.file_download_outlined;
      case AuditAction.import_:
        return Icons.file_upload_outlined;
      case AuditAction.view:
        return Icons.visibility_outlined;
    }
  }

  IconData _getActionIconByName(String actionName) {
    return _getActionIcon(AuditAction.fromString(actionName));
  }

  String _getActionDisplayName(String actionName) {
    return AuditAction.fromString(actionName).displayName;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '방금 전';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Business Place Selector Widget
  Widget _buildBusinessPlaceSelector(double screenWidth, double screenHeight) {
    if (_businessPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedPlace = _businessPlaces.firstWhere(
      (bp) => bp.businessPlace.id == _selectedBusinessPlaceId,
      orElse: () => _businessPlaces.first,
    );

    return Container(
      margin: EdgeInsets.fromLTRB(
        screenWidth * 0.04,
        screenHeight * 0.015,
        screenWidth * 0.04,
        screenHeight * 0.01,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeColor.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBusinessPlaceSelectorDialog(screenWidth, screenHeight),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.014,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: ThemeColor.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: ThemeColor.primary,
                    size: screenWidth * 0.05,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                // Business Place Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '사업장',
                        style: TextStyle(
                          fontSize: screenWidth * 0.028,
                          color: ThemeColor.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.002),
                      Text(
                        selectedPlace.businessPlace.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.textPrimary,
                          letterSpacing: screenWidth * -0.0008,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Dropdown Icon
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: ThemeColor.primary,
                  size: screenWidth * 0.07,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show Business Place Selector Dialog
  Future<void> _showBusinessPlaceSelectorDialog(
    double screenWidth,
    double screenHeight,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.9,
            maxHeight: screenHeight * 0.6,
          ),
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.store_rounded,
                    color: ThemeColor.primary,
                    size: screenWidth * 0.06,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    '사업장 선택',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w700,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close, color: ThemeColor.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _businessPlaces.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bp = _businessPlaces[index];
                    final isSelected =
                        bp.businessPlace.id == _selectedBusinessPlaceId;

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                        vertical: screenHeight * 0.005,
                      ),
                      leading: Container(
                        width: screenWidth * 0.1,
                        height: screenWidth * 0.1,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ThemeColor.primary
                              : ThemeColor.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.store,
                          color: isSelected ? Colors.white : ThemeColor.primary,
                          size: screenWidth * 0.05,
                        ),
                      ),
                      title: Text(
                        bp.businessPlace.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? ThemeColor.primary
                              : ThemeColor.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        bp.userRole.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: ThemeColor.textTertiary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: ThemeColor.primary)
                          : null,
                      onTap: () {
                        if (_selectedBusinessPlaceId != bp.businessPlace.id) {
                          setState(() {
                            _selectedBusinessPlaceId = bp.businessPlace.id;
                          });
                          Navigator.pop(dialogContext);
                          _loadData(); // Reload data with new business place
                        } else {
                          Navigator.pop(dialogContext);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
