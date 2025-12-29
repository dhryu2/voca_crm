import 'package:flutter/foundation.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/notification_service.dart';
import 'package:voca_crm/domain/entity/notification.dart';

/// 알림 상태
enum NotificationState {
  initial,
  loading,
  loaded,
  error,
}

/// 알림 뷰모델
class NotificationViewModel extends ChangeNotifier {
  final NotificationService _notificationService;

  NotificationViewModel({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  NotificationState _state = NotificationState.initial;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  int _currentPage = 0;
  bool _hasMore = true;
  String? _errorMessage;
  String? _userId;

  // Getters
  NotificationState get state => _state;
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == NotificationState.loading;

  /// 사용자 ID 설정
  void setUserId(String userId) {
    if (_userId != userId) {
      _userId = userId;
      _notifications = [];
      _currentPage = 0;
      _hasMore = true;
      _unreadCount = 0;
    }
  }

  /// 알림 목록 로드
  Future<void> loadNotifications({bool refresh = false}) async {
    if (_userId == null) return;
    if (_state == NotificationState.loading) return;
    if (!refresh && !_hasMore) return;

    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
    }

    _state = NotificationState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _notificationService.getNotifications(
        userId: _userId!,
        page: _currentPage,
        size: 20,
      );

      if (refresh) {
        _notifications = response.content;
      } else {
        _notifications = [..._notifications, ...response.content];
      }

      _hasMore = !response.last;
      if (_hasMore) {
        _currentPage++;
      }

      _state = NotificationState.loaded;
    } catch (e) {
      _errorMessage = AppMessageHandler.parseErrorMessage(e);
      _state = NotificationState.error;
    }

    notifyListeners();
  }

  /// 읽지 않은 알림 수 로드
  Future<void> loadUnreadCount() async {
    if (_userId == null) return;

    try {
      _unreadCount = await _notificationService.getUnreadCount(_userId!);
      notifyListeners();
    } catch (e) {
      // Error loading unread count
    }
  }

  /// 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);

      // 로컬 상태 업데이트
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = AppNotification(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          notificationType: _notifications[index].notificationType,
          title: _notifications[index].title,
          body: _notifications[index].body,
          entityType: _notifications[index].entityType,
          entityId: _notifications[index].entityId,
          data: _notifications[index].data,
          status: _notifications[index].status,
          isRead: true,
          readAt: DateTime.now(),
          createdAt: _notifications[index].createdAt,
        );

        if (_unreadCount > 0) {
          _unreadCount--;
        }

        notifyListeners();
      }
    } catch (e) {
      // Error marking as read
    }
  }

  /// 모든 알림 읽음 처리
  Future<void> markAllAsRead() async {
    if (_userId == null) return;

    try {
      await _notificationService.markAllAsRead(_userId!);

      // 로컬 상태 업데이트
      _notifications = _notifications.map((n) {
        if (!n.isRead) {
          return AppNotification(
            id: n.id,
            userId: n.userId,
            notificationType: n.notificationType,
            title: n.title,
            body: n.body,
            entityType: n.entityType,
            entityId: n.entityId,
            data: n.data,
            status: n.status,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();

      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      // Error marking all as read
    }
  }

  /// 새 알림 수신 (FCM에서 호출)
  void onNewNotification(AppNotification notification) {
    // 목록 맨 앞에 추가
    _notifications = [notification, ..._notifications];
    _unreadCount++;
    notifyListeners();
  }

  /// 초기화
  void reset() {
    _state = NotificationState.initial;
    _notifications = [];
    _unreadCount = 0;
    _currentPage = 0;
    _hasMore = true;
    _errorMessage = null;
    _userId = null;
    notifyListeners();
  }
}
