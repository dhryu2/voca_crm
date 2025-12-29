import 'package:voca_crm/domain/entity/audit_log.dart';

abstract class AuditLogRepository {
  /// 사업장별 감사 로그 목록 조회 (페이징)
  Future<AuditLogPage> getAuditLogs({
    required String businessPlaceId,
    int page = 0,
    int size = 20,
    String? entityType,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// 특정 엔티티의 변경 이력 조회
  Future<List<AuditLog>> getEntityHistory({
    required String entityType,
    required String entityId,
  });

  /// 특정 사용자의 활동 로그 조회
  Future<AuditLogPage> getUserLogs({
    required String userId,
    int page = 0,
    int size = 20,
  });

  /// 내 활동 로그 조회
  Future<AuditLogPage> getMyLogs({
    int page = 0,
    int size = 20,
  });

  /// 액션별 통계 조회
  Future<ActionStatistics> getActionStatistics({
    required String businessPlaceId,
    int days = 30,
  });

  /// 사용자별 활동 통계 조회
  Future<UserActivityStatistics> getUserActivityStatistics({
    required String businessPlaceId,
    int days = 30,
  });
}
