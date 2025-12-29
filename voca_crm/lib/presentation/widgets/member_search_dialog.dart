import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/domain/entity/business_place_with_role.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/user.dart';

/// 회원 선택 다이얼로그 결과
class MemberSearchResult {
  final Member member;

  MemberSearchResult({required this.member});
}

/// 공통 회원 검색/선택 다이얼로그
///
/// 사용법:
/// ```dart
/// final result = await MemberSearchDialog.show(
///   context: context,
///   user: currentUser,
/// );
/// if (result != null) {
///   // result.member 사용
/// }
/// ```
class MemberSearchDialog {
  /// 회원 검색 다이얼로그 표시
  ///
  /// [context] BuildContext
  /// [user] 현재 로그인한 사용자
  /// [initialBusinessPlaceId] 초기 선택할 사업장 ID (기본값: user.defaultBusinessPlaceId)
  ///
  /// 반환값: 선택된 회원 정보 (MemberSearchResult) 또는 null (취소 시)
  static Future<MemberSearchResult?> show({
    required BuildContext context,
    required User user,
    String? initialBusinessPlaceId,
  }) async {
    return showDialog<MemberSearchResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _MemberSearchDialogContent(
        user: user,
        initialBusinessPlaceId: initialBusinessPlaceId ?? user.defaultBusinessPlaceId,
      ),
    );
  }
}

class _MemberSearchDialogContent extends StatefulWidget {
  final User user;
  final String? initialBusinessPlaceId;

  const _MemberSearchDialogContent({
    required this.user,
    this.initialBusinessPlaceId,
  });

  @override
  State<_MemberSearchDialogContent> createState() => _MemberSearchDialogContentState();
}

class _MemberSearchDialogContentState extends State<_MemberSearchDialogContent> {
  final _memberRepository = MemberRepositoryImpl(MemberService());
  final _businessPlaceService = BusinessPlaceService();

  final _memberNumberController = TextEditingController();
  final _memberNameController = TextEditingController();

  List<BusinessPlaceWithRole> _businessPlaces = [];
  String? _selectedBusinessPlaceId;
  String _memberNumberSearch = '';
  String _memberNameSearch = '';

