class Memo {
  final String id;
  final String memberId;
  final String content;
  final bool isImportant;
  final String? ownerId;
  final String? lastModifiedById;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Memo({
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

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      content: json['content'] as String,
      isImportant: json['isImportant'] as bool? ?? false,
      ownerId: json['ownerId'] as String?,
      lastModifiedById: json['lastModifiedById'] as String?,
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

  Memo copyWith({
    String? id,
    String? memberId,
    String? content,
    bool? isImportant,
    String? ownerId,
    String? lastModifiedById,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Memo(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      content: content ?? this.content,
      isImportant: isImportant ?? this.isImportant,
      ownerId: ownerId ?? this.ownerId,
      lastModifiedById: lastModifiedById ?? this.lastModifiedById,
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

    return other is Memo &&
        other.id == id &&
        other.memberId == memberId &&
        other.content == content &&
        other.isImportant == isImportant &&
        other.ownerId == ownerId &&
        other.lastModifiedById == lastModifiedById &&
        other.isDeleted == isDeleted &&
        other.deletedAt == deletedAt &&
        other.deletedBy == deletedBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        memberId.hashCode ^
        content.hashCode ^
        isImportant.hashCode ^
        (ownerId?.hashCode ?? 0) ^
        (lastModifiedById?.hashCode ?? 0) ^
        isDeleted.hashCode ^
        (deletedAt?.hashCode ?? 0) ^
        (deletedBy?.hashCode ?? 0) ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
