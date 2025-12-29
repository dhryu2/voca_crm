import 'package:voca_crm/data/datasource/memo_service.dart';
import 'package:voca_crm/data/model/memo_model.dart';
import 'package:voca_crm/domain/entity/memo.dart';
import 'package:voca_crm/domain/repository/memo_repository.dart';

class MemoRepositoryImpl implements MemoRepository {
  final MemoService memoService;

  MemoRepositoryImpl(this.memoService);

  @override
  Future<Memo> createMemo({
    required String memberId,
    required String content,
  }) async {
    final model = await memoService.createMemo(
      memberId: memberId,
      content: content,
    );
    return model.toEntity();
  }

  @override
  Future<Memo> createMemoWithDeletion({
    required String memberId,
    required String content,
  }) async {
    final model = await memoService.createMemoWithDeletion(
      memberId: memberId,
      content: content,
    );
    return model.toEntity();
  }

  @override
  Future<Memo?> getMemoById(String id) async {
    final model = await memoService.getMemoById(id);
    return model?.toEntity();
  }

  @override
  Future<List<Memo>> getMemosByMemberId(String memberId) async {
    final models = await memoService.getMemosByMemberId(memberId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Memo?> getLatestMemoByMemberId(String memberId) async {
    final model = await memoService.getLatestMemoByMemberId(memberId);
    return model?.toEntity();
  }

  @override
  Future<Memo> updateMemo(
    Memo memo, {
    String? userId,
    String? businessPlaceId,
  }) async {
    final model = await memoService.updateMemo(
      MemoModel.fromEntity(memo),
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
    return model.toEntity();
  }

  @override
  Future<void> deleteMemo(
    String id, {
    String? userId,
    String? businessPlaceId,
  }) async {
    await memoService.deleteMemo(
      id,
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
  }

  @override
  Future<Memo> toggleImportant(String id) async {
    final model = await memoService.toggleImportant(id);
    return model.toEntity();
  }


  // ===== Soft Delete Methods =====

  @override
  Future<Memo> softDeleteMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final model = await memoService.softDeleteMemo(
      id,
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
    return model.toEntity();
  }

  @override
  Future<List<Memo>> getDeletedMemos({
    required String businessPlaceId,
  }) async {
    final models = await memoService.getDeletedMemos(
      businessPlaceId: businessPlaceId,
    );
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Memo>> getDeletedMemosByMemberId(String memberId) async {
    final models = await memoService.getDeletedMemosByMemberId(memberId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Memo> restoreMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final model = await memoService.restoreMemo(
      id,
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
    return model.toEntity();
  }

  @override
  Future<void> permanentDeleteMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    await memoService.permanentDeleteMemo(
      id,
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
  }
}
