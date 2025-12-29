import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voca_crm/core/notification/business_place_change_notifier.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/datasource/memo_service.dart';
import 'package:voca_crm/data/datasource/user_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/data/repository/memo_repository_impl.dart';
import 'package:voca_crm/domain/entity/business_place_with_role.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/memo.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';
import 'package:voca_crm/presentation/screens/main_screen.dart';
import 'package:voca_crm/presentation/screens/memos/deleted_memos_screen.dart';
import 'package:voca_crm/presentation/widgets/character_count_text_field.dart';
import 'package:voca_crm/presentation/widgets/member_search_dialog.dart';

class MemosScreen extends StatefulWidget {
  final User user;

  const MemosScreen({super.key, required this.user});

  @override
  State<MemosScreen> createState() => _MemosScreenState();
}

class _MemosScreenState extends State<MemosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _memberIdFilterController =
      TextEditingController();

  final _memberRepository = MemberRepositoryImpl(MemberService());
  final _memoRepository = MemoRepositoryImpl(MemoService());
  final _businessPlaceService = BusinessPlaceService();
  final _userService = UserService();

  // User name cache to avoid repeated API calls
  final Map<String, String> _userNameCache = {};

  String _searchQuery = '';
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  List<BusinessPlaceWithRole> _businessPlaces = [];
  Map<String, Memo?> _latestMemos = {};
  bool _isLoading = false;

  // Filter states
  String? _selectedBusinessPlaceFilter;
  String _memberIdFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFilterExpanded = false;

  // Business place change listener
  StreamSubscription<BusinessPlaceChangeEvent>?
  _businessPlaceChangeSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Set default business place filter to user's default
    _selectedBusinessPlaceFilter = widget.user.defaultBusinessPlaceId;
    _loadMembersWithMemos();
    _loadBusinessPlaces();

    // Listen to business place changes
    _businessPlaceChangeSubscription = BusinessPlaceChangeNotifier().stream
        .listen((event) {
          // Reload business places when any change occurs
          _loadBusinessPlaces();
        });
  }

  Future<void> _loadBusinessPlaces() async {
    try {
      final businessPlaces = await _businessPlaceService.getMyBusinessPlaces(
        widget.user.id,
      );
      if (!mounted) return;
      setState(() {
        _businessPlaces = businessPlaces;
      });
    } catch (e) {
      // Silent fail
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _memberIdFilterController.dispose();
    _businessPlaceChangeSubscription?.cancel();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _filteredMembers = _members.where((member) {
        // Member ID filter
        bool matchesMemberId = true;
        if (_memberIdFilter.isNotEmpty) {
          matchesMemberId = member.memberNumber.toLowerCase().contains(
            _memberIdFilter.toLowerCase(),
          );
        }

        // Date filter - check if member has memos in the date range
        bool matchesDateRange = true;
        if (_startDate != null || _endDate != null) {
          final memo = _latestMemos[member.id];
          if (memo != null) {
            if (_startDate != null && _endDate != null) {
              // Both dates set
              matchesDateRange =
                  memo.createdAt.isAfter(
                    _startDate!.subtract(const Duration(days: 1)),
                  ) &&
                  memo.createdAt.isBefore(
                    _endDate!.add(const Duration(days: 1)),
                  );
            } else if (_startDate != null) {
              // Only start date set
              matchesDateRange = memo.createdAt.isAfter(
                _startDate!.subtract(const Duration(days: 1)),
              );
            } else if (_endDate != null) {
              // Only end date set
              matchesDateRange = memo.createdAt.isBefore(
                _endDate!.add(const Duration(days: 1)),
              );
            }
          } else {
            matchesDateRange = false; // No memo, exclude from date filter
          }
        }

        return matchesMemberId && matchesDateRange;
      }).toList();
    });
  }

  Future<void> _loadMembersWithMemos() async {
    if (_selectedBusinessPlaceFilter == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Server-side filtering by business place
      final members = await _memberRepository.getMembersByBusinessPlace(
        _selectedBusinessPlaceFilter!,
      );
      final Map<String, Memo?> memos = {};

      for (final member in members) {
        try {
          final latestMemo = await _memoRepository.getLatestMemoByMemberId(
            member.id,
          );
          memos[member.id] = latestMemo;
        } catch (e) {
          memos[member.id] = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _filteredMembers = members;
        _latestMemos = memos;
        _isLoading = false;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppMessageHandler.handleApiError(context, e);
    }
  }

  /// 회원 검색 다이얼로그 표시 (공통 위젯 사용)
  ///
  /// [onMemberSelected] 회원 선택 시 콜백 (null이면 필터링용으로 사용)
  Future<void> _showMemberSearchDialog({
    Function(Member)? onMemberSelected,
  }) async {
    final result = await MemberSearchDialog.show(
      context: context,
      user: widget.user,
      initialBusinessPlaceId: widget.user.defaultBusinessPlaceId,
    );

    if (result != null) {
      if (onMemberSelected != null) {
        // 메모 추가 다이얼로그에서 호출된 경우
        onMemberSelected(result.member);
      } else {
        // 필터 검색에서 호출된 경우
        setState(() {
          _memberIdFilter = result.member.memberNumber;
          _memberIdFilterController.text = result.member.memberNumber;
          _applyFilters();
        });
      }
    }
  }

  Future<void> _showAddMemoDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    Member? selectedMember;
    final contentController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                        // Large circular icon
                        Container(
                          width: screenWidth * 0.16,
                          height: screenWidth * 0.16,
                          decoration: BoxDecoration(
                            color: ThemeColor.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_note,
                            size: screenWidth * 0.08,
                            color: ThemeColor.primary,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.025),

                        // Large title
                        Text(
                          '메모 작성',
                          style: TextStyle(
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.w700,
                            color: ThemeColor.textPrimary,
                            letterSpacing: screenWidth * -0.0012,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.01),

                        // Subtitle
                        Text(
                          '고객 상담 내용을 기록하세요',
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            color: ThemeColor.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Customer selection label
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '고객 선택',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.w600,
                              color: ThemeColor.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),

                        // Member selection button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              await _showMemberSearchDialog(
                                onMemberSelected: (member) {
                                  setDialogState(() {
                                    selectedMember = member;
                                  });
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.03,
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.045,
                                vertical: screenHeight * 0.02,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selectedMember != null
                                      ? ThemeColor.primary.withValues(
                                          alpha: 0.3,
                                        )
                                      : ThemeColor.border,
                                  width: screenWidth * 0.004,
                                ),
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                color: selectedMember != null
                                    ? ThemeColor.primary.withValues(alpha: 0.05)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  if (selectedMember != null) ...[
                                    Container(
                                      width: screenWidth * 0.09,
                                      height: screenWidth * 0.09,
                                      decoration: BoxDecoration(
                                        color: ThemeColor.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          screenWidth * 0.02,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          selectedMember!.name.substring(0, 1),
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.04,
                                            fontWeight: FontWeight.bold,
                                            color: ThemeColor.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: screenWidth * 0.03),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedMember!.name,
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.042,
                                              fontWeight: FontWeight.w600,
                                              color: ThemeColor.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            selectedMember!.memberNumber,
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.035,
                                              color: ThemeColor.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(
                                      Icons.person_search,
                                      color: ThemeColor.textTertiary,
                                      size: screenWidth * 0.05,
                                    ),
                                    SizedBox(width: screenWidth * 0.03),
                                    Expanded(
                                      child: Text(
                                        '고객을 검색하여 선택하세요',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.038,
                                          color: ThemeColor.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: ThemeColor.primary,
                                    size: screenWidth * 0.04,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        // Memo content label
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '메모 내용',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.w600,
                              color: ThemeColor.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),

                        // Clean outline input field
                        CharacterCountTextField(
                          controller: contentController,
                          hintText: '상담 내용을 자세히 기록하세요',
                          maxLength: InputLimits.memoContent,
                          maxLines: 5,
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Full-width primary button
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.065,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (selectedMember == null) {
                                AppMessageHandler.showErrorSnackBar(
                                  context,
                                  '고객을 선택하세요',
                                );
                                return;
                              }
                              if (contentController.text.isEmpty) {
                                AppMessageHandler.showErrorSnackBar(
                                  context,
                                  '메모 내용을 입력하세요',
                                );
                                return;
                              }

                              try {
                                await _memoRepository.createMemo(
                                  memberId: selectedMember!.id,
                                  content: contentController.text,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  AppMessageHandler.showSuccessSnackBar(
                                    context,
                                    '메모가 작성되었습니다',
                                  );
                                  _loadMembersWithMemos();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  // Check if it's memo limit exceeded error
                                  String errorMsg = e.toString();
                                  if (errorMsg.contains(
                                    'MEMO_LIMIT_EXCEEDED',
                                  )) {
                                    // Extract max memos from error message
                                    String maxMemos = '100';
                                    if (errorMsg.contains(':')) {
                                      maxMemos = errorMsg
                                          .split(':')
                                          .last
                                          .trim();
                                    }

                                    // Show confirmation dialog
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            screenWidth * 0.06,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: ThemeColor.warning,
                                            ),
                                            SizedBox(width: screenWidth * 0.02),
                                            Text(
                                              '메모 개수 초과',
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.05,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          '회원의 메모는 최대 $maxMemos개까지 저장 가능합니다.\n가장 오래된 메모를 삭제하고 저장하겠습니까?',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.04,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogCtx, false),
                                            child: Text('아니요'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogCtx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  ThemeColor.primary,
                                            ),
                                            child: Text('예'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      // Delete oldest and create new
                                      try {
                                        await _memoRepository
                                            .createMemoWithDeletion(
                                              memberId: selectedMember!.id,
                                              content: contentController.text,
                                            );

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          AppMessageHandler.showSuccessSnackBar(
                                            context,
                                            '가장 오래된 메모가 삭제되고 새 메모가 작성되었습니다',
                                          );
                                          _loadMembersWithMemos();
                                        }
                                      } catch (e2) {
                                        if (context.mounted) {
                                          AppMessageHandler.handleApiError(
                                            context,
                                            e2,
                                          );
                                        }
                                      }
                                    }
                                  } else {
                                    AppMessageHandler.handleApiError(context, e);
                                  }
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeColor.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                              ),
                            ),
                            child: Text(
                              '저장',
                              style: TextStyle(
                                fontSize: screenWidth * 0.043,
                                fontWeight: FontWeight.w700,
                                letterSpacing: screenWidth * -0.0008,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMemberMemos(Member member) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    List<Memo> memos = await _memoRepository.getMemosByMemberId(member.id);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Reload memos function
          Future<void> reloadMemos() async {
            final newMemos = await _memoRepository.getMemosByMemberId(
              member.id,
            );
            setDialogState(() {
              memos = newMemos;
            });
            _loadMembersWithMemos(); // Also refresh main list
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
                maxHeight: screenHeight * 0.85,
                maxWidth: screenWidth * 0.9,
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

                  // Header with icon and title
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      screenWidth * 0.08,
                      0,
                      screenWidth * 0.08,
                      screenHeight * 0.02,
                    ),
                    child: Column(
                      children: [
                        // Large circular icon
                        Container(
                          width: screenWidth * 0.16,
                          height: screenWidth * 0.16,
                          decoration: BoxDecoration(
                            color: ThemeColor.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            size: screenWidth * 0.08,
                            color: ThemeColor.primary,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.025),

                        // Member name as title
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

                        // Subtitle with memo count
                        Text(
                          '전체 메모 ${memos.length}개',
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            color: ThemeColor.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Divider(height: 1, color: ThemeColor.border),

                  // Memos list or empty state
                  if (memos.isEmpty)
                    Expanded(
                      child: Center(
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
                                  Icons.note_outlined,
                                  size: screenWidth * 0.16,
                                  color: ThemeColor.textTertiary,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.02),
                              Text(
                                '작성된 메모가 없습니다',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: ThemeColor.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.01),
                              Text(
                                '첫 메모를 작성해보세요',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: ThemeColor.neutral500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        itemCount: memos.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: screenHeight * 0.015),
                        itemBuilder: (context, index) {
                          final memo = memos[index];
                          final isFirst = index == 0;

                          return GestureDetector(
                            onTap: () => _showEditMemoDialog(
                              memo,
                              member,
                              reloadMemos,
                              screenWidth,
                              screenHeight,
                            ),
                            child: Container(
                              padding: EdgeInsets.all(screenWidth * 0.04),
                              decoration: BoxDecoration(
                                color: isFirst
                                    ? ThemeColor.primary.withValues(alpha: 0.05)
                                    : ThemeColor.neutral50,
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                border: Border.all(
                                  color: isFirst
                                      ? ThemeColor.primary.withValues(
                                          alpha: 0.3,
                                        )
                                      : ThemeColor.border,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row with badge and actions
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Left side: badges
                                      Row(
                                        children: [
                                          if (memo.isImportant)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: screenWidth * 0.02,
                                                vertical: screenHeight * 0.002,
                                              ),
                                              margin: EdgeInsets.only(
                                                right: screenWidth * 0.01,
                                              ),
                                              decoration: BoxDecoration(
                                                color: ThemeColor.warning,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      screenWidth * 0.015,
                                                    ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    size: screenWidth * 0.03,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(
                                                    width: screenWidth * 0.01,
                                                  ),
                                                  Text(
                                                    '중요',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.025,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (isFirst && !memo.isImportant)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: screenWidth * 0.025,
                                                vertical: screenHeight * 0.003,
                                              ),
                                              decoration: BoxDecoration(
                                                color: ThemeColor.primary,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      screenWidth * 0.02,
                                                    ),
                                              ),
                                              child: Text(
                                                '최신',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.025,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      // Right side: action buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Important toggle
                                          InkWell(
                                            onTap: () async {
                                              try {
                                                await _memoRepository
                                                    .toggleImportant(memo.id);
                                                reloadMemos();
                                                AppMessageHandler.showSuccessSnackBar(
                                                  context,
                                                  memo.isImportant
                                                      ? '중요 메모 해제'
                                                      : '중요 메모로 설정',
                                                );
                                              } catch (e) {
                                                AppMessageHandler.showErrorSnackBar(
                                                  context,
                                                  '오류가 발생했습니다',
                                                );
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(
                                              screenWidth * 0.02,
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(
                                                screenWidth * 0.015,
                                              ),
                                              child: Icon(
                                                memo.isImportant
                                                    ? Icons.star
                                                    : Icons.star_outline,
                                                size: screenWidth * 0.045,
                                                color: memo.isImportant
                                                    ? ThemeColor.warning
                                                    : ThemeColor.textSecondary,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => _showEditMemoDialog(
                                              memo,
                                              member,
                                              reloadMemos,
                                              screenWidth,
                                              screenHeight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              screenWidth * 0.02,
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(
                                                screenWidth * 0.015,
                                              ),
                                              child: Icon(
                                                Icons.edit_outlined,
                                                size: screenWidth * 0.045,
                                                color: ThemeColor.textSecondary,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => _confirmDeleteMemo(
                                              memo,
                                              reloadMemos,
                                              screenWidth,
                                              screenHeight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              screenWidth * 0.02,
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(
                                                screenWidth * 0.015,
                                              ),
                                              child: Icon(
                                                Icons.delete_outline,
                                                size: screenWidth * 0.045,
                                                color: ThemeColor.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isFirst)
                                    SizedBox(height: screenHeight * 0.01),
                                  // Content
                                  Text(
                                    memo.content,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.0375,
                                      height: 1.5,
                                      color: ThemeColor.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.015),
                                  // Author/Modifier info
                                  FutureBuilder<String>(
                                    future: _getUserName(memo.ownerId),
                                    builder: (context, authorSnapshot) {
                                      final authorName =
                                          authorSnapshot.data ?? '로딩중...';
                                      return FutureBuilder<String>(
                                        future: _getUserName(
                                          memo.lastModifiedById,
                                        ),
                                        builder: (context, modifierSnapshot) {
                                          final modifierName =
                                              modifierSnapshot.data;
                                          final hasModifier =
                                              memo.lastModifiedById != null &&
                                              memo.lastModifiedById!.isNotEmpty;

                                          return Container(
                                            padding: EdgeInsets.all(
                                              screenWidth * 0.025,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ThemeColor.neutral100,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    screenWidth * 0.02,
                                                  ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Created info
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.person_outline,
                                                      size: screenWidth * 0.035,
                                                      color: ThemeColor
                                                          .textSecondary,
                                                    ),
                                                    SizedBox(
                                                      width: screenWidth * 0.01,
                                                    ),
                                                    Text(
                                                      '작성: $authorName',
                                                      style: TextStyle(
                                                        fontSize:
                                                            screenWidth * 0.028,
                                                        color: ThemeColor
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: screenWidth * 0.03,
                                                    ),
                                                    Icon(
                                                      Icons.access_time,
                                                      size: screenWidth * 0.03,
                                                      color: ThemeColor
                                                          .textTertiary,
                                                    ),
                                                    SizedBox(
                                                      width: screenWidth * 0.01,
                                                    ),
                                                    Text(
                                                      _formatDateTime(
                                                        memo.createdAt,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize:
                                                            screenWidth * 0.028,
                                                        color: ThemeColor
                                                            .textTertiary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // Modified info (only if modified)
                                                if (hasModifier &&
                                                    memo.updatedAt !=
                                                        memo.createdAt) ...[
                                                  SizedBox(
                                                    height:
                                                        screenHeight * 0.005,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit_note,
                                                        size:
                                                            screenWidth * 0.035,
                                                        color: ThemeColor
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                      ),
                                                      SizedBox(
                                                        width:
                                                            screenWidth * 0.01,
                                                      ),
                                                      Text(
                                                        '수정: ${modifierName ?? '로딩중...'}',
                                                        style: TextStyle(
                                                          fontSize:
                                                              screenWidth *
                                                              0.028,
                                                          color: ThemeColor
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.7,
                                                              ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width:
                                                            screenWidth * 0.03,
                                                      ),
                                                      Icon(
                                                        Icons.access_time,
                                                        size:
                                                            screenWidth * 0.03,
                                                        color: ThemeColor
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                      SizedBox(
                                                        width:
                                                            screenWidth * 0.01,
                                                      ),
                                                      Text(
                                                        _formatDateTime(
                                                          memo.updatedAt,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize:
                                                              screenWidth *
                                                              0.028,
                                                          color: ThemeColor
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.6,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

  // Show edit memo dialog
  Future<void> _showEditMemoDialog(
    Memo memo,
    Member member,
    Future<void> Function() reloadMemos,
    double screenWidth,
    double screenHeight,
  ) async {
    final contentController = TextEditingController(text: memo.content);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                          // Large circular icon
                          Container(
                            width: screenWidth * 0.16,
                            height: screenWidth * 0.16,
                            decoration: BoxDecoration(
                              color: ThemeColor.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit_note,
                              size: screenWidth * 0.08,
                              color: ThemeColor.primary,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.025),

                          // Large title
                          Text(
                            '메모 수정',
                            style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.w700,
                              color: ThemeColor.textPrimary,
                              letterSpacing: screenWidth * -0.0012,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.01),

                          // Member name
                          Text(
                            member.name,
                            style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              color: ThemeColor.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.03),

                          // Info section (creator, modifier, dates)
                          FutureBuilder<String>(
                            future: _getUserName(memo.ownerId),
                            builder: (context, authorSnapshot) {
                              return FutureBuilder<String>(
                                future: _getUserName(memo.lastModifiedById),
                                builder: (context, modifierSnapshot) {
                                  final authorName =
                                      authorSnapshot.data ?? '로딩중...';
                                  final modifierName = modifierSnapshot.data;
                                  final hasModifier =
                                      memo.lastModifiedById != null &&
                                      memo.lastModifiedById!.isNotEmpty;

                                  return Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(screenWidth * 0.04),
                                    decoration: BoxDecoration(
                                      color: ThemeColor.neutral50,
                                      borderRadius: BorderRadius.circular(
                                        screenWidth * 0.03,
                                      ),
                                      border: Border.all(
                                        color: ThemeColor.border,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildInfoRow(
                                          icon: Icons.person_outline,
                                          label: '작성자',
                                          value: authorName,
                                          screenWidth: screenWidth,
                                        ),
                                        SizedBox(height: screenHeight * 0.008),
                                        _buildInfoRow(
                                          icon: Icons.calendar_today_outlined,
                                          label: '작성일',
                                          value: _formatDateTime(
                                            memo.createdAt,
                                          ),
                                          screenWidth: screenWidth,
                                        ),
                                        if (hasModifier &&
                                            memo.updatedAt !=
                                                memo.createdAt) ...[
                                          SizedBox(
                                            height: screenHeight * 0.008,
                                          ),
                                          Divider(
                                            color: ThemeColor.border,
                                            height: 1,
                                          ),
                                          SizedBox(
                                            height: screenHeight * 0.008,
                                          ),
                                          _buildInfoRow(
                                            icon: Icons.edit_outlined,
                                            label: '수정자',
                                            value: modifierName ?? '-',
                                            screenWidth: screenWidth,
                                            isHighlighted: true,
                                          ),
                                          SizedBox(
                                            height: screenHeight * 0.008,
                                          ),
                                          _buildInfoRow(
                                            icon: Icons.update,
                                            label: '수정일',
                                            value: _formatDateTime(
                                              memo.updatedAt,
                                            ),
                                            screenWidth: screenWidth,
                                            isHighlighted: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          SizedBox(height: screenHeight * 0.025),

                          // Memo content label
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '메모 내용',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w600,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),

                          // Clean outline input field
                          CharacterCountTextField(
                            controller: contentController,
                            hintText: '메모 내용을 입력하세요',
                            maxLength: InputLimits.memoContent,
                            maxLines: 5,
                          ),

                          SizedBox(height: screenHeight * 0.04),

                          // Full-width primary button
                          SizedBox(
                            width: double.infinity,
                            height: screenHeight * 0.065,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (contentController.text.isEmpty) {
                                  AppMessageHandler.showErrorSnackBar(
                                    context,
                                    '메모 내용을 입력하세요',
                                  );
                                  return;
                                }

                                final businessPlaceId =
                                    widget.user.defaultBusinessPlaceId;
                                if (businessPlaceId == null ||
                                    businessPlaceId.isEmpty) {
                                  if (context.mounted) {
                                    AppMessageHandler.showErrorSnackBar(
                                      context,
                                      '사업장 정보가 없어 메모를 수정할 수 없습니다.',
                                    );
                                  }
                                  return;
                                }

                                try {
                                  final updatedMemo = memo.copyWith(
                                    content: contentController.text,
                                  );

                                  await _memoRepository.updateMemo(
                                    updatedMemo,
                                    userId: widget.user.id,
                                    businessPlaceId: businessPlaceId,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    AppMessageHandler.showSuccessSnackBar(
                                      context,
                                      '메모가 수정되었습니다',
                                    );
                                    await reloadMemos();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppMessageHandler.handleApiError(context, e);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeColor.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                ),
                              ),
                              child: Text(
                                '저장',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.043,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: screenWidth * -0.0008,
                                ),
                              ),
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

  // Info row builder for edit dialog
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required double screenWidth,
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: screenWidth * 0.04,
          color: isHighlighted ? ThemeColor.primary : ThemeColor.textTertiary,
        ),
        SizedBox(width: screenWidth * 0.02),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: screenWidth * 0.032,
            color: ThemeColor.textSecondary,
          ),
        ),
        SizedBox(width: screenWidth * 0.02),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.032,
              fontWeight: FontWeight.w500,
              color: isHighlighted
                  ? ThemeColor.primary
                  : ThemeColor.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // Confirm delete memo dialog
  Future<void> _confirmDeleteMemo(
    Memo memo,
    Future<void> Function() reloadMemos,
    double screenWidth,
    double screenHeight,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
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
              // Warning icon
              Container(
                width: screenWidth * 0.16,
                height: screenWidth * 0.16,
                decoration: BoxDecoration(
                  color: ThemeColor.warningSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: screenWidth * 0.08,
                  color: ThemeColor.warning,
                ),
              ),

              SizedBox(height: screenHeight * 0.025),

              // Title
              Text(
                '메모 삭제',
                style: TextStyle(
                  fontSize: screenWidth * 0.055,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.textPrimary,
                ),
              ),

              SizedBox(height: screenHeight * 0.015),

              // Message
              Text(
                '이 메모를 삭제하시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  color: ThemeColor.textSecondary,
                  height: 1.5,
                ),
              ),

              SizedBox(height: screenHeight * 0.01),

              // Info box
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: ThemeColor.infoSurface,
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  border: Border.all(
                    color: ThemeColor.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: ThemeColor.info,
                      size: screenWidth * 0.045,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: Text(
                        '삭제된 메모는 삭제 대기 화면에서 복원할 수 있습니다.',
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          color: ThemeColor.info,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.035),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: screenHeight * 0.06,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
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
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeColor.warning,
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

    if (confirm == true) {
      final businessPlaceId = widget.user.defaultBusinessPlaceId;
      if (businessPlaceId == null || businessPlaceId.isEmpty) {
        if (mounted) {
          AppMessageHandler.showErrorSnackBar(context, '사업장 정보가 없어 메모를 삭제할 수 없습니다.');
        }
        return;
      }

      try {
        await _memoRepository.softDeleteMemo(
          memo.id,
          userId: widget.user.id,
          businessPlaceId: businessPlaceId,
        );

        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '메모가 삭제 대기 상태로 전환되었습니다');
          await reloadMemos();
        }
      } catch (e) {
        if (mounted) {
          AppMessageHandler.handleApiError(context, e);
        }
      }
    }
  }

  /// 삭제 대기 메모 화면으로 이동
  Future<void> _showDeletedMemosScreen() async {
    if (_businessPlaces.isEmpty) {
      AppMessageHandler.showErrorSnackBar(
        context,
        '사업장 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.',
      );
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 사업장이 1개면 바로 이동, 여러 개면 선택 다이얼로그
    if (_businessPlaces.length == 1) {
      final bp = _businessPlaces.first;
      final now = DateTime.now();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeletedMemosScreen(
            user: widget.user,
            currentBusinessPlace: UserBusinessPlace(
              id: bp.businessPlace.id,
              userId: widget.user.id,
              businessPlaceId: bp.businessPlace.id,
              role: bp.userRole,
              status: AccessStatus.APPROVED,
              createdAt: now,
              updatedAt: now,
            ),
          ),
        ),
      );
      // 삭제 대기 화면에서 복원 후 돌아오면 새로고침
      _loadMembersWithMemos();
      return;
    }

    // 사업장 선택 다이얼로그
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.5),
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '삭제 대기 조회',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                '사업장을 선택해주세요',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: ThemeColor.textSecondary,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _businessPlaces.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bp = _businessPlaces[index];
                    final now = DateTime.now();
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                        vertical: screenHeight * 0.005,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: ThemeColor.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Icon(
                          Icons.store,
                          color: ThemeColor.primary,
                          size: screenWidth * 0.05,
                        ),
                      ),
                      title: Text(
                        bp.businessPlace.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        bp.userRole.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: ThemeColor.textTertiary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeletedMemosScreen(
                                user: widget.user,
                                currentBusinessPlace: UserBusinessPlace(
                                  id: bp.businessPlace.id,
                                  userId: widget.user.id,
                                  businessPlaceId: bp.businessPlace.id,
                                  role: bp.userRole,
                                  status: AccessStatus.APPROVED,
                                  createdAt: now,
                                  updatedAt: now,
                                ),
                              ),
                            ),
                          );
                          // 삭제 대기 화면에서 복원 후 돌아오면 새로고침
                          _loadMembersWithMemos();
                        });
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      color: ThemeColor.textSecondary,
                      fontSize: screenWidth * 0.038,
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Filter members with memos for each category
    final allMembers = _filteredMembers
        .where((m) => _latestMemos[m.id] != null)
        .toList();
    final importantMembers = <Member>[]; // TODO: Implement important flag

    return Scaffold(
      backgroundColor: ThemeColor.neutral50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ThemeColor.warningSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: ThemeColor.warning,
                size: screenWidth * 0.05,
              ),
            ),
            tooltip: '삭제 대기',
            onPressed: _showDeletedMemosScreen,
          ),
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: ThemeColor.textSecondary),
            tooltip: '새로고침',
            onPressed: _loadMembersWithMemos,
          ),
          SizedBox(width: screenWidth * 0.02),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: ThemeColor.primary,
          unselectedLabelColor: ThemeColor.textSecondary,
          indicatorColor: ThemeColor.primary,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.035,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: screenWidth * 0.035,
          ),
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '중요'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: ThemeColor.primary))
          : Column(
              children: [
                // Business Place Selector (Salesforce/Notion/Trello style)
                _buildBusinessPlaceSelector(screenWidth, screenHeight),

                // Toss/Karrot style Search Filter
                _buildSearchFilter(screenWidth, screenHeight),

                // TabBarView with Pull-to-Refresh
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        onRefresh: _loadMembersWithMemos,
                        color: ThemeColor.primary,
                        child: _buildMemoList(allMembers, '전체'),
                      ),
                      RefreshIndicator(
                        onRefresh: _loadMembersWithMemos,
                        color: ThemeColor.primary,
                        child: _buildMemoList(importantMembers, '중요'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'memos_fab',
        onPressed: _showAddMemoDialog,
        backgroundColor: ThemeColor.primary,
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: const Text(
          '메모 작성',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  // Helper method to get user name
  Future<String> _getUserName(String? userId) async {
    if (userId == null || userId.isEmpty) return '알 수 없음';

    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      final user = await _userService.getUser(userId);
      _userNameCache[userId] = user.username;
      return user.username;
    } catch (e) {
      return '알 수 없음';
    }
  }

  // Format datetime to Korean style
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Business Place Selector Widget (Salesforce/Notion/Trello style)
  Widget _buildBusinessPlaceSelector(double screenWidth, double screenHeight) {
    if (_businessPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedPlace = _businessPlaces.firstWhere(
      (bp) => bp.businessPlace.id == _selectedBusinessPlaceFilter,
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
          width: screenWidth * 0.004,
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
          onTap: () =>
              _showBusinessPlaceSelectorDialog(screenWidth, screenHeight),
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
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.6),
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.store_rounded, color: ThemeColor.primary),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    '사업장 선택',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _businessPlaces.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bp = _businessPlaces[index];
                    final isSelected =
                        bp.businessPlace.id == _selectedBusinessPlaceFilter;

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
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
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
                        if (_selectedBusinessPlaceFilter !=
                            bp.businessPlace.id) {
                          setState(() {
                            _selectedBusinessPlaceFilter = bp.businessPlace.id;
                          });
                          Navigator.pop(dialogContext);
                          _loadMembersWithMemos(); // Reload memos with new business place
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

  Widget _buildSearchFilter(double screenWidth, double screenHeight) {
    final hasActiveFilters =
        _memberIdFilter.isNotEmpty || _startDate != null || _endDate != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.01,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsed Header - Always visible
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isFilterExpanded = !_isFilterExpanded;
                });
              },
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.045,
                  vertical: screenHeight * 0.018,
                ),
                child: Row(
                  children: [
                    // Filter icon with gradient background
                    Container(
                      width: screenWidth * 0.09,
                      height: screenWidth * 0.09,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ThemeColor.primary.withValues(alpha: 0.1),
                            ThemeColor.primary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          screenWidth * 0.025,
                        ),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: ThemeColor.primary,
                        size: screenWidth * 0.05,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.035),
                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '검색 조건',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w600,
                              color: ThemeColor.textPrimary,
                              letterSpacing: screenWidth * -0.0008,
                            ),
                          ),
                          if (!_isFilterExpanded && hasActiveFilters)
                            Padding(
                              padding: EdgeInsets.only(
                                top: screenHeight * 0.004,
                              ),
                              child: Text(
                                _getActiveFilterSummary(),
                                style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: ThemeColor.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Active filter badge
                    if (hasActiveFilters && !_isFilterExpanded)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.025,
                          vertical: screenHeight * 0.005,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeColor.primary,
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.04,
                          ),
                        ),
                        child: Text(
                          _getActiveFilterCount().toString(),
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    SizedBox(width: screenWidth * 0.02),
                    // Expand/Collapse icon
                    AnimatedRotation(
                      turns: _isFilterExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: ThemeColor.textTertiary,
                        size: screenWidth * 0.06,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterContent(screenWidth, screenHeight),
            crossFadeState: _isFilterExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  String _getActiveFilterSummary() {
    List<String> filters = [];
    if (_memberIdFilter.isNotEmpty) {
      filters.add('ID: $_memberIdFilter');
    }
    if (_startDate != null) {
      filters.add('시작: ${_startDate!.month}/${_startDate!.day}');
    }
    if (_endDate != null) {
      filters.add('종료: ${_endDate!.month}/${_endDate!.day}');
    }
    return filters.join(' · ');
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_memberIdFilter.isNotEmpty) count++;
    if (_startDate != null) count++;
    if (_endDate != null) count++;
    return count;
  }

  Widget _buildFilterContent(double screenWidth, double screenHeight) {
    final hasActiveFilters =
        _memberIdFilter.isNotEmpty || _startDate != null || _endDate != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.045,
        0,
        screenWidth * 0.045,
        screenWidth * 0.045,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(height: 1, color: ThemeColor.neutral100),
          SizedBox(height: screenHeight * 0.02),

          // Member ID Filter
          Text(
            '회원 ID',
            style: TextStyle(
              fontSize: screenWidth * 0.032,
              fontWeight: FontWeight.w600,
              color: ThemeColor.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: screenHeight * 0.008),
          Container(
            decoration: BoxDecoration(
              color: ThemeColor.neutral50,
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              border: Border.all(
                color: _memberIdFilter.isNotEmpty
                    ? ThemeColor.primary.withValues(alpha: 0.3)
                    : ThemeColor.border,
              ),
            ),
            child: TextField(
              controller: _memberIdFilterController,
              onChanged: (value) {
                setState(() {
                  _memberIdFilter = value;
                  _applyFilters();
                });
              },
              style: TextStyle(
                fontSize: screenWidth * 0.038,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '회원 ID 검색',
                hintStyle: TextStyle(
                  color: ThemeColor.textTertiary,
                  fontSize: screenWidth * 0.036,
                ),
                prefixIcon: Icon(
                  Icons.tag,
                  color: ThemeColor.textTertiary,
                  size: screenWidth * 0.05,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_memberIdFilter.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: ThemeColor.textTertiary,
                          size: screenWidth * 0.045,
                        ),
                        onPressed: () {
                          _memberIdFilterController.clear();
                          setState(() {
                            _memberIdFilter = '';
                            _applyFilters();
                          });
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.search,
                        color: ThemeColor.primary,
                        size: screenWidth * 0.05,
                      ),
                      onPressed: _showMemberSearchDialog,
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.015,
                ),
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.02),

          // Date Range Filter
          Text(
            '기간',
            style: TextStyle(
              fontSize: screenWidth * 0.032,
              fontWeight: FontWeight.w600,
              color: ThemeColor.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: screenHeight * 0.008),
          Row(
            children: [
              Expanded(
                child: _buildDateFilterButton(
                  label: _startDate != null
                      ? '${_startDate!.month}/${_startDate!.day}'
                      : '시작일',
                  isSelected: _startDate != null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        _applyFilters();
                      });
                    }
                  },
                  onClear: _startDate != null
                      ? () {
                          setState(() {
                            _startDate = null;
                            _applyFilters();
                          });
                        }
                      : null,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                child: Text(
                  '~',
                  style: TextStyle(
                    color: ThemeColor.textTertiary,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              Expanded(
                child: _buildDateFilterButton(
                  label: _endDate != null
                      ? '${_endDate!.month}/${_endDate!.day}'
                      : '종료일',
                  isSelected: _endDate != null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _endDate = picked;
                        _applyFilters();
                      });
                    }
                  },
                  onClear: _endDate != null
                      ? () {
                          setState(() {
                            _endDate = null;
                            _applyFilters();
                          });
                        }
                      : null,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
              ),
            ],
          ),

          // Reset Filter Button
          if (hasActiveFilters) ...[
            SizedBox(height: screenHeight * 0.02),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _memberIdFilter = '';
                    _startDate = null;
                    _endDate = null;
                    _memberIdFilterController.clear();
                    _applyFilters();
                  });
                },
                icon: Icon(Icons.refresh_rounded, size: screenWidth * 0.045),
                label: Text(
                  '필터 초기화',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: ThemeColor.textSecondary,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required double screenWidth,
    required double screenHeight,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.035,
          vertical: screenHeight * 0.01,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? ThemeColor.primary.withValues(alpha: 0.1)
              : ThemeColor.neutral100,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          border: Border.all(
            color: isSelected
                ? ThemeColor.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.033,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? ThemeColor.primary : ThemeColor.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onClear,
    required double screenWidth,
    required double screenHeight,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.035,
          vertical: screenHeight * 0.012,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? ThemeColor.primary.withValues(alpha: 0.1)
              : ThemeColor.neutral50,
          borderRadius: BorderRadius.circular(screenWidth * 0.025),
          border: Border.all(
            color: isSelected
                ? ThemeColor.primary.withValues(alpha: 0.3)
                : ThemeColor.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: screenWidth * 0.04,
              color: isSelected ? ThemeColor.primary : ThemeColor.textTertiary,
            ),
            SizedBox(width: screenWidth * 0.02),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.033,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? ThemeColor.primary
                      : ThemeColor.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: screenWidth * 0.04,
                  color: ThemeColor.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoList(List<Member> members, String category) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (members.isEmpty) {
      return _buildEmptyState(category);
    }

    final bottomNavPadding =
        MainScreen.navBarHeight + MediaQuery.of(context).padding.bottom;

    return ListView.separated(
      padding: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: screenHeight * 0.02,
        bottom: bottomNavPadding,
      ),
      itemCount: members.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: screenHeight * 0.015),
      itemBuilder: (context, index) {
        final member = members[index];
        final latestMemo = _latestMemos[member.id];

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          child: InkWell(
            onTap: () => _showMemberMemos(member),
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: screenWidth * 0.1,
                        height: screenWidth * 0.1,
                        decoration: BoxDecoration(
                          color: ThemeColor.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            member.name.substring(0, 1),
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.bold,
                              color: ThemeColor.primary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                            if (latestMemo != null)
                              Text(
                                '${latestMemo.createdAt.year}-${latestMemo.createdAt.month.toString().padLeft(2, '0')}-${latestMemo.createdAt.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.03,
                                  color: ThemeColor.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: ThemeColor.textTertiary),
                    ],
                  ),
                  if (latestMemo != null) ...[
                    SizedBox(height: screenHeight * 0.015),
                    Container(
                      padding: EdgeInsets.all(screenWidth * 0.03),
                      decoration: BoxDecoration(
                        color: ThemeColor.neutral50,
                        borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      ),
                      child: Text(
                        latestMemo.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: ThemeColor.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String category) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    String title;
    String subtitle;

    switch (category) {
      case '중요':
        title = '중요 메모가 없습니다';
        subtitle = '중요한 메모를 별표로\n표시하고 관리하세요';
        break;
      case '보관':
        title = '보관된 메모가 없습니다';
        subtitle = '완료된 메모를\n보관함으로 옮겨보세요';
        break;
      default:
        title = '작성된 메모가 없습니다';
        subtitle = '고객과의 대화 내용을\n메모로 남겨보세요';
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: screenHeight * 0.15),
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
                    Icons.note_outlined,
                    size: screenWidth * 0.2,
                    color: ThemeColor.textTertiary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  subtitle,
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
}