  // 사업장별 회원 목록 캐시
  final Map<String, List<Member>> _membersByBusinessPlace = {};
  List<Member> _searchResults = [];
  bool _isLoading = true;
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _selectedBusinessPlaceId = widget.initialBusinessPlaceId;
    _loadInitialData();
  }

  @override
  void dispose() {
    _memberNumberController.dispose();
    _memberNameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // 사업장 목록 로드
      final businessPlaces = await _businessPlaceService.getMyBusinessPlaces(widget.user.id);

      if (!mounted) return;

      setState(() {
        _businessPlaces = businessPlaces;
      });

      // 초기 사업장의 회원 로드
      if (_selectedBusinessPlaceId != null) {
        await _loadMembersForBusinessPlace(_selectedBusinessPlaceId!);
      }
    } catch (e) {
      // Silent fail
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMembersForBusinessPlace(String businessPlaceId) async {
    // 캐시에 있으면 사용
    if (_membersByBusinessPlace.containsKey(businessPlaceId)) {
      _filterSearchResults(_membersByBusinessPlace[businessPlaceId]!);
      return;
    }

    setState(() => _isLoadingMembers = true);

    try {
      final members = await _memberRepository.getMembersByBusinessPlace(businessPlaceId);
      _membersByBusinessPlace[businessPlaceId] = members;

      if (mounted) {
        _filterSearchResults(members);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _filterSearchResults(List<Member> members) {
    setState(() {
      _searchResults = members.where((member) {
        final matchesMemberNumber = _memberNumberSearch.isEmpty ||
            member.memberNumber.toLowerCase().contains(_memberNumberSearch.toLowerCase());
        final matchesMemberName = _memberNameSearch.isEmpty ||
            member.name.toLowerCase().contains(_memberNameSearch.toLowerCase());
        return matchesMemberNumber && matchesMemberName;
      }).toList();
    });
  }

  void _onBusinessPlaceChanged(String? businessPlaceId) {
    setState(() {
      _selectedBusinessPlaceId = businessPlaceId;
    });

    if (businessPlaceId != null) {
      _loadMembersForBusinessPlace(businessPlaceId);
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  void _onSearchChanged() {
    final members = _membersByBusinessPlace[_selectedBusinessPlaceId] ?? [];
    _filterSearchResults(members);
  }

  void _onMemberSelected(Member member) {
    Navigator.of(context).pop(MemberSearchResult(member: member));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: ThemeColor.textSecondary),
                padding: EdgeInsets.all(screenWidth * 0.04),
              ),
            ),
            // Content
            Flexible(
              child: _isLoading
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(screenWidth * 0.1),
                        child: CircularProgressIndicator(color: ThemeColor.primary),
                      ),
                    )
                  : SingleChildScrollView(
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
                            width: screenWidth * 0.16,
                            height: screenWidth * 0.16,
                            decoration: BoxDecoration(
                              color: ThemeColor.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_search_rounded,
                              size: screenWidth * 0.08,
                              color: ThemeColor.primary,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          // Title
                          Text(
                            '회원 검색',
                            style: TextStyle(
                              fontSize: screenWidth * 0.055,
                              fontWeight: FontWeight.w700,
                              color: ThemeColor.textPrimary,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            '예약할 회원을 검색하세요',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: ThemeColor.textSecondary,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.03),

                          // Business Place Selector
                          if (_businessPlaces.isNotEmpty) ...[
                            _buildLabel('사업장', screenWidth),
                            SizedBox(height: screenHeight * 0.01),
                            _buildBusinessPlaceDropdown(screenWidth),
                            SizedBox(height: screenHeight * 0.02),
                          ],

                          // Member Number Search
                          _buildLabel('회원 번호', screenWidth),
                          SizedBox(height: screenHeight * 0.01),
                          _buildTextField(
                            controller: _memberNumberController,
                            hintText: '회원 번호를 입력하세요',
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                            onChanged: (value) {
                              _memberNumberSearch = value;
                              _onSearchChanged();
                            },
                          ),
                          SizedBox(height: screenHeight * 0.02),

                          // Member Name Search
                          _buildLabel('회원 이름', screenWidth),
                          SizedBox(height: screenHeight * 0.01),
                          _buildTextField(
                            controller: _memberNameController,
                            hintText: '회원 이름을 입력하세요',
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                            onChanged: (value) {
                              _memberNameSearch = value;
                              _onSearchChanged();
                            },
                          ),
                          SizedBox(height: screenHeight * 0.03),

                          // Divider
                          Divider(height: 1, color: ThemeColor.border),
                          SizedBox(height: screenHeight * 0.02),

                          // Search Results Label
                          _buildLabel('검색 결과 (${_searchResults.length}명)', screenWidth),
                          SizedBox(height: screenHeight * 0.01),

                          // Search Results List
                          _buildSearchResultsList(screenWidth, screenHeight),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, double screenWidth) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: screenWidth * 0.035,
          fontWeight: FontWeight.w600,
          color: ThemeColor.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBusinessPlaceDropdown(double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ThemeColor.border, width: 1.5),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBusinessPlaceId,
          isExpanded: true,
          icon: Padding(
            padding: EdgeInsets.only(right: screenWidth * 0.03),
            child: Icon(Icons.arrow_drop_down, color: ThemeColor.primary),
          ),
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          items: _businessPlaces.map((item) {
            return DropdownMenuItem<String>(
              value: item.businessPlace.id,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                child: Text(
                  item.businessPlace.name,
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: _onBusinessPlaceChanged,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required double screenWidth,
    required double screenHeight,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ThemeColor.border, width: 1.5),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontSize: screenWidth * 0.04,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: screenWidth * 0.038,
            color: ThemeColor.textTertiary,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.018,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSearchResultsList(double screenWidth, double screenHeight) {
    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.3),
      child: _isLoadingMembers
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.08),
                child: CircularProgressIndicator(color: ThemeColor.primary),
              ),
            )
          : _searchResults.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(screenWidth * 0.08),
                    child: Text(
                      '검색 결과가 없습니다',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: ThemeColor.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: ThemeColor.border,
                  ),
                  itemBuilder: (context, index) {
                    final member = _searchResults[index];
                    return _buildMemberTile(member, screenWidth, screenHeight);
                  },
                ),
    );
  }

  Widget _buildMemberTile(Member member, double screenWidth, double screenHeight) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenHeight * 0.005,
      ),
      leading: Container(
        width: screenWidth * 0.1,
        height: screenWidth * 0.1,
        decoration: BoxDecoration(
          color: ThemeColor.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(screenWidth * 0.025),
        ),
        child: Center(
          child: Text(
            member.name.isNotEmpty ? member.name.substring(0, 1) : '?',
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
              color: ThemeColor.primary,
            ),
          ),
        ),
      ),
      title: Text(
        member.name,
        style: TextStyle(
          fontSize: screenWidth * 0.04,
          fontWeight: FontWeight.w600,
          color: ThemeColor.textPrimary,
        ),
      ),
      subtitle: Text(
        member.memberNumber,
        style: TextStyle(
          fontSize: screenWidth * 0.032,
          color: ThemeColor.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: ThemeColor.textTertiary,
        size: screenWidth * 0.05,
      ),
      onTap: () => _onMemberSelected(member),
    );
  }
}
