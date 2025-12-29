import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/datasource/memo_service.dart';
import 'package:voca_crm/data/datasource/user_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/data/repository/memo_repository_impl.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/memo.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';

/// 삭제 대기 메모 화면
/// STAFF: 삭제 대기 메모 목록 조회만 가능
/// MANAGER 이상: 복원 및 영구 삭제 가능
class DeletedMemosScreen extends StatefulWidget {
  final User user;
  final UserBusinessPlace currentBusinessPlace;

  const DeletedMemosScreen({
    super.key,
    required this.user,
    required this.currentBusinessPlace,
  });

  @override
  State<DeletedMemosScreen> createState() => _DeletedMemosScreenState();
}

class _DeletedMemosScreenState extends State<DeletedMemosScreen> {
  final _memoRepository = MemoRepositoryImpl(MemoService());
  final _memberRepository = MemberRepositoryImpl(MemberService());
  final _userService = UserService();
  final Map<String, String> _userNameCache = {};

  List<Memo> _deletedMemos = [];
  Map<String, Member> _deletedMemoMembers = {};
  bool _isLoading = false;

  bool get _canManage =>
      widget.currentBusinessPlace.role == Role.OWNER ||
      widget.currentBusinessPlace.role == Role.MANAGER;

  @override
  void initState() {
    super.initState();
    _loadDeletedMemos();
  }

