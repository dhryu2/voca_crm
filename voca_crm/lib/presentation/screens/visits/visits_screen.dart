import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/notification/business_place_change_notifier.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/core/utils/haptic_helper.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/datasource/visit_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/data/repository/visit_repository_impl.dart';
import 'package:voca_crm/domain/entity/business_place_with_role.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/visit.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';
import 'package:voca_crm/presentation/widgets/character_count_text_field.dart';

class VisitsScreen extends StatefulWidget {
  final User user;

  const VisitsScreen({super.key, required this.user});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen>
    with SingleTickerProviderStateMixin {
  final _visitRepository = VisitRepositoryImpl(VisitService());
  final _memberRepository = MemberRepositoryImpl(MemberService());
  final _businessPlaceService = BusinessPlaceService();

  late TabController _tabController;

  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  // 사업장 상태
  List<BusinessPlaceWithRole> _businessPlaces = [];
  String? _selectedBusinessPlaceId;
  StreamSubscription<BusinessPlaceChangeEvent>? _businessPlaceChangeSubscription;

  // 오늘 체크인 기록 (서버에서 로드)
  List<_RecentCheckIn> _recentCheckIns = [];

  // 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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
    _loadMembers();
    _loadTodayVisits();
  }

  Future<void> _loadTodayVisits() async {
    if (_selectedBusinessPlaceId == null || _selectedBusinessPlaceId!.isEmpty) {
      return;
    }

    try {
      final visits = await _visitRepository.getTodayVisits(_selectedBusinessPlaceId!);
      if (!mounted) return;

      setState(() {
        _recentCheckIns = visits
            .where((v) => v.member != null)
            .map((v) => _RecentCheckIn(member: v.member!, visit: v))
            .toList();
      });
    } catch (e) {
      // Silent fail - 오늘 방문 목록은 필수가 아님
      debugPrint('[VisitsScreen] Failed to load today visits: $e');
    }
  }

