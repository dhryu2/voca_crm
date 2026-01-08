import 'dart:async';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/notification/access_request_notifier.dart';
import 'package:voca_crm/core/notification/business_place_change_notifier.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/notice_service.dart';
import 'package:voca_crm/domain/entity/notice.dart';
import 'package:voca_crm/presentation/screens/memos/memos_screen.dart';
import 'package:voca_crm/presentation/screens/reservations/reservations_screen.dart';
import 'package:voca_crm/presentation/screens/visits/visits_screen.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';
import 'package:voca_crm/presentation/widgets/notice_popup_dialog.dart';
import 'package:voca_crm/services/fcm_service.dart';

import '../../domain/entity/user.dart';
import 'customers/customers_screen.dart';
import 'home/home_screen.dart';

class MainScreen extends StatefulWidget {
  final User user;

  /// 바텀 네비게이션 바 높이 (Safe Area 제외)
  static const double navBarHeight = 56.0;

  /// 바텀 네비게이션 바 전체 높이 (Safe Area 포함)
  static double getNavBarTotalHeight(BuildContext context) {
    return navBarHeight + MediaQuery.of(context).padding.bottom;
  }

  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final NoticeService _noticeService = NoticeService();
  StreamSubscription<BusinessPlaceChangeEvent>? _businessPlaceSubscription;

  // 화면 재구성을 위한 키 - defaultBusinessPlaceId 변경 시 화면 재생성
  Key _screensKey = UniqueKey();

  @override
  void initState() {
    super.initState();

    // FCM 초기화 및 포그라운드 메시지 핸들러 설정
    _setupFCM();

    // 공지사항 표시
    _checkAndShowNotices();

    // 사업장 변경 이벤트 구독
    _businessPlaceSubscription =
        BusinessPlaceChangeNotifier().stream.listen(
      (event) {
        if (event.type == BusinessPlaceChangeType.deleted) {
          // 사업장 삭제 시, 현재 탭이 홈이 아니면 홈으로 이동
          final currentUser =
              Provider.of<UserViewModel>(context, listen: false).user;
          if (currentUser?.defaultBusinessPlaceId == null && _selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
          }
          // 화면 재구성을 위해 키 변경
          setState(() {
            _screensKey = UniqueKey();
          });
        }
      },
      onError: (error) {
        // 스트림 에러 로깅 (크래시 방지)
        if (kDebugMode) {
          debugPrint('[MainScreen] BusinessPlaceChangeNotifier stream error: $error');
        }
      },
    );
  }

  /// 탭에 해당하는 화면 리스트 (홈, 고객, 체크인, 메모, 예약)
  List<Widget> _buildScreens(User user) {
    return [
      HomeScreen(user: user, onNavigateToTab: _onItemTapped),
      CustomersScreen(user: user),
      VisitsScreen(user: user),
      MemosScreen(user: user),
      ReservationsScreen(user: user),
    ];
  }

  @override
  void dispose() {
    _businessPlaceSubscription?.cancel();
    super.dispose();
  }

  /// FCM 초기화 및 포그라운드 메시지 핸들러 설정
  void _setupFCM() {
    final fcmService = FCMService();
    fcmService.initialize(widget.user.providerId);

    // 포그라운드 메시지 수신 핸들러 설정
    fcmService.onForegroundMessage = _handleForegroundMessage;

    // 알림 탭 핸들러 설정 (앱이 백그라운드에서 열릴 때)
    fcmService.onNotificationTap = _handleNotificationTap;
  }

  /// 포그라운드 푸시 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final notificationType = data['type'] as String?;

