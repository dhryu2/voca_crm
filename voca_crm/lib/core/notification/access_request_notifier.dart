import 'dart:async';

/// 사업장 등록 요청 이벤트 타입
enum AccessRequestEventType {
  /// 새 요청이 도착 (Owner가 받음)
  newRequest,

  /// 요청이 승인됨 (요청자가 받음)
  approved,

  /// 요청이 거절됨 (요청자가 받음)
  rejected,

  /// 요청 상태가 변경됨 (일반적인 갱신)
  updated,
}

/// 사업장 등록 요청 이벤트
class AccessRequestEvent {
  final AccessRequestEventType type;
  final String? businessPlaceId;
  final String? businessPlaceName;
  final String? requesterId;
  final String? requesterName;

  AccessRequestEvent({
    required this.type,
    this.businessPlaceId,
    this.businessPlaceName,
    this.requesterId,
    this.requesterName,
  });

  @override
  String toString() {
    return 'AccessRequestEvent(type: $type, businessPlaceId: $businessPlaceId, businessPlaceName: $businessPlaceName)';
  }
}

/// 사업장 등록 요청 알림 서비스
///
/// 등록 요청이 생성, 승인, 거절될 때 모든 구독자에게 알림을 전송합니다.
/// FCM 푸시 알림 수신 시 이 Notifier를 통해 UI를 갱신합니다.
class AccessRequestNotifier {
  static final AccessRequestNotifier _instance =
      AccessRequestNotifier._internal();

  factory AccessRequestNotifier() => _instance;

  AccessRequestNotifier._internal();

  final StreamController<AccessRequestEvent> _controller =
      StreamController<AccessRequestEvent>.broadcast();

  /// 등록 요청 이벤트 스트림
  Stream<AccessRequestEvent> get stream => _controller.stream;

  /// 새 요청 도착 알림 (Owner용)
  void notifyNewRequest({
    String? businessPlaceId,
    String? businessPlaceName,
    String? requesterId,
    String? requesterName,
  }) {
    _controller.add(AccessRequestEvent(
      type: AccessRequestEventType.newRequest,
      businessPlaceId: businessPlaceId,
      businessPlaceName: businessPlaceName,
      requesterId: requesterId,
      requesterName: requesterName,
    ));
  }

  /// 요청 승인 알림 (요청자용)
  void notifyApproved({
    String? businessPlaceId,
    String? businessPlaceName,
  }) {
    _controller.add(AccessRequestEvent(
      type: AccessRequestEventType.approved,
      businessPlaceId: businessPlaceId,
      businessPlaceName: businessPlaceName,
    ));
  }

  /// 요청 거절 알림 (요청자용)
  void notifyRejected({
    String? businessPlaceId,
    String? businessPlaceName,
  }) {
    _controller.add(AccessRequestEvent(
      type: AccessRequestEventType.rejected,
      businessPlaceId: businessPlaceId,
      businessPlaceName: businessPlaceName,
    ));
  }

  /// 일반적인 요청 상태 변경 알림
  void notifyUpdated() {
    _controller.add(AccessRequestEvent(
      type: AccessRequestEventType.updated,
    ));
  }

  /// 리소스 해제
  void dispose() {
    _controller.close();
  }
}
