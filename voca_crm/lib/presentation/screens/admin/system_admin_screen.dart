import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/domain/entity/user.dart';

import 'notices_management_screen.dart';

/// 시스템 관리 화면 (시스템 관리자 전용)
///
/// 시스템 관리자만 접근 가능한 화면
/// 공지사항 관리 등 시스템 전반의 관리 기능 제공
class SystemAdminScreen extends StatefulWidget {
  final User user;

  const SystemAdminScreen({super.key, required this.user});

  @override
  State<SystemAdminScreen> createState() => _SystemAdminScreenState();
}

class _SystemAdminScreenState extends State<SystemAdminScreen> {
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
          height: MediaQuery.of(context).size.height * 0.04,
          fit: BoxFit.contain,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(screenWidth * 0.05),
        children: [
          // Admin Info Card
          Container(
            padding: EdgeInsets.all(screenWidth * 0.05),
            decoration: BoxDecoration(
              color: ThemeColor.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
              border: Border.all(
                color: ThemeColor.primary.withValues(alpha: 0.3),
                width: screenWidth * 0.0025,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: screenWidth * 0.12,
                  height: screenWidth * 0.12,
                  decoration: BoxDecoration(
                    color: ThemeColor.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
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
                        '시스템 관리자',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: ThemeColor.primary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        widget.user.username,
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: screenHeight * 0.03),

          // Management Sections
          _buildManagementCard(
            context: context,
            icon: Icons.campaign_outlined,
            title: '공지사항 관리',
            description: '시스템 공지사항 등록 및 관리',
            color: ThemeColor.info,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoticesManagementScreen(user: widget.user),
                ),
              );
            },
          ),

          SizedBox(height: screenHeight * 0.02),

          _buildManagementCard(
            context: context,
            icon: Icons.people_outline,
            title: '사용자 관리',
            description: '전체 사용자 조회 및 관리 (준비 중)',
            color: ThemeColor.warning,
            enabled: false,
            onTap: () {},
          ),

          SizedBox(height: screenHeight * 0.02),

          _buildManagementCard(
            context: context,
            icon: Icons.bar_chart_outlined,
            title: '시스템 통계',
            description: '전체 시스템 통계 및 분석 (준비 중)',
            color: ThemeColor.success,
            enabled: false,
            onTap: () {},
          ),

          SizedBox(height: screenHeight * 0.02),

          _buildManagementCard(
            context: context,
            icon: Icons.settings_outlined,
            title: '시스템 설정',
            description: '시스템 전반 설정 관리 (준비 중)',
            color: ThemeColor.primary,
            enabled: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(screenWidth * 0.04),
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.045),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.3) : ThemeColor.border,
            width: screenWidth * 0.0025,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.12,
              height: screenWidth * 0.12,
              decoration: BoxDecoration(
                color: enabled ? color.withValues(alpha: 0.1) : ThemeColor.neutral100,
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
              ),
              child: Icon(
                icon,
                color: enabled ? color : ThemeColor.textTertiary,
                size: screenWidth * 0.06,
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: screenWidth * 0.042,
                      fontWeight: FontWeight.bold,
                      color: enabled ? ThemeColor.textPrimary : ThemeColor.textTertiary,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: ThemeColor.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: enabled ? ThemeColor.textTertiary : ThemeColor.border,
            ),
          ],
        ),
      ),
    );
  }
}
