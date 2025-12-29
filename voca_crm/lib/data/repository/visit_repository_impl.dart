import 'package:voca_crm/data/datasource/visit_service.dart';
import 'package:voca_crm/domain/entity/visit.dart';
import 'package:voca_crm/domain/repository/visit_repository.dart';

class VisitRepositoryImpl implements VisitRepository {
  final VisitService _visitService;

  VisitRepositoryImpl([VisitService? visitService])
      : _visitService = visitService ?? VisitService();

  @override
  Future<Visit> checkIn(String memberId, {String? note}) async {
    return _visitService.checkIn(memberId: memberId, note: note);
  }

  @override
  Future<List<Visit>> getVisitsByMemberId(String memberId) async {
    return _visitService.getVisitsByMemberId(memberId);
  }

  @override
  Future<List<Visit>> getTodayVisits(String businessPlaceId) async {
    return _visitService.getTodayVisits(businessPlaceId);
  }

  @override
  Future<void> cancelCheckIn(String visitId, String businessPlaceId) async {
    return _visitService.cancelCheckIn(
      visitId: visitId,
      businessPlaceId: businessPlaceId,
    );
  }
}
