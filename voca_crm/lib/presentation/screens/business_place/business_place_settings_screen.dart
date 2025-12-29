import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/data/datasource/user_service.dart';
import 'package:voca_crm/domain/entity/business_place.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';
import 'package:voca_crm/presentation/screens/business_place/business_place_members_screen.dart';
import 'package:voca_crm/presentation/widgets/business_place_delete_dialog.dart';
import 'package:voca_crm/presentation/widgets/settings_widgets.dart';

class BusinessPlaceSettingsScreen extends StatefulWidget {
  final BusinessPlace businessPlace;
  final User user;
  final Role currentUserRole;

  const BusinessPlaceSettingsScreen({
    super.key,
    required this.businessPlace,
    required this.user,
    required this.currentUserRole,
  });

  @override
  State<BusinessPlaceSettingsScreen> createState() =>
      _BusinessPlaceSettingsScreenState();
}

class _BusinessPlaceSettingsScreenState
    extends State<BusinessPlaceSettingsScreen> {
  final UserService _userService = UserService();
  final BusinessPlaceService _businessPlaceService = BusinessPlaceService();
  bool _isDefault = false;
  bool _notificationsEnabled = true;
  int _memberCount = 0;

  @override
  void initState() {
    super.initState();
    _isDefault = widget.user.defaultBusinessPlaceId == widget.businessPlace.id;
    _loadMemberCount();
  }

  Future<void> _loadMemberCount() async {
    try {
      final members = await _businessPlaceService.getBusinessPlaceMembers(
        widget.businessPlace.id,
      );
      if (mounted) {
        setState(() => _memberCount = members.length);
      }
    } catch (e) {
      // Non-critical error
    }
  }

  void _showDeleteDialog() {
    // Owner만 삭제 가능
    if (widget.currentUserRole != Role.OWNER) {
      AppMessageHandler.showErrorSnackBar(
        context,
        'Owner만 사업장을 삭제할 수 있습니다',
      );
      return;
    }

    BusinessPlaceDeleteDialog.show(
      context,
      businessPlace: widget.businessPlace,
      onDeleted: () {
        // 삭제 성공 시 이전 화면들을 모두 닫고 메인 화면으로 이동
        AppMessageHandler.showSuccessSnackBar(context, '사업장이 삭제되었습니다');
        // Pop until we reach the main screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  Future<void> _toggleDefault(bool value) async {
    if (!value && _isDefault) {
      AppMessageHandler.showSnackBar(context, '다른 사업장을 기본으로 설정하면 자동으로 해제됩니다');
      return;
    }

    try {
      if (value) {
        await _userService.updateDefaultBusinessPlace(
          userId: widget.user.id,
          businessPlaceId: widget.businessPlace.id,
        );
        setState(() => _isDefault = true);
        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '기본 사업장으로 설정되었습니다');
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleApiError(context, e);
      }
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
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ThemeColor.textPrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(screenWidth * 0.06),
              width: double.infinity,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: screenWidth * 0.1,
                    backgroundColor: ThemeColor.primarySurface,
                    child: Icon(
                      Icons.store,
                      size: screenWidth * 0.1,
                      color: ThemeColor.primary,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    widget.businessPlace.name,
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    widget.businessPlace.address ?? '주소 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: ThemeColor.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // General Settings
            SettingsSection(
              title: '일반',
              tiles: [
                SettingsTile(
                  icon: Icons.star_outline,
                  title: '기본 사업장으로 설정',
                  subtitle: '앱 실행 시 이 사업장이 먼저 표시됩니다',
                  trailing: Switch(
                    value: _isDefault,
                    onChanged: _toggleDefault,
                  ),
                  onTap: () => _toggleDefault(!_isDefault),
                ),
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: '알림 설정',
                  subtitle: '이 사업장의 알림을 받습니다',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
                    },
                  ),
                  showDivider: false,
                  onTap: () {
                    setState(
                      () => _notificationsEnabled = !_notificationsEnabled,
                    );
                  },
                ),
              ],
            ),

            // Member Management
            SettingsSection(
              title: '멤버 및 권한',
              tiles: [
                SettingsTile(
                  icon: Icons.people_outline,
                  title: '멤버 관리',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_memberCount}명',
                        style: TextStyle(
                          color: ThemeColor.textSecondary,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: ThemeColor.textTertiary),
                    ],
                  ),
                  showDivider: false,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessPlaceMembersScreen(
                          businessPlace: widget.businessPlace,
                          currentUserRole: widget.currentUserRole,
                        ),
                      ),
                    );
                    // 화면에서 돌아오면 멤버 수 다시 로드
                    _loadMemberCount();
                  },
                ),
              ],
            ),

            // Danger Zone
            SettingsSection(
              title: '관리',
              tiles: [
                SettingsTile(
                  icon: Icons.edit_outlined,
                  title: '사업장 정보 수정',
                  onTap: () {
                    AppMessageHandler.showSnackBar(context, '정보 수정 기능 준비 중');
                  },
                ),
                SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: '사업장 삭제',
                  subtitle: widget.currentUserRole == Role.OWNER
                      ? '모든 데이터가 영구 삭제됩니다'
                      : 'Owner만 삭제할 수 있습니다',
                  iconColor: ThemeColor.error,
                  titleColor: ThemeColor.error,
                  showDivider: false,
                  onTap: () => _showDeleteDialog(),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.04),
          ],
        ),
      ),
    );
  }
}
