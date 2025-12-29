import 'package:voca_crm/domain/entity/visit.dart';

abstract class VisitRepository {
  /// 체크인 (방문 기록 생성)
  Future<Visit> checkIn(String memberId, {String? note});

  /// 회원별 방문 기록 조회
  Future<List<Visit>> getVisitsByMemberId(String memberId);

  /// 오늘 방문 기록 조회 (사업장별)
  Future<List<Visit>> getTodayVisits(String businessPlaceId);

  /// 체크인 취소 (삭제)
  Future<void> cancelCheckIn(String visitId, String businessPlaceId);
}
