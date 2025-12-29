import 'package:voca_crm/domain/entity/memo.dart';
import 'package:voca_crm/domain/repository/memo_repository.dart';

class GetMemosByMemberUseCase {
  final MemoRepository repository;

  GetMemosByMemberUseCase(this.repository);

  Future<List<Memo>> execute(String memberId) async {
    return await repository.getMemosByMemberId(memberId);
  }
}
