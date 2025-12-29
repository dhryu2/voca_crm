/// 감사 로그 엔티티
class AuditLog {
  final String id;
  final String userId;
  final String? username;
  final String? businessPlaceId;
  final AuditAction action;
  final String entityType;
  final String entityId;
  final String? entityName;
  final String? changesBefore;
  final String? changesAfter;
  final String? description;
  final String? ipAddress;
  final String? deviceInfo;
  final String? requestUri;
  final String? httpMethod;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    required this.userId,
    this.username,
    this.businessPlaceId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.changesBefore,
    this.changesAfter,
    this.description,
    this.ipAddress,
    this.deviceInfo,
    this.requestUri,
    this.httpMethod,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String?,
      businessPlaceId: json['businessPlaceId'] as String?,
      action: AuditAction.fromString(json['action'] as String),
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      entityName: json['entityName'] as String?,
      changesBefore: json['changesBefore'] as String?,
      changesAfter: json['changesAfter'] as String?,
      description: json['description'] as String?,
      ipAddress: json['ipAddress'] as String?,
      deviceInfo: json['deviceInfo'] as String?,
      requestUri: json['requestUri'] as String?,
      httpMethod: json['httpMethod'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'businessPlaceId': businessPlaceId,
      'action': action.name,
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'changesBefore': changesBefore,
      'changesAfter': changesAfter,
      'description': description,
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
      'requestUri': requestUri,
      'httpMethod': httpMethod,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// 감사 로그 액션 타입
enum AuditAction {
  create('CREATE', '생성'),
  update('UPDATE', '수정'),
  delete('DELETE', '삭제'),
  restore('RESTORE', '복원'),
  permanentDelete('PERMANENT_DELETE', '영구 삭제'),
  login('LOGIN', '로그인'),
  logout('LOGOUT', '로그아웃'),
  loginFailed('LOGIN_FAILED', '로그인 실패'),
  export_('EXPORT', '내보내기'),
  import_('IMPORT', '가져오기'),
  view('VIEW', '조회');

  final String value;
  final String displayName;

  const AuditAction(this.value, this.displayName);

  static AuditAction fromString(String value) {
    return AuditAction.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AuditAction.view,
    );
  }
}

/// 감사 로그 페이지네이션 응답
class AuditLogPage {
  final List<AuditLog> data;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int size;

  AuditLogPage({
    required this.data,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.size,
  });

  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    return AuditLogPage(
      data: (json['data'] as List<dynamic>)
          .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
      currentPage: json['currentPage'] as int,
      size: json['size'] as int,
    );
  }
}

/// 액션별 통계
class ActionStatistics {
  final String period;
  final Map<String, int> statistics;

  ActionStatistics({
    required this.period,
    required this.statistics,
  });

  factory ActionStatistics.fromJson(Map<String, dynamic> json) {
    final statsJson = json['statistics'] as Map<String, dynamic>;
    return ActionStatistics(
      period: json['period'] as String,
      statistics: statsJson.map((key, value) => MapEntry(key, value as int)),
    );
  }
}

/// 사용자별 활동 통계
class UserActivityStatistics {
  final String period;
  final List<UserActivityStat> statistics;

  UserActivityStatistics({
    required this.period,
    required this.statistics,
  });

  factory UserActivityStatistics.fromJson(Map<String, dynamic> json) {
    return UserActivityStatistics(
      period: json['period'] as String,
      statistics: (json['statistics'] as List<dynamic>)
          .map((e) => UserActivityStat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UserActivityStat {
  final String userId;
  final String? username;
  final int activityCount;

  UserActivityStat({
    required this.userId,
    this.username,
    required this.activityCount,
  });

  factory UserActivityStat.fromJson(Map<String, dynamic> json) {
    return UserActivityStat(
      userId: json['userId'] as String,
      username: json['username'] as String?,
      activityCount: json['activityCount'] as int,
    );
  }
}
