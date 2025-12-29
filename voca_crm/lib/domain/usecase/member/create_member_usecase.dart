import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/repository/member_repository.dart';

class CreateMemberUseCase {
  final MemberRepository repository;

  CreateMemberUseCase(this.repository);

  Future<Member> execute({
    required String memberNumber,
    required String name,
    String? phone,
    String? email,
  }) async {
    return await repository.createMember(
      memberNumber: memberNumber,
      name: name,
      phone: phone,
      email: email,
    );
  }
}
