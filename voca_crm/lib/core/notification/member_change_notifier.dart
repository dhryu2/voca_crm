import 'dart:async';

/// 회원 변경 이벤트 타입
enum MemberChangeType {
  created,
  updated,
  deleted,
}

/// 회원 변경 이벤트
class MemberChangeEvent {
  final MemberChangeType type;
  final String? memberId;
  final String? businessPlaceId;

  MemberChangeEvent({
    required this.type,
    this.memberId,
    this.businessPlaceId,
  });
}

/// 회원 변경 알림 서비스
///
/// 회원이 추가, 수정, 삭제될 때 모든 구독자에게 알림을 전송합니다.
class MemberChangeNotifier {
  static final MemberChangeNotifier _instance =
      MemberChangeNotifier._internal();

  factory MemberChangeNotifier() => _instance;

  MemberChangeNotifier._internal();

  final StreamController<MemberChangeEvent> _controller =
      StreamController<MemberChangeEvent>.broadcast();

  /// 회원 변경 이벤트 스트림
  Stream<MemberChangeEvent> get stream => _controller.stream;

  /// 회원 생성 알림
  void notifyCreated({String? memberId, String? businessPlaceId}) {
    _controller.add(MemberChangeEvent(
      type: MemberChangeType.created,
      memberId: memberId,
      businessPlaceId: businessPlaceId,
    ));
  }

  /// 회원 수정 알림
  void notifyUpdated({String? memberId, String? businessPlaceId}) {
    _controller.add(MemberChangeEvent(
      type: MemberChangeType.updated,
      memberId: memberId,
      businessPlaceId: businessPlaceId,
    ));
  }

  /// 회원 삭제 알림
  void notifyDeleted({String? memberId, String? businessPlaceId}) {
    _controller.add(MemberChangeEvent(
      type: MemberChangeType.deleted,
      memberId: memberId,
      businessPlaceId: businessPlaceId,
    ));
  }

  /// 리소스 해제
  void dispose() {
    _controller.close();
  }
}
