/// 오류 로그 엔티티
class ErrorLog {
  final String id;
  final String? userId;
  final String? username;
  final String? businessPlaceId;
  final String? screenName;
  final String? action;
  final String? requestUrl;
  final String? requestMethod;
  final String? requestBody;
  final int? httpStatusCode;
  final String? errorCode;
  final String errorMessage;
  final String? stackTrace;
  final ErrorSeverity severity;
  final String? deviceInfo;
  final String? appVersion;
  final String? osVersion;
  final String? platform;
  final bool resolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final DateTime createdAt;

  ErrorLog({
    required this.id,
    this.userId,
    this.username,
    this.businessPlaceId,
    this.screenName,
    this.action,
    this.requestUrl,
    this.requestMethod,
    this.requestBody,
    this.httpStatusCode,
    this.errorCode,
    required this.errorMessage,
    this.stackTrace,
    this.severity = ErrorSeverity.error,
    this.deviceInfo,
    this.appVersion,
    this.osVersion,
    this.platform,
    this.resolved = false,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNote,
    required this.createdAt,
  });

  factory ErrorLog.fromJson(Map<String, dynamic> json) {
    return ErrorLog(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      username: json['username'] as String?,
      businessPlaceId: json['businessPlaceId'] as String?,
      screenName: json['screenName'] as String?,
      action: json['action'] as String?,
      requestUrl: json['requestUrl'] as String?,
      requestMethod: json['requestMethod'] as String?,
      requestBody: json['requestBody'] as String?,
      httpStatusCode: json['httpStatusCode'] as int?,
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String,
      stackTrace: json['stackTrace'] as String?,
      severity: ErrorSeverity.fromString(json['severity'] as String?),
      deviceInfo: json['deviceInfo'] as String?,
      appVersion: json['appVersion'] as String?,
      osVersion: json['osVersion'] as String?,
      platform: json['platform'] as String?,
      resolved: json['resolved'] as bool? ?? false,
      resolvedBy: json['resolvedBy'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      resolutionNote: json['resolutionNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'businessPlaceId': businessPlaceId,
      'screenName': screenName,
      'action': action,
      'requestUrl': requestUrl,
      'requestMethod': requestMethod,
      'requestBody': requestBody,
      'httpStatusCode': httpStatusCode,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'stackTrace': stackTrace,
      'severity': severity.name.toUpperCase(),
      'deviceInfo': deviceInfo,
      'appVersion': appVersion,
      'osVersion': osVersion,
      'platform': platform,
      'resolved': resolved,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolutionNote': resolutionNote,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// 오류 심각도
enum ErrorSeverity {
  info('INFO', '정보'),
  warning('WARNING', '경고'),
  error('ERROR', '오류'),
  critical('CRITICAL', '치명적');

  final String value;
  final String displayName;

  const ErrorSeverity(this.value, this.displayName);

  static ErrorSeverity fromString(String? value) {
    if (value == null) return ErrorSeverity.error;
    return ErrorSeverity.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => ErrorSeverity.error,
    );
  }
}

/// 오류 로그 페이지네이션 응답
class ErrorLogPage {
  final List<ErrorLog> content;
  final int totalElements;
  final int totalPages;
  final int number; // current page
  final int size;

  ErrorLogPage({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
  });

  factory ErrorLogPage.fromJson(Map<String, dynamic> json) {
    return ErrorLogPage(
      content: (json['content'] as List<dynamic>)
          .map((e) => ErrorLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
      number: json['number'] as int,
      size: json['size'] as int,
    );
  }
}

/// 오류 통계 요약
class ErrorSummary {
  final int totalErrors;
  final int unresolvedErrors;
  final Map<String, int> bySeverity;
  final List<ScreenErrorStat> byScreen;

  ErrorSummary({
    required this.totalErrors,
    required this.unresolvedErrors,
    required this.bySeverity,
    required this.byScreen,
  });

  factory ErrorSummary.fromJson(Map<String, dynamic> json) {
    final bySeverityJson = json['bySeverity'] as Map<String, dynamic>? ?? {};
    final byScreenJson = json['byScreen'] as List<dynamic>? ?? [];

    return ErrorSummary(
      totalErrors: json['totalErrors'] as int? ?? 0,
      unresolvedErrors: json['unresolvedErrors'] as int? ?? 0,
      bySeverity: bySeverityJson.map((k, v) => MapEntry(k, (v as num).toInt())),
      byScreen: byScreenJson
          .map((e) => ScreenErrorStat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 화면별 오류 통계
class ScreenErrorStat {
  final String screenName;
  final int errorCount;

  ScreenErrorStat({
    required this.screenName,
    required this.errorCount,
  });

  factory ScreenErrorStat.fromJson(Map<String, dynamic> json) {
    return ScreenErrorStat(
      screenName: json['screenName'] as String? ?? 'Unknown',
      errorCount: (json['errorCount'] as num?)?.toInt() ?? 0,
    );
  }
}
