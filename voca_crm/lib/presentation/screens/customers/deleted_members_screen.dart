import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/datasource/user_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';

/// 삭제 대기 화면
/// STAFF: 삭제 대기 회원 목록 조회만 가능
/// MANAGER 이상: 복원 및 영구 삭제 가능
class DeletedMembersScreen extends StatefulWidget {
  final User user;
  final UserBusinessPlace currentBusinessPlace;

  const DeletedMembersScreen({
    super.key,
    required this.user,
    required this.currentBusinessPlace,
  });

  @override
  State<DeletedMembersScreen> createState() => _DeletedMembersScreenState();
}

class _DeletedMembersScreenState extends State<DeletedMembersScreen> {
  final _memberRepository = MemberRepositoryImpl(MemberService());
  final _userService = UserService();
  final Map<String, String> _userNameCache = {};

  List<Member> _deletedMembers = [];
  bool _isLoading = false;

  bool get _canManage =>
      widget.currentBusinessPlace.role == Role.OWNER ||
      widget.currentBusinessPlace.role == Role.MANAGER;

  @override
  void initState() {
    super.initState();
    _loadDeletedMembers();
  }

  Future<void> _loadDeletedMembers() async {
    setState(() => _isLoading = true);

    try {
      final members = await _memberRepository.getDeletedMembers(
        businessPlaceId: widget.currentBusinessPlace.businessPlaceId,
      );
      setState(() {
        _deletedMembers = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.handleApiError(context, e);
      }
    }
  }

  Future<String> _getUserName(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return '정보 없음';
    }

    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      final user = await _userService.getUser(userId);
      final userName = user.username;
      _userNameCache[userId] = userName;
      return userName;
    } catch (e) {
      return '알 수 없음';
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showRestoreConfirmDialog(Member member) async {
    if (!_canManage) {
      AppMessageHandler.showErrorSnackBar(context, '복원 권한이 없습니다. MANAGER 이상만 가능합니다.');
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: screenWidth * 0.16,
                height: screenWidth * 0.16,
                decoration: BoxDecoration(
                  color: ThemeColor.successSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restore,
                  size: screenWidth * 0.08,
                  color: ThemeColor.success,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),
              Text(
                '고객 복원',
                style: TextStyle(
                  fontSize: screenWidth * 0.055,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
              Text(
                '\'${member.name}\' 고객과 관련 메모를 복원하시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  color: ThemeColor.textSecondary,
                  height: 1.5,
                ),
              ),
              SizedBox(height: screenHeight * 0.035),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: screenHeight * 0.06,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThemeColor.textSecondary,
                          side: BorderSide(color: ThemeColor.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.03,
                            ),
                          ),
                        ),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: SizedBox(
                      height: screenHeight * 0.06,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await _memberRepository.restoreMember(
                              member.id,
                              userId: widget.user.id,
                              businessPlaceId:
                                  widget.currentBusinessPlace.businessPlaceId,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppMessageHandler.showSuccessSnackBar(
                                context,
                                '고객이 복원되었습니다',
                              );
                              _loadDeletedMembers();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppMessageHandler.handleApiError(context, e);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeColor.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.03,
                            ),
                          ),
                        ),
                        child: Text(
                          '복원',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w700,
                          ),
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
  }

