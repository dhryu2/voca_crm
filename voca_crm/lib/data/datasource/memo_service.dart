import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/data/model/memo_model.dart';

/// 메모 서비스
/// API 서버와 통신하여 메모 데이터를 관리
class MemoService {
  final ApiClient _apiClient;

  MemoService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  /// 메모 생성
  Future<MemoModel> createMemo({
    required String memberId,
    required String content,
  }) async {
    final response = await _apiClient.post(
      '/api/memos',
      body: {'memberId': memberId, 'content': content},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return MemoModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemoServiceException(errorData['message'] ?? '메모 생성 중 오류가 발생했습니다.');
    }
  }

  /// 메모 생성 (기존 메모 삭제 후)
  Future<MemoModel> createMemoWithDeletion({
    required String memberId,
    required String content,
  }) async {
    final response = await _apiClient.post(
      '/api/memos/with-deletion',
      body: {'memberId': memberId, 'content': content},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return MemoModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemoServiceException(errorData['message'] ?? '메모 생성 중 오류가 발생했습니다.');
    }
  }

  /// ID로 메모 조회
  Future<MemoModel?> getMemoById(String id) async {
    try {
      final response = await _apiClient.get('/api/memos/$id');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MemoModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 회원 ID로 메모 목록 조회
  Future<List<MemoModel>> getMemosByMemberId(String memberId) async {
    try {
      final response = await _apiClient.get('/api/memos/member/$memberId');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data
            .map((json) => MemoModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 회원의 최신 메모 조회
  Future<MemoModel?> getLatestMemoByMemberId(String memberId) async {
    try {
      final response = await _apiClient.get(
        '/api/memos/member/$memberId/latest',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MemoModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 메모 수정
  Future<MemoModel> updateMemo(
    MemoModel memo, {
    String? userId,
    String? businessPlaceId,
  }) async {
    final additionalHeaders = <String, String>{};

    // 권한 체크 헤더 추가
    if (userId != null && businessPlaceId != null) {
      additionalHeaders['X-User-Id'] = userId;
      additionalHeaders['X-Business-Place-Id'] = businessPlaceId;
    }

    final response = await _apiClient.put(
      '/api/memos/${memo.id}',
      body: memo.toJson(),
      additionalHeaders: additionalHeaders.isNotEmpty
          ? additionalHeaders
          : null,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MemoModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemoServiceException(errorData['message'] ?? '메모 수정 중 오류가 발생했습니다.');
    }
  }

  /// 메모 삭제
  Future<void> deleteMemo(
    String id, {
    String? userId,
    String? businessPlaceId,
  }) async {
    final additionalHeaders = <String, String>{};

    // 권한 체크 헤더 추가
    if (userId != null && businessPlaceId != null) {
      additionalHeaders['X-User-Id'] = userId;
      additionalHeaders['X-Business-Place-Id'] = businessPlaceId;
    }

    final response = await _apiClient.delete(
      '/api/memos/$id',
      additionalHeaders: additionalHeaders.isNotEmpty
          ? additionalHeaders
          : null,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw MemoServiceException(errorData['message'] ?? '메모 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 메모 중요도 토글
  Future<MemoModel> toggleImportant(String id) async {
    final response = await _apiClient.patch('/api/memos/$id/toggle-important');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MemoModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemoServiceException(
        errorData['message'] ?? '메모 중요도 변경 중 오류가 발생했습니다.',
      );
    }
  }

  // ===== Soft Delete Methods =====

  /// 메모 Soft Delete (삭제 대기 상태로 전환)
  Future<MemoModel> softDeleteMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final response = await _apiClient.delete(
      '/api/memos/$id/soft',
      additionalHeaders: {
        'X-User-Id': userId,
        'X-Business-Place-Id': businessPlaceId,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MemoModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemoServiceException(
        errorData['message'] ?? '메모 삭제 대기 처리 중 오류가 발생했습니다.',
      );
    }
  }

  /// 특정 사업장의 삭제 대기 메모 목록 조회
  Future<List<MemoModel>> getDeletedMemos({
    required String businessPlaceId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/memos/deleted',
        queryParams: {'businessPlaceId': businessPlaceId},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data
            .map((json) => MemoModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 삭제 대기 중인 메모 목록 조회 (회원별)
  Future<List<MemoModel>> getDeletedMemosByMemberId(String memberId) async {
    try {
      final response = await _apiClient.get(
        '/api/memos/member/$memberId/deleted',
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data
            .map((json) => MemoModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 삭제 대기 메모 복원
  Future<MemoModel> restoreMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final response = await _apiClient.post(
      '/api/memos/$id/restore',
      additionalHeaders: {
        'X-User-Id': userId,
        'X-Business-Place-Id': businessPlaceId,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MemoModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw MemoServiceException(errorData['message'] ?? '메모 복원 중 오류가 발생했습니다.');
    }
  }

  /// 메모 영구 삭제
  Future<void> permanentDeleteMemo(
    String id, {
    required String userId,
    required String businessPlaceId,
  }) async {
    final response = await _apiClient.delete(
      '/api/memos/$id/permanent',
      additionalHeaders: {
        'X-User-Id': userId,
        'X-Business-Place-Id': businessPlaceId,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw MemoServiceException(
        errorData['message'] ?? '메모 영구 삭제 중 오류가 발생했습니다.',
      );
    }
  }
}

/// 메모 서비스 예외
class MemoServiceException implements Exception {
  final String message;

  MemoServiceException(this.message);

  @override
  String toString() => message;
}
