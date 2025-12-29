import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';

class HomeStatistics {
  final String businessPlaceId;
  final String businessPlaceName;
  final int todayReservations;
  final int todayVisits;
  final int pendingMemos;
  final int totalMembers;

  HomeStatistics({
    required this.businessPlaceId,
    required this.businessPlaceName,
    required this.todayReservations,
    required this.todayVisits,
    required this.pendingMemos,
    required this.totalMembers,
  });

  factory HomeStatistics.fromJson(Map<String, dynamic> json) {
    return HomeStatistics(
      businessPlaceId: json['businessPlaceId'] ?? '',
      businessPlaceName: json['businessPlaceName'] ?? '사업장 없음',
      todayReservations: json['todayReservations'] ?? 0,
      todayVisits: json['todayVisits'] ?? 0,
      pendingMemos: json['pendingMemos'] ?? 0,
      totalMembers: json['totalMembers'] ?? 0,
    );
  }
}

class TimeSeriesDataPoint {
  final DateTime date;
  final int count;

  TimeSeriesDataPoint({
    required this.date,
    required this.count,
  });

  factory TimeSeriesDataPoint.fromJson(Map<String, dynamic> json) {
    return TimeSeriesDataPoint(
      date: DateTime.parse(json['date']),
      count: json['count'] ?? 0,
    );
  }
}

class MemberRegistrationTrend {
  final List<TimeSeriesDataPoint> dataPoints;
  final int totalNewMembers;

  MemberRegistrationTrend({
    required this.dataPoints,
    required this.totalNewMembers,
  });

  factory MemberRegistrationTrend.fromJson(Map<String, dynamic> json) {
    return MemberRegistrationTrend(
      dataPoints: (json['dataPoints'] as List)
          .map((item) => TimeSeriesDataPoint.fromJson(item))
          .toList(),
      totalNewMembers: json['totalNewMembers'] ?? 0,
    );
  }
}

class MemberGradeDistribution {
  final Map<String, int> distribution;
  final int totalMembers;

  MemberGradeDistribution({
    required this.distribution,
    required this.totalMembers,
  });

  factory MemberGradeDistribution.fromJson(Map<String, dynamic> json) {
    final Map<String, int> dist = {};
    (json['distribution'] as Map<String, dynamic>).forEach((key, value) {
      dist[key] = value as int;
    });
    return MemberGradeDistribution(
      distribution: dist,
      totalMembers: json['totalMembers'] ?? 0,
    );
  }
}

class ReservationTrend {
  final List<TimeSeriesDataPoint> dataPoints;
  final int totalReservations;

  ReservationTrend({
    required this.dataPoints,
    required this.totalReservations,
  });

  factory ReservationTrend.fromJson(Map<String, dynamic> json) {
    return ReservationTrend(
      dataPoints: (json['dataPoints'] as List)
          .map((item) => TimeSeriesDataPoint.fromJson(item))
          .toList(),
      totalReservations: json['totalReservations'] ?? 0,
    );
  }
}

class MemoStatistics {
  final int totalMemos;
  final int importantMemos;
  final int archivedMemos;
  final List<TimeSeriesDataPoint> dailyMemos;

  MemoStatistics({
    required this.totalMemos,
    required this.importantMemos,
    required this.archivedMemos,
    required this.dailyMemos,
  });

  factory MemoStatistics.fromJson(Map<String, dynamic> json) {
    return MemoStatistics(
      totalMemos: json['totalMemos'] ?? 0,
      importantMemos: json['importantMemos'] ?? 0,
      archivedMemos: json['archivedMemos'] ?? 0,
      dailyMemos: (json['dailyMemos'] as List)
          .map((item) => TimeSeriesDataPoint.fromJson(item))
          .toList(),
    );
  }
}

class RecentActivity {
  final String activityId;
  final String activityType; // MEMO or VISIT
  final String memberId;
  final String memberName;
  final String content;
  final DateTime activityTime;

  RecentActivity({
    required this.activityId,
    required this.activityType,
    required this.memberId,
    required this.memberName,
    required this.content,
    required this.activityTime,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      activityId: json['activityId'] ?? '',
      activityType: json['activityType'] ?? 'MEMO',
      memberId: json['memberId'] ?? '',
      memberName: json['memberName'] ?? '',
      content: json['content'] ?? '',
      activityTime: DateTime.parse(json['activityTime']),
    );
  }
}

class TodaySchedule {
  final String reservationId;
  final String memberId;
  final String memberName;
  final String reservationTime; // HH:mm:ss format
  final String? serviceType;
  final int durationMinutes;
  final String status;
  final String? notes;

  TodaySchedule({
    required this.reservationId,
    required this.memberId,
    required this.memberName,
    required this.reservationTime,
    this.serviceType,
    required this.durationMinutes,
    required this.status,
    this.notes,
  });

