import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/notification/access_request_notifier.dart';
import 'package:voca_crm/core/notification/business_place_change_notifier.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/domain/entity/business_place_with_role.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';
import 'package:voca_crm/presentation/widgets/character_count_text_field.dart';
import 'package:voca_crm/presentation/widgets/empty_state_widget.dart';
import 'package:voca_crm/presentation/widgets/phone_number_field.dart';
import 'package:voca_crm/presentation/widgets/skeleton_loader.dart';
import 'package:badges/badges.dart' as badges;

import 'business_place_settings_screen.dart';
import 'received_requests_screen.dart';
import 'request_access_screen.dart';
import 'sent_requests_screen.dart';

class BusinessPlaceManagementScreen extends StatefulWidget {
  final User user;

  const BusinessPlaceManagementScreen({super.key, required this.user});

  @override
  State<BusinessPlaceManagementScreen> createState() =>
      _BusinessPlaceManagementScreenState();
}

class _BusinessPlaceManagementScreenState
    extends State<BusinessPlaceManagementScreen> {
  final BusinessPlaceService _service = BusinessPlaceService();
  final TextEditingController _searchController = TextEditingController();

  List<BusinessPlaceWithRole> _businessPlaces = [];
  List<BusinessPlaceWithRole> _filteredBusinessPlaces = [];
  String? _defaultBusinessPlaceId;
  bool _isLoading = true;
  String _sortOption = 'name'; // 'name', 'recent', 'role'
  String _searchQuery = '';
  int _pendingRequestCount = 0; // Owner가 받은 PENDING 요청 개수
  int _unreadResultCount = 0; // 요청자의 미확인 답변 개수

  /// 등록 요청 이벤트 구독 (실시간 Badge 갱신용)
  StreamSubscription<AccessRequestEvent>? _accessRequestSubscription;

  @override
  void initState() {
    super.initState();
    _defaultBusinessPlaceId = widget.user.defaultBusinessPlaceId;
    _loadBusinessPlaces();
    _loadBadgeCounts();

    // 등록 요청 이벤트 구독 - 실시간 Badge 갱신
    _accessRequestSubscription =
        AccessRequestNotifier().stream.listen((event) {
      // 이벤트 발생 시 Badge 카운트 새로고침
      _loadBadgeCounts();
    });
  }

  @override
  void dispose() {
    _accessRequestSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessPlaces() async {
    setState(() => _isLoading = true);
    try {
      final places = await _service.getMyBusinessPlaces(widget.user.id);
      setState(() {
        _businessPlaces = places;
        _filterAndSortPlaces();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(context, AppMessageHandler.parseErrorMessage(e));
      }
    }
  }

  Future<void> _loadBadgeCounts() async {
    try {
      final pendingCount = await _service.getPendingRequestCount(widget.user.id);
      final unreadCount = await _service.getUnreadResultCount(widget.user.id);
      setState(() {
        _pendingRequestCount = pendingCount;
        _unreadResultCount = unreadCount;
      });
    } catch (e) {
      // Badge count load failed (non-critical)
    }
  }

  void _filterAndSortPlaces() {
    // Filter
    List<BusinessPlaceWithRole> filtered = _businessPlaces.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.businessPlace.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.businessPlace.address?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'name':
          return a.businessPlace.name.compareTo(b.businessPlace.name);
        case 'recent':
          // Default business place first, then by name
          if (a.businessPlace.id == _defaultBusinessPlaceId) return -1;
          if (b.businessPlace.id == _defaultBusinessPlaceId) return 1;
          return a.businessPlace.name.compareTo(b.businessPlace.name);
        case 'role':
          // OWNER first, then MANAGER, then STAFF
          int aRoleOrder = _getRoleOrder(a.userRole);
          int bRoleOrder = _getRoleOrder(b.userRole);
          return aRoleOrder.compareTo(bRoleOrder);
        default:
          return 0;
      }
    });

    _filteredBusinessPlaces = filtered;
  }

  int _getRoleOrder(Role role) {
    switch (role) {
      case Role.OWNER:
        return 0;
      case Role.MANAGER:
        return 1;
      case Role.STAFF:
        return 2;
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterAndSortPlaces();
    });
  }

  void _onSortChanged(String? value) {
    if (value != null) {
      setState(() {
        _sortOption = value;
        _filterAndSortPlaces();
      });
    }
  }

  Future<void> _createBusinessPlace() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final screenHeight = MediaQuery.of(dialogContext).size.height;

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
                    onPressed: () => Navigator.pop(context, false),
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
                        // Large icon
                        Container(
                          width: screenWidth * 0.16,
                          height: screenWidth * 0.16,
                          decoration: BoxDecoration(
                            color: ThemeColor.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_business,
                            size: screenWidth * 0.08,
                            color: ThemeColor.primary,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.025),

                        // Title
                        Text(
                          '새 사업장 생성',
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
                          '사업장 정보를 입력해주세요',
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            color: ThemeColor.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Input fields
                        CharacterCountTextField(
                          controller: nameController,
                          labelText: '사업장 이름',
                          hintText: '예: 강남지점',
                          maxLength: InputLimits.businessPlaceName,
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        CharacterCountTextField(
                          controller: addressController,
                          labelText: '주소 (선택)',
                          hintText: '예: 서울시 강남구',
                          maxLength: InputLimits.businessPlaceAddress,
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        PhoneNumberField(
                          controller: phoneController,
                          labelText: '전화번호 (선택)',
                          hintText: '02-1234-5678',
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Primary action button
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.065,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isEmpty) {
                                AppMessageHandler.showErrorSnackBar(
                                  context,
                                  '사업장 이름을 입력해주세요',
                                );
                                return;
                              }

                              // 전화번호에서 숫자만 추출하여 포맷팅된 형태로 전송
                              final phoneText = phoneController.text.trim();

                              try {
                                final response = await _service
                                    .createBusinessPlace(
                                      name: nameController.text,
                                      address: addressController.text.isEmpty
                                          ? null
                                          : addressController.text,
                                      phone: phoneText.isEmpty
                                          ? null
                                          : phoneText,
                                      userId: widget.user.id,
                                    );
                                if (!mounted) return;

                                // Update UserViewModel with new user data
                                Provider.of<UserViewModel>(context, listen: false)
                                    .updateUser(response['user']);

                                if (_defaultBusinessPlaceId == null) {
                                  setState(() {
                                    _defaultBusinessPlaceId = response['businessPlace'].id;
                                  });
                                }

                                // Notify business place created
                                BusinessPlaceChangeNotifier().notifyCreated(
                                  response['businessPlace'].id,
                                );

                                Navigator.pop(context, true);
                                _loadBusinessPlaces();
                              } catch (e) {
                                if (mounted) {
                                  AppMessageHandler.showErrorSnackBar(
                                    context,
                                    AppMessageHandler.parseErrorMessage(e),
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
                              '생성하기',
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

    if (result == true) {
      _loadBusinessPlaces();
    }
  }

  Future<void> _setDefaultBusinessPlace(String businessPlaceId) async {
    try {
      final updatedUser = await _service.setDefaultBusinessPlace(widget.user.id, businessPlaceId);

      // Update UserViewModel with new user data
      if (mounted) {
        Provider.of<UserViewModel>(context, listen: false)
            .updateUser(updatedUser);
      }

      setState(() {
        _defaultBusinessPlaceId = businessPlaceId;
      });
      if (mounted) {
        AppMessageHandler.showSuccessSnackBar(context, '기본 사업장으로 설정되었습니다');
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(context, AppMessageHandler.parseErrorMessage(e));
      }
    }
  }

  Future<void> _deleteBusinessPlace(BusinessPlaceWithRole item) async {
    final confirmed = await AppMessageHandler.showConfirmDialog(
      context,
      title: '사업장 나가기',
      message: '${item.businessPlace.name} 사업장에서 나가시겠습니까?',
      confirmText: '나가기',
    );

    if (confirmed) {
      try {
        await _service.removeBusinessPlace(widget.user.id, item.businessPlace.id);

        // 나간 사업장이 현재 기본 사업장이었는지 확인
        final userViewModel = Provider.of<UserViewModel>(context, listen: false);
        final currentDefaultId = userViewModel.user?.defaultBusinessPlaceId;
        final wasDefaultBusinessPlace = currentDefaultId == item.businessPlace.id;

        // Notify business place deleted
        BusinessPlaceChangeNotifier().notifyDeleted(item.businessPlace.id);

        // 사업장 목록 다시 로드
        await _loadBusinessPlaces();

        // 나간 사업장이 기본 사업장이었거나, 남은 사업장이 없으면 처리
        if (wasDefaultBusinessPlace || _businessPlaces.isEmpty) {
          if (_businessPlaces.isEmpty) {
            // 남은 사업장이 없으면 defaultBusinessPlaceId를 null로 설정
            userViewModel.updateDefaultBusinessPlace(null);
          } else {
            // 남은 사업장 중 첫 번째를 기본 사업장으로 설정
            final newDefaultId = _businessPlaces.first.businessPlace.id;
            await _service.setDefaultBusinessPlace(widget.user.id, newDefaultId);
            userViewModel.updateDefaultBusinessPlace(newDefaultId);
          }
        }

        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '사업장에서 나갔습니다');
        }
      } catch (e) {
        if (mounted) {
          AppMessageHandler.showErrorSnackBar(context, AppMessageHandler.parseErrorMessage(e));
        }
      }
    }
  }

  Future<void> _editBusinessPlace(BusinessPlaceWithRole item) async {
    final nameController = TextEditingController(text: item.businessPlace.name);
    final addressController = TextEditingController(text: item.businessPlace.address ?? '');
    final phoneController = TextEditingController(text: item.businessPlace.phone ?? '');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final screenHeight = MediaQuery.of(dialogContext).size.height;

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
                    onPressed: () => Navigator.pop(context, false),
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
                        // Large icon
                        Container(
                          width: screenWidth * 0.16,
                          height: screenWidth * 0.16,
                          decoration: BoxDecoration(
                            color: ThemeColor.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_location_alt,
                            size: screenWidth * 0.08,
                            color: ThemeColor.primary,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.025),

                        // Title
                        Text(
                          '사업장 정보 수정',
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
                          '사업장 정보를 수정해주세요',
                          style: TextStyle(
                            fontSize: screenWidth * 0.038,
                            color: ThemeColor.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Input fields
                        TextField(
                          controller: nameController,
                          style: TextStyle(
                            fontSize: screenWidth * 0.042,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            labelText: '사업장 이름',
                            labelStyle: TextStyle(
                              fontSize: screenWidth * 0.038,
                              color: ThemeColor.textSecondary,
                            ),
                            hintText: '예: 강남지점',
                            hintStyle: TextStyle(
                              fontSize: screenWidth * 0.038,
                              color: ThemeColor.textTertiary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                              borderSide: BorderSide(
                                color: ThemeColor.border,
                                width: screenWidth * 0.004,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                              borderSide: BorderSide(
                                color: ThemeColor.border,
                                width: screenWidth * 0.004,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                              borderSide: BorderSide(
                                color: ThemeColor.primary,
                                width: screenWidth * 0.005,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.045,
                              vertical: screenHeight * 0.02,
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        TextField(
                          controller: addressController,
                          style: TextStyle(
                            fontSize: screenWidth * 0.042,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            labelText: '주소 (선택)',
                            labelStyle: TextStyle(
                              fontSize: screenWidth * 0.038,
                              color: ThemeColor.textSecondary,
                            ),
                            hintText: '예: 서울시 강남구',
                            hintStyle: TextStyle(
                              fontSize: screenWidth * 0.038,
                              color: ThemeColor.textTertiary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                              borderSide: BorderSide(
                                color: ThemeColor.border,
                                width: screenWidth * 0.004,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                              borderSide: BorderSide(
                                color: ThemeColor.border,
                                width: screenWidth * 0.004,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                              borderSide: BorderSide(
                                color: ThemeColor.primary,
                                width: screenWidth * 0.005,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.045,
                              vertical: screenHeight * 0.02,
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        PhoneNumberField(
                          controller: phoneController,
                          labelText: '전화번호 (선택)',
                          hintText: '02-1234-5678',
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Primary action button
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.065,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isEmpty) {
                                AppMessageHandler.showErrorSnackBar(
                                  context,
                                  '사업장 이름을 입력해주세요',
                                );
                                return;
                              }

                              // 전화번호에서 숫자만 추출하여 포맷팅된 형태로 전송
                              final phoneText = phoneController.text.trim();

                              try {
                                await _service.updateBusinessPlace(
                                  userId: widget.user.id,
                                  businessPlaceId: item.businessPlace.id,
                                  name: nameController.text,
                                  address: addressController.text.isEmpty
                                      ? null
                                      : addressController.text,
                                  phone: phoneText.isEmpty
                                      ? null
                                      : phoneText,
                                );
                                if (!mounted) return;

                                // Notify business place updated
                                BusinessPlaceChangeNotifier().notifyUpdated(
                                  item.businessPlace.id,
                                );

                                Navigator.pop(context, true);
                              } catch (e) {
                                if (mounted) {
                                  AppMessageHandler.showErrorSnackBar(
                                    context,
                                    AppMessageHandler.parseErrorMessage(e),
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

    if (result == true) {
      _loadBusinessPlaces();
      if (mounted) {
        AppMessageHandler.showSuccessSnackBar(context, '사업장 정보가 수정되었습니다');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '정렬',
            onSelected: _onSortChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('이름순')),
              const PopupMenuItem(value: 'recent', child: Text('최근 사용순')),
              const PopupMenuItem(value: 'role', child: Text('역할별')),
            ],
          ),
          badges.Badge(
            showBadge: _unreadResultCount > 0,
            badgeContent: Text(
              '$_unreadResultCount',
              style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.025),
            ),
            badgeStyle: const badges.BadgeStyle(
              badgeColor: ThemeColor.error,
            ),
            position: badges.BadgePosition.topEnd(top: 6, end: 6),
            child: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SentRequestsScreen(user: widget.user),
                  ),
                );
                // 화면에서 돌아왔을 때 badge 개수 재로드
                _loadBadgeCounts();
              },
              tooltip: '보낸 요청',
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: screenWidth * 0.02),
            child: badges.Badge(
              showBadge: _pendingRequestCount > 0,
              badgeContent: Text(
                '$_pendingRequestCount',
                style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.025),
              ),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: ThemeColor.error,
              ),
              position: badges.BadgePosition.topEnd(top: 6, end: 6),
              child: IconButton(
                icon: const Icon(Icons.inbox),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReceivedRequestsScreen(user: widget.user),
                    ),
                  );
                  // 화면에서 돌아왔을 때 badge 개수 재로드
                  _loadBadgeCounts();
                },
                tooltip: '받은 요청',
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(screenHeight * 0.08),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.02),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '사업장 검색...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const SkeletonListView()
          : _businessPlaces.isEmpty
          ? EmptyStateWidget(
              title: '사업장이 없습니다',
              message: '새로운 사업장을 생성하거나\n다른 사업장에 접근 요청을 보내보세요',
              icon: Icons.business,
              actionLabel: '사업장 생성',
              onAction: _createBusinessPlace,
            )
          : _filteredBusinessPlaces.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: screenWidth * 0.16,
                    color: ThemeColor.textTertiary,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    '검색 결과가 없습니다',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: ThemeColor.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBusinessPlaces,
              child: ListView.builder(
                padding: EdgeInsets.all(screenWidth * 0.04),
                itemCount: _filteredBusinessPlaces.length,
                itemBuilder: (context, index) {
                  final item = _filteredBusinessPlaces[index];
                  final place = item.businessPlace;
                  final isDefault = place.id == _defaultBusinessPlaceId;
                  final isOwner = item.userRole == Role.OWNER;

                  return Card(
                    margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                      side: isDefault
                          ? BorderSide(
                              color: ThemeColor.primary,
                              width: screenWidth * 0.005,
                            )
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusinessPlaceSettingsScreen(
                              user: widget.user,
                              businessPlace: place,
                              currentUserRole: item.userRole,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                      child: Padding(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: screenWidth * 0.12,
                                  height: screenWidth * 0.12,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.03,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.business,
                                    color: ThemeColor.primary,
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.04),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              place.name,
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.045,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (isDefault)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: screenWidth * 0.02,
                                                vertical: screenHeight * 0.005,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      screenWidth * 0.02,
                                                    ),
                                              ),
                                              child: Text(
                                                '기본',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: screenWidth * 0.03,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          SizedBox(width: screenWidth * 0.02),
                                          // Role badge
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: screenWidth * 0.02,
                                              vertical: screenHeight * 0.005,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(item.userRole),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    screenWidth * 0.02,
                                                  ),
                                            ),
                                            child: Text(
                                              item.userRole.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: screenWidth * 0.025,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Business Place ID with copy button
                                      SizedBox(height: screenHeight * 0.005),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.key,
                                            size: screenWidth * 0.04,
                                            color: ThemeColor.textSecondary,
                                          ),
                                          SizedBox(width: screenWidth * 0.01),
                                          Expanded(
                                            child: Text(
                                              'ID: ${place.id.length > 8 ? '${place.id.substring(0, 8)}...' : place.id}',
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.03,
                                                color: ThemeColor.textSecondary,
                                                fontFamily: 'monospace',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Copy button - separate touch target
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                Clipboard.setData(
                                                  ClipboardData(text: place.id),
                                                );
                                                AppMessageHandler.showSuccessSnackBar(
                                                  context,
                                                  '사업장 ID가 복사되었습니다',
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(screenWidth * 0.02),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: screenWidth * 0.02,
                                                  vertical: screenHeight * 0.006,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: ThemeColor.neutral100,
                                                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                                                  border: Border.all(
                                                    color: ThemeColor.border,
                                                    width: screenWidth * 0.002,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.copy_rounded,
                                                      size: screenWidth * 0.035,
                                                      color: ThemeColor.textSecondary,
                                                    ),
                                                    SizedBox(width: screenWidth * 0.01),
                                                    Text(
                                                      '복사',
                                                      style: TextStyle(
                                                        fontSize: screenWidth * 0.028,
                                                        color: ThemeColor.textSecondary,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Member count
                                      SizedBox(height: screenHeight * 0.005),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: screenWidth * 0.04,
                                            color: ThemeColor.textSecondary,
                                          ),
                                          SizedBox(width: screenWidth * 0.01),
                                          Text(
                                            '멤버 ${item.memberCount}명',
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.035,
                                              color: ThemeColor.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (place.address != null) ...[
                                        SizedBox(height: screenHeight * 0.005),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: screenWidth * 0.04,
                                              color: ThemeColor.textSecondary,
                                            ),
                                            SizedBox(width: screenWidth * 0.01),
                                            Expanded(
                                              child: Text(
                                                place.address!,
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.035,
                                                  color: ThemeColor.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (place.phone != null) ...[
                                        SizedBox(height: screenHeight * 0.005),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: screenWidth * 0.04,
                                              color: ThemeColor.textSecondary,
                                            ),
                                            SizedBox(width: screenWidth * 0.01),
                                            Text(
                                              place.phone!,
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.035,
                                                color: ThemeColor.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isDefault)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _setDefaultBusinessPlace(place.id),
                                    icon: Icon(
                                      Icons.star_border,
                                      size: screenWidth * 0.045,
                                    ),
                                    label: const Text('기본으로 설정'),
                                  ),
                                if (isOwner) ...[
                                  SizedBox(width: screenWidth * 0.02),
                                  TextButton.icon(
                                    onPressed: () => _editBusinessPlace(item),
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: screenWidth * 0.045,
                                    ),
                                    label: const Text('수정'),
                                  ),
                                ],
                                if (!isOwner) ...[
                                  SizedBox(width: screenWidth * 0.02),
                                  TextButton.icon(
                                    onPressed: () => _deleteBusinessPlace(item),
                                    icon: Icon(
                                      Icons.exit_to_app,
                                      size: screenWidth * 0.045,
                                    ),
                                    label: const Text('나가기'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: ThemeColor.error,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'request_access',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RequestAccessScreen(user: widget.user),
                ),
              );
            },
            child: const Icon(Icons.group_add),
            tooltip: '접근 요청',
          ),
          SizedBox(height: screenHeight * 0.02),
          FloatingActionButton(
            heroTag: 'create_business',
            onPressed: _createBusinessPlace,
            child: const Icon(Icons.add),
            tooltip: '사업장 생성',
          ),
        ],
      ),
    );
  }
}
