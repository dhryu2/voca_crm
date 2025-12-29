import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/repository/member_repository.dart';

class GetMembersByNumberUseCase {
  final MemberRepository repository;

  GetMembersByNumberUseCase(this.repository);

  Future<List<Member>> execute(String memberNumber) async {
    return await repository.getMembersByNumber(memberNumber);
  }
}