  factory TodaySchedule.fromJson(Map<String, dynamic> json) {
    return TodaySchedule(
      reservationId: json['reservationId'] ?? '',
      memberId: json['memberId'] ?? '',
      memberName: json['memberName'] ?? '',
      reservationTime: json['reservationTime'] ?? '',
      serviceType: json['serviceType'],
      durationMinutes: json['durationMinutes'] ?? 60,
      status: json['status'] ?? 'PENDING',
      notes: json['notes'],
    );
  }

  /// 시간 포맷팅 (HH:mm)
  String get formattedTime {
    final parts = reservationTime.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return reservationTime;
  }
}

class StatisticsService {
  final ApiClient _apiClient;

  StatisticsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// API 응답에서 사용자 친화적 오류 메시지 추출
  String _extractErrorMessage(String responseBody, String fallbackMessage) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map<String, dynamic>) {
        if (data['fieldErrors'] is Map && (data['fieldErrors'] as Map).isNotEmpty) {
          final fieldErrors = data['fieldErrors'] as Map;
          return fieldErrors.values.first.toString();
        }
        if (data['message'] != null && data['message'].toString().isNotEmpty) {
          return data['message'].toString();
        }
      }
    } catch (_) {}
    return fallbackMessage;
  }

  Future<HomeStatistics> getHomeStatistics(String businessPlaceId) async {
    final response = await _apiClient.get('/api/statistics/home/$businessPlaceId');

    if (response.statusCode == 200) {
      return HomeStatistics.fromJson(jsonDecode(response.body));
    } else {
      throw StatisticsServiceException(
        _extractErrorMessage(response.body, '홈 통계를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  Future<List<RecentActivity>> getRecentActivities(
    String businessPlaceId, {
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/statistics/recent-activities/$businessPlaceId',
      queryParams: {'limit': limit.toString()},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => RecentActivity.fromJson(json)).toList();
    } else {
      throw StatisticsServiceException(
        _extractErrorMessage(response.body, '최근 활동을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 오늘의 예약 일정 조회
  Future<List<TodaySchedule>> getTodaySchedule(
    String businessPlaceId, {
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/statistics/today-schedule/$businessPlaceId',
      queryParams: {'limit': limit.toString()},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => TodaySchedule.fromJson(json)).toList();
    } else {
      throw StatisticsServiceException(
        _extractErrorMessage(response.body, '오늘의 일정을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 회원 등록 추이 조회
  Future<MemberRegistrationTrend> getMemberRegistrationTrend(
    String businessPlaceId, {
    int days = 7,
  }) async {
    final response = await _apiClient.get(
      '/api/statistics/member-registration-trend/$businessPlaceId',
      queryParams: {'days': days.toString()},
    );

    if (response.statusCode == 200) {
      return MemberRegistrationTrend.fromJson(jsonDecode(response.body));
    } else {
      throw StatisticsServiceException(
        _extractErrorMessage(response.body, '회원 등록 추이를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 회원 등급별 분포 조회
  Future<MemberGradeDistribution> getMemberGradeDistribution(
    String businessPlaceId,
  ) async {
    final response = await _apiClient.get(
      '/api/statistics/member-grade-distribution/$businessPlaceId',
    );

    if (response.statusCode == 200) {
      return MemberGradeDistribution.fromJson(jsonDecode(response.body));
    } else {
      throw StatisticsServiceException(
        _extractErrorMessage(response.body, '회원 등급 분포를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 예약 추이 조회
  Future<ReservationTrend> getReservationTrend(
    String businessPlaceId, {
    int days = 7,
  }) async {
    final response = await _apiClient.get(
      '/api/statistics/reservation-trend/$businessPlaceId',
      queryParams: {'days': days.toString()},
    );

    if (response.statusCode == 200) {
      return ReservationTrend.fromJson(jsonDecode(response.body));
    } else {
      throw StatisticsServiceException(
        _extractErrorMessage(response.body, '예약 추이를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 메모 작성 통계 조회
  Future<MemoStatistics> getMemoStatistics(
    String businessPlaceId, {
    int days = 7,
  }) async {
    final response = await _apiClient.get(
      '/api/statistics/memo-statistics/$businessPlaceId',
      queryParams: {'days': days.toString()},
    );

    if (response.statusCode == 200) {
      return MemoStatistics.fromJson(jsonDecode(response.body));
    } else {
      throw StatisticsServiceException(
        _extractErrorMessage(response.body, '메모 통계를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }
}

/// 통계 서비스 예외
class StatisticsServiceException implements Exception {
  final String message;

  StatisticsServiceException(this.message);

  @override
  String toString() => message;
}
