import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/domain/entity/business_place.dart';
import 'package:voca_crm/domain/entity/business_place_member.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';

class BusinessPlaceMembersScreen extends StatefulWidget {
  final BusinessPlace businessPlace;
  final Role currentUserRole;

  const BusinessPlaceMembersScreen({
    super.key,
    required this.businessPlace,
    required this.currentUserRole,
  });

  @override
  State<BusinessPlaceMembersScreen> createState() =>
      _BusinessPlaceMembersScreenState();
}

class _BusinessPlaceMembersScreenState
    extends State<BusinessPlaceMembersScreen> {
  final BusinessPlaceService _service = BusinessPlaceService();

  List<BusinessPlaceMember> _members = [];
  bool _isLoading = true;

  bool get _isOwner => widget.currentUserRole == Role.OWNER;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await _service.getBusinessPlaceMembers(
        widget.businessPlace.id,
      );
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      if (mounted) {
        // Note: This screen doesn't have direct access to user.id, so we pass null
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'BusinessPlaceMembersScreen',
          action: '멤버 목록 조회',
          userId: null,
        );
      }
    }
  }

  Color _getRoleColor(Role role) {
    switch (role) {
      case Role.OWNER:
        return ThemeColor.warning;
      case Role.MANAGER:
        return ThemeColor.info;
      case Role.STAFF:
        return ThemeColor.success;
    }
  }

  String _getRoleText(Role role) {
    switch (role) {
      case Role.OWNER:
        return '소유자';
      case Role.MANAGER:
        return '관리자';
      case Role.STAFF:
        return '직원';
    }
  }

  Future<void> _showMemberInfoDialog(BusinessPlaceMember member) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              CircleAvatar(
                radius: screenWidth * 0.1,
                backgroundColor: ThemeColor.primarySurface,
                child: Icon(
                  Icons.person,
                  size: screenWidth * 0.1,
                  color: ThemeColor.primary,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              // Title
              Text(
                '멤버 정보',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              // Info Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral50,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  border: Border.all(color: ThemeColor.border),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.badge_outlined,
                      label: '이름',
                      value: member.displayNameOrUsername,
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: '전화번호',
                      value: member.phone ?? '-',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: '이메일',
                      value: member.email ?? '-',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Divider(color: ThemeColor.border, height: 1),
                    SizedBox(height: screenHeight * 0.015),
                    _buildInfoRow(
                      icon: Icons.shield_outlined,
                      label: '역할',
                      value: _getRoleText(member.role),
                      valueColor: _getRoleColor(member.role),
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    _buildInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: '가입일',
                      value: _formatDate(member.joinedAt),
                      screenWidth: screenWidth,
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColor.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.018,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.025),
                    ),
                  ),
                  child: Text(
                    '확인',
                    style: TextStyle(
                      fontSize: screenWidth * 0.038,
                      fontWeight: FontWeight.w600,
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

  Future<void> _showChangeRoleDialog(BusinessPlaceMember member) async {
    if (!_isOwner) return;
    if (member.role == Role.OWNER) {
      AppMessageHandler.showSnackBar(context, '소유자의 역할은 변경할 수 없습니다');
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    Role selectedRole = member.role;

    final result = await showDialog<Role>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.06),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: screenWidth * 0.18,
                  height: screenWidth * 0.18,
                  decoration: BoxDecoration(
                    color: ThemeColor.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: screenWidth * 0.09,
                    color: ThemeColor.info,
                  ),
                ),
                SizedBox(height: screenHeight * 0.025),

                // Title
                Text(
                  '역할 변경',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),

                // Member name
                Text(
                  member.displayNameOrUsername,
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: ThemeColor.textSecondary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.025),

                // Role Selection
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: ThemeColor.neutral50,
                    borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    border: Border.all(color: ThemeColor.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '새로운 역할 선택',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildRoleOption(
                        role: Role.MANAGER,
                        selectedRole: selectedRole,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        onTap: () {
                          setDialogState(() => selectedRole = Role.MANAGER);
                        },
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      _buildRoleOption(
                        role: Role.STAFF,
                        selectedRole: selectedRole,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        onTap: () {
                          setDialogState(() => selectedRole = Role.STAFF);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.018,
                          ),
                          side: BorderSide(color: ThemeColor.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.025,
                            ),
                          ),
                        ),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            color: ThemeColor.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedRole == member.role
                            ? null
                            : () => Navigator.pop(dialogContext, selectedRole),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeColor.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: ThemeColor.border,
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.018,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.025,
                            ),
                          ),
                        ),
                        child: Text(
                          '변경하기',
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result != member.role) {
      try {
        await _service.updateMemberRole(
          userBusinessPlaceId: member.userBusinessPlaceId,
          role: result,
        );
        await _loadMembers();
        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '역할이 변경되었습니다');
        }
      } catch (e, stackTrace) {
        if (mounted) {
          await AppMessageHandler.handleErrorWithLogging(
            context,
            e,
            stackTrace,
            screenName: 'BusinessPlaceMembersScreen',
            action: '멤버 역할 변경',
            userId: null,
          );
        }
      }
    }
  }

  Widget _buildRoleOption({
    required Role role,
    required Role selectedRole,
    required double screenWidth,
    required double screenHeight,
    required VoidCallback onTap,
  }) {
    final isSelected = role == selectedRole;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(screenWidth * 0.02),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.015,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? _getRoleColor(role).withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.02),
          border: Border.all(
            color: isSelected ? _getRoleColor(role) : ThemeColor.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.06,
              height: screenWidth * 0.06,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _getRoleColor(role) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _getRoleColor(role) : ThemeColor.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: screenWidth * 0.04,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(width: screenWidth * 0.03),
            Text(
              _getRoleText(role),
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _getRoleColor(role) : ThemeColor.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveMemberDialog(BusinessPlaceMember member) async {
    if (!_isOwner) return;
    if (member.role == Role.OWNER) {
      AppMessageHandler.showSnackBar(context, '소유자는 삭제할 수 없습니다');
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: screenWidth * 0.18,
                height: screenWidth * 0.18,
                decoration: BoxDecoration(
                  color: ThemeColor.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_remove,
                  size: screenWidth * 0.09,
                  color: ThemeColor.error,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              // Title
              Text(
                '멤버 삭제',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              // Member Info Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral50,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  border: Border.all(color: ThemeColor.border),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.badge_outlined,
                      label: '이름',
                      value: member.displayNameOrUsername,
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    _buildInfoRow(
                      icon: Icons.shield_outlined,
                      label: '역할',
                      value: _getRoleText(member.role),
                      valueColor: _getRoleColor(member.role),
                      screenWidth: screenWidth,
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              // Warning message
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03,
                  vertical: screenHeight * 0.01,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: screenWidth * 0.045,
                      color: ThemeColor.error,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: Text(
                        '삭제 시 해당 멤버가 생성한 데이터의 소유자 정보가 초기화됩니다',
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          color: ThemeColor.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.03),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.018,
                        ),
                        side: BorderSide(color: ThemeColor.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          color: ThemeColor.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeColor.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.018,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                        ),
                      ),
                      child: Text(
                        '삭제하기',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _service.removeMember(member.userBusinessPlaceId);
        await _loadMembers();
        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '멤버가 삭제되었습니다');
        }
      } catch (e, stackTrace) {
        if (mounted) {
          await AppMessageHandler.handleErrorWithLogging(
            context,
            e,
            stackTrace,
            screenName: 'BusinessPlaceMembersScreen',
            action: '멤버 강제 탈퇴',
            userId: null,
          );
        }
      }
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required double screenWidth,
    Color? valueColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: screenWidth * 0.28,
          child: Row(
            children: [
              Icon(
                icon,
                size: screenWidth * 0.045,
                color: ThemeColor.textTertiary,
              ),
              SizedBox(width: screenWidth * 0.02),
              SizedBox(
                width: screenWidth * 0.2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: screenWidth * 0.033,
                    color: ThemeColor.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.w600,
              color: valueColor ?? ThemeColor.textPrimary,
            ),
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
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
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMembers),
        ],
      ),
      body: _isLoading
          ? Center(
              child: SizedBox(
                width: screenWidth * 0.1,
                height: screenWidth * 0.1,
                child: CircularProgressIndicator(
                  strokeWidth: screenWidth * 0.008,
                ),
              ),
            )
          : Column(
              children: [
                // Header
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Row(
                    children: [
                      Icon(
                        Icons.store,
                        size: screenWidth * 0.06,
                        color: ThemeColor.primary,
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.businessPlace.name,
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '총 ${_members.length}명의 멤버',
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
                SizedBox(height: screenHeight * 0.01),

                // Member List
                Expanded(
                  child: _members.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: screenWidth * 0.2,
                                color: ThemeColor.textTertiary,
                              ),
                              SizedBox(height: screenHeight * 0.02),
                              Text(
                                '멤버가 없습니다',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: ThemeColor.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final isOwnerMember = member.role == Role.OWNER;

                            return Card(
                              margin: EdgeInsets.only(
                                bottom: screenHeight * 0.012,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                side: BorderSide(color: ThemeColor.border),
                              ),
                              child: InkWell(
                                onTap: () => _showMemberInfoDialog(member),
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.04),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      CircleAvatar(
                                        radius: screenWidth * 0.06,
                                        backgroundColor: _getRoleColor(
                                          member.role,
                                        ).withValues(alpha: 0.1),
                                        child: Icon(
                                          isOwnerMember
                                              ? Icons.star
                                              : Icons.person,
                                          size: screenWidth * 0.06,
                                          color: _getRoleColor(member.role),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.03),

                                      // Member Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    member.displayNameOrUsername,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize:
                                                          screenWidth * 0.04,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: screenWidth * 0.02,
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        screenWidth * 0.02,
                                                    vertical:
                                                        screenHeight * 0.003,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getRoleColor(
                                                      member.role,
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      screenWidth * 0.01,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _getRoleText(member.role),
                                                    style: TextStyle(
                                                      color: _getRoleColor(
                                                        member.role,
                                                      ),
                                                      fontSize:
                                                          screenWidth * 0.028,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: screenHeight * 0.005,
                                            ),
                                            Text(
                                              member.email ?? member.phone ?? '-',
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.032,
                                                color: ThemeColor.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Actions (Owner only, not for owner member)
                                      if (_isOwner && !isOwnerMember)
                                        PopupMenuButton<String>(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: ThemeColor.textSecondary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              screenWidth * 0.02,
                                            ),
                                          ),
                                          onSelected: (value) {
                                            if (value == 'role') {
                                              _showChangeRoleDialog(member);
                                            } else if (value == 'remove') {
                                              _showRemoveMemberDialog(member);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'role',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.admin_panel_settings,
                                                    size: screenWidth * 0.05,
                                                    color: ThemeColor.info,
                                                  ),
                                                  SizedBox(
                                                    width: screenWidth * 0.02,
                                                  ),
                                                  Text('역할 변경'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'remove',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.person_remove,
                                                    size: screenWidth * 0.05,
                                                    color: ThemeColor.error,
                                                  ),
                                                  SizedBox(
                                                    width: screenWidth * 0.02,
                                                  ),
                                                  Text(
                                                    '삭제',
                                                    style: TextStyle(
                                                      color: ThemeColor.error,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (!_isOwner || isOwnerMember)
                                        // Info icon for non-owner users or owner member
                                        IconButton(
                                          icon: Icon(
                                            Icons.info_outline,
                                            color: ThemeColor.textSecondary,
                                          ),
                                          onPressed: () =>
                                              _showMemberInfoDialog(member),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
