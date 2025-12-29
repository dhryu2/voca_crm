import 'dart:convert';

import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/domain/entity/notice.dart';

/// 공지사항 서비스
/// API 서버와 통신하여 공지사항 데이터를 관리
class NoticeService {
  final ApiClient _apiClient;

  NoticeService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// 사용자가 볼 수 있는 활성 공지사항 조회
  Future<List<Notice>> getActiveNotices(String userId) async {
    try {
      final response = await _apiClient.get(
        '/api/notices/active',
        queryParams: {'userId': userId},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data
            .map((json) => Notice.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 공지사항 열람 기록 저장
  Future<void> recordView({
    required String noticeId,
    required String userId,
    required bool doNotShowAgain,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/notices/$noticeId/view',
        body: {
          'userId': userId,
          'doNotShowAgain': doNotShowAgain,
        },
      );
    } catch (e) {
      // Error recording view
    }
  }

  // ========== 관리자 전용 API ==========

  /// 모든 공지사항 조회 (관리자용)
  Future<List<Notice>> getAllNotices() async {
    try {
      final response = await _apiClient.get('/api/admin/notices');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic>? data = responseData['data'] as List<dynamic>?;

        if (data == null) {
          return [];
        }

        return data
            .map((json) => Notice.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// ID로 공지사항 조회 (관리자용)
  Future<Notice?> getNoticeById(String id) async {
    try {
      final response = await _apiClient.get('/api/admin/notices/$id');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Notice.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 공지사항 생성 (관리자용)
  Future<Notice> createNotice(Notice notice) async {
    final response = await _apiClient.post(
      '/api/admin/notices',
      body: notice.toJson(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Notice.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw NoticeServiceException(
        errorData['message'] ?? '공지사항 생성 중 오류가 발생했습니다.',
      );
    }
  }

  /// 공지사항 수정 (관리자용)
  Future<Notice> updateNotice(String id, Notice notice) async {
    final response = await _apiClient.put(
      '/api/admin/notices/$id',
      body: notice.toJson(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Notice.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw NoticeServiceException(
        errorData['message'] ?? '공지사항 수정 중 오류가 발생했습니다.',
      );
    }
  }

  /// 공지사항 삭제 (관리자용)
  Future<void> deleteNotice(String id) async {
    final response = await _apiClient.delete('/api/admin/notices/$id');

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw NoticeServiceException(
        errorData['message'] ?? '공지사항 삭제 중 오류가 발생했습니다.',
      );
    }
  }

  /// 공지사항 통계 조회 (관리자용)
  Future<Map<String, int>> getNoticeStats(String id) async {
    try {
      final response = await _apiClient.get('/api/admin/notices/$id/stats');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'viewCount': (data['viewCount'] as num).toInt(),
          'hideCount': (data['hideCount'] as num).toInt(),
        };
      }
      return {'viewCount': 0, 'hideCount': 0};
    } catch (e) {
      return {'viewCount': 0, 'hideCount': 0};
    }
  }
}

/// 공지사항 서비스 예외
class NoticeServiceException implements Exception {
  final String message;

  NoticeServiceException(this.message);

  @override
  String toString() => message;
}
