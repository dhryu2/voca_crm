import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/memo.dart';

/// Member with their latest memo
class MemberWithMemo {
  final Member member;
  final Memo? latestMemo;

  MemberWithMemo({
    required this.member,
    this.latestMemo,
  });
}
