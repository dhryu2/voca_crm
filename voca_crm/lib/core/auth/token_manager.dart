import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:voca_crm/core/constants/api_constants.dart';
import 'package:voca_crm/core/constants/auth_constants.dart';
import 'package:voca_crm/domain/entity/tokens.dart';

/// 토큰 관리자
///
/// Access Token과 Refresh Token의 저장, 조회, 삭제, 갱신을 담당합니다.
/// 싱글톤 패턴으로 앱 전체에서 하나의 인스턴스를 공유합니다.
///
/// 사용 예:
/// ```dart
/// // 토큰 저장
/// await TokenManager.instance.saveTokens(
///   accessToken: 'xxx',
///   refreshToken: 'yyy',
/// );
///
/// // 토큰 조회
/// final tokens = await TokenManager.instance.getTokens();
///
/// // 토큰 갱신
/// final newTokens = await TokenManager.instance.refreshTokens();
/// ```
class TokenManager {
  static TokenManager? _instance;
  static TokenManager get instance => _instance ??= TokenManager._();

  final FlutterSecureStorage _storage;
  final String _baseUrl;

  /// 토큰 갱신 중 중복 요청 방지용 Completer
  Completer<Tokens?>? _refreshCompleter;

  /// 토큰 갱신 성공 콜백
  void Function(Tokens tokens)? onTokensRefreshed;

  /// 토큰 갱신 실패 콜백 (로그인 화면 이동 등)
  void Function()? onRefreshFailed;

  TokenManager._({
    FlutterSecureStorage? storage,
    String? baseUrl,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _baseUrl = baseUrl ?? ApiConstants.apiBaseUrl;

  /// 테스트용 인스턴스 리셋
  static void resetInstance() {
    _instance = null;
  }

  // ============ 토큰 저장 ============

  /// Access Token과 Refresh Token 저장
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(
      key: AuthConstants.accessTokenKey,
      value: accessToken,
    );
    if (refreshToken != null) {
      await _storage.write(
        key: AuthConstants.refreshTokenKey,
        value: refreshToken,
      );
    }
  }

  // ============ 토큰 조회 ============

  /// Access Token 조회
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AuthConstants.accessTokenKey);
  }

  /// Refresh Token 조회
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AuthConstants.refreshTokenKey);
  }

  /// Access Token과 Refresh Token 조회
  Future<Tokens?> getTokens() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();

    if (accessToken != null && refreshToken != null) {
      return Tokens(accessToken: accessToken, refreshToken: refreshToken);
    }
    return null;
  }

  /// 토큰 존재 여부 확인
  Future<bool> hasTokens() async {
    final tokens = await getTokens();
    return tokens != null;
  }

  // ============ 토큰 삭제 ============

  /// 모든 토큰 삭제 (로그아웃)
  Future<void> clearTokens() async {
    await _storage.delete(key: AuthConstants.accessTokenKey);
    await _storage.delete(key: AuthConstants.refreshTokenKey);
  }

  // ============ 토큰 갱신 ============

  /// Refresh Token으로 Access Token 갱신
  ///
  /// Token Rotation이 적용되어 새로운 Refresh Token도 함께 발급됩니다.
  /// 중복 요청 시 기존 요청 결과를 공유합니다.
  ///
  /// 반환값: 새로운 Access Token (갱신 실패 시 null)
  Future<String?> refreshAccessToken() async {
    // 이미 갱신 중이면 기존 작업 완료 대기
    if (_refreshCompleter != null) {
      try {
        final result = await _refreshCompleter!.future;
        return result?.accessToken;
      } catch (e) {
        // 다른 요청에서 갱신 실패한 경우 null 반환
        return null;
      }
    }

    _refreshCompleter = Completer<Tokens?>();

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String?;

        // 새 토큰 저장 (Token Rotation)
        await saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        final tokens = Tokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken ?? refreshToken,
        );

        onTokensRefreshed?.call(tokens);
        _refreshCompleter!.complete(tokens);
        return newAccessToken;
      } else {
        // Refresh Token 만료, 폐기, 또는 재사용 감지
        await clearTokens();
        onRefreshFailed?.call();
        _refreshCompleter!.complete(null);
        return null;
      }
    } catch (e) {
      // 갱신 실패 시 토큰 삭제 및 콜백 호출
      await clearTokens();
      onRefreshFailed?.call();
      _refreshCompleter!.complete(null);  // 에러 대신 null 완료 (race condition 방지)
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Refresh Token으로 토큰 갱신 (Access + Refresh 모두 반환)
  Future<Tokens?> refreshTokens() async {
    if (_refreshCompleter != null) {
      try {
        return await _refreshCompleter!.future;
      } catch (e) {
        // 다른 요청에서 갱신 실패한 경우 null 반환
        return null;
      }
    }

    _refreshCompleter = Completer<Tokens?>();

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String?;

        await saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        final tokens = Tokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken ?? refreshToken,
        );

        onTokensRefreshed?.call(tokens);
        _refreshCompleter!.complete(tokens);
        return tokens;
      } else {
        // Refresh Token 만료, 폐기, 또는 재사용 감지
        await clearTokens();
        onRefreshFailed?.call();
        _refreshCompleter!.complete(null);
        return null;
      }
    } catch (e) {
      // 갱신 실패 시 토큰 삭제 및 콜백 호출
      await clearTokens();
      onRefreshFailed?.call();
      _refreshCompleter!.complete(null);  // 에러 대신 null 완료 (race condition 방지)
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  // ============ 토큰 유효성 검사 ============

  /// Access Token 만료 여부 확인
  Future<bool> isAccessTokenExpired() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return true;

    try {
      return JwtDecoder.isExpired(accessToken);
    } catch (e) {
      return true;
    }
  }

  /// Access Token 만료 시간 조회
  Future<DateTime?> getAccessTokenExpiry() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return null;

    try {
      final decodedToken = JwtDecoder.decode(accessToken);
      final exp = decodedToken['exp'] as int?;
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      return null;
    }
  }

  /// Access Token 남은 시간 조회 (초)
  Future<int?> getAccessTokenRemainingSeconds() async {
    final expiry = await getAccessTokenExpiry();
    if (expiry == null) return null;

    final remaining = expiry.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  // ============ 유틸리티 ============

  /// Authorization 헤더 생성
  Future<Map<String, String>> getAuthHeaders() async {
    final accessToken = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }
}
