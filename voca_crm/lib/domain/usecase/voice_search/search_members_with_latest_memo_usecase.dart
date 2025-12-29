import 'package:voca_crm/domain/entity/member_with_memo.dart';
import 'package:voca_crm/domain/repository/member_repository.dart';
import 'package:voca_crm/domain/repository/memo_repository.dart';

/// UseCase for voice search: search members by number and get their latest memos
class SearchMembersWithLatestMemoUseCase {
  final MemberRepository memberRepository;
  final MemoRepository memoRepository;

  SearchMembersWithLatestMemoUseCase({
    required this.memberRepository,
    required this.memoRepository,
  });

  Future<List<MemberWithMemo>> execute(String memberNumber) async {
    // Get all members with this number (may have duplicates)
    final members = await memberRepository.getMembersByNumber(memberNumber);

    // For each member, get their latest memo
    final result = <MemberWithMemo>[];
    for (final member in members) {
      final latestMemo = await memoRepository.getLatestMemoByMemberId(member.id);
      result.add(MemberWithMemo(
        member: member,
        latestMemo: latestMemo,
      ));
    }

    return result;
  }
}
