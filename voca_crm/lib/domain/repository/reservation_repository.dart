import 'package:voca_crm/domain/entity/reservation.dart';

/// 예약 레포지토리 인터페이스
abstract class ReservationRepository {
  /// 예약 생성
  Future<Reservation> createReservation(Reservation reservation);

  /// 예약 조회 by ID
  Future<Reservation> getReservationById(String id);

  /// 회원의 예약 목록 조회
  Future<List<Reservation>> getReservationsByMemberId(String memberId);

  /// 사업장의 예약 목록 조회
  Future<List<Reservation>> getReservationsByBusinessPlaceId(
      String businessPlaceId);

  /// 사업장의 특정 날짜 예약 목록 조회
  Future<List<Reservation>> getReservationsByDate(
      String businessPlaceId, DateTime date);

  /// 사업장의 날짜 범위 예약 목록 조회
  Future<List<Reservation>> getReservationsByDateRange(
      String businessPlaceId, DateTime startDate, DateTime endDate);

  /// 사업장의 특정 상태 예약 목록 조회
  Future<List<Reservation>> getReservationsByStatus(
      String businessPlaceId, ReservationStatus status);

  /// 예약 수정
  Future<Reservation> updateReservation(String id, Reservation reservation);

  /// 예약 상태 변경
  Future<Reservation> updateReservationStatus(
      String id, ReservationStatus status, {String? updatedBy});

  // 예약 삭제 API는 제거됨
  // - 고객 취소: updateReservationStatus(id, CANCELLED) 사용
  // - 노쇼: updateReservationStatus(id, NO_SHOW) 사용
  // - 오래된 데이터: 서버에서 900일 후 자동 삭제

  /// 특정 날짜의 예약 개수 조회
  Future<int> getReservationCount(String businessPlaceId, DateTime? date);

  /// 회원의 예약 통계 조회
  Future<Map<String, dynamic>> getMemberReservationStats(String memberId);
}
