import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/data/model/reservation_model.dart';

/// 예약 서비스
class ReservationService {
  final ApiClient _apiClient;

  ReservationService({ApiClient? apiClient})
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

  /// 예약 생성
  Future<ReservationModel> createReservation(ReservationModel reservation) async {
    final response = await _apiClient.post(
      '/api/reservations',
      body: reservation.toJson(),
    );

    if (response.statusCode == 201) {
      return ReservationModel.fromJson(jsonDecode(response.body));
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '예약 생성 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 예약 조회 by ID
  Future<ReservationModel> getReservationById(String id) async {
    final response = await _apiClient.get('/api/reservations/$id');

    if (response.statusCode == 200) {
      return ReservationModel.fromJson(jsonDecode(response.body));
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '예약 정보를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 회원의 예약 목록 조회
  Future<List<ReservationModel>> getReservationsByMemberId(String memberId) async {
    final response = await _apiClient.get('/api/reservations/member/$memberId');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => ReservationModel.fromJson(json)).toList();
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '회원 예약 목록을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 사업장의 예약 목록 조회
  Future<List<ReservationModel>> getReservationsByBusinessPlaceId(
      String businessPlaceId) async {
    final response = await _apiClient.get('/api/reservations/business-place/$businessPlaceId');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => ReservationModel.fromJson(json)).toList();
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '예약 목록을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 사업장의 특정 날짜 예약 목록 조회
  Future<List<ReservationModel>> getReservationsByDate(
      String businessPlaceId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final response = await _apiClient.get(
      '/api/reservations/business-place/$businessPlaceId/date/$dateStr',
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => ReservationModel.fromJson(json)).toList();
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '날짜별 예약 목록을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 사업장의 날짜 범위 예약 목록 조회
  Future<List<ReservationModel>> getReservationsByDateRange(
      String businessPlaceId, DateTime startDate, DateTime endDate) async {
    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];

    final response = await _apiClient.get(
      '/api/reservations/business-place/$businessPlaceId/range',
      queryParams: {
        'startDate': startDateStr,
        'endDate': endDateStr,
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => ReservationModel.fromJson(json)).toList();
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '기간별 예약 목록을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 사업장의 특정 상태 예약 목록 조회
  Future<List<ReservationModel>> getReservationsByStatus(
      String businessPlaceId, String status) async {
    final response = await _apiClient.get(
      '/api/reservations/business-place/$businessPlaceId/status/$status',
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => ReservationModel.fromJson(json)).toList();
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '상태별 예약 목록을 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 예약 수정
  Future<ReservationModel> updateReservation(
      String id, ReservationModel reservation) async {
    final response = await _apiClient.put(
      '/api/reservations/$id',
      body: reservation.toJson(),
    );

    if (response.statusCode == 200) {
      return ReservationModel.fromJson(jsonDecode(response.body));
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '예약 수정 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 예약 상태 변경
  Future<ReservationModel> updateReservationStatus(
      String id, String status, {String? updatedBy}) async {
    final body = <String, dynamic>{'status': status};
    if (updatedBy != null) {
      body['updatedBy'] = updatedBy;
    }

    final response = await _apiClient.patch(
      '/api/reservations/$id/status',
      body: body,
    );

    if (response.statusCode == 200) {
      return ReservationModel.fromJson(jsonDecode(response.body));
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '예약 상태 변경 중 오류가 발생했습니다.'),
      );
    }
  }

  // 예약 삭제 API는 제거됨
  // - 고객 취소: updateReservationStatus(id, 'CANCELLED') 사용
  // - 노쇼: updateReservationStatus(id, 'NO_SHOW') 사용
  // - 오래된 데이터: 서버에서 900일 후 자동 삭제

  /// 특정 날짜의 예약 개수 조회
  Future<int> getReservationCount(
      String businessPlaceId, DateTime? date) async {
    final queryParams = <String, String>{};
    if (date != null) {
      queryParams['date'] = date.toIso8601String().split('T')[0];
    }

    final response = await _apiClient.get(
      '/api/reservations/business-place/$businessPlaceId/count',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['count'] as int;
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '예약 개수를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }

  /// 회원의 예약 통계 조회
  Future<Map<String, dynamic>> getMemberReservationStats(String memberId) async {
    final response = await _apiClient.get('/api/reservations/member/$memberId/stats');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ReservationServiceException(
        _extractErrorMessage(response.body, '예약 통계를 불러오는 중 오류가 발생했습니다.'),
      );
    }
  }
}

/// 예약 서비스 예외
class ReservationServiceException implements Exception {
  final String message;

  ReservationServiceException(this.message);

  @override
  String toString() => message;
}
