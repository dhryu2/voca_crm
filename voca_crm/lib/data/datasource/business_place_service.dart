import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/core/error/exception_parser.dart';
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

  Future<Map<String, dynamic>> createBusinessPlace({
    required String userId,
    required String name,
    String? address,
    String? phone,
  }) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.post(
      '/api/business-places',
      body: {'name': name, 'address': address, 'phone': phone},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // API 응답: CreateBusinessPlaceResponse DTO (플랫 구조)
      final now = DateTime.now();
      final businessPlace = BusinessPlace(
        id: data['businessPlaceId'],
        name: data['businessPlaceName'],
        address: data['businessPlaceAddress'],
        phone: data['businessPlacePhone'],
        createdAt: data['businessPlaceCreatedAt'] != null
            ? DateTime.parse(data['businessPlaceCreatedAt'])
            : now,
        updatedAt: data['businessPlaceCreatedAt'] != null
            ? DateTime.parse(data['businessPlaceCreatedAt'])
            : now,
      );
      final user = User(
        id: data['userId'].toString(),
        username: data['username'] ?? '',
        displayName: data['displayName'],
        email: data['email'] ?? '',
        phone: '', // CreateBusinessPlaceResponse에는 phone이 없음
        defaultBusinessPlaceId: data['defaultBusinessPlaceId'],
        createdAt: now,
        updatedAt: now,
      );
      return {
        'businessPlace': businessPlace,
        'user': user,
      };
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<List<BusinessPlaceWithRole>> getMyBusinessPlaces(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/business-places/my',
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceWithRole.fromJson(json)).toList();
    } else {
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<BusinessPlaceAccessRequest> requestAccess({
    required String userId,
    required String businessPlaceId,
    required Role role,
  }) async {
    // userId는 JWT 토큰에서 추출되므로 role만 query param으로 전송
    final response = await _apiClient.post(
      '/api/business-places/$businessPlaceId/request-access',
      queryParams: {'role': role.name},
    );

    if (response.statusCode == 200) {
      return BusinessPlaceAccessRequest.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<List<BusinessPlaceAccessRequest>> getSentRequests(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/business-places/requests/sent',
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceAccessRequest.fromJson(json)).toList();
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<List<BusinessPlaceAccessRequest>> getReceivedRequests(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/business-places/requests/received',
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceAccessRequest.fromJson(json)).toList();
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<BusinessPlaceAccessRequest> approveRequest({
    required String requestId,
    required String ownerId,
  }) async {
    // ownerId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.put(
      '/api/business-places/requests/$requestId/approve',
    );

    if (response.statusCode == 200) {
      return BusinessPlaceAccessRequest.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<BusinessPlaceAccessRequest> rejectRequest({
    required String requestId,
    required String ownerId,
  }) async {
    // ownerId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.put(
      '/api/business-places/requests/$requestId/reject',
    );

    if (response.statusCode == 200) {
      return BusinessPlaceAccessRequest.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<void> deleteRequest({
    required String requestId,
    required String userId,
  }) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.delete(
      '/api/business-places/requests/$requestId',
    );

    if (response.statusCode != 204) {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<User> setDefaultBusinessPlace(
    String userId,
    String businessPlaceId,
  ) async {
    final response = await _apiClient.put(
      '/api/business-places/$businessPlaceId/set-default',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // API 응답: SetDefaultBusinessPlaceResponse DTO (플랫 구조)
      // userId, username, displayName, email, defaultBusinessPlaceId
      final now = DateTime.now();
      return User(
        id: data['userId'].toString(),
        username: data['username'] ?? '',
        displayName: data['displayName'],
        email: data['email'] ?? '',
        phone: '', // SetDefaultBusinessPlaceResponse에는 phone이 없음
        defaultBusinessPlaceId: data['defaultBusinessPlaceId'],
        createdAt: now,
        updatedAt: now,
      );
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<void> removeBusinessPlace(
    String userId,
    String businessPlaceId,
  ) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.delete(
      '/api/business-places/$businessPlaceId/remove',
    );

    if (response.statusCode != 204) {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<BusinessPlace> updateBusinessPlace({
    required String userId,
    required String businessPlaceId,
    required String name,
    String? address,
    String? phone,
  }) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.put(
      '/api/business-places/$businessPlaceId',
      body: {'name': name, 'address': address, 'phone': phone},
    );

    if (response.statusCode == 200) {
      return BusinessPlace.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<int> getPendingRequestCount(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/business-places/requests/pending-count',
    );

    if (response.statusCode == 200) {
      return int.parse(response.body);
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<int> getUnreadResultCount(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/business-places/requests/unread-count',
    );

    if (response.statusCode == 200) {
      return int.parse(response.body);
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  Future<BusinessPlaceAccessRequest> markRequestAsRead({
    required String requestId,
    required String userId,
  }) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.put(
      '/api/business-places/requests/$requestId/mark-read',
    );

    if (response.statusCode == 200) {
      return BusinessPlaceAccessRequest.fromJson(jsonDecode(response.body));
    } else {
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  /// 읽지 않은 처리된 요청 목록 조회 (요청자 본인 기준)
  Future<List<BusinessPlaceAccessRequest>> getUnreadRequests(String userId) async {
    // userId는 JWT 토큰에서 추출되므로 query param으로 전송하지 않음
    final response = await _apiClient.get(
      '/api/business-places/requests/unread',
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BusinessPlaceAccessRequest.fromJson(json)).toList();
    } else {
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
    }
  }

  /// 멤버 강제 탈퇴 (Owner만 가능)
  Future<void> removeMember(String userBusinessPlaceId) async {
    final response = await _apiClient.delete(
      '/api/business-places/members/$userBusinessPlaceId',
    );

    if (response.statusCode != 204) {
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
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
      throw ExceptionParser.fromHttpResponse(response);
    }
  }
}
