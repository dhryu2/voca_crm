import 'package:voca_crm/domain/entity/member.dart';

abstract class MemberRepository {
  /// Create a new member
  /// [ownerId]: ID of user who creates this member (for permission check)
  Future<Member> createMember({
    String? businessPlaceId,
    required String memberNumber,
    required String name,
    String? phone,
    String? email,
    String? ownerId,
    String? remark,
    String? grade,
  });

  /// Get member by ID
  Future<Member?> getMemberById(String id);

  /// Get members by member number (can have duplicates)
  Future<List<Member>> getMembersByNumber(String memberNumber);

  /// Get members by business place ID
  Future<List<Member>> getMembersByBusinessPlace(String businessPlaceId);

  /// Search members with filters
  Future<List<Member>> searchMembers({
    String? memberNumber,
    String? name,
    String? phone,
    String? email,
  });

  /// Update member
  /// [userId]: Request user ID for permission check
  /// [businessPlaceId]: Business place ID for permission check
  Future<Member> updateMember(
    Member member, {
    String? userId,
    String? businessPlaceId,
  });

  // WB-13: hard-delete deleteMember (DELETE /api/members/{id}) 제거됨 — 서버에 해당 엔드포인트가 없어
  // 호출 시 404 이며, 이미 @Deprecated 상태로 어떤 화면도 사용하지 않던 죽은 코드였다. 삭제는 softDeleteMember 사용.

  /// Get all members
  Future<List<Member>> getAllMembers();

  // ===== Soft Delete Methods =====

  /// Soft delete member (moves to pending deletion)
  /// Returns the deleted member with updated isDeleted status
  Future<Member> softDeleteMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  });

  /// Get deleted members for a specific business place
  Future<List<Member>> getDeletedMembers({
    required String businessPlaceId,
  });

  /// Restore a deleted member
  /// Only MANAGER and above can restore
  Future<Member> restoreMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  });

  /// Permanently delete a member
  /// Only MANAGER and above can permanently delete
  /// Only members in deleted state can be permanently deleted
  Future<void> permanentDeleteMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  });
}
