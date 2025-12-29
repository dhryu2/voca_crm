import 'dart:async';

/// 사업장 변경 이벤트 타입
enum BusinessPlaceChangeType {
  created,
  updated,
  deleted,
}

/// 사업장 변경 이벤트
class BusinessPlaceChangeEvent {
  final BusinessPlaceChangeType type;
  final String? businessPlaceId;

  BusinessPlaceChangeEvent({
    required this.type,
    this.businessPlaceId,
  });
}

/// 사업장 변경 알림 서비스
///
/// 사업장이 추가, 수정, 삭제될 때 모든 구독자에게 알림을 전송합니다.
class BusinessPlaceChangeNotifier {
  static final BusinessPlaceChangeNotifier _instance =
      BusinessPlaceChangeNotifier._internal();

  factory BusinessPlaceChangeNotifier() => _instance;

  BusinessPlaceChangeNotifier._internal();

  final StreamController<BusinessPlaceChangeEvent> _controller =
      StreamController<BusinessPlaceChangeEvent>.broadcast();

  /// 사업장 변경 이벤트 스트림
  Stream<BusinessPlaceChangeEvent> get stream => _controller.stream;

  /// 사업장 생성 알림
  void notifyCreated(String businessPlaceId) {
    _controller.add(BusinessPlaceChangeEvent(
      type: BusinessPlaceChangeType.created,
      businessPlaceId: businessPlaceId,
    ));
  }

  /// 사업장 수정 알림
  void notifyUpdated(String businessPlaceId) {
    _controller.add(BusinessPlaceChangeEvent(
      type: BusinessPlaceChangeType.updated,
      businessPlaceId: businessPlaceId,
    ));
  }

  /// 사업장 삭제 알림
  void notifyDeleted(String businessPlaceId) {
    _controller.add(BusinessPlaceChangeEvent(
      type: BusinessPlaceChangeType.deleted,
      businessPlaceId: businessPlaceId,
    ));
  }

  /// 리소스 해제
  void dispose() {
    _controller.close();
  }
}
