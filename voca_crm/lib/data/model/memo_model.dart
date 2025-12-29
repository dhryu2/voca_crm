import 'package:voca_crm/domain/entity/memo.dart';

class MemoModel {
  final String id;
  final String memberId;
  final String content;
  final bool isImportant;
  final String? ownerId;
  final String? lastModifiedById;
  final bool isDeleted;
  final String? deletedAt;
  final String? deletedBy;
  final String createdAt;
  final String updatedAt;

  MemoModel({
    required this.id,
    required this.memberId,
    required this.content,
    this.isImportant = false,
    this.ownerId,
    this.lastModifiedById,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoModel.fromJson(Map<String, dynamic> json) {
    return MemoModel(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      content: json['content'] as String,
      isImportant: json['isImportant'] as bool? ?? false,
      ownerId: json['ownerId'] as String?,
      lastModifiedById: json['lastModifiedById'] as String?,
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
      'memberId': memberId,
      'content': content,
      'isImportant': isImportant,
      'ownerId': ownerId,
      'lastModifiedById': lastModifiedById,
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (deletedBy != null) 'deletedBy': deletedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Memo toEntity() {
    return Memo(
      id: id,
      memberId: memberId,
      content: content,
      isImportant: isImportant,
      ownerId: ownerId,
      lastModifiedById: lastModifiedById,
      isDeleted: isDeleted,
      deletedAt: deletedAt != null ? DateTime.parse(deletedAt!) : null,
      deletedBy: deletedBy,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory MemoModel.fromEntity(Memo entity) {
    return MemoModel(
      id: entity.id,
      memberId: entity.memberId,
      content: entity.content,
      isImportant: entity.isImportant,
      ownerId: entity.ownerId,
      lastModifiedById: entity.lastModifiedById,
      isDeleted: entity.isDeleted,
      deletedAt: entity.deletedAt?.toIso8601String(),
      deletedBy: entity.deletedBy,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }
}