    // 사업장 등록 요청 관련 알림 처리
    if (notificationType == 'ACCESS_REQUEST') {
      // 새 등록 요청이 도착 (Owner용)
      AccessRequestNotifier().notifyNewRequest(
        businessPlaceId: data['businessPlaceId'],
        businessPlaceName: data['businessPlaceName'],
        requesterId: data['requesterId'],
        requesterName: data['requesterName'],
      );

      // 포그라운드에서도 토스트 메시지 표시
      if (mounted) {
        final requesterName = data['requesterName'] ?? '알 수 없음';
        final businessPlaceName = data['businessPlaceName'] ?? '사업장';
        AppMessageHandler.showInfoSnackBar(
          context,
          '$businessPlaceName에 $requesterName님이 등록 요청을 보냈습니다',
        );
      }
    } else if (notificationType == 'ACCESS_APPROVED') {
      // 요청이 승인됨 (요청자용)
      AccessRequestNotifier().notifyApproved(
        businessPlaceId: data['businessPlaceId'],
        businessPlaceName: data['businessPlaceName'],
      );

      if (mounted) {
        final businessPlaceName = data['businessPlaceName'] ?? '사업장';
        AppMessageHandler.showSuccessSnackBar(
          context,
          '$businessPlaceName 등록 요청이 승인되었습니다!',
        );
      }
    } else if (notificationType == 'ACCESS_REJECTED') {
      // 요청이 거절됨 (요청자용)
      AccessRequestNotifier().notifyRejected(
        businessPlaceId: data['businessPlaceId'],
        businessPlaceName: data['businessPlaceName'],
      );

      if (mounted) {
        final businessPlaceName = data['businessPlaceName'] ?? '사업장';
        AppMessageHandler.showErrorSnackBar(
          context,
          '$businessPlaceName 등록 요청이 거절되었습니다',
        );
      }
    }
  }

  /// 알림 탭으로 앱이 열릴 때 처리
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final notificationType = data['type'] as String?;

    // 등록 요청 관련 알림 탭 시 사업장 관리 화면으로 이동
    if (notificationType == 'ACCESS_REQUEST' ||
        notificationType == 'ACCESS_APPROVED' ||
        notificationType == 'ACCESS_REJECTED') {
      // TODO: 사업장 관리 화면으로 네비게이션
      // Navigator.push(context, MaterialPageRoute(builder: ...));
    }
  }

  /// 공지사항 확인 및 표시
  Future<void> _checkAndShowNotices() async {
    // 화면이 완전히 로드된 후 공지사항 표시
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    try {
      // 활성 공지사항 조회
      final notices = await _noticeService.getActiveNotices(
        widget.user.providerId,
      );

      if (notices.isEmpty || !mounted) return;

      // 공지사항을 우선순위 순으로 하나씩 표시
      await _showNoticePopups(notices);
    } catch (e, stackTrace) {
      // Silent catch with logging
      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'MainScreen',
          action: '공지사항 조회',
          userId: widget.user.id,
          showSnackbar: false,
        );
      }
    }
  }

  /// 공지사항 팝업 순차 표시
  Future<void> _showNoticePopups(List<Notice> notices) async {
    for (final notice in notices) {
      if (!mounted) break;

      bool doNotShowAgain = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return NoticePopupDialog(
            notice: notice,
            onClose: (value) {
              doNotShowAgain = value;
              Navigator.pop(context);
            },
          );
        },
      );

      // 열람 기록 저장
      try {
        await _noticeService.recordView(
          noticeId: notice.id,
          userId: widget.user.providerId,
          doNotShowAgain: doNotShowAgain,
        );
      } catch (e, stackTrace) {
        // Silent catch with logging
        if (mounted) {
          await AppMessageHandler.handleErrorWithLogging(
            context,
            e,
            stackTrace,
            screenName: 'MainScreen',
            action: '공지사항 열람 기록 저장',
            userId: widget.user.id,
            showSnackbar: false,
          );
        }
      }
    }
  }

  void _onItemTapped(int index) {
    final currentUser =
        Provider.of<UserViewModel>(context, listen: false).user;

    // 5탭 구조: 0=홈, 1=고객, 2=체크인, 3=메모, 4=예약
    // 홈(0)은 항상 접근 가능
    if (currentUser?.defaultBusinessPlaceId == null && index != 0) {
      AppMessageHandler.showErrorSnackBar(context, "기본 사업장을 설정해주세요");
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, userViewModel, child) {
        final currentUser = userViewModel.user ?? widget.user;
        final screens = _buildScreens(currentUser);

        return Scaffold(
          key: _screensKey,
          body: IndexedStack(index: _selectedIndex, children: screens),
          bottomNavigationBar: _LiquidGlassNavBar(
            selectedIndex: _selectedIndex,
            onItemTapped: _onItemTapped,
          ),
        );
      },
    );
  }
}

/// Apple Liquid Glass 스타일 바텀 네비게이션 바 (5탭 구조)
class _LiquidGlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const _LiquidGlassNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  // 5탭 구조: 홈, 고객, 체크인, 메모, 예약
  static const List<_NavItemData> _items = [
    _NavItemData(Icons.home_outlined, Icons.home_rounded, '홈'),
    _NavItemData(Icons.people_outline_rounded, Icons.people_rounded, '고객'),
    _NavItemData(Icons.login_outlined, Icons.login_rounded, '체크인'),
    _NavItemData(Icons.note_outlined, Icons.note_rounded, '메모'),
    _NavItemData(Icons.event_note_outlined, Icons.event_note_rounded, '예약'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / _items.length;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MainScreen.navBarHeight + bottomPadding,
          decoration: BoxDecoration(
            // Liquid Glass 배경: 반투명 + 미세한 그라데이션
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.78),
                Colors.white.withValues(alpha: 0.85),
              ],
            ),
            // 상단 하이라이트 라인 (글래스 반사 효과)
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.6),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Stack(
              children: [
                // 슬라이딩 인디케이터 (선택된 탭 배경)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * itemWidth + (itemWidth - 56) / 2,
                  top: 6,
                  child: Container(
                    width: 56,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ThemeColor.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: ThemeColor.primary.withValues(alpha: 0.08),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
                // 네비게이션 아이템들
                Row(
                  children: List.generate(_items.length, (index) {
                    return Expanded(
                      child: _LiquidGlassNavItem(
                        data: _items[index],
                        isSelected: selectedIndex == index,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onItemTapped(index);
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 네비게이션 아이템 데이터
class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItemData(this.icon, this.selectedIcon, this.label);
}

/// Liquid Glass 스타일 네비게이션 아이템
class _LiquidGlassNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _LiquidGlassNavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: MainScreen.navBarHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Icon(
                  isSelected ? data.selectedIcon : data.icon,
                  size: 24,
                  color: Color.lerp(
                    ThemeColor.textTertiary,
                    ThemeColor.primary,
                    value,
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            // 라벨
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w500,
                      FontWeight.w600,
                      value,
                    ),
                    color: Color.lerp(
                      ThemeColor.textTertiary,
                      ThemeColor.primary,
                      value,
                    ),
                    letterSpacing: -0.3,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
