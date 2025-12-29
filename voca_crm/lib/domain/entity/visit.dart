import 'package:voca_crm/domain/entity/member.dart';

/// 방문 기록(Visit) 엔티티 클래스
class Visit {
  final String id;
  final String memberId;
  final Member? member;  // 오늘 방문 조회 시 회원 정보 포함
  final String? visitorId;
  final DateTime visitedAt;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Visit({
    required this.id,
    required this.memberId,
    this.member,
    this.visitorId,
    required this.visitedAt,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      member: json['member'] != null
          ? Member.fromJson(json['member'] as Map<String, dynamic>)
          : null,
      visitorId: json['visitorId'] as String?,
      visitedAt: DateTime.parse(json['visitedAt'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'visitorId': visitorId,
      'visitedAt': visitedAt.toIso8601String(),
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
