import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/model/member_model.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/repository/member_repository.dart';

class MemberRepositoryImpl implements MemberRepository {
  final MemberService memberService;

  MemberRepositoryImpl(this.memberService);

  @override
  Future<Member> createMember({
    String? businessPlaceId,
    required String memberNumber,
    required String name,
    String? phone,
    String? email,
    String? ownerId,
    String? remark,
    String? grade,
  }) async {
    final model = await memberService.createMember(
      businessPlaceId: businessPlaceId,
      memberNumber: memberNumber,
      name: name,
      phone: phone,
      email: email,
      ownerId: ownerId,
      remark: remark,
      grade: grade,
    );
    return model.toEntity();
  }

  @override
  Future<Member?> getMemberById(String id) async {
    final model = await memberService.getMemberById(id);
    return model?.toEntity();
  }

  @override
  Future<List<Member>> getMembersByNumber(String memberNumber) async {
    final models = await memberService.getMembersByNumber(memberNumber);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Member>> getMembersByBusinessPlace(String businessPlaceId) async {
    final models = await memberService.getMembersByBusinessPlace(businessPlaceId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Member>> searchMembers({
    String? memberNumber,
    String? name,
    String? phone,
    String? email,
  }) async {
    final models = await memberService.searchMembers(
      memberNumber: memberNumber,
      name: name,
      phone: phone,
      email: email,
    );
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Member> updateMember(
    Member member, {
    String? userId,
    String? businessPlaceId,
  }) async {
    final model = await memberService.updateMember(
      MemberModel.fromEntity(member),
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
    return model.toEntity();
  }

  @override
  Future<void> deleteMember(
    String id, {
    String? userId,
    String? businessPlaceId,
  }) async {
    await memberService.deleteMember(
      id,
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
  }

  @override
  Future<List<Member>> getAllMembers() async {
    final models = await memberService.getAllMembers();
    return models.map((model) => model.toEntity()).toList();
  }

  // ===== Soft Delete Methods =====

  @override
  Future<Member> softDeleteMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final model = await memberService.softDeleteMember(
      id,
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
    return model.toEntity();
  }

  @override
  Future<List<Member>> getDeletedMembers({
    required String businessPlaceId,
  }) async {
    final models = await memberService.getDeletedMembers(
      businessPlaceId: businessPlaceId,
    );
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Member> restoreMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final model = await memberService.restoreMember(
      id,
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
    return model.toEntity();
  }

  @override
  Future<void> permanentDeleteMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    await memberService.permanentDeleteMember(
      id,
      userId: userId,
      businessPlaceId: businessPlaceId,
    );
  }

  static MemberModel _modelFromEntity(Member entity) {
    return MemberModel.fromEntity(entity);
  }
}
