import 'dart:convert';
import 'dart:developer' as developer;

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/data/model/member_model.dart';

/// 회원 서비스
/// API 서버와 통신하여 회원 데이터를 관리
class MemberService {
  final ApiClient _apiClient;

  MemberService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// 회원 생성
  /// [ownerId]: 회원을 추가한 사용자 ID (권한 체크용)
  Future<MemberModel> createMember({
    String? businessPlaceId,
    required String memberNumber,
    required String name,
    String? phone,
    String? email,
    String? ownerId,
    String? grade,
    String? remark,
  }) async {
    final requestBody = <String, dynamic>{
      if (businessPlaceId != null) 'businessPlaceId': businessPlaceId,
      'memberNumber': memberNumber,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (ownerId != null) 'ownerId': ownerId,
      if (grade != null) 'grade': grade,
      if (remark != null) 'remark': remark,
    };

    final response = await _apiClient.post('/api/members', body: requestBody);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return MemberModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemberServiceException(
        errorData['message'] ?? '회원 생성 중 오류가 발생했습니다.',
      );
    }
  }

  /// ID로 회원 조회
  Future<MemberModel?> getMemberById(String id) async {
    try {
      final response = await _apiClient.get('/api/members/$id');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MemberModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 회원번호로 회원 목록 조회
  Future<List<MemberModel>> getMembersByNumber(String memberNumber) async {
    try {
      final response = await _apiClient.get('/api/members/by-number/$memberNumber');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data.map((json) => MemberModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 사업장별 회원 목록 조회
  Future<List<MemberModel>> getMembersByBusinessPlace(String businessPlaceId) async {
    try {
      developer.log('[MemberService] getMembersByBusinessPlace called with: $businessPlaceId');
      final response = await _apiClient.get('/api/members/by-business-place/$businessPlaceId');
      developer.log('[MemberService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          developer.log('[MemberService] data is null');
          return [];
        }

        developer.log('[MemberService] Found ${data.length} members');
        return data.map((json) => MemberModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      developer.log('[MemberService] Non-200 response');
      return [];
    } catch (e) {
      developer.log('[MemberService] Error: $e');
      return [];
    }
  }

  /// 회원 검색
  Future<List<MemberModel>> searchMembers({
    String? memberNumber,
    String? name,
    String? phone,
    String? email,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (memberNumber != null) queryParams['memberNumber'] = memberNumber;
      if (name != null) queryParams['name'] = name;
      if (phone != null) queryParams['phone'] = phone;
      if (email != null) queryParams['email'] = email;

      final response = await _apiClient.get('/api/members/search', queryParams: queryParams);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data.map((json) => MemberModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 회원 정보 수정
  /// [userId]: 요청자 사용자 ID (권한 체크용)
  /// [businessPlaceId]: 사업장 ID (권한 체크용)
  Future<MemberModel> updateMember(
    MemberModel member, {
    String? userId,
    String? businessPlaceId,
  }) async {
    final additionalHeaders = <String, String>{
      if (userId != null) 'X-User-Id': userId,
      if (businessPlaceId != null) 'X-Business-Place-Id': businessPlaceId,
    };

    final response = await _apiClient.put(
      '/api/members/${member.id}',
      body: member.toJson(),
      additionalHeaders: additionalHeaders.isNotEmpty ? additionalHeaders : null,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MemberModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemberServiceException(
        errorData['message'] ?? '회원 수정 중 오류가 발생했습니다.',
      );
    }
  }

  /// 회원 삭제
  /// [userId]: 요청자 사용자 ID (권한 체크용)
  /// [businessPlaceId]: 사업장 ID (권한 체크용)
  Future<void> deleteMember(
    String id, {
    String? userId,
    String? businessPlaceId,
  }) async {
    final additionalHeaders = <String, String>{
      if (userId != null) 'X-User-Id': userId,
      if (businessPlaceId != null) 'X-Business-Place-Id': businessPlaceId,
    };

    final response = await _apiClient.delete(
      '/api/members/$id',
      additionalHeaders: additionalHeaders.isNotEmpty ? additionalHeaders : null,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw MemberServiceException(
        errorData['message'] ?? '회원 삭제 중 오류가 발생했습니다.',
      );
    }
  }

  /// 전체 회원 목록 조회
  /// [skip]: 페이지 번호 (기본값: 0)
  /// [limit]: 페이지 크기 (기본값: 1000, 대부분의 경우를 커버하도록 큰 값 설정)
  Future<List<MemberModel>> getAllMembers({
    int skip = 0,
    int limit = 1000,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/members',
        queryParams: {
          'skip': skip.toString(),
          'limit': limit.toString(),
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // Spring Boot Page response has 'content' field
        final List<dynamic>? data = responseData['content'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data.map((json) => MemberModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===== Soft Delete Methods =====

  /// 회원 Soft Delete (삭제 대기 상태로 전환)
  Future<MemberModel> softDeleteMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final response = await _apiClient.delete(
      '/api/members/$id/soft',
      additionalHeaders: {
        'X-User-Id': userId,
        'X-Business-Place-Id': businessPlaceId,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MemberModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemberServiceException(
        errorData['message'] ?? '회원 삭제 대기 처리 중 오류가 발생했습니다.',
      );
    }
  }

  /// 특정 사업장의 삭제 대기 회원 목록 조회
  Future<List<MemberModel>> getDeletedMembers({
    required String businessPlaceId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/members/deleted',
        queryParams: {'businessPlaceId': businessPlaceId},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data.map((json) => MemberModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 삭제 대기 회원 복원
  Future<MemberModel> restoreMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final response = await _apiClient.post(
      '/api/members/$id/restore',
      additionalHeaders: {
        'X-User-Id': userId,
        'X-Business-Place-Id': businessPlaceId,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MemberModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemberServiceException(
        errorData['message'] ?? '회원 복원 중 오류가 발생했습니다.',
      );
    }
  }

  /// 회원 영구 삭제
  Future<void> permanentDeleteMember(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final response = await _apiClient.delete(
      '/api/members/$id/permanent',
      additionalHeaders: {
        'X-User-Id': userId,
        'X-Business-Place-Id': businessPlaceId,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw MemberServiceException(
        errorData['message'] ?? '회원 영구 삭제 중 오류가 발생했습니다.',
      );
    }
  }
}

/// 회원 서비스 예외
class MemberServiceException implements Exception {
  final String message;

  MemberServiceException(this.message);

  @override
  String toString() => message;
}
