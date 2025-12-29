/// 회원 등급
enum MemberGrade {
  GENERAL,
  VIP;

  String get displayName {
    switch (this) {
      case MemberGrade.GENERAL:
        return '일반';
      case MemberGrade.VIP:
        return 'VIP';
    }
  }

  static MemberGrade? fromString(String? value) {
    if (value == null) return null;
    try {
      return MemberGrade.values.firstWhere(
        (e) => e.name.toLowerCase() == value.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}

class Member {
  final String id;
  final String memberNumber;
  final String name;
  final String? phone;
  final String? email;
  final String? businessPlaceId;
  final String? ownerId;
  final String? lastModifiedById;
  final String? grade;
  final String? remark;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MemberGrade? get gradeEnum => MemberGrade.fromString(grade);

  Member({
    required this.id,
    required this.memberNumber,
    required this.name,
    this.phone,
    this.email,
    this.businessPlaceId,
    this.ownerId,
    this.lastModifiedById,
    this.grade,
    this.remark,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      memberNumber: json['memberNumber'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      businessPlaceId: json['businessPlaceId'] as String?,
      ownerId: json['ownerId'] as String?,
      lastModifiedById: json['lastModifiedById'] as String?,
      grade: json['grade'] as String?,
      remark: json['remark'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      deletedBy: json['deletedBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Member copyWith({
    String? id,
    String? memberNumber,
    String? name,
    String? phone,
    String? email,
    String? businessPlaceId,
    String? ownerId,
    String? lastModifiedById,
    String? grade,
    String? remark,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      memberNumber: memberNumber ?? this.memberNumber,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      businessPlaceId: businessPlaceId ?? this.businessPlaceId,
      ownerId: ownerId ?? this.ownerId,
      lastModifiedById: lastModifiedById ?? this.lastModifiedById,
      grade: grade ?? this.grade,
      remark: remark ?? this.remark,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Member &&
        other.id == id &&
        other.memberNumber == memberNumber &&
        other.name == name &&
        other.phone == phone &&
        other.email == email &&
        other.businessPlaceId == businessPlaceId &&
        other.ownerId == ownerId &&
        other.lastModifiedById == lastModifiedById &&
        other.grade == grade &&
        other.remark == remark &&
        other.isDeleted == isDeleted &&
        other.deletedAt == deletedAt &&
        other.deletedBy == deletedBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        memberNumber.hashCode ^
        name.hashCode ^
        phone.hashCode ^
        email.hashCode ^
        businessPlaceId.hashCode ^
        ownerId.hashCode ^
        lastModifiedById.hashCode ^
        grade.hashCode ^
        remark.hashCode ^
        isDeleted.hashCode ^
        (deletedAt?.hashCode ?? 0) ^
        (deletedBy?.hashCode ?? 0) ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
