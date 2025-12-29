import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/domain/entity/business_place.dart';
import 'package:voca_crm/domain/entity/business_place_deletion_preview.dart';
import 'package:voca_crm/domain/entity/business_place_access_request.dart';
import 'package:voca_crm/domain/entity/business_place_member.dart';
import 'package:voca_crm/domain/entity/business_place_with_role.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';

class BusinessPlaceService {
  final ApiClient _apiClient;

  BusinessPlaceService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// API 응답에서 사용자 친화적 오류 메시지 추출
  String _extractErrorMessage(String responseBody, String fallbackMessage) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map<String, dynamic>) {
        // fieldErrors가 있으면 첫 번째 필드 오류 메시지 반환
        if (data['fieldErrors'] is Map && (data['fieldErrors'] as Map).isNotEmpty) {
          final fieldErrors = data['fieldErrors'] as Map;
          return fieldErrors.values.first.toString();
        }
        // message 필드가 있으면 반환
        if (data['message'] != null && data['message'].toString().isNotEmpty) {
          return data['message'].toString();
        }
      }
    } catch (_) {}
    return fallbackMessage;
  }

  Future<Map<String, dynamic>> createBusinessPlace({
    required String userId,
    required String name,
    String? address,
    String? phone,
  }) async {
    final response = await _apiClient.post(
      '/api/business-places',
      body: {'name': name, 'address': address, 'phone': phone},
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'businessPlace': BusinessPlace.fromJson(data['businessPlace']),
        'user': User.fromJson(data['user']),
      };
    } else {
      throw Exception(_extractErrorMessage(response.body, '사업장 생성에 실패했습니다.'));
    }
  }

  Future<List<BusinessPlaceWithRole>> getMyBusinessPlaces(String userId) async {
    final response = await _apiClient.get(
      '/api/business-places/my',
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceWithRole.fromJson(json)).toList();
    } else {
      throw Exception(_extractErrorMessage(response.body, '사업장 목록을 불러오는데 실패했습니다.'));
    }
  }

  /// 사업장 단일 조회
  Future<BusinessPlace> getBusinessPlace(String businessPlaceId) async {
    final response = await _apiClient.get(
      '/api/business-places/$businessPlaceId',
    );

    if (response.statusCode == 200) {
      return BusinessPlace.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '사업장 정보를 불러오는데 실패했습니다.'));
    }
  }

  Future<BusinessPlaceAccessRequest> requestAccess({
    required String userId,
    required String businessPlaceId,
    required Role role,
  }) async {
    final response = await _apiClient.post(
      '/api/business-places/$businessPlaceId/request-access',
      queryParams: {'userId': userId, 'role': role.name},
    );

    if (response.statusCode == 200) {
      return BusinessPlaceAccessRequest.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '접근 요청에 실패했습니다.'));
    }
  }

  Future<List<BusinessPlaceAccessRequest>> getSentRequests(String userId) async {
    final response = await _apiClient.get(
      '/api/business-places/requests/sent',
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceAccessRequest.fromJson(json)).toList();
    } else {
      throw Exception(_extractErrorMessage(response.body, '보낸 요청 목록을 불러오는데 실패했습니다.'));
    }
  }

  Future<List<BusinessPlaceAccessRequest>> getReceivedRequests(String userId) async {
    final response = await _apiClient.get(
      '/api/business-places/requests/received',
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceAccessRequest.fromJson(json)).toList();
    } else {
      throw Exception(_extractErrorMessage(response.body, '받은 요청 목록을 불러오는데 실패했습니다.'));
    }
  }

  Future<BusinessPlaceAccessRequest> approveRequest({
    required String requestId,
    required String ownerId,
  }) async {
    final response = await _apiClient.put(
      '/api/business-places/requests/$requestId/approve',
      queryParams: {'ownerId': ownerId},
    );

    if (response.statusCode == 200) {
      return BusinessPlaceAccessRequest.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '요청 승인에 실패했습니다.'));
    }
  }

  Future<BusinessPlaceAccessRequest> rejectRequest({
    required String requestId,
    required String ownerId,
  }) async {
    final response = await _apiClient.put(
      '/api/business-places/requests/$requestId/reject',
      queryParams: {'ownerId': ownerId},
    );

    if (response.statusCode == 200) {
      return BusinessPlaceAccessRequest.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '요청 거절에 실패했습니다.'));
    }
  }

  Future<void> deleteRequest({
    required String requestId,
    required String userId,
  }) async {
    final response = await _apiClient.delete(
      '/api/business-places/requests/$requestId',
      queryParams: {'userId': userId},
    );

    if (response.statusCode != 204) {
      throw Exception(_extractErrorMessage(response.body, '요청 삭제에 실패했습니다.'));
    }
  }

  Future<User> setDefaultBusinessPlace(
    String userId,
    String businessPlaceId,
  ) async {
    final response = await _apiClient.put(
      '/api/business-places/$businessPlaceId/set-default',
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['user']);
    } else {
      throw Exception(_extractErrorMessage(response.body, '기본 사업장 설정에 실패했습니다.'));
    }
  }

  Future<void> removeBusinessPlace(
    String userId,
    String businessPlaceId,
  ) async {
    final response = await _apiClient.delete(
      '/api/business-places/$businessPlaceId/remove',
      queryParams: {'userId': userId},
    );

    if (response.statusCode != 204) {
      throw Exception(_extractErrorMessage(response.body, '사업장 탈퇴에 실패했습니다.'));
    }
  }

  Future<BusinessPlace> updateBusinessPlace({
    required String userId,
    required String businessPlaceId,
    required String name,
    String? address,
    String? phone,
  }) async {
    final response = await _apiClient.put(
      '/api/business-places/$businessPlaceId',
      body: {'name': name, 'address': address, 'phone': phone},
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      return BusinessPlace.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '사업장 정보 수정에 실패했습니다.'));
    }
  }

  Future<int> getPendingRequestCount(String userId) async {
    final response = await _apiClient.get(
      '/api/business-places/requests/pending-count',
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      return int.parse(response.body);
    } else {
      throw Exception(_extractErrorMessage(response.body, '대기 중인 요청 수를 불러오는데 실패했습니다.'));
    }
  }

  Future<int> getUnreadResultCount(String userId) async {
    final response = await _apiClient.get(
      '/api/business-places/requests/unread-count',
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      return int.parse(response.body);
    } else {
      throw Exception(_extractErrorMessage(response.body, '읽지 않은 결과 수를 불러오는데 실패했습니다.'));
    }
  }

  Future<BusinessPlaceAccessRequest> markRequestAsRead({
    required String requestId,
    required String userId,
  }) async {
    final response = await _apiClient.put(
      '/api/business-places/requests/$requestId/mark-read',
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      return BusinessPlaceAccessRequest.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '읽음 처리에 실패했습니다.'));
    }
  }

  /// 읽지 않은 처리된 요청 목록 조회 (요청자 본인 기준)
  Future<List<BusinessPlaceAccessRequest>> getUnreadRequests(String userId) async {
    final response = await _apiClient.get(
      '/api/business-places/requests/unread',
      queryParams: {'userId': userId},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceAccessRequest.fromJson(json)).toList();
    } else {
      throw Exception(_extractErrorMessage(response.body, '읽지 않은 요청 목록을 불러오는데 실패했습니다.'));
    }
  }

  /// 사업장 멤버 목록 조회
  Future<List<BusinessPlaceMember>> getBusinessPlaceMembers(
    String businessPlaceId,
  ) async {
    final response = await _apiClient.get(
      '/api/business-places/$businessPlaceId/members',
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceMember.fromJson(json)).toList();
    } else {
      throw Exception(_extractErrorMessage(response.body, '멤버 목록을 불러오는데 실패했습니다.'));
    }
  }

  /// 멤버 역할 변경 (Owner만 가능)
  Future<BusinessPlaceMember> updateMemberRole({
    required String userBusinessPlaceId,
    required Role role,
  }) async {
    final response = await _apiClient.put(
      '/api/business-places/members/$userBusinessPlaceId/role',
      queryParams: {'role': role.name},
    );

    if (response.statusCode == 200) {
      return BusinessPlaceMember.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '역할 변경에 실패했습니다.'));
    }
  }

  /// 멤버 강제 탈퇴 (Owner만 가능)
  Future<void> removeMember(String userBusinessPlaceId) async {
    final response = await _apiClient.delete(
      '/api/business-places/members/$userBusinessPlaceId',
    );

    if (response.statusCode != 204) {
      throw Exception(_extractErrorMessage(response.body, '멤버 삭제에 실패했습니다.'));
    }
  }

  /// 사업장 삭제 미리보기 (삭제될 데이터 개수 조회)
  Future<BusinessPlaceDeletionPreview> getDeletionPreview(
    String businessPlaceId,
  ) async {
    final response = await _apiClient.get(
      '/api/business-places/$businessPlaceId/deletion-preview',
    );

    if (response.statusCode == 200) {
      return BusinessPlaceDeletionPreview.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response.body, '삭제 미리보기를 불러오는데 실패했습니다.'));
    }
  }

  /// 사업장 영구 삭제 (Owner만 가능, 사업장 이름 입력 필요)
  Future<void> deleteBusinessPlacePermanently({
    required String businessPlaceId,
    required String confirmName,
  }) async {
    final response = await _apiClient.delete(
      '/api/business-places/$businessPlaceId/permanent',
      queryParams: {'confirmName': confirmName},
    );

    if (response.statusCode != 204) {
      throw Exception(_extractErrorMessage(response.body, '사업장 삭제에 실패했습니다.'));
    }
  }
}
