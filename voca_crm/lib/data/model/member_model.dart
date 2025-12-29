import 'package:voca_crm/domain/entity/member.dart';

class MemberModel {
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
  final String? deletedAt;
  final String? deletedBy;
  final String createdAt;
  final String updatedAt;

  MemberModel({
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

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
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
      deletedAt: json['deletedAt'] as String?,
      deletedBy: json['deletedBy'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberNumber': memberNumber,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (businessPlaceId != null) 'businessPlaceId': businessPlaceId,
      if (ownerId != null) 'ownerId': ownerId,
      if (lastModifiedById != null) 'lastModifiedById': lastModifiedById,
      if (grade != null) 'grade': grade,
      if (remark != null) 'remark': remark,
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (deletedBy != null) 'deletedBy': deletedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Member toEntity() {
    return Member(
      id: id,
      memberNumber: memberNumber,
      name: name,
      phone: phone,
      email: email,
      businessPlaceId: businessPlaceId,
      ownerId: ownerId,
      lastModifiedById: lastModifiedById,
      grade: grade,
      remark: remark,
      isDeleted: isDeleted,
      deletedAt: deletedAt != null ? DateTime.parse(deletedAt!) : null,
      deletedBy: deletedBy,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory MemberModel.fromEntity(Member entity) {
    return MemberModel(
      id: entity.id,
      memberNumber: entity.memberNumber,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      businessPlaceId: entity.businessPlaceId,
      ownerId: entity.ownerId,
      lastModifiedById: entity.lastModifiedById,
      grade: entity.grade,
      remark: entity.remark,
      isDeleted: entity.isDeleted,
      deletedAt: entity.deletedAt?.toIso8601String(),
      deletedBy: entity.deletedBy,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }
}