  Future<void> _showCancelCheckInDialog(_RecentCheckIn checkIn) async {
    HapticHelper.medium();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final timeStr =
        '${checkIn.visit.visitedAt.hour.toString().padLeft(2, '0')}:${checkIn.visit.visitedAt.minute.toString().padLeft(2, '0')}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.02),
              decoration: BoxDecoration(
                color: ThemeColor.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.cancel_outlined,
                color: ThemeColor.error,
                size: screenWidth * 0.05,
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Text(
              '체크인 취소',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.035),
              decoration: BoxDecoration(
                color: ThemeColor.neutral50,
                borderRadius: BorderRadius.circular(screenWidth * 0.025),
                border: Border.all(color: ThemeColor.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: screenWidth * 0.1,
                    height: screenWidth * 0.1,
                    decoration: BoxDecoration(
                      color: ThemeColor.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        checkIn.member.name.isNotEmpty
                            ? checkIn.member.name[0]
                            : '?',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.025),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checkIn.member.name,
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                        Text(
                          '체크인: $timeStr',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            Text(
              '이 체크인 기록을 취소하시겠습니까?\n취소된 기록은 복구할 수 없습니다.',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: ThemeColor.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              '닫기',
              style: TextStyle(
                color: ThemeColor.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColor.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '취소하기',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelCheckIn(checkIn);
    }
  }

  Future<void> _cancelCheckIn(_RecentCheckIn checkIn) async {
    if (_selectedBusinessPlaceId == null) return;

    try {
      await _visitRepository.cancelCheckIn(
        checkIn.visit.id,
        _selectedBusinessPlaceId!,
      );

      setState(() {
        _recentCheckIns.removeWhere((c) => c.visit.id == checkIn.visit.id);
      });

      if (mounted) {
        HapticHelper.success();
        AppMessageHandler.showSuccessSnackBar(
          context,
          '${checkIn.member.name}님의 체크인이 취소되었습니다.',
        );
      }
    } catch (e) {
      if (mounted) {
        HapticHelper.error();
        AppMessageHandler.showErrorSnackBar(
          context,
          '체크인 취소 실패: ${AppMessageHandler.parseErrorMessage(e)}',
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _businessPlaceChangeSubscription?.cancel();
    super.dispose();
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

  Future<void> _loadMembers() async {
    if (_selectedBusinessPlaceId == null || _selectedBusinessPlaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '사업장을 선택해주세요';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final members =
          await _memberRepository.getMembersByBusinessPlace(_selectedBusinessPlaceId!);

      if (!mounted) return;
      setState(() {
        _members = members;
        _filteredMembers = members;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppMessageHandler.parseErrorMessage(e);
      });
    }
  }

  void _filterMembers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMembers = _members;
      } else {
        _filteredMembers = _members.where((member) {
          final nameLower = member.name.toLowerCase();
          final phoneLower = member.phone?.toLowerCase() ?? '';
          final numberLower = member.memberNumber.toLowerCase();
          final queryLower = query.toLowerCase();

          return nameLower.contains(queryLower) ||
              phoneLower.contains(queryLower) ||
              numberLower.contains(queryLower);
        }).toList();
      }
    });
  }

  Future<void> _checkIn(Member member) async {
    HapticHelper.medium();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final noteController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(screenWidth * 0.06),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                width: screenWidth * 0.1,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeColor.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: screenWidth * 0.14,
                    height: screenWidth * 0.14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ThemeColor.success,
                          ThemeColor.success.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(screenWidth * 0.035),
                    ),
                    child: Icon(
                      Icons.how_to_reg_rounded,
                      size: screenWidth * 0.07,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '체크인',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w700,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.003),
                        Text(
                          '방문을 기록합니다',
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),

              // Member info card (Notion style)
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral50,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  border: Border.all(color: ThemeColor.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: screenWidth * 0.12,
                      height: screenWidth * 0.12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ThemeColor.primary,
                            ThemeColor.primary.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(screenWidth * 0.03),
                      ),
                      child: Center(
                        child: Text(
                          member.name.isNotEmpty ? member.name[0] : '?',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.035),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                member.name,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.042,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeColor.textPrimary,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.02),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ThemeColor.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  member.memberNumber,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.028,
                                    color: ThemeColor.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (member.phone != null) ...[
                            SizedBox(height: screenHeight * 0.003),
                            Text(
                              member.phone!,
                              style: TextStyle(
                                fontSize: screenWidth * 0.032,
                                color: ThemeColor.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Note input
              CharacterCountTextField(
                controller: noteController,
                labelText: '메모 (선택)',
                hintText: '방문 관련 메모를 입력하세요',
                maxLength: 200,
                maxLines: 2,
              ),

              SizedBox(height: screenHeight * 0.025),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: screenHeight * 0.058,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: ThemeColor.border),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.03),
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
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: screenHeight * 0.058,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeColor.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.03),
                          ),
                        ),
                        icon: Icon(Icons.check_rounded, size: screenWidth * 0.05),
                        label: Text(
                          '체크인 완료',
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

              SizedBox(height: screenHeight * 0.01),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final note = noteController.text.trim();
        final visit = await _visitRepository.checkIn(
          member.id,
          note: note.isEmpty ? null : note,
        );

        // 최근 체크인 기록에 추가
        setState(() {
          _recentCheckIns.insert(
            0,
            _RecentCheckIn(member: member, visit: visit),
          );
          // 최근 10개만 유지
          if (_recentCheckIns.length > 10) {
            _recentCheckIns.removeLast();
          }
        });

        if (mounted) {
          HapticHelper.success();
          _showCheckInSuccessDialog(member, visit);
        }
      } catch (e) {
        if (mounted) {
          HapticHelper.error();
          AppMessageHandler.showErrorSnackBar(
            context,
            '체크인 실패: ${AppMessageHandler.parseErrorMessage(e)}',
          );
        }
      }
    }
  }

  void _showCheckInSuccessDialog(Member member, Visit visit) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Container(
                    width: screenWidth * 0.2,
                    height: screenWidth * 0.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ThemeColor.success,
                          ThemeColor.success.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ThemeColor.success.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: screenWidth * 0.1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              Text(
                '체크인 완료!',
                style: TextStyle(
                  fontSize: screenWidth * 0.055,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.008),
              Text(
                '${member.name}님의 방문이 기록되었습니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: ThemeColor.textSecondary,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),

              // Visit time
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.01,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral50,
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: screenWidth * 0.04,
                      color: ThemeColor.textSecondary,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      '${visit.visitedAt.hour.toString().padLeft(2, '0')}:${visit.visitedAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.025),

              SizedBox(
                width: double.infinity,
                height: screenHeight * 0.055,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColor.primary,
                    foregroundColor: Colors.white,
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

  Future<void> _showVisitHistory(Member member) async {
    HapticHelper.light();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
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
                    width: screenWidth * 0.12,
                    height: screenWidth * 0.12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ThemeColor.primary,
                          ThemeColor.primary.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                    child: Center(
                      child: Text(
                        member.name.isNotEmpty ? member.name[0] : '?',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                          '${member.name}님의 방문 기록',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w700,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                        Text(
                          member.memberNumber,
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Check-in button
                  SizedBox(
                    height: screenHeight * 0.04,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _checkIn(member);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeColor.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.add_rounded, size: screenWidth * 0.04),
                      label: Text(
                        '체크인',
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: ThemeColor.border, height: screenHeight * 0.03),

            // Visit list
            Flexible(
              child: FutureBuilder<List<Visit>>(
                future: _visitRepository.getVisitsByMemberId(member.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(screenWidth * 0.1),
                        child: CircularProgressIndicator(
                          color: ThemeColor.primary,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildHistoryError(screenWidth, screenHeight);
                  }

                  final visits = snapshot.data ?? [];

                  if (visits.isEmpty) {
                    return _buildHistoryEmpty(screenWidth, screenHeight);
                  }

                  return _buildVisitTimeline(visits, screenWidth, screenHeight);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryError(double screenWidth, double screenHeight) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.08),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: ThemeColor.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: ThemeColor.error,
              size: screenWidth * 0.1,
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          Text(
            '방문 기록을 불러올 수 없습니다',
            style: TextStyle(
              fontSize: screenWidth * 0.038,
              color: ThemeColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmpty(double screenWidth, double screenHeight) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.08),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: ThemeColor.neutral100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              color: ThemeColor.textTertiary,
              size: screenWidth * 0.1,
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          Text(
            '방문 기록이 없습니다',
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w600,
              color: ThemeColor.textPrimary,
            ),
          ),
          SizedBox(height: screenHeight * 0.005),
          Text(
            '첫 방문을 기록해보세요!',
            style: TextStyle(
              fontSize: screenWidth * 0.032,
              color: ThemeColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitTimeline(
      List<Visit> visits, double screenWidth, double screenHeight) {
    // Group visits by date
    final groupedVisits = <String, List<Visit>>{};
    for (final visit in visits) {
      final dateKey =
          '${visit.visitedAt.year}.${visit.visitedAt.month.toString().padLeft(2, '0')}.${visit.visitedAt.day.toString().padLeft(2, '0')}';
      groupedVisits.putIfAbsent(dateKey, () => []).add(visit);
    }

    final dateKeys = groupedVisits.keys.toList();

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.01,
      ),
      itemCount: dateKeys.length,
      itemBuilder: (context, index) {
        final dateKey = dateKeys[index];
        final dayVisits = groupedVisits[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.025,
                vertical: screenHeight * 0.006,
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
                _formatDateHeader(dateKey),
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.textSecondary,
                ),
              ),
            ),
            // Visits for this date
            ...dayVisits.asMap().entries.map((entry) {
              final isLast = entry.key == dayVisits.length - 1 &&
                  index == dateKeys.length - 1;
              return _buildVisitTimelineItem(
                  entry.value, isLast, screenWidth, screenHeight);
            }),
          ],
        );
      },
    );
  }

  Widget _buildVisitTimelineItem(
      Visit visit, bool isLast, double screenWidth, double screenHeight) {
    final timeStr =
        '${visit.visitedAt.hour.toString().padLeft(2, '0')}:${visit.visitedAt.minute.toString().padLeft(2, '0')}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: screenWidth * 0.06,
            child: Column(
              children: [
                Container(
                  width: screenWidth * 0.02,
                  height: screenWidth * 0.02,
                  decoration: BoxDecoration(
                    color: ThemeColor.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ThemeColor.success.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: ThemeColor.neutral200,
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: screenHeight * 0.012),
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: ThemeColor.neutral50,
                borderRadius: BorderRadius.circular(screenWidth * 0.025),
                border: Border.all(color: ThemeColor.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: ThemeColor.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: ThemeColor.success,
                      size: screenWidth * 0.045,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.025),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                        if (visit.note != null && visit.note!.isNotEmpty) ...[
                          SizedBox(height: screenHeight * 0.003),
                          Text(
                            visit.note!,
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              color: ThemeColor.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(String dateKey) {
    final now = DateTime.now();
    final todayKey =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year}.${yesterday.month.toString().padLeft(2, '0')}.${yesterday.day.toString().padLeft(2, '0')}';

    if (dateKey == todayKey) {
      return '오늘';
    } else if (dateKey == yesterdayKey) {
      return '어제';
    } else {
      return dateKey;
    }
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
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ThemeColor.textSecondary),
            onPressed: _loadMembers,
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
                Tab(text: '회원 검색'),
                Tab(text: '오늘 방문'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: ThemeColor.primary),
            )
          : _error != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSearchTab(),
                    _buildTodayVisitsTab(),
                  ],
                ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    if (_isLoading || _error != null) return null;

    final screenWidth = MediaQuery.of(context).size.width;

    return FloatingActionButton.extended(
      heroTag: 'visits_fab',
      onPressed: () {
        _tabController.animateTo(0);
        _searchFocusNode.requestFocus();
      },
      backgroundColor: ThemeColor.success,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: Icon(Icons.person_search_rounded, size: screenWidth * 0.055),
      label: Text(
        '빠른 체크인',
        style: TextStyle(
          fontSize: screenWidth * 0.035,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
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
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.people_rounded,
                  iconColor: ThemeColor.primary,
                  title: '전체 회원',
                  value: '${_members.length}',
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.how_to_reg_rounded,
                  iconColor: ThemeColor.success,
                  title: '오늘 체크인',
                  value: '${_recentCheckIns.length}',
                ),
              ),
            ],
          ),
        ),

        // Search bar (HubSpot style)
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            screenWidth * 0.04,
            0,
            screenWidth * 0.04,
            screenWidth * 0.04,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _filterMembers,
            decoration: InputDecoration(
              hintText: '이름, 전화번호, 회원번호로 검색',
              hintStyle: TextStyle(
                color: ThemeColor.textTertiary,
                fontSize: screenWidth * 0.038,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: ThemeColor.textTertiary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: ThemeColor.textTertiary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _filterMembers('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: ThemeColor.neutral50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                borderSide: BorderSide(color: ThemeColor.primary, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenHeight * 0.015,
              ),
            ),
          ),
        ),

        // Recent check-ins (Trello style)
        if (_recentCheckIns.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.01,
            ),
            color: ThemeColor.success.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: screenWidth * 0.045,
                  color: ThemeColor.success,
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  '방금 체크인',
                  style: TextStyle(
                    fontSize: screenWidth * 0.033,
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.success,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: screenHeight * 0.075,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenHeight * 0.008,
              ),
              itemCount: _recentCheckIns.length,
              separatorBuilder: (context, index) =>
                  SizedBox(width: screenWidth * 0.02),
              itemBuilder: (context, index) {
                final checkIn = _recentCheckIns[index];
                return _buildRecentCheckInChip(
                  checkIn,
                  screenWidth,
                  screenHeight,
                );
              },
            ),
          ),
        ],

        // Section header
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.012,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _searchQuery.isEmpty ? '전체 회원' : '검색 결과',
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.025,
                  vertical: screenWidth * 0.01,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral100,
                  borderRadius: BorderRadius.circular(screenWidth * 0.04),
                ),
                child: Text(
                  '${_filteredMembers.length}명',
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Member list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadMembers,
            color: ThemeColor.primary,
            child: _filteredMembers.isEmpty
                ? _buildEmptyList()
                : ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenHeight * 0.005,
                    ),
                    itemCount: _filteredMembers.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: screenHeight * 0.01),
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      return _buildMemberCard(
                        member,
                        screenWidth,
                        screenHeight,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayVisitsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_recentCheckIns.isEmpty) {
      return Center(
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
                Icons.event_available_rounded,
                size: screenWidth * 0.12,
                color: ThemeColor.textTertiary,
              ),
            ),
            SizedBox(height: screenHeight * 0.025),
            Text(
              '오늘 체크인 기록이 없습니다',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w600,
                color: ThemeColor.textPrimary,
              ),
            ),
            SizedBox(height: screenHeight * 0.008),
            Text(
              '회원을 검색하여 체크인해보세요',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: ThemeColor.textSecondary,
              ),
            ),
            SizedBox(height: screenHeight * 0.03),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(0);
                _searchFocusNode.requestFocus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeColor.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenHeight * 0.015,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(screenWidth * 0.025),
                ),
              ),
              icon: const Icon(Icons.search_rounded),
              label: const Text('회원 검색'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: ThemeColor.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: ThemeColor.success,
                  size: screenWidth * 0.06,
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘 ${_recentCheckIns.length}명 방문',
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.w700,
                        color: ThemeColor.textPrimary,
                      ),
                    ),
                    Text(
                      '이번 세션에서 체크인한 방문 기록입니다',
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: ThemeColor.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: ThemeColor.border),

        // Today's timeline
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(screenWidth * 0.04),
            itemCount: _recentCheckIns.length,
            itemBuilder: (context, index) {
              final checkIn = _recentCheckIns[index];
              final isLast = index == _recentCheckIns.length - 1;
              return _buildTodayTimelineItem(
                  checkIn, isLast, screenWidth, screenHeight);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTodayTimelineItem(_RecentCheckIn checkIn, bool isLast,
      double screenWidth, double screenHeight) {
    final timeStr =
        '${checkIn.visit.visitedAt.hour.toString().padLeft(2, '0')}:${checkIn.visit.visitedAt.minute.toString().padLeft(2, '0')}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          SizedBox(
            width: screenWidth * 0.08,
            child: Column(
              children: [
                Container(
                  width: screenWidth * 0.025,
                  height: screenWidth * 0.025,
                  decoration: BoxDecoration(
                    color: ThemeColor.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ThemeColor.success.withValues(alpha: 0.3),
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

          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => _showVisitHistory(checkIn.member),
              onLongPress: () => _showCancelCheckInDialog(checkIn),
              child: Container(
                margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                padding: EdgeInsets.all(screenWidth * 0.04),
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
                child: Row(
                  children: [
                    Container(
                      width: screenWidth * 0.12,
                      height: screenWidth * 0.12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ThemeColor.primary,
                            ThemeColor.primary.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(screenWidth * 0.03),
                      ),
                      child: Center(
                        child: Text(
                          checkIn.member.name.isNotEmpty
                              ? checkIn.member.name[0]
                              : '?',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                checkIn.member.name,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeColor.textPrimary,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.02),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.015,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      ThemeColor.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '체크인',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.024,
                                    color: ThemeColor.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenHeight * 0.003),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: screenWidth * 0.035,
                                color: ThemeColor.textTertiary,
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: ThemeColor.textSecondary,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Text(
                                checkIn.member.memberNumber,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.028,
                                  color: ThemeColor.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          if (checkIn.visit.note != null &&
                              checkIn.visit.note!.isNotEmpty) ...[
                            SizedBox(height: screenHeight * 0.005),
                            Text(
                              checkIn.visit.note!,
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                color: ThemeColor.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: ThemeColor.textTertiary,
                      size: screenWidth * 0.05,
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

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
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

  Widget _buildRecentCheckInChip(
    _RecentCheckIn checkIn,
    double screenWidth,
    double screenHeight,
  ) {
    final timeStr =
        '${checkIn.visit.visitedAt.hour.toString().padLeft(2, '0')}:${checkIn.visit.visitedAt.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _showVisitHistory(checkIn.member),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: screenHeight * 0.008,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.025),
          border: Border.all(color: ThemeColor.success.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: ThemeColor.success.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: screenWidth * 0.07,
              height: screenWidth * 0.07,
              decoration: BoxDecoration(
                color: ThemeColor.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  checkIn.member.name.isNotEmpty ? checkIn.member.name[0] : '?',
                  style: TextStyle(
                    fontSize: screenWidth * 0.032,
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.success,
                  ),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  checkIn.member.name,
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: screenWidth * 0.024,
                    color: ThemeColor.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(
    Member member,
    double screenWidth,
    double screenHeight,
  ) {
    return Material(
      color: ThemeColor.surface,
      borderRadius: BorderRadius.circular(screenWidth * 0.03),
      child: InkWell(
        onTap: () => _showVisitHistory(member),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.035),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
            border: Border.all(color: ThemeColor.border),
          ),
          child: Row(
            children: [
              // Avatar (Notion style gradient)
              Container(
                width: screenWidth * 0.12,
                height: screenWidth * 0.12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeColor.primary,
                      ThemeColor.primary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty ? member.name[0] : '?',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),

              // Info
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
                            horizontal: screenWidth * 0.018,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColor.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            member.memberNumber,
                            style: TextStyle(
                              fontSize: screenWidth * 0.026,
                              color: ThemeColor.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (member.phone != null) ...[
                      SizedBox(height: screenHeight * 0.004),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: screenWidth * 0.035,
                            color: ThemeColor.textTertiary,
                          ),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            member.phone!,
                            style: TextStyle(
                              fontSize: screenWidth * 0.032,
                              color: ThemeColor.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Check-in button
              SizedBox(
                height: screenHeight * 0.045,
                child: ElevatedButton.icon(
                  onPressed: () => _checkIn(member),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColor.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.03,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    Icons.how_to_reg_rounded,
                    size: screenWidth * 0.04,
                  ),
                  label: Text(
                    '체크인',
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
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

  Widget _buildEmptyList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: screenHeight * 0.1),
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
                  _searchQuery.isEmpty
                      ? Icons.people_outline_rounded
                      : Icons.search_off_rounded,
                  size: screenWidth * 0.12,
                  color: ThemeColor.textTertiary,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),
              Text(
                _searchQuery.isEmpty ? '등록된 회원이 없습니다' : '검색 결과가 없습니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.008),
              Text(
                _searchQuery.isEmpty ? '먼저 회원을 등록해주세요' : '다른 검색어로 시도해보세요',
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
              onPressed: _loadMembers,
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
                          _loadMembers();
                          _loadTodayVisits();
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

/// 최근 체크인 기록을 저장하기 위한 클래스
class _RecentCheckIn {
  final Member member;
  final Visit visit;

  _RecentCheckIn({required this.member, required this.visit});
}
