import 'package:voca_crm/domain/entity/memo.dart';
import 'package:voca_crm/domain/repository/memo_repository.dart';

class CreateMemoUseCase {
  final MemoRepository repository;

  CreateMemoUseCase(this.repository);

  Future<Memo> execute({
    required String memberId,
    required String content,
  }) async {
    return await repository.createMemo(
      memberId: memberId,
      content: content,
    );
  }
}
