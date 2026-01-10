import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/notification/business_place_change_notifier.dart';
import 'package:voca_crm/core/notification/member_change_notifier.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/datasource/user_service.dart';
import 'package:voca_crm/data/datasource/visit_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/data/repository/visit_repository_impl.dart';
import 'package:voca_crm/domain/entity/visit.dart';
import 'package:voca_crm/domain/entity/business_place_with_role.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';
import 'package:voca_crm/presentation/screens/customers/deleted_members_screen.dart';
import 'package:voca_crm/presentation/screens/main_screen.dart';
import 'package:voca_crm/presentation/widgets/character_count_text_field.dart';
import 'package:voca_crm/presentation/widgets/phone_number_field.dart';

class CustomersScreen extends StatefulWidget {
  final User user;

  const CustomersScreen({super.key, required this.user});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _memberIdFilterController =
      TextEditingController();
  final _memberRepository = MemberRepositoryImpl(MemberService());
  final _visitRepository = VisitRepositoryImpl(VisitService());
  final _businessPlaceService = BusinessPlaceService();
  final _userService = UserService();

  // User name cache to avoid repeated API calls
  final Map<String, String> _userNameCache = {};

  String _searchQuery = '';
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  List<BusinessPlaceWithRole> _businessPlaces = [];
  bool _isLoading = false;

  // Filter states
  String? _selectedBusinessPlaceFilter;
  String _memberIdFilter = '';
  bool _isFilterExpanded = false;

  // Business place change listener
  StreamSubscription<BusinessPlaceChangeEvent>?
  _businessPlaceChangeSubscription;