  Future<void> _loadDeletedMemos() async {
    setState(() => _isLoading = true);

    try {
      final deletedMemos = await _memoRepository.getDeletedMemos(
        businessPlaceId: widget.currentBusinessPlace.businessPlaceId,
      );
      final Map<String, Member> memberCache = {};

      // Load member info for each deleted memo
      for (final memo in deletedMemos) {
        if (!memberCache.containsKey(memo.memberId)) {
          try {
            final member = await _memberRepository.getMemberById(memo.memberId);
            if (member != null) {
              memberCache[memo.memberId] = member;
            }
          } catch (e) {
            // Skip if member not found
          }
        }
      }

      setState(() {
        _deletedMemos = deletedMemos;
        _deletedMemoMembers = memberCache;
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

  Future<void> _showRestoreConfirmDialog(Memo memo, Member member) async {
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
                '메모 복원',
                style: TextStyle(
                  fontSize: screenWidth * 0.055,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
              Text(
                '\'${member.name}\' 고객의 메모를 복원하시겠습니까?',
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
                            await _memoRepository.restoreMemo(
                              memo.id,
                              userId: widget.user.id,
                              businessPlaceId:
                                  widget.currentBusinessPlace.businessPlaceId,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppMessageHandler.showSuccessSnackBar(
                                context,
                                '메모가 복원되었습니다',
                              );
                              _loadDeletedMemos();
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

  Future<void> _showPermanentDeleteConfirmDialog(Memo memo, Member member) async {
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
                '\'${member.name}\' 고객의 메모를 영구 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다!',
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
                            await _memoRepository.permanentDeleteMemo(
                              memo.id,
                              userId: widget.user.id,
                              businessPlaceId:
                                  widget.currentBusinessPlace.businessPlaceId,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppMessageHandler.showSuccessSnackBar(
                                context,
                                '메모가 영구 삭제되었습니다',
                              );
                              _loadDeletedMemos();
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
                          '삭제',
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

  void _showMemoDetailDialog(Member member, Memo memo) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
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
              // Close button at top right
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

              // Content
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
                      // Warning icon
                      Container(
                        width: screenWidth * 0.16,
                        height: screenWidth * 0.16,
                        decoration: BoxDecoration(
                          color: ThemeColor.warningSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.note_outlined,
                          size: screenWidth * 0.08,
                          color: ThemeColor.warning,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Member name
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

                      // Deleted badge
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

                      // Info card with details
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Member number
                            _buildDetailRow(
                              Icons.badge_outlined,
                              '회원 번호',
                              member.memberNumber,
                              screenWidth,
                              screenHeight,
                            ),
                            SizedBox(height: screenHeight * 0.015),
                            Divider(height: 1, color: ThemeColor.border),
                            SizedBox(height: screenHeight * 0.015),

                            // Memo content
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: screenWidth * 0.05,
                                  color: ThemeColor.textSecondary,
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '메모 내용',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.03,
                                          color: ThemeColor.textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.002),
                                      Text(
                                        memo.content,
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.0375,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.015),
                            Divider(height: 1, color: ThemeColor.border),
                            SizedBox(height: screenHeight * 0.015),

                            // Deleted at
                            _buildDetailRow(
                              Icons.access_time,
                              '삭제 요청 시간',
                              _formatDateTime(memo.deletedAt),
                              screenWidth,
                              screenHeight,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.03),

                      // Action buttons
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
                                      _showPermanentDeleteConfirmDialog(memo, member);
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
                                      _showRestoreConfirmDialog(memo, member);
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
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    double screenWidth,
    double screenHeight,
  ) {
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
        backgroundColor: ThemeColor.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: ThemeColor.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ThemeColor.textSecondary),
            tooltip: '새로고침',
            onPressed: _loadDeletedMemos,
          ),
          SizedBox(width: screenWidth * 0.02),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: screenWidth * 0.1,
                    height: screenWidth * 0.1,
                    child: CircularProgressIndicator(
                      color: ThemeColor.primary,
                      strokeWidth: screenWidth * 0.008,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    '삭제 대기 메모를 불러오는 중...',
                    style: TextStyle(
                      color: ThemeColor.textSecondary,
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDeletedMemos,
              color: ThemeColor.primary,
              child: _deletedMemos.isEmpty
                  ? _buildEmptyState(screenWidth, screenHeight)
                  : _buildMemoList(screenWidth, screenHeight),
            ),
    );
  }

  Widget _buildEmptyState(double screenWidth, double screenHeight) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: screenHeight * 0.2),
        Center(
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
                  '삭제 대기 중인 메모가 없습니다',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  '삭제된 메모는 이 화면에서\n관리할 수 있습니다',
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
        ),
      ],
    );
  }

  Widget _buildMemoList(double screenWidth, double screenHeight) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.015,
      ),
      itemCount: _deletedMemos.length,
      separatorBuilder: (context, index) => SizedBox(height: screenHeight * 0.01),
      itemBuilder: (context, index) {
        final memo = _deletedMemos[index];
        final member = _deletedMemoMembers[memo.memberId];

        // Skip if member not found
        if (member == null) {
          return const SizedBox.shrink();
        }

        return Material(
          color: ThemeColor.surface,
          borderRadius: BorderRadius.circular(screenWidth * 0.035),
          child: InkWell(
            onTap: () => _showMemoDetailDialog(member, memo),
            borderRadius: BorderRadius.circular(screenWidth * 0.035),
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(screenWidth * 0.035),
                border: Border.all(color: ThemeColor.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: screenWidth * 0.12,
                    height: screenWidth * 0.12,
                    decoration: BoxDecoration(
                      color: ThemeColor.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                    child: Center(
                      child: Text(
                        member.name.isNotEmpty ? member.name.substring(0, 1) : '?',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.w700,
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
                                fontWeight: FontWeight.w600,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.02,
                                vertical: screenHeight * 0.004,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeColor.neutral100,
                                borderRadius: BorderRadius.circular(screenWidth * 0.015),
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
                        SizedBox(height: screenHeight * 0.006),
                        Text(
                          memo.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: screenWidth * 0.033,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.004),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: screenWidth * 0.03,
                              color: ThemeColor.warning,
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              '삭제: ${_formatDateTime(memo.deletedAt)}',
                              style: TextStyle(
                                fontSize: screenWidth * 0.028,
                                color: ThemeColor.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: ThemeColor.neutral100,
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: ThemeColor.textTertiary,
                      size: screenWidth * 0.05,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