  Future<void> _showPermanentDeleteConfirmDialog(Member member) async {
    if (!_canManage) {
      AppMessageHandler.showErrorSnackBar(
        context,
        '영구 삭제 권한이 없습니다. MANAGER 이상만 가능합니다.',
      );
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: screenWidth * 0.16,
                height: screenWidth * 0.16,
                decoration: BoxDecoration(
                  color: ThemeColor.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever,
                  size: screenWidth * 0.08,
                  color: ThemeColor.error,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),
              Text(
                '영구 삭제',
                style: TextStyle(
                  fontSize: screenWidth * 0.055,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
              Text(
                '\'${member.name}\' 고객과 관련 메모를 영구 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  color: ThemeColor.textSecondary,
                  height: 1.5,
                ),
              ),
              SizedBox(height: screenHeight * 0.035),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: screenHeight * 0.06,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThemeColor.textSecondary,
                          side: BorderSide(color: ThemeColor.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.03,
                            ),
                          ),
                        ),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: SizedBox(
                      height: screenHeight * 0.06,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await _memberRepository.permanentDeleteMember(
                              member.id,
                              userId: widget.user.id,
                              businessPlaceId:
                                  widget.currentBusinessPlace.businessPlaceId,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppMessageHandler.showSuccessSnackBar(
                                context,
                                '고객이 영구 삭제되었습니다',
                              );
                              _loadDeletedMembers();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppMessageHandler.handleApiError(context, e);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeColor.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.03,
                            ),
                          ),
                        ),
                        child: Text(
                          '영구 삭제',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w700,
                          ),
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
  }

  Future<void> _showMemberDetailsDialog(Member member) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    String deletedByName = '로딩 중...';

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (deletedByName == '로딩 중...' && member.deletedBy != null) {
            _getUserName(member.deletedBy).then((name) {
              setDialogState(() {
                deletedByName = name;
              });
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.06),
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.9,
                maxHeight: screenHeight * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: ThemeColor.textSecondary,
                        size: screenWidth * 0.06,
                      ),
                      padding: EdgeInsets.all(screenWidth * 0.04),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        screenWidth * 0.08,
                        0,
                        screenWidth * 0.08,
                        screenWidth * 0.08,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: screenWidth * 0.16,
                            height: screenWidth * 0.16,
                            decoration: BoxDecoration(
                              color: ThemeColor.warningSurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_off,
                              size: screenWidth * 0.08,
                              color: ThemeColor.warning,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.025),
                          Text(
                            member.name,
                            style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.w700,
                              color: ThemeColor.textPrimary,
                              letterSpacing: screenWidth * -0.0012,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenHeight * 0.006,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColor.warning.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.02,
                              ),
                            ),
                            child: Text(
                              '삭제 대기',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: ThemeColor.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.04),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: ThemeColor.neutral50,
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                              border: Border.all(color: ThemeColor.border),
                            ),
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            child: Column(
                              children: [
                                _buildDetailRow(
                                  Icons.badge_outlined,
                                  '회원 번호',
                                  member.memberNumber,
                                ),
                                SizedBox(height: screenHeight * 0.015),
                                Divider(height: 1, color: ThemeColor.border),
                                SizedBox(height: screenHeight * 0.015),
                                if (member.phone != null) ...[
                                  _buildDetailRow(
                                    Icons.phone,
                                    '전화번호',
                                    member.phone!,
                                  ),
                                  SizedBox(height: screenHeight * 0.015),
                                  Divider(height: 1, color: ThemeColor.border),
                                  SizedBox(height: screenHeight * 0.015),
                                ],
                                _buildDetailRow(
                                  Icons.delete_outline,
                                  '삭제 요청자',
                                  deletedByName,
                                ),
                                SizedBox(height: screenHeight * 0.015),
                                Divider(height: 1, color: ThemeColor.border),
                                SizedBox(height: screenHeight * 0.015),
                                _buildDetailRow(
                                  Icons.access_time,
                                  '삭제 요청 시간',
                                  _formatDateTime(member.deletedAt),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.03),
                          if (_canManage)
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: screenHeight * 0.06,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _showPermanentDeleteConfirmDialog(
                                            member,
                                          );
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: ThemeColor.error,
                                        side: BorderSide(
                                          color: ThemeColor.error.withValues(alpha: 0.5),
                                          width: screenWidth * 0.004,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            screenWidth * 0.03,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.delete_forever,
                                        size: screenWidth * 0.045,
                                      ),
                                      label: Text(
                                        '영구 삭제',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.038,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                Expanded(
                                  child: SizedBox(
                                    height: screenHeight * 0.06,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _showRestoreConfirmDialog(member);
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ThemeColor.success,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            screenWidth * 0.03,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.restore,
                                        size: screenWidth * 0.045,
                                      ),
                                      label: Text(
                                        '복원',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.038,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: EdgeInsets.all(screenWidth * 0.03),
                              decoration: BoxDecoration(
                                color: ThemeColor.neutral100,
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.02,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: ThemeColor.textSecondary,
                                    size: screenWidth * 0.045,
                                  ),
                                  SizedBox(width: screenWidth * 0.02),
                                  Expanded(
                                    child: Text(
                                      'MANAGER 이상만 복원 또는 영구 삭제가 가능합니다.',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.032,
                                        color: ThemeColor.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: screenWidth * 0.05, color: ThemeColor.textSecondary),
        SizedBox(width: screenWidth * 0.03),
        Expanded(
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
              SizedBox(height: screenHeight * 0.002),
              Text(
                value,
                style: TextStyle(
                  fontSize: screenWidth * 0.0375,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
          icon: Icon(Icons.arrow_back_ios, color: ThemeColor.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: ThemeColor.textSecondary),
            tooltip: '새로고침',
            onPressed: _loadDeletedMembers,
          ),
          SizedBox(width: screenWidth * 0.02),
        ],
      ),
      body: Column(
        children: [
          // Info header
          Container(
            margin: EdgeInsets.all(screenWidth * 0.04),
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: ThemeColor.warningSurface,
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              border: Border.all(color: ThemeColor.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: ThemeColor.warning,
                  size: screenWidth * 0.055,
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '삭제 대기 중인 고객 목록',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.warning,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        _canManage
                            ? '복원하거나 영구 삭제할 수 있습니다.'
                            : 'MANAGER 이상만 복원 또는 삭제가 가능합니다.',
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          color: ThemeColor.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: ThemeColor.primary,
                    ),
                  )
                : _deletedMembers.isEmpty
                    ? _buildEmptyState(screenWidth, screenHeight)
                    : _buildDeletedMembersList(screenWidth, screenHeight),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedMembersList(double screenWidth, double screenHeight) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.01,
      ),
      itemCount: _deletedMembers.length,
      separatorBuilder: (context, index) => SizedBox(height: screenHeight * 0.01),
      itemBuilder: (context, index) {
        final member = _deletedMembers[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          child: InkWell(
            onTap: () => _showMemberDetailsDialog(member),
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Row(
                children: [
                  Container(
                    width: screenWidth * 0.12,
                    height: screenWidth * 0.12,
                    decoration: BoxDecoration(
                      color: ThemeColor.warning.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                    child: Center(
                      child: Text(
                        member.name.substring(0, 1),
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: ThemeColor.warning,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              member.name,
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.02,
                                vertical: screenHeight * 0.002,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeColor.neutral100,
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.01,
                                ),
                              ),
                              child: Text(
                                member.memberNumber,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.028,
                                  color: ThemeColor.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.005),
                        Text(
                          '삭제 요청: ${_formatDateTime(member.deletedAt)}',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: ThemeColor.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: ThemeColor.textTertiary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(double screenWidth, double screenHeight) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.08),
              decoration: BoxDecoration(
                color: ThemeColor.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                size: screenWidth * 0.2,
                color: ThemeColor.textTertiary,
              ),
            ),
            SizedBox(height: screenHeight * 0.04),
            Text(
              '삭제 대기 중인 고객이 없습니다',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: ThemeColor.textPrimary,
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            Text(
              '삭제된 고객은 이 화면에서\n관리할 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: ThemeColor.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
