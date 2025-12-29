class Notice {
  final String id;
  final String title;
  final String content;
  final DateTime startDate;
  final DateTime endDate;
  final int priority;
  final bool isActive;
  final String? createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.startDate,
    required this.endDate,
    required this.priority,
    required this.isActive,
    this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      priority: json['priority'] as int,
      isActive: json['isActive'] as bool,
      createdByUserId: json['createdByUserId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'priority': priority,
      'isActive': isActive,
      'createdByUserId': createdByUserId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Notice copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? startDate,
    DateTime? endDate,
    int? priority,
    bool? isActive,
    String? createdByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
