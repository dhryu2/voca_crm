import 'package:voca_crm/data/datasource/reservation_service.dart';
import 'package:voca_crm/data/model/reservation_model.dart';
import 'package:voca_crm/domain/entity/reservation.dart';
import 'package:voca_crm/domain/repository/reservation_repository.dart';

/// 예약 레포지토리 구현체
class ReservationRepositoryImpl implements ReservationRepository {
  final ReservationService reservationService;

  ReservationRepositoryImpl(this.reservationService);

  @override
  Future<Reservation> createReservation(Reservation reservation) async {
    final model = ReservationModel.fromEntity(reservation);
    final created = await reservationService.createReservation(model);
    return created.toEntity();
  }

  @override
  Future<Reservation> getReservationById(String id) async {
    final model = await reservationService.getReservationById(id);
    return model.toEntity();
  }

  @override
  Future<List<Reservation>> getReservationsByMemberId(String memberId) async {
    final models = await reservationService.getReservationsByMemberId(memberId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Reservation>> getReservationsByBusinessPlaceId(
      String businessPlaceId) async {
    final models =
        await reservationService.getReservationsByBusinessPlaceId(businessPlaceId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Reservation>> getReservationsByDate(
      String businessPlaceId, DateTime date) async {
    final models =
        await reservationService.getReservationsByDate(businessPlaceId, date);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Reservation>> getReservationsByDateRange(
      String businessPlaceId, DateTime startDate, DateTime endDate) async {
    final models = await reservationService.getReservationsByDateRange(
        businessPlaceId, startDate, endDate);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Reservation>> getReservationsByStatus(
      String businessPlaceId, ReservationStatus status) async {
    final models = await reservationService.getReservationsByStatus(
        businessPlaceId, status.name);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Reservation> updateReservation(
      String id, Reservation reservation) async {
    final model = ReservationModel.fromEntity(reservation);
    final updated = await reservationService.updateReservation(id, model);
    return updated.toEntity();
  }

  @override
  Future<Reservation> updateReservationStatus(
      String id, ReservationStatus status, {String? updatedBy}) async {
    final updated =
        await reservationService.updateReservationStatus(id, status.name, updatedBy: updatedBy);
    return updated.toEntity();
  }

  // 예약 삭제 API는 제거됨
  // - 고객 취소: updateReservationStatus(id, CANCELLED) 사용
  // - 노쇼: updateReservationStatus(id, NO_SHOW) 사용
  // - 오래된 데이터: 서버에서 900일 후 자동 삭제

  @override
  Future<int> getReservationCount(String businessPlaceId, DateTime? date) async {
    return await reservationService.getReservationCount(businessPlaceId, date);
  }

  @override
  Future<Map<String, dynamic>> getMemberReservationStats(String memberId) async {
    return await reservationService.getMemberReservationStats(memberId);
  }
}
