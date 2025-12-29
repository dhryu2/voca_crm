import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/repository/member_repository.dart';

class SearchMembersUseCase {
  final MemberRepository repository;

  SearchMembersUseCase(this.repository);

  Future<List<Member>> execute({
    String? memberNumber,
    String? name,
    String? phone,
    String? email,
  }) async {
    return await repository.searchMembers(
      memberNumber: memberNumber,
      name: name,
      phone: phone,
      email: email,
    );
  }
}
