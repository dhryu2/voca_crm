import 'package:voca_crm/domain/entity/memo.dart';

abstract class MemoRepository {
  /// Create a new memo for a member
  Future<Memo> createMemo({
    required String memberId,
    required String content,
  });

  /// Create a new memo with deletion of oldest memo if limit exceeded
  Future<Memo> createMemoWithDeletion({
    required String memberId,
    required String content,
  });

  /// Get memo by ID
  Future<Memo?> getMemoById(String id);

  /// Get all memos for a member (sorted by createdAt desc)
  Future<List<Memo>> getMemosByMemberId(String memberId);

  /// Get latest memo for a member
  Future<Memo?> getLatestMemoByMemberId(String memberId);

  /// Update memo (with optional permission check)
  Future<Memo> updateMemo(
    Memo memo, {
    String? userId,
    String? businessPlaceId,
  });

  /// Delete memo (hard delete - deprecated, use softDeleteMemo)
  @Deprecated('Use softDeleteMemo instead')
  Future<void> deleteMemo(
    String id, {
    String? userId,
    String? businessPlaceId,
  });

  /// Toggle memo importance
  Future<Memo> toggleImportant(String id);

  // ===== Soft Delete Methods =====

  /// Soft delete memo (moves to pending deletion)
  /// Returns the deleted memo with updated isDeleted status
  Future<Memo> softDeleteMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  });

  /// Get deleted memos for a specific business place
  Future<List<Memo>> getDeletedMemos({
    required String businessPlaceId,
  });

  /// Get deleted memos list for a member
  Future<List<Memo>> getDeletedMemosByMemberId(String memberId);

  /// Restore a deleted memo
  /// Only MANAGER and above can restore
  Future<Memo> restoreMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  });

  /// Permanently delete a memo
  /// Only MANAGER and above can permanently delete
  /// Only memos in deleted state can be permanently deleted
  Future<void> permanentDeleteMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  });
}
