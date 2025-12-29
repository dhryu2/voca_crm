/// 선택된 엔티티 정보
class SelectedEntity {
  final String entityType; // "member", "memo", "visit"
  final List<String> ids; // 선택된 ID 리스트
  final bool selectAll; // 전체 선택 여부
  final Map<String, dynamic>? filterConditions;
  final int? count;

  SelectedEntity({
    required this.entityType,
    required this.ids,
    this.selectAll = false,
    this.filterConditions,
    this.count,
  });

  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType,
      'ids': ids,
      'selectAll': selectAll,
      if (filterConditions != null) 'filterConditions': filterConditions,
      if (count != null) 'count': count,
    };
  }

  factory SelectedEntity.fromJson(Map<String, dynamic> json) {
    return SelectedEntity(
      entityType: json['entityType'] as String,
      ids: (json['ids'] as List<dynamic>?)?.cast<String>() ?? [],
      selectAll: json['selectAll'] as bool? ?? false,
      filterConditions: json['filterConditions'] as Map<String, dynamic>?,
      count: json['count'] as int?,
    );
  }
}
