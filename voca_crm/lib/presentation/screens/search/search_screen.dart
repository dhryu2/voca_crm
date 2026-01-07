import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/utils/haptic_helper.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/core/utils/recent_search_manager.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/datasource/memo_service.dart';
import 'package:voca_crm/data/datasource/reservation_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/data/repository/memo_repository_impl.dart';
import 'package:voca_crm/data/repository/reservation_repository_impl.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/memo.dart';
import 'package:voca_crm/domain/entity/reservation.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final _memberRepository = MemberRepositoryImpl(
    MemberService(),
  );
  final _memoRepository = MemoRepositoryImpl(
    MemoService(),
  );
  final _reservationRepository = ReservationRepositoryImpl(
    ReservationService(),
  );

  List<String> _recentSearches = [];
  late TabController _tabController;

  String _searchQuery = '';
  bool _isSearching = false;
  List<Member> _memberResults = [];
  List<Member> _membersForMemos = [];
  Map<String, List<Memo>> _memoResults = {};
  List<Reservation> _reservationResults = [];

  /// 검색 요청 카운터 (Race Condition 방지)
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecentSearches();
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await RecentSearchManager.getRecentSearches();
    setState(() {
      _recentSearches = searches;
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    // 검색 요청 ID 증가 (Race Condition 방지)
    final currentRequestId = ++_searchRequestId;

    HapticHelper.light();
    setState(() {
      _searchQuery = query;
      _isSearching = true;
      _memberResults = [];
      _memoResults = {};
      _membersForMemos = [];
      _reservationResults = [];
    });

    await RecentSearchManager.addSearch(query);
    await _loadRecentSearches();

    try {
      // Get business place ID
      final currentUser = Provider.of<UserViewModel>(context, listen: false).user;
      final businessPlaceId = currentUser?.defaultBusinessPlaceId;

      // Search members
      final members = await _memberRepository.searchMembers(
        name: query,
      );

      // 새로운 검색이 시작되었으면 이전 결과 무시
      if (currentRequestId != _searchRequestId) return;

      // Search memos for each member
      final allMembers = await _memberRepository.getAllMembers();

      // 새로운 검색이 시작되었으면 이전 결과 무시
      if (currentRequestId != _searchRequestId) return;

      final Map<String, List<Memo>> memosByMember = {};
      final List<Member> membersWithMatchingMemos = [];

      for (final member in allMembers) {
        // 새로운 검색이 시작되었으면 중단
        if (currentRequestId != _searchRequestId) return;

        try {
          final memos = await _memoRepository.getMemosByMemberId(member.id);
          final matchingMemos = memos.where((memo) {
            return memo.content.toLowerCase().contains(query.toLowerCase());
          }).toList();

          if (matchingMemos.isNotEmpty) {
            memosByMember[member.id] = matchingMemos;
            membersWithMatchingMemos.add(member);
          }
        } catch (e) {
          // Ignore errors for individual member memo searches
        }
      }

      // 새로운 검색이 시작되었으면 이전 결과 무시
      if (currentRequestId != _searchRequestId) return;

      // Search reservations
      List<Reservation> reservations = [];
      if (businessPlaceId != null && businessPlaceId.isNotEmpty) {
        try {
          final allReservations = await _reservationRepository
              .getReservationsByBusinessPlaceId(businessPlaceId);

          // 새로운 검색이 시작되었으면 이전 결과 무시
          if (currentRequestId != _searchRequestId) return;

          // Filter reservations by member name or service type
          reservations = allReservations.where((reservation) {
            final member = allMembers.firstWhere(
              (m) => m.id == reservation.memberId,
              orElse: () => Member(
                id: '',
                memberNumber: '',
                name: '',
                businessPlaceId: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            return member.name.toLowerCase().contains(query.toLowerCase()) ||
                (reservation.serviceType?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
                (reservation.notes?.toLowerCase().contains(query.toLowerCase()) ?? false);
          }).toList();
        } catch (e) {
          // Ignore errors for reservation search
        }
      }

      // 새로운 검색이 시작되었으면 이전 결과 무시
      if (currentRequestId != _searchRequestId) return;
      if (!mounted) return;

      setState(() {
        _memberResults = members;
        _memoResults = memosByMember;
        _membersForMemos = membersWithMatchingMemos;
        _reservationResults = reservations;
        _isSearching = false;
      });
    } catch (e, stackTrace) {
      // 새로운 검색이 시작되었으면 에러 무시
      if (currentRequestId != _searchRequestId) return;
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      if (mounted) {
        // Get current user from context
        final currentUser = Provider.of<UserViewModel>(context, listen: false).user;
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'SearchScreen',
          action: '검색',
          userId: currentUser?.id,
        );
      }
    }
  }

  void _clearSearch() {
    HapticHelper.light();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _memberResults = [];
      _memoResults = {};
      _membersForMemos = [];
      _reservationResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.neutral50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeColor.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Builder(
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            return TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: TextStyle(fontSize: screenWidth * 0.04),
              decoration: InputDecoration(
                hintText: '고객, 메모 검색...',
                hintStyle: TextStyle(color: ThemeColor.neutral500),
                border: InputBorder.none,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: ThemeColor.textSecondary),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {});
              },
              onSubmitted: _performSearch,
            );
          },
        ),
        bottom: _searchQuery.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return Container(
                      color: Colors.white,
                      child: TabBar(
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
                        tabs: [
                          Tab(text: '고객 (${_memberResults.length})'),
                          Tab(text: '메모 (${_memoResults.length})'),
                          Tab(text: '예약 (${_reservationResults.length})'),
                        ],
                      ),
                    );
                  },
                ),
              )
            : null,
      ),
      body: _searchQuery.isEmpty
          ? _buildRecentSearches()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCustomerResults(),
                _buildMemoResults(),
                _buildReservationResults(),
              ],
            ),
    );
  }

  Widget _buildRecentSearches() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.08),
              decoration: BoxDecoration(
                color: ThemeColor.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_outlined, size: screenWidth * 0.2, color: ThemeColor.textTertiary),
            ),
            SizedBox(height: screenHeight * 0.04),
            Text(
              '검색어를 입력하세요',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: ThemeColor.textPrimary,
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            Text(
              '고객과 메모를 빠르게 찾아보세요',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: ThemeColor.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: ListView(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(screenWidth * 0.05, screenHeight * 0.025, screenWidth * 0.03, screenHeight * 0.015),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 검색어',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                    color: ThemeColor.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    HapticHelper.light();
                    await RecentSearchManager.clearAll();
                    await _loadRecentSearches();
                  },
                  child: Text(
                    '전체 삭제',
                    style: TextStyle(
                      color: ThemeColor.textSecondary,
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_recentSearches.length, (index) {
            final query = _recentSearches[index];
            return Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  _searchController.text = query;
                  _performSearch(query);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.015,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: ThemeColor.neutral100,
                        width: screenWidth * 0.0025,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: ThemeColor.textSecondary,
                        size: screenWidth * 0.05,
                      ),
                      SizedBox(width: screenWidth * 0.04),
                      Expanded(
                        child: Text(
                          query,
                          style: TextStyle(
                            fontSize: screenWidth * 0.0375,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: ThemeColor.textTertiary,
                          size: screenWidth * 0.05,
                        ),
                        onPressed: () async {
                          HapticHelper.light();
                          await RecentSearchManager.removeSearch(query);
                          await _loadRecentSearches();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCustomerResults() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          color: ThemeColor.primary,
        ),
      );
    }

    if (_memberResults.isEmpty) {
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
                  Icons.people_outline,
                  size: screenWidth * 0.2,
                  color: ThemeColor.textTertiary,
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              Text(
                '검색 결과가 없습니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
              Text(
                '"$_searchQuery"에 대한\n고객 검색 결과가 없습니다',
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

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
      itemCount: _memberResults.length,
      separatorBuilder: (context, index) => SizedBox(height: screenHeight * 0.01),
      itemBuilder: (context, index) {
        final member = _memberResults[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          child: InkWell(
            onTap: () {
              // 회원 상세 화면으로 이동 (Customers 탭에서 확인 가능)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${member.name}님의 상세 정보는 회원 탭에서 확인하세요'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Row(
                children: [
                  Container(
                    width: screenWidth * 0.12,
                    height: screenWidth * 0.12,
                    decoration: BoxDecoration(
                      color: ThemeColor.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                    child: Center(
                      child: Text(
                        member.name.substring(0, 1),
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
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
                        Text(
                          member.name,
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.005),
                        if (member.phone != null)
                          Text(
                            member.phone!,
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: ThemeColor.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: ThemeColor.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemoResults() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          color: ThemeColor.primary,
        ),
      );
    }

    if (_membersForMemos.isEmpty) {
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
                  Icons.note_outlined,
                  size: screenWidth * 0.2,
                  color: ThemeColor.textTertiary,
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              Text(
                '검색 결과가 없습니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
              Text(
                '"$_searchQuery"에 대한\n메모 검색 결과가 없습니다',
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

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
      itemCount: _membersForMemos.length,
      separatorBuilder: (context, index) => SizedBox(height: screenHeight * 0.015),
      itemBuilder: (context, index) {
        final member = _membersForMemos[index];
        final memos = _memoResults[member.id] ?? [];

        return Material(
          color: Colors.white,
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
                        borderRadius: BorderRadius.circular(screenWidth * 0.025),
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
                          Text(
                            '메모 ${memos.length}개',
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
                SizedBox(height: screenHeight * 0.015),
                ...memos.take(2).map((memo) {
                  return Container(
                    margin: EdgeInsets.only(top: screenHeight * 0.01),
                    padding: EdgeInsets.all(screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: ThemeColor.neutral50,
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    ),
                    child: Text(
                      memo.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: ThemeColor.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  );
                }).toList(),
                if (memos.length > 2)
                  Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.01),
                    child: Text(
                      '외 ${memos.length - 2}개 더보기',
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: ThemeColor.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReservationResults() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          color: ThemeColor.primary,
        ),
      );
    }

    if (_reservationResults.isEmpty) {
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
                  Icons.event_busy,
                  size: screenWidth * 0.2,
                  color: ThemeColor.textTertiary,
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              Text(
                '검색 결과가 없습니다',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
              Text(
                '"$_searchQuery"에 대한\n예약 검색 결과가 없습니다',
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

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
      itemCount: _reservationResults.length,
      separatorBuilder: (context, index) => SizedBox(height: screenHeight * 0.015),
      itemBuilder: (context, index) {
        final reservation = _reservationResults[index];
        return FutureBuilder<Member?>(
          future: _memberRepository.getMemberById(reservation.memberId),
          builder: (context, snapshot) {
            final memberName = snapshot.data?.name ?? '로딩중...';

            return Material(
              color: Colors.white,
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
                            color: _getReservationStatusColor(reservation.status)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(screenWidth * 0.025),
                          ),
                          child: Center(
                            child: Text(
                              memberName.isNotEmpty ? memberName[0] : '?',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                                color: _getReservationStatusColor(reservation.status),
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
                                memberName,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeColor.textPrimary,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.005),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: screenWidth * 0.035,
                                    color: ThemeColor.textSecondary,
                                  ),
                                  SizedBox(width: screenWidth * 0.01),
                                  Text(
                                    '${reservation.reservationDate.year}-${reservation.reservationDate.month.toString().padLeft(2, '0')}-${reservation.reservationDate.day.toString().padLeft(2, '0')} '
                                    '${reservation.reservationTime.hour.toString().padLeft(2, '0')}:${reservation.reservationTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.03,
                                      color: ThemeColor.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.03,
                            vertical: screenHeight * 0.008,
                          ),
                          decoration: BoxDecoration(
                            color: _getReservationStatusColor(reservation.status)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                          ),
                          child: Text(
                            reservation.status.displayName,
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.w600,
                              color: _getReservationStatusColor(reservation.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (reservation.serviceType != null) ...[
                      SizedBox(height: screenHeight * 0.015),
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.02),
                        decoration: BoxDecoration(
                          color: ThemeColor.neutral50,
                          borderRadius: BorderRadius.circular(screenWidth * 0.02),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.work_outline,
                              size: screenWidth * 0.035,
                              color: ThemeColor.textSecondary,
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              reservation.serviceType!,
                              style: TextStyle(
                                fontSize: screenWidth * 0.033,
                                color: ThemeColor.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getReservationStatusColor(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.PENDING:
        return ThemeColor.warning;
      case ReservationStatus.CONFIRMED:
        return ThemeColor.success;
      case ReservationStatus.CANCELLED:
        return ThemeColor.error;
      case ReservationStatus.COMPLETED:
        return ThemeColor.info;
      case ReservationStatus.NO_SHOW:
        return ThemeColor.textTertiary;
    }
  }
}
