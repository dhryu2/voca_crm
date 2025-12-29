import 'package:equatable/equatable.dart';

/// 알림 엔티티
class AppNotification extends Equatable {
  final String id;
  final String userId;
  final NotificationType notificationType;
  final String title;
  final String? body;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? data;
  final NotificationStatus status;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.notificationType,
    required this.title,
    this.body,
    this.entityType,
    this.entityId,
    this.data,
    required this.status,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      notificationType: NotificationType.fromString(json['notificationType'] as String),
      title: json['title'] as String,
      body: json['body'] as String?,
      entityType: json['entityType'] as String?,
      entityId: json['entityId'] as String?,
      data: json['data'] != null
          ? (json['data'] is String
              ? _parseDataString(json['data'] as String)
              : json['data'] as Map<String, dynamic>)
          : null,
      status: NotificationStatus.fromString(json['status'] as String),
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static Map<String, dynamic>? _parseDataString(String dataStr) {
    try {
      // Simple parsing for {key=value, key2=value2} format
      if (dataStr.startsWith('{') && dataStr.endsWith('}')) {
        final content = dataStr.substring(1, dataStr.length - 1);
        final pairs = content.split(', ');
        final result = <String, dynamic>{};
        for (final pair in pairs) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            result[parts[0].trim()] = parts[1].trim();
          }
        }
        return result.isEmpty ? null : result;
      }
    } catch (_) {}
    return null;
  }

  /// 알림 클릭 시 이동할 화면 경로
  String? get navigateTo {
    if (data != null && data!.containsKey('screen')) {
      return data!['screen'] as String;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, userId, notificationType, title, isRead, createdAt];
}

/// 알림 타입
enum NotificationType {
  reservationCreated,
  reservationReminder,
  reservationCancelled,
  reservationModified,
  memoCreated,
  memoMentioned,
  memberCreated,
  memberVisited,
  noticeNew,
  systemAnnouncement,
  securityAlert;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'RESERVATION_CREATED':
        return NotificationType.reservationCreated;
      case 'RESERVATION_REMINDER':
        return NotificationType.reservationReminder;
      case 'RESERVATION_CANCELLED':
        return NotificationType.reservationCancelled;
      case 'RESERVATION_MODIFIED':
        return NotificationType.reservationModified;
      case 'MEMO_CREATED':
        return NotificationType.memoCreated;
      case 'MEMO_MENTIONED':
        return NotificationType.memoMentioned;
      case 'MEMBER_CREATED':
        return NotificationType.memberCreated;
      case 'MEMBER_VISITED':
        return NotificationType.memberVisited;
      case 'NOTICE_NEW':
        return NotificationType.noticeNew;
      case 'SYSTEM_ANNOUNCEMENT':
        return NotificationType.systemAnnouncement;
      case 'SECURITY_ALERT':
        return NotificationType.securityAlert;
      default:
        return NotificationType.systemAnnouncement;
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.reservationCreated:
        return '새 예약';
      case NotificationType.reservationReminder:
        return '예약 알림';
      case NotificationType.reservationCancelled:
        return '예약 취소';
      case NotificationType.reservationModified:
        return '예약 변경';
      case NotificationType.memoCreated:
        return '새 메모';
      case NotificationType.memoMentioned:
        return '멘션';
      case NotificationType.memberCreated:
        return '새 회원';
      case NotificationType.memberVisited:
        return '회원 방문';
      case NotificationType.noticeNew:
        return '공지사항';
      case NotificationType.systemAnnouncement:
        return '시스템';
      case NotificationType.securityAlert:
        return '보안';
    }
  }
}

/// 알림 상태
enum NotificationStatus {
  pending,
  sent,
  failed,
  cancelled;

  static NotificationStatus fromString(String value) {
    switch (value) {
      case 'PENDING':
        return NotificationStatus.pending;
      case 'SENT':
        return NotificationStatus.sent;
      case 'FAILED':
        return NotificationStatus.failed;
      case 'CANCELLED':
        return NotificationStatus.cancelled;
      default:
        return NotificationStatus.pending;
    }
  }
}