  @override
  void initState() {
    super.initState();

    // UserViewModel에서 최신 defaultBusinessPlaceId 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userViewModel = Provider.of<UserViewModel>(context, listen: false);
      final currentUser = userViewModel.user;
      _selectedBusinessPlaceFilter = currentUser?.defaultBusinessPlaceId ?? widget.user.defaultBusinessPlaceId;
      if (kDebugMode) {
        debugPrint('[CustomersScreen] initState - defaultBusinessPlaceId: $_selectedBusinessPlaceFilter');
      }
      _initializeData();
    });

    // Listen to business place changes
    _businessPlaceChangeSubscription = BusinessPlaceChangeNotifier().stream
        .listen((event) {
          // Reload business places when any change occurs
          _loadBusinessPlaces();
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // UserViewModel의 defaultBusinessPlaceId 변경 감지
    final userViewModel = Provider.of<UserViewModel>(context);
    final newDefaultBusinessPlaceId = userViewModel.user?.defaultBusinessPlaceId;

    // 기본 사업장이 변경되었고, 현재 선택된 사업장이 없으면 새 기본값 사용
    if (newDefaultBusinessPlaceId != null &&
        newDefaultBusinessPlaceId.isNotEmpty &&
        (_selectedBusinessPlaceFilter == null || _selectedBusinessPlaceFilter!.isEmpty)) {
      if (kDebugMode) {
        debugPrint('[CustomersScreen] didChangeDependencies - updating to: $newDefaultBusinessPlaceId');
      }
      setState(() {
        _selectedBusinessPlaceFilter = newDefaultBusinessPlaceId;
      });
      _loadMembers();
    }
  }

  Future<void> _initializeData() async {
    await _loadBusinessPlaces();
    // If no business place filter is set but we have business places, use the first one
    if (_selectedBusinessPlaceFilter == null && _businessPlaces.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[CustomersScreen] No default BP, using first from list: ${_businessPlaces.first.businessPlace.id}');
      }
      setState(() {
        _selectedBusinessPlaceFilter = _businessPlaces.first.businessPlace.id;
      });
    }
    _loadMembers();
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
      // Silent fail - user can still add members without selecting business place
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _memberIdFilterController.dispose();
    _businessPlaceChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (kDebugMode) {
      debugPrint('[CustomersScreen] _loadMembers called');
      debugPrint('[CustomersScreen] _selectedBusinessPlaceFilter: $_selectedBusinessPlaceFilter');
      debugPrint('[CustomersScreen] user.defaultBusinessPlaceId: ${widget.user.defaultBusinessPlaceId}');
    }

    if (_selectedBusinessPlaceFilter == null) {
      if (kDebugMode) {
        debugPrint('[CustomersScreen] _selectedBusinessPlaceFilter is null, returning');
      }
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Server-side filtering by business place
      if (kDebugMode) {
        debugPrint('[CustomersScreen] Calling getMembersByBusinessPlace with: $_selectedBusinessPlaceFilter');
      }
      final members = await _memberRepository.getMembersByBusinessPlace(
        _selectedBusinessPlaceFilter!,
      );
      if (kDebugMode) {
        debugPrint('[CustomersScreen] Got ${members.length} members from API');
      }
      if (!mounted) return;
      setState(() {
        _members = members;
        _filteredMembers = members;
        _isLoading = false;
      });
      // Client-side filtering for other criteria
      _applyFilters();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[CustomersScreen] Error loading members: $e');
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'CustomersScreen',
          action: '고객 목록 조회',
          userId: widget.user.id,
          businessPlaceId: _selectedBusinessPlaceFilter,
        );
      }
    }
  }

  void _filterMembers(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredMembers = _members.where((member) {
        // Search bar filter (name, phone, email)
        bool matchesSearchQuery = true;
        if (_searchQuery.isNotEmpty) {
          final nameLower = member.name.toLowerCase();
          final phoneLower = member.phone?.toLowerCase() ?? '';
          final emailLower = member.email?.toLowerCase() ?? '';
          final queryLower = _searchQuery.toLowerCase();

          matchesSearchQuery =
              nameLower.contains(queryLower) ||
              phoneLower.contains(queryLower) ||
              emailLower.contains(queryLower);
        }

        // Member ID filter
        bool matchesMemberId = true;
        if (_memberIdFilter.isNotEmpty) {
          matchesMemberId = member.memberNumber.toLowerCase().contains(
            _memberIdFilter.toLowerCase(),
          );
        }

        return matchesSearchQuery && matchesMemberId;
      }).toList();
    });
  }

  Future<void> _showAddMemberDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final memberNumberController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final remarkController = TextEditingController();

    // 현재 필터로 선택된 사업장을 기본값으로 사용 (필터가 없으면 사용자 기본 사업장)
    String? selectedBusinessPlaceId = _selectedBusinessPlaceFilter ?? widget.user.defaultBusinessPlaceId;
    MemberGrade? selectedGrade;

    await showDialog(
      context: context,
      barrierDismissible: false,
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
                      // Large circular icon
                      Container(
                        width: screenWidth * 0.16,
                        height: screenWidth * 0.16,
                        decoration: BoxDecoration(
                          color: ThemeColor.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add,
                          size: screenWidth * 0.08,
                          color: ThemeColor.primary,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Large title
                      Text(
                        '고객 추가',
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
                        '새로운 고객 정보를 입력하세요',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          color: ThemeColor.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Clean input fields with CharacterCountTextField
                      CharacterCountTextField(
                        controller: memberNumberController,
                        labelText: '회원 번호 *',
                        hintText: '예: M001',
                        maxLength: InputLimits.memberNumber,
                        validationType: ValidationType.memberNumber,
                        isRequired: true,
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      CharacterCountTextField(
                        controller: nameController,
                        labelText: '이름 *',
                        hintText: '예: 홍길동',
                        maxLength: InputLimits.memberName,
                        validationType: ValidationType.name,
                        isRequired: true,
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      PhoneNumberField(
                        controller: phoneController,
                        labelText: '전화번호 (선택)',
                        hintText: '010-1234-5678',
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Business Place Dropdown
                      if (_businessPlaces.isNotEmpty)
                        StatefulBuilder(
                          builder: (context, setDialogState) {
                            return DropdownButtonFormField<String>(
                              value: selectedBusinessPlaceId,
                              decoration: InputDecoration(
                                labelText: '사업장 *',
                                labelStyle: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  color: ThemeColor.textSecondary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                  borderSide: BorderSide(
                                    color: ThemeColor.border,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                  borderSide: BorderSide(
                                    color: ThemeColor.border,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                  borderSide: BorderSide(
                                    color: ThemeColor.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.045,
                                  vertical: screenHeight * 0.02,
                                ),
                              ),
                              items: _businessPlaces.map((item) {
                                return DropdownMenuItem<String>(
                                  value: item.businessPlace.id,
                                  child: Text(
                                    item.businessPlace.name,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.042,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedBusinessPlaceId = value;
                                });
                              },
                            );
                          },
                        ),

                      if (_businessPlaces.isNotEmpty)
                        SizedBox(height: screenHeight * 0.02),

                      CharacterCountTextField(
                        controller: emailController,
                        labelText: '이메일 (선택)',
                        hintText: '예: example@email.com',
                        maxLength: InputLimits.memberEmail,
                        keyboardType: TextInputType.emailAddress,
                        validationType: ValidationType.email,
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      CharacterCountTextField(
                        controller: remarkController,
                        labelText: '비고 (선택)',
                        hintText: '추가 메모나 특이사항을 입력하세요',
                        maxLength: InputLimits.memberRemark,
                        maxLines: 3,
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Grade Dropdown
                      StatefulBuilder(
                        builder: (context, setDialogState) {
                          return DropdownButtonFormField<MemberGrade>(
                            value: selectedGrade,
                            decoration: InputDecoration(
                              labelText: '등급 (선택)',
                              labelStyle: TextStyle(
                                fontSize: screenWidth * 0.038,
                                color: ThemeColor.textSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                borderSide: BorderSide(
                                  color: ThemeColor.border,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                borderSide: BorderSide(
                                  color: ThemeColor.border,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                borderSide: BorderSide(
                                  color: ThemeColor.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.045,
                                vertical: screenHeight * 0.02,
                              ),
                            ),
                            items: MemberGrade.values.map((grade) {
                              return DropdownMenuItem<MemberGrade>(
                                value: grade,
                                child: Text(
                                  grade.displayName,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.042,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedGrade = value;
                              });
                            },
                          );
                        },
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Full-width primary button at bottom
                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * 0.065,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (memberNumberController.text.isEmpty ||
                                nameController.text.isEmpty) {
                              AppMessageHandler.showErrorSnackBar(
                                context,
                                '회원 번호와 이름은 필수입니다',
                              );
                              return;
                            }

                            try {
                              await _memberRepository.createMember(
                                businessPlaceId: selectedBusinessPlaceId,
                                memberNumber: memberNumberController.text,
                                name: nameController.text,
                                phone: phoneController.text.isEmpty
                                    ? null
                                    : phoneController.text,
                                email: emailController.text.isEmpty
                                    ? null
                                    : emailController.text,
                                ownerId: widget.user.id,
                                remark: remarkController.text.isEmpty
                                    ? null
                                    : remarkController.text,
                                grade: selectedGrade?.name,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                AppMessageHandler.showSuccessSnackBar(
                                  context,
                                  '고객이 추가되었습니다',
                                );
                                _loadMembers();
                                // 회원 추가 이벤트 발행
                                MemberChangeNotifier().notifyCreated(
                                  businessPlaceId: selectedBusinessPlaceId,
                                );
                              }
                            } catch (e, stackTrace) {
                              if (context.mounted) {
                                await AppMessageHandler.handleErrorWithLogging(
                                  context,
                                  e,
                                  stackTrace,
                                  screenName: 'CustomersScreen',
                                  action: '고객 추가',
                                  userId: widget.user.id,
                                  businessPlaceId: _selectedBusinessPlaceFilter,
                                );
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
                            '추가하기',
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
    );
  }

  Future<void> _showMemberDetails(Member member) async {
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
                          Icons.person,
                          size: screenWidth * 0.08,
                          color: ThemeColor.primary,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Large title
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

                      // Subtitle with member number
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenHeight * 0.006,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeColor.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.02,
                          ),
                        ),
                        child: Text(
                          member.memberNumber,
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            color: ThemeColor.primary,
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
                          children: [
                            if (member.gradeEnum != null) ...[
                              _buildDetailRow(
                                Icons.star_outline,
                                '등급',
                                member.gradeEnum!.displayName,
                              ),
                              SizedBox(height: screenHeight * 0.015),
                              Divider(height: 1, color: Colors.grey[300]),
                              SizedBox(height: screenHeight * 0.015),
                            ],
                            if (member.phone != null) ...[
                              _buildDetailRow(
                                Icons.phone,
                                '전화번호',
                                member.phone!,
                              ),
                              SizedBox(height: screenHeight * 0.015),
                              Divider(height: 1, color: Colors.grey[300]),
                              SizedBox(height: screenHeight * 0.015),
                            ],
                            if (member.email != null) ...[
                              _buildDetailRow(
                                Icons.email,
                                '이메일',
                                member.email!,
                              ),
                              SizedBox(height: screenHeight * 0.015),
                              Divider(height: 1, color: Colors.grey[300]),
                              SizedBox(height: screenHeight * 0.015),
                            ],
                            if (member.remark != null) ...[
                              _buildDetailRow(
                                Icons.note_outlined,
                                '비고',
                                member.remark!,
                              ),
                              SizedBox(height: screenHeight * 0.015),
                              Divider(height: 1, color: Colors.grey[300]),
                              SizedBox(height: screenHeight * 0.015),
                            ],
                            _buildDetailRow(
                              Icons.calendar_today,
                              '등록일',
                              '${member.createdAt.year}-${member.createdAt.month.toString().padLeft(2, '0')}-${member.createdAt.day.toString().padLeft(2, '0')}',
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Info box
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: ThemeColor.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.03,
                          ),
                          border: Border.all(
                            color: ThemeColor.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: ThemeColor.primary,
                              size: screenWidth * 0.05,
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Text(
                                '메모 작성 버튼을 눌러 고객 메모를 관리할 수 있습니다',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: ThemeColor.primary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.03),

                      // Visit action buttons row
                      Row(
                        children: [
                          // Check-in button
                          Expanded(
                            child: SizedBox(
                              height: screenHeight * 0.055,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _showCheckInDialog(member);
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
                                  Icons.how_to_reg_rounded,
                                  size: screenWidth * 0.04,
                                ),
                                label: Text(
                                  '체크인',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          // Visit history button
                          Expanded(
                            child: SizedBox(
                              height: screenHeight * 0.055,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _showVisitHistoryDialog(member);
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ThemeColor.success,
                                  side: BorderSide(
                                    color: ThemeColor.success,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.03,
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.history_rounded,
                                  size: screenWidth * 0.04,
                                ),
                                label: Text(
                                  '방문기록',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Action buttons row
                      Row(
                        children: [
                          // Edit button
                          Expanded(
                            child: SizedBox(
                              height: screenHeight * 0.055,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _showEditMemberDialog(member);
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ThemeColor.primary,
                                  side: BorderSide(
                                    color: ThemeColor.primary,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.03,
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: screenWidth * 0.04,
                                ),
                                label: Text(
                                  '수정',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          // Delete button
                          Expanded(
                            child: SizedBox(
                              height: screenHeight * 0.055,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _showDeleteConfirmDialog(member);
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(
                                    color: Colors.red.shade300,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.03,
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: screenWidth * 0.04,
                                ),
                                label: Text(
                                  '삭제',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Full-width primary button at bottom
                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * 0.065,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              // MainScreen의 Memo 탭으로 이동 (index 2)
                              // MainScreen이 PageView를 사용하므로 상태를 변경해야 함
                              // 현재는 간단하게 스낵바로 안내
                              AppMessageHandler.showSuccessSnackBar(
                                context,
                                '메모 탭으로 이동하여 ${member.name}님의 메모를 작성하세요',
                              );
                            });
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
                          icon: Icon(
                            Icons.edit_note,
                            size: screenWidth * 0.055,
                          ),
                          label: Text(
                            '메모 작성',
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
    );
  }

  /// 사용자 ID로 사용자 이름 조회 (캐시 사용)
  Future<String> _getUserName(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return '정보 없음';
    }

    // 캐시에서 먼저 확인
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

  /// 날짜 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showEditMemberDialog(Member member) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final memberNumberController = TextEditingController(
      text: member.memberNumber,
    );
    final nameController = TextEditingController(text: member.name);
    final phoneController = TextEditingController(text: member.phone ?? '');
    final emailController = TextEditingController(text: member.email ?? '');
    final remarkController = TextEditingController(text: member.remark ?? '');

    MemberGrade? selectedGrade = member.gradeEnum;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // 사용자 이름을 저장할 변수
        String creatorName = '로딩 중...';
        String modifierName = member.lastModifiedById != null ? '로딩 중...' : '-';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 사용자 정보 비동기 로드
            if (creatorName == '로딩 중...' && member.ownerId != null) {
              _getUserName(member.ownerId).then((name) {
                setDialogState(() {
                  creatorName = name;
                });
              });
            }
            if (modifierName == '로딩 중...' && member.lastModifiedById != null) {
              _getUserName(member.lastModifiedById).then((name) {
                setDialogState(() {
                  modifierName = name;
                });
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.06),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.9,
                  maxHeight: screenHeight * 0.9,
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
                              width: screenWidth * 0.14,
                              height: screenWidth * 0.14,
                              decoration: BoxDecoration(
                                color: ThemeColor.primary.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                size: screenWidth * 0.07,
                                color: ThemeColor.primary,
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.02),

                            // Large title
                            Text(
                              '고객 수정',
                              style: TextStyle(
                                fontSize: screenWidth * 0.055,
                                fontWeight: FontWeight.w700,
                                color: ThemeColor.textPrimary,
                                letterSpacing: screenWidth * -0.0012,
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.025),

                            // Member Info Section
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(screenWidth * 0.04),
                              decoration: BoxDecoration(
                                color: ThemeColor.neutral50,
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                border: Border.all(color: ThemeColor.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section Header
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: screenWidth * 0.04,
                                        color: ThemeColor.textSecondary,
                                      ),
                                      SizedBox(width: screenWidth * 0.02),
                                      Text(
                                        '등록 정보',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.035,
                                          fontWeight: FontWeight.w600,
                                          color: ThemeColor.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: screenHeight * 0.015),

                                  // Info Grid
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoItem(
                                          icon: Icons.person_add_outlined,
                                          label: '추가한 사람',
                                          value: creatorName,
                                          screenWidth: screenWidth,
                                          screenHeight: screenHeight,
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Expanded(
                                        child: _buildInfoItem(
                                          icon: Icons.calendar_today_outlined,
                                          label: '추가한 날짜',
                                          value: _formatDateTime(
                                            member.createdAt,
                                          ),
                                          screenWidth: screenWidth,
                                          screenHeight: screenHeight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: screenHeight * 0.012),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoItem(
                                          icon: Icons.edit_outlined,
                                          label: '마지막 수정자',
                                          value: modifierName,
                                          screenWidth: screenWidth,
                                          screenHeight: screenHeight,
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Expanded(
                                        child: _buildInfoItem(
                                          icon: Icons.update_outlined,
                                          label: '마지막 수정일',
                                          value: _formatDateTime(
                                            member.updatedAt,
                                          ),
                                          screenWidth: screenWidth,
                                          screenHeight: screenHeight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.025),

                            // Input fields section header
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '수정할 정보',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeColor.textSecondary,
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.015),

                            // Input fields
                            CharacterCountTextField(
                              controller: memberNumberController,
                              labelText: '회원 번호 *',
                              hintText: '예: M001',
                              maxLength: InputLimits.memberNumber,
                              validationType: ValidationType.memberNumber,
                              isRequired: true,
                            ),

                            SizedBox(height: screenHeight * 0.02),

                            CharacterCountTextField(
                              controller: nameController,
                              labelText: '이름 *',
                              hintText: '예: 홍길동',
                              maxLength: InputLimits.memberName,
                              validationType: ValidationType.name,
                              isRequired: true,
                            ),

                            SizedBox(height: screenHeight * 0.02),

                            PhoneNumberField(
                              controller: phoneController,
                              labelText: '전화번호 (선택)',
                              hintText: '010-1234-5678',
                            ),

                            SizedBox(height: screenHeight * 0.02),

                            CharacterCountTextField(
                              controller: emailController,
                              labelText: '이메일 (선택)',
                              hintText: '예: example@email.com',
                              maxLength: InputLimits.memberEmail,
                              keyboardType: TextInputType.emailAddress,
                              validationType: ValidationType.email,
                            ),

                            SizedBox(height: screenHeight * 0.02),

                            CharacterCountTextField(
                              controller: remarkController,
                              labelText: '비고 (선택)',
                              hintText: '추가 메모나 특이사항을 입력하세요',
                              maxLength: InputLimits.memberRemark,
                              maxLines: 3,
                            ),

                            SizedBox(height: screenHeight * 0.02),

                            // Grade Dropdown
                            DropdownButtonFormField<MemberGrade>(
                              value: selectedGrade,
                              decoration: InputDecoration(
                                labelText: '등급 (선택)',
                                labelStyle: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  color: ThemeColor.textSecondary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                  borderSide: BorderSide(
                                    color: ThemeColor.border,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                  borderSide: BorderSide(
                                    color: ThemeColor.border,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                  borderSide: BorderSide(
                                    color: ThemeColor.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.045,
                                  vertical: screenHeight * 0.02,
                                ),
                              ),
                              items: MemberGrade.values.map((grade) {
                                return DropdownMenuItem<MemberGrade>(
                                  value: grade,
                                  child: Text(
                                    grade.displayName,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.042,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedGrade = value;
                                });
                              },
                            ),

                            SizedBox(height: screenHeight * 0.04),

                            // Full-width primary button at bottom
                            SizedBox(
                              width: double.infinity,
                              height: screenHeight * 0.065,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (memberNumberController.text.isEmpty ||
                                      nameController.text.isEmpty) {
                                    AppMessageHandler.showErrorSnackBar(
                                      context,
                                      '회원 번호와 이름은 필수입니다',
                                    );
                                    return;
                                  }

                                  try {
                                    final updatedMember = member.copyWith(
                                      memberNumber: memberNumberController.text,
                                      name: nameController.text,
                                      phone: phoneController.text.isEmpty
                                          ? null
                                          : phoneController.text,
                                      email: emailController.text.isEmpty
                                          ? null
                                          : emailController.text,
                                      remark: remarkController.text.isEmpty
                                          ? null
                                          : remarkController.text,
                                      grade: selectedGrade?.name,
                                    );

                                    await _memberRepository.updateMember(
                                      updatedMember,
                                      userId: widget.user.id,
                                      businessPlaceId: member.businessPlaceId,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      AppMessageHandler.showSuccessSnackBar(
                                        context,
                                        '고객 정보가 수정되었습니다',
                                      );
                                      _loadMembers();
                                    }
                                  } catch (e, stackTrace) {
                                    if (context.mounted) {
                                      await AppMessageHandler.handleErrorWithLogging(
                                        context,
                                        e,
                                        stackTrace,
                                        screenName: 'CustomersScreen',
                                        action: '고객 수정',
                                        userId: widget.user.id,
                                        businessPlaceId: _selectedBusinessPlaceFilter,
                                      );
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
                                  '수정하기',
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
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required double screenWidth,
    required double screenHeight,
  }) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.025),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth * 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: screenWidth * 0.035,
                color: ThemeColor.textTertiary,
              ),
              SizedBox(width: screenWidth * 0.015),
              Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.028,
                  color: ThemeColor.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.004),
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.032,
              color: ThemeColor.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmDialog(Member member) async {
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
              // Warning icon
              Container(
                width: screenWidth * 0.16,
                height: screenWidth * 0.16,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: screenWidth * 0.08,
                  color: Colors.orange,
                ),
              ),

              SizedBox(height: screenHeight * 0.025),

              // Title
              Text(
                '고객 삭제',
                style: TextStyle(
                  fontSize: screenWidth * 0.055,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.textPrimary,
                ),
              ),

              SizedBox(height: screenHeight * 0.015),

              // Message
              Text(
                '해당 회원 삭제 시 회원의 메모도 전부 삭제됩니다.\n정말 삭제하시겠습니까?',
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: screenWidth * 0.045,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: Text(
                        '삭제된 고객은 삭제 대기 화면에서 복원할 수 있습니다.',
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          color: Colors.blue.shade700,
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
                          if (member.businessPlaceId == null) {
                            Navigator.pop(context);
                            AppMessageHandler.showErrorSnackBar(
                              context,
                              '사업장 정보가 없는 회원은 삭제할 수 없습니다.',
                            );
                            return;
                          }
                          try {
                            await _memberRepository.softDeleteMember(
                              member.id,
                              userId: widget.user.id,
                              businessPlaceId: member.businessPlaceId!,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppMessageHandler.showSuccessSnackBar(
                                context,
                                '고객이 삭제 대기 상태로 전환되었습니다',
                              );
                              _loadMembers();
                              // 회원 삭제 이벤트 발행
                              MemberChangeNotifier().notifyDeleted(
                                memberId: member.id,
                                businessPlaceId: member.businessPlaceId,
                              );
                            }
                          } catch (e, stackTrace) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              await AppMessageHandler.handleErrorWithLogging(
                                context,
                                e,
                                stackTrace,
                                screenName: 'CustomersScreen',
                                action: '고객 삭제',
                                userId: widget.user.id,
                                businessPlaceId: _selectedBusinessPlaceFilter,
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
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

  Future<void> _showCheckInDialog(Member member) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: screenWidth * 0.16,
                height: screenWidth * 0.16,
                decoration: BoxDecoration(
                  color: ThemeColor.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.how_to_reg_rounded,
                  size: screenWidth * 0.08,
                  color: ThemeColor.success,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              // Title
              Text(
                '체크인',
                style: TextStyle(
                  fontSize: screenWidth * 0.055,
                  fontWeight: FontWeight.w700,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),

              // Member info
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.012,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral50,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  border: Border.all(color: ThemeColor.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                          member.name.isNotEmpty ? member.name[0] : '?',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w700,
                            color: ThemeColor.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: TextStyle(
                            fontSize: screenWidth * 0.042,
                            fontWeight: FontWeight.w600,
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
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.025),

              // Note input
              CharacterCountTextField(
                controller: noteController,
                labelText: '메모 (선택)',
                hintText: '방문 관련 메모를 입력하세요',
                maxLength: 200,
                maxLines: 2,
              ),

              SizedBox(height: screenHeight * 0.03),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: screenHeight * 0.06,
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
                            fontSize: screenWidth * 0.04,
                            color: ThemeColor.textSecondary,
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
                        child: Text(
                          '체크인',
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

    if (confirmed == true) {
      try {
        final note = noteController.text.trim();
        await _visitRepository.checkIn(
          member.id,
          note: note.isEmpty ? null : note,
        );

        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(
            context,
            '${member.name}님이 체크인되었습니다',
          );
        }
      } catch (e, stackTrace) {
        if (mounted) {
          await AppMessageHandler.handleErrorWithLogging(
            context,
            e,
            stackTrace,
            screenName: 'CustomersScreen',
            action: '고객 체크인',
            userId: widget.user.id,
            businessPlaceId: _selectedBusinessPlaceFilter,
          );
        }
      }
    }
  }

  Future<void> _showVisitHistoryDialog(Member member) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: Icon(Icons.close, color: ThemeColor.textSecondary),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                ),
              ),

              // Content
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.06,
                    0,
                    screenWidth * 0.06,
                    screenWidth * 0.06,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: screenWidth * 0.14,
                        height: screenWidth * 0.14,
                        decoration: BoxDecoration(
                          color: ThemeColor.success.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: screenWidth * 0.07,
                          color: ThemeColor.success,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // Title
                      Text(
                        '${member.name}님의 방문 기록',
                        style: TextStyle(
                          fontSize: screenWidth * 0.048,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Visit list
                      Flexible(
                        child: FutureBuilder<List<Visit>>(
                          future: _visitRepository.getVisitsByMemberId(member.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: ThemeColor.primary,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: ThemeColor.error,
                                      size: screenWidth * 0.12,
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    Text(
                                      '방문 기록을 불러올 수 없습니다',
                                      style: TextStyle(
                                        color: ThemeColor.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final visits = snapshot.data ?? [];

                            if (visits.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      color: ThemeColor.textTertiary,
                                      size: screenWidth * 0.12,
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    Text(
                                      '방문 기록이 없습니다',
                                      style: TextStyle(
                                        color: ThemeColor.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              itemCount: visits.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: ThemeColor.border),
                              itemBuilder: (context, index) {
                                final visit = visits[index];
                                return _buildVisitItem(visit, screenWidth, screenHeight);
                              },
                            );
                          },
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
    );
  }

  Widget _buildVisitItem(Visit visit, double screenWidth, double screenHeight) {
    final dateStr =
        '${visit.visitedAt.year}.${visit.visitedAt.month.toString().padLeft(2, '0')}.${visit.visitedAt.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${visit.visitedAt.hour.toString().padLeft(2, '0')}:${visit.visitedAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.02),
            decoration: BoxDecoration(
              color: ThemeColor.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: ThemeColor.success,
              size: screenWidth * 0.05,
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
                      dateStr,
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.textPrimary,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        color: ThemeColor.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (visit.note != null && visit.note!.isNotEmpty) ...[
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    visit.note!,
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
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
    );
  }

  Future<void> _showDeletedMembersScreen() async {
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
          builder: (context) => DeletedMembersScreen(
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
      _loadMembers();
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
                              builder: (context) => DeletedMembersScreen(
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
                          _loadMembers();
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
                          _loadMembers(); // Reload members with new business place
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
        _memberIdFilter.isNotEmpty || _searchQuery.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.01,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColor.border),
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
                            ThemeColor.primary.withValues(alpha: 0.12),
                            ThemeColor.primary.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
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
    if (_searchQuery.isNotEmpty) {
      filters.add('검색: $_searchQuery');
    }
    return filters.join(' · ');
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_memberIdFilter.isNotEmpty) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  Widget _buildFilterContent(double screenWidth, double screenHeight) {
    final hasActiveFilters =
        _memberIdFilter.isNotEmpty || _searchQuery.isNotEmpty;

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
                suffixIcon: _memberIdFilter.isNotEmpty
                    ? IconButton(
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
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.015,
                ),
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.015),

          // Combined Search Filter (name, phone, email)
          Text(
            '통합 검색',
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
                color: _searchQuery.isNotEmpty
                    ? ThemeColor.primary.withValues(alpha: 0.3)
                    : ThemeColor.border,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterMembers,
              style: TextStyle(
                fontSize: screenWidth * 0.038,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '이름, 전화번호, 이메일 검색',
                hintStyle: TextStyle(
                  color: ThemeColor.textTertiary,
                  fontSize: screenWidth * 0.036,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: ThemeColor.textTertiary,
                  size: screenWidth * 0.05,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: ThemeColor.textTertiary,
                          size: screenWidth * 0.045,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterMembers('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.015,
                ),
              ),
            ),
          ),

          // Reset Button
          if (hasActiveFilters) ...[
            SizedBox(height: screenHeight * 0.02),
            SizedBox(
              width: double.infinity,
              height: screenHeight * 0.055,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _memberIdFilter = '';
                    _searchQuery = '';
                    _memberIdFilterController.clear();
                    _searchController.clear();
                    _applyFilters();
                  });
                },
                icon: Icon(Icons.refresh_rounded, size: screenWidth * 0.045),
                label: Text(
                  '필터 초기화',
                  style: TextStyle(
                    fontSize: screenWidth * 0.038,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: ThemeColor.textSecondary,
                  backgroundColor: ThemeColor.neutral100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.025),
                  ),
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
          color: isSelected ? ThemeColor.primary : ThemeColor.neutral100,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          border: Border.all(
            color: isSelected ? ThemeColor.primary : ThemeColor.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.033,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : ThemeColor.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: screenWidth * 0.05, color: Colors.grey.shade600),
        SizedBox(width: screenWidth * 0.03),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.grey.shade600,
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
                size: 20,
              ),
            ),
            tooltip: '삭제 대기',
            onPressed: _showDeletedMembersScreen,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ThemeColor.textSecondary),
            tooltip: '새로고침',
            onPressed: _loadMembers,
          ),
          SizedBox(width: screenWidth * 0.02),
        ],
      ),
      body: Column(
        children: [
          // Business Place Selector (Inspired by Salesforce, Notion, Trello)
          _buildBusinessPlaceSelector(screenWidth, screenHeight),

          // Modern Search Filter
          _buildSearchFilter(screenWidth, screenHeight),

          // Customer List with Pull-to-Refresh
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: ThemeColor.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '고객 목록을 불러오는 중...',
                          style: TextStyle(
                            color: ThemeColor.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadMembers,
                    color: ThemeColor.primary,
                    child: _filteredMembers.isEmpty
                        ? _buildEmptyState()
                        : _buildCustomerList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_fab',
        onPressed: _showAddMemberDialog,
        backgroundColor: ThemeColor.primary,
        elevation: 2,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(
          '고객 추가',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: screenWidth * -0.0008,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bottomPadding =
        MainScreen.navBarHeight + MediaQuery.of(context).padding.bottom;

    return ListView.separated(
      padding: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: screenHeight * 0.015,
        bottom: bottomPadding,
      ),
      itemCount: _filteredMembers.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: screenHeight * 0.012),
      itemBuilder: (context, index) {
        final member = _filteredMembers[index];
        return Material(
          color: ThemeColor.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _showMemberDetails(member),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ThemeColor.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: screenWidth * 0.12,
                    height: screenWidth * 0.12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ThemeColor.primary.withValues(alpha: 0.15),
                          ThemeColor.primary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        member.name.isNotEmpty
                            ? member.name.substring(0, 1)
                            : '?',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.primary,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeColor.neutral100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                member.memberNumber,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ThemeColor.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.006),
                        if (member.phone != null)
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: ThemeColor.textTertiary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                member.phone!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ThemeColor.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        if (member.email != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 14,
                                  color: ThemeColor.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    member.email!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ThemeColor.textTertiary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ThemeColor.neutral100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: ThemeColor.textTertiary,
                      size: 20,
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

  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
                  padding: EdgeInsets.all(screenWidth * 0.06),
                  decoration: BoxDecoration(
                    color: ThemeColor.neutral100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_outline_rounded,
                    size: screenWidth * 0.15,
                    color: ThemeColor.textTertiary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                Text(
                  _searchQuery.isEmpty ? '등록된 고객이 없습니다' : '검색 결과가 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  _searchQuery.isEmpty
                      ? '새로운 고객을 추가하고\n관계를 관리해보세요'
                      : '"$_searchQuery"에 대한\n고객을 찾을 수 없습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeColor.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (_searchQuery.isEmpty) ...[
                  SizedBox(height: screenHeight * 0.035),
                  ElevatedButton.icon(
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.person_add_rounded, size: 20),
                    label: const Text('첫 고객 추가하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColor.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
