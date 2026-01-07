import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/haptic_helper.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/statistics_service.dart';
import 'package:voca_crm/data/datasource/voice_command_service.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/presentation/screens/main_screen.dart';
import 'package:voca_crm/presentation/screens/mypage/my_page_screen.dart';
import 'package:voca_crm/presentation/screens/voice/voice_command_screen.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';

import '../business_place/business_place_management_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, required this.user, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  final VoiceCommandService _voiceCommandService = VoiceCommandService();

  HomeStatistics? _statistics;
  List<RecentActivity> _recentActivities = [];
  List<TodaySchedule> _todaySchedule = [];
  bool _isLoading = true;
  String? _error;
  bool _isBriefingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _moveBusinessPage() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessPlaceManagementScreen(user: widget.user),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get default business place ID from UserViewModel
      final currentUser = Provider.of<UserViewModel>(
        context,
        listen: false,
      ).user;
      final businessPlaceId =
          currentUser?.defaultBusinessPlaceId ??
          widget.user.defaultBusinessPlaceId;

      if (businessPlaceId == null || businessPlaceId.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = '기본 사업장이 설정되지 않았습니다';
        });
        return;
      }

      // Load statistics, today's schedule, and recent activities
      final statistics = await _statisticsService.getHomeStatistics(
        businessPlaceId,
      );
      final todaySchedule = await _statisticsService.getTodaySchedule(
        businessPlaceId,
        limit: 5,
      );
      final activities = await _statisticsService.getRecentActivities(
        businessPlaceId,
        limit: 5,
      );

      setState(() {
        _statistics = statistics;
        _todaySchedule = todaySchedule;
        _recentActivities = activities;
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
          screenName: 'HomeScreen',
          action: '대시보드 데이터 조회',
          userId: widget.user.id,
        );
      }
    }
  }

  Future<void> _showDailyBriefing() async {
    HapticHelper.medium();
    setState(() {
      _isBriefingLoading = true;
    });

    try {
      final currentUser = Provider.of<UserViewModel>(
        context,
        listen: false,
      ).user;
      final businessPlaceId =
          currentUser?.defaultBusinessPlaceId ??
          widget.user.defaultBusinessPlaceId;

      final response = await _voiceCommandService.getDailyBriefing(
        userId: widget.user.providerId,
        businessPlaceId: businessPlaceId,
      );

      setState(() {
        _isBriefingLoading = false;
      });

      if (mounted) {
        final dialogWidth = MediaQuery.of(context).size.width;
        final dialogHeight = MediaQuery.of(context).size.height;
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogWidth * 0.05),
            ),
            child: Padding(
              padding: EdgeInsets.all(dialogWidth * 0.06),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(dialogWidth * 0.04),
                    decoration: BoxDecoration(
                      color: ThemeColor.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: ThemeColor.primary,
                      size: dialogWidth * 0.08,
                    ),
                  ),
                  SizedBox(height: dialogHeight * 0.02),
                  Text(
                    '오늘의 브리핑',
                    style: TextStyle(
                      fontSize: dialogWidth * 0.05,
                      fontWeight: FontWeight.w700,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                  SizedBox(height: dialogHeight * 0.02),
                  Container(
                    constraints: BoxConstraints(maxHeight: dialogHeight * 0.35),
                    child: SingleChildScrollView(
                      child: Text(
                        response.message,
                        style: TextStyle(
                          fontSize: dialogWidth * 0.038,
                          height: 1.6,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: dialogHeight * 0.03),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeColor.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          vertical: dialogHeight * 0.018,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            dialogWidth * 0.03,
                          ),
                        ),
                      ),
                      child: Text(
                        '확인',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: dialogWidth * 0.038,
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
    } catch (e, stackTrace) {
      setState(() {
        _isBriefingLoading = false;
      });

      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'HomeScreen',
          action: '브리핑 조회',
          userId: widget.user.id,
        );
      }
    }
  }

  /// 음성 명령 화면으로 이동
  void _navigateToVoiceCommand() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VoiceCommandScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ThemeColor.background,
      appBar: _buildAppBar(screenWidth, screenHeight),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: ThemeColor.primary,
        backgroundColor: ThemeColor.surface,
        child: _isLoading
            ? _buildLoadingView()
            : _error != null
            ? _buildErrorView()
            : _buildContent(),
      ),
      // 음성 명령 FAB (navigation_plan.txt)
      floatingActionButton: _buildVoiceCommandFAB(screenWidth),
    );
  }

  /// 음성 명령 FAB 위젯
  Widget _buildVoiceCommandFAB(double screenWidth) {
    return Container(
      margin: EdgeInsets.only(bottom: MainScreen.navBarHeight),
      child: FloatingActionButton(
        onPressed: _navigateToVoiceCommand,
        backgroundColor: ThemeColor.primary,
        elevation: 4,
        highlightElevation: 8,
        child: Icon(
          Icons.mic_rounded,
          color: Colors.white,
          size: screenWidth * 0.07,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(double screenWidth, double screenHeight) {
    return AppBar(
      backgroundColor: ThemeColor.surface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(screenWidth * 0.02),
          decoration: BoxDecoration(
            color: ThemeColor.neutral100,
            borderRadius: BorderRadius.circular(screenWidth * 0.025),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            color: ThemeColor.textSecondary,
            size: screenWidth * 0.05,
          ),
        ),
        tooltip: '마이페이지',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyPageScreen(user: widget.user),
            ),
          );
        },
      ),
      title: Image.asset(
        'assets/images/app_logo2.png',
        height: screenHeight * 0.04,
        fit: BoxFit.contain,
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: ThemeColor.textSecondary),
          tooltip: '검색',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.business_rounded, color: ThemeColor.textSecondary),
          tooltip: '사업장 관리',
          onPressed: () => _moveBusinessPage(),
        ),
        SizedBox(width: screenWidth * 0.02),
      ],
    );
  }

  Widget _buildLoadingView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: screenWidth * 0.1,
            height: screenWidth * 0.1,
            child: CircularProgressIndicator(
              strokeWidth: screenWidth * 0.008,
              valueColor: AlwaysStoppedAnimation<Color>(ThemeColor.primary),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            '데이터를 불러오는 중...',
            style: TextStyle(
              color: ThemeColor.textSecondary,
              fontSize: screenWidth * 0.035,
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
                color: ThemeColor.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: screenWidth * 0.12,
                color: ThemeColor.textTertiary,
              ),
            ),
            SizedBox(height: screenHeight * 0.025),
            Text(
              _error ?? '오류가 발생했습니다',
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: ThemeColor.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.03),
            SizedBox(
              width: screenWidth * 0.6,
              child: ElevatedButton.icon(
                onPressed: () => _moveBusinessPage(),
                icon: Icon(Icons.business_rounded, size: screenWidth * 0.05),
                label: Text(
                  '사업장 관리',
                  style: TextStyle(fontSize: screenWidth * 0.038),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColor.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.05;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              screenHeight * 0.025,
              horizontalPadding,
              screenHeight * 0.02,
            ),
            decoration: BoxDecoration(
              color: ThemeColor.surface,
              border: Border(
                bottom: BorderSide(
                  color: ThemeColor.border,
                  width: screenWidth * 0.002,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요,',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: ThemeColor.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  '${widget.user.name}님',
                  style: TextStyle(
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.textPrimary,
                    letterSpacing: screenWidth * -0.001,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: screenHeight * 0.02),

          // Daily Briefing Card
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: _buildBriefingCard(screenWidth),
          ),

          SizedBox(height: screenHeight * 0.02),

          // Summary Stats (오늘 예약, 오늘 방문)
          if (_statistics != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _buildStatsGrid(screenWidth),
            ),

          SizedBox(height: screenHeight * 0.025),

          // Today's Schedule Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('오늘의 일정'),
                SizedBox(height: screenHeight * 0.015),
                _buildTodayScheduleCard(screenWidth, screenHeight),
              ],
            ),
          ),

          SizedBox(height: screenHeight * 0.025),

          // Recent Activity Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('최근 활동'),
                SizedBox(height: screenHeight * 0.015),
                _buildRecentActivityCard(screenWidth, screenHeight),
              ],
            ),
          ),

          // 바텀 네비게이션 바 높이 + FAB 공간만큼 하단 패딩 추가
          SizedBox(
            height:
                MainScreen.navBarHeight +
                MediaQuery.of(context).padding.bottom +
                80,
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingCard(double screenWidth) {
    return GestureDetector(
      onTap: _isBriefingLoading ? null : _showDailyBriefing,
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.05),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ThemeColor.primaryGradient,
          ),
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          boxShadow: [
            BoxShadow(
              color: ThemeColor.primary.withValues(alpha: 0.25),
              blurRadius: screenWidth * 0.04,
              offset: Offset(0, screenWidth * 0.015),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
              ),
              child: Icon(
                Icons.campaign_rounded,
                color: Colors.white,
                size: screenWidth * 0.06,
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 브리핑 듣기',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text(
                    '예약 현황과 중요 메모를 확인하세요',
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            if (_isBriefingLoading)
              SizedBox(
                width: screenWidth * 0.05,
                height: screenWidth * 0.05,
                child: CircularProgressIndicator(
                  strokeWidth: screenWidth * 0.005,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: screenWidth * 0.05,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(double screenWidth) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            screenWidth: screenWidth,
            icon: Icons.event_note_rounded,
            label: '오늘 예약',
            value: '${_statistics!.todayReservations}',
            color: ThemeColor.primary,
            onTap: () => widget.onNavigateToTab?.call(4), // 예약 탭으로 이동
          ),
        ),
        SizedBox(width: screenWidth * 0.03),
        Expanded(
          child: _buildStatCard(
            screenWidth: screenWidth,
            icon: Icons.how_to_reg_rounded,
            label: '오늘 방문',
            value: '${_statistics!.todayVisits}',
            color: ThemeColor.success,
            onTap: () => widget.onNavigateToTab?.call(2), // 체크인 탭으로 이동
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required double screenWidth,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: ThemeColor.surface,
          borderRadius: BorderRadius.circular(screenWidth * 0.035),
          border: Border.all(color: ThemeColor.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.02),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(screenWidth * 0.02),
              ),
              child: Icon(icon, color: color, size: screenWidth * 0.045),
            ),
            SizedBox(height: screenWidth * 0.03),
            Text(
              value,
              style: TextStyle(
                fontSize: screenWidth * 0.055,
                fontWeight: FontWeight.w700,
                color: ThemeColor.textPrimary,
              ),
            ),
            SizedBox(height: screenWidth * 0.01),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: ThemeColor.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Text(
      title,
      style: TextStyle(
        fontSize: screenWidth * 0.045,
        fontWeight: FontWeight.w700,
        color: ThemeColor.textPrimary,
        letterSpacing: screenWidth * -0.0008,
      ),
    );
  }

  /// 오늘의 일정 카드
  Widget _buildTodayScheduleCard(double screenWidth, double screenHeight) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        border: Border.all(color: ThemeColor.border),
      ),
      child: Column(
        children: [
          if (_todaySchedule.isEmpty)
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.06),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: screenWidth * 0.1,
                    color: ThemeColor.textTertiary,
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    '오늘 예정된 예약이 없습니다',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: ThemeColor.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todaySchedule.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: ThemeColor.border,
              ),
              itemBuilder: (context, index) {
                final schedule = _todaySchedule[index];
                return _buildScheduleItem(schedule, screenWidth);
              },
            ),
          // 전체보기 버튼
          if (_todaySchedule.isNotEmpty)
            InkWell(
              onTap: () => widget.onNavigateToTab?.call(4), // 예약 탭으로 이동
              child: Container(
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: ThemeColor.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '전체보기',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: ThemeColor.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.01),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: screenWidth * 0.035,
                      color: ThemeColor.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(TodaySchedule schedule, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.035,
      ),
      child: Row(
        children: [
          // 시간
          Container(
            width: screenWidth * 0.15,
            child: Text(
              schedule.formattedTime,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w700,
                color: ThemeColor.primary,
              ),
            ),
          ),
          // 구분선
          Container(
            width: 2,
            height: screenWidth * 0.08,
            margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
            decoration: BoxDecoration(
              color: ThemeColor.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // 예약 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.memberName,
                  style: TextStyle(
                    fontSize: screenWidth * 0.038,
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                if (schedule.serviceType != null && schedule.serviceType!.isNotEmpty)
                  Text(
                    schedule.serviceType!,
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: ThemeColor.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          // 상태 뱃지
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.025,
              vertical: screenWidth * 0.01,
            ),
            decoration: BoxDecoration(
              color: schedule.status == 'CONFIRMED'
                  ? ThemeColor.success.withValues(alpha: 0.1)
                  : ThemeColor.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
            ),
            child: Text(
              schedule.status == 'CONFIRMED' ? '확정' : '대기',
              style: TextStyle(
                fontSize: screenWidth * 0.028,
                fontWeight: FontWeight.w600,
                color: schedule.status == 'CONFIRMED'
                    ? ThemeColor.success
                    : ThemeColor.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 최근 활동 카드
  Widget _buildRecentActivityCard(double screenWidth, double screenHeight) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        border: Border.all(color: ThemeColor.border),
      ),
      child: Column(
        children: [
          if (_recentActivities.isEmpty)
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.06),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: screenWidth * 0.1,
                    color: ThemeColor.textTertiary,
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    '최근 활동이 없습니다',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: ThemeColor.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentActivities.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: ThemeColor.border,
              ),
              itemBuilder: (context, index) {
                final activity = _recentActivities[index];
                return _buildActivityItem(activity, screenWidth);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(RecentActivity activity, double screenWidth) {
    final isVisit = activity.activityType == 'VISIT';
    final icon = isVisit ? Icons.login_rounded : Icons.note_add_rounded;
    final color = isVisit ? ThemeColor.success : ThemeColor.info;
    final actionText = isVisit ? '방문' : '메모';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.035,
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            padding: EdgeInsets.all(screenWidth * 0.025),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
            ),
            child: Icon(icon, color: color, size: screenWidth * 0.045),
          ),
          SizedBox(width: screenWidth * 0.03),
          // 활동 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: ThemeColor.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: activity.memberName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: '님 $actionText'),
                    ],
                  ),
                ),
                if (activity.content.isNotEmpty)
                  Text(
                    activity.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: ThemeColor.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          // 시간
          Text(
            _formatRelativeTime(activity.activityTime),
            style: TextStyle(
              fontSize: screenWidth * 0.03,
              color: ThemeColor.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}
