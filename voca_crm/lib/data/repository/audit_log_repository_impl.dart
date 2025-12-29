import 'package:voca_crm/data/datasource/audit_log_service.dart';
import 'package:voca_crm/domain/entity/audit_log.dart';
import 'package:voca_crm/domain/repository/audit_log_repository.dart';

class AuditLogRepositoryImpl implements AuditLogRepository {
  final AuditLogService _auditLogService;

  AuditLogRepositoryImpl([AuditLogService? auditLogService])
      : _auditLogService = auditLogService ?? AuditLogService();

  @override
  Future<AuditLogPage> getAuditLogs({
    required String businessPlaceId,
    int page = 0,
    int size = 20,
    String? entityType,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _auditLogService.getAuditLogs(
      businessPlaceId: businessPlaceId,
      page: page,
      size: size,
      entityType: entityType,
      action: action,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<AuditLog>> getEntityHistory({
    required String entityType,
    required String entityId,
  }) {
    return _auditLogService.getEntityHistory(
      entityType: entityType,
      entityId: entityId,
    );
  }

  @override
  Future<AuditLogPage> getUserLogs({
    required String userId,
    int page = 0,
    int size = 20,
  }) {
    return _auditLogService.getUserLogs(
      userId: userId,
      page: page,
      size: size,
    );
  }

  @override
  Future<AuditLogPage> getMyLogs({
    int page = 0,
    int size = 20,
  }) {
    return _auditLogService.getMyLogs(page: page, size: size);
  }

  @override
  Future<ActionStatistics> getActionStatistics({
    required String businessPlaceId,
    int days = 30,
  }) {
    return _auditLogService.getActionStatistics(
      businessPlaceId: businessPlaceId,
      days: days,
    );
  }

  @override
  Future<UserActivityStatistics> getUserActivityStatistics({
    required String businessPlaceId,
    int days = 30,
  }) {
    return _auditLogService.getUserActivityStatistics(
      businessPlaceId: businessPlaceId,
      days: days,
    );
  }
}
