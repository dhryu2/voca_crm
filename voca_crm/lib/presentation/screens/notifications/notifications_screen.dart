import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/domain/entity/notification.dart';
import 'package:voca_crm/presentation/viewmodels/notification_view_model.dart';
import 'package:voca_crm/presentation/widgets/skeleton_loader.dart';
import 'package:voca_crm/presentation/widgets/empty_state_widget.dart';

/// 알림 목록 화면
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 화면 진입 시 알림 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationViewModel>().loadNotifications(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final viewModel = context.read<NotificationViewModel>();
      if (!viewModel.isLoading && viewModel.hasMore) {
        viewModel.loadNotifications();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Consumer<NotificationViewModel>(
            builder: (context, vm, _) {
              if (vm.unreadCount > 0) {
                return TextButton(
                  onPressed: () => vm.markAllAsRead(),
                  child: const Text('모두 읽음'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationViewModel>(
        builder: (context, viewModel, _) {
          switch (viewModel.state) {
            case NotificationState.initial:
            case NotificationState.loading:
              if (viewModel.notifications.isEmpty) {
                return const _LoadingList();
              }
              return _NotificationList(
                notifications: viewModel.notifications,
                scrollController: _scrollController,
                isLoadingMore: true,
                onNotificationTap: _onNotificationTap,
              );

            case NotificationState.loaded:
              if (viewModel.notifications.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.notifications_none,
                  title: '알림이 없습니다',
                  message: '새로운 알림이 오면 여기에 표시됩니다',
                );
              }
              return RefreshIndicator(
                onRefresh: () => viewModel.loadNotifications(refresh: true),
                child: _NotificationList(
                  notifications: viewModel.notifications,
                  scrollController: _scrollController,
                  isLoadingMore: false,
                  onNotificationTap: _onNotificationTap,
                ),
              );

            case NotificationState.error:
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: screenWidth * 0.12, color: Colors.grey),
                    SizedBox(height: screenHeight * 0.02),
                    Text(
                      viewModel.errorMessage ?? '알림을 불러오는데 실패했습니다',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    ElevatedButton(
                      onPressed: () => viewModel.loadNotifications(refresh: true),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }

  void _onNotificationTap(AppNotification notification) {
    // 읽음 처리
    if (!notification.isRead) {
      context.read<NotificationViewModel>().markAsRead(notification.id);
    }

    // 해당 화면으로 이동
    final navigateTo = notification.navigateTo;
    if (navigateTo != null && mounted) {
      Navigator.pushNamed(context, navigateTo);
    }
  }
}

/// 로딩 리스트 (스켈레톤)
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) => const _NotificationSkeletonItem(),
    );
  }
}

/// 스켈레톤 아이템
class _NotificationSkeletonItem extends StatelessWidget {
  const _NotificationSkeletonItem();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.015),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(
            width: screenWidth * 0.1,
            height: screenWidth * 0.1,
            borderRadius: BorderRadius.all(Radius.circular(screenWidth * 0.05)),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  height: screenHeight * 0.02,
                  width: screenWidth * 0.6,
                ),
                SizedBox(height: screenHeight * 0.01),
                SkeletonLoader(
                  height: screenHeight * 0.018,
                  width: screenWidth * 0.38,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 알림 목록
class _NotificationList extends StatelessWidget {
  final List<AppNotification> notifications;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final Function(AppNotification) onNotificationTap;

  const _NotificationList({
    required this.notifications,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: notifications.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == notifications.length) {
          final screenWidth = MediaQuery.of(context).size.width;
          return Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final notification = notifications[index];
        return _NotificationItem(
          notification: notification,
          onTap: () => onNotificationTap(notification),
        );
      },
    );
  }
}

/// 알림 아이템
class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead ? null : ThemeColor.primaryPurple.withValues(alpha: 0.05),
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.015),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationIcon(type: notification.notificationType),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight:
                                notification.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: screenWidth * 0.0375,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: screenWidth * 0.02,
                          height: screenWidth * 0.02,
                          decoration: const BoxDecoration(
                            color: ThemeColor.primaryPurple,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (notification.body != null) ...[
                    SizedBox(height: screenHeight * 0.005),
                    Text(
                      notification.body!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: screenWidth * 0.035,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: screenHeight * 0.005),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.015, vertical: screenHeight * 0.003),
                        decoration: BoxDecoration(
                          color: _getTypeColor(notification.notificationType)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(screenWidth * 0.01),
                        ),
                        child: Text(
                          notification.notificationType.displayName,
                          style: TextStyle(
                            color: _getTypeColor(notification.notificationType),
                            fontSize: screenWidth * 0.028,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: screenWidth * 0.03,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.reservationCreated:
      case NotificationType.reservationReminder:
      case NotificationType.reservationModified:
        return Colors.blue;
      case NotificationType.reservationCancelled:
        return Colors.red;
      case NotificationType.memoCreated:
      case NotificationType.memoMentioned:
        return Colors.orange;
      case NotificationType.memberCreated:
      case NotificationType.memberVisited:
        return Colors.green;
      case NotificationType.noticeNew:
        return ThemeColor.primaryPurple;
      case NotificationType.systemAnnouncement:
        return Colors.grey;
      case NotificationType.securityAlert:
        return Colors.red;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '방금 전';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}

/// 알림 타입별 아이콘
class _NotificationIcon extends StatelessWidget {
  final NotificationType type;

  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.reservationCreated:
      case NotificationType.reservationReminder:
      case NotificationType.reservationModified:
      case NotificationType.reservationCancelled:
        icon = Icons.calendar_today;
        color = Colors.blue;
        break;
      case NotificationType.memoCreated:
      case NotificationType.memoMentioned:
        icon = Icons.note;
        color = Colors.orange;
        break;
      case NotificationType.memberCreated:
      case NotificationType.memberVisited:
        icon = Icons.person;
        color = Colors.green;
        break;
      case NotificationType.noticeNew:
        icon = Icons.campaign;
        color = ThemeColor.primaryPurple;
        break;
      case NotificationType.systemAnnouncement:
        icon = Icons.info;
        color = Colors.grey;
        break;
      case NotificationType.securityAlert:
        icon = Icons.security;
        color = Colors.red;
        break;
    }

    return Container(
      width: screenWidth * 0.1,
      height: screenWidth * 0.1,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: screenWidth * 0.05),
    );
  }
}
