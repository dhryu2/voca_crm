import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:voca_crm/core/auth/token_manager.dart';
import 'package:voca_crm/core/constants/api_constants.dart';
import 'package:voca_crm/core/error/app_exception.dart';
import 'package:voca_crm/core/session/session_manager.dart';
import 'package:voca_crm/domain/entity/login_result.dart';
import 'package:voca_crm/domain/entity/tokens.dart';
import 'package:voca_crm/domain/entity/user.dart';

class AuthService {
  final String baseUrl;
  final TokenManager _tokenManager;

  AuthService({
    String? baseUrl,
    TokenManager? tokenManager,
  })  : baseUrl = baseUrl ?? ApiConstants.apiBaseUrl,
        _tokenManager = tokenManager ?? TokenManager.instance;

  /// 소셜 로그인 (Provider별 Token 사용)
  Future<LoginResult> login({
    required String provider,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'provider': provider, 'token': token}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;

      // Create User from JWT token
      User user = User.fromJwt(accessToken);

      // 세션 시작
      SessionManager.instance.startSession(accessToken: accessToken);

      return LoginResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
    } else if (response.statusCode == 404) {
      // USER_NOT_FOUND
      final data = jsonDecode(response.body);
      throw UserNotFoundException(data['message'] ?? '등록되지 않은 사용자입니다');
    } else if (response.statusCode == 400) {
      // INVALID_TOKEN
      final data = jsonDecode(response.body);
      throw InvalidTokenException(data['message'] ?? '유효하지 않은 인증 토큰입니다');
    } else {
      // 서버 오류 메시지 추출하여 ServerException으로 throw
      String message = '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
      try {
        final data = jsonDecode(response.body);
        if (data['message'] != null) {
          message = data['message'];
        }
      } catch (_) {}
      throw ServerException(message: message);
    }
  }

  /// 소셜 회원가입 (Provider별 Token + 사용자 정보)
  Future<LoginResult> signup({
    required String provider,
    required String token,
    required String username,
    required String phone,
    String? email,
  }) async {
    final body = {
      'provider': provider,
      'token': token,
      'username': username,
      'phone': phone,
    };

    // email이 있으면 추가 (null이거나 빈 문자열이면 제외)
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;

      // Create User from JWT token
      User user = User.fromJwt(accessToken);

      // 세션 시작
      SessionManager.instance.startSession(accessToken: accessToken);

      return LoginResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
    } else if (response.statusCode == 409) {
      // USER_ALREADY_EXISTS
      final data = jsonDecode(response.body);
      throw DuplicateUserException(data['message'] ?? '이미 가입된 사용자입니다');
    } else if (response.statusCode == 400) {
      // INVALID_INPUT
      final data = jsonDecode(response.body);
      // fieldErrors가 있으면 첫 번째 필드 오류 메시지 사용
      if (data['fieldErrors'] is Map && (data['fieldErrors'] as Map).isNotEmpty) {
        final fieldErrors = data['fieldErrors'] as Map;
        throw InvalidInputException(fieldErrors.values.first.toString());
      }
      throw InvalidInputException(data['message'] ?? '입력 정보가 올바르지 않습니다');
    } else {
      // 서버 오류 메시지 추출하여 ServerException으로 throw
      String message = '회원가입에 실패했습니다. 잠시 후 다시 시도해주세요.';
      try {
        final data = jsonDecode(response.body);
        if (data['message'] != null) {
          message = data['message'];
        }
      } catch (_) {}
      throw ServerException(message: message);
    }
  }

  // ============ Token Management (TokenManager 위임) ============

  /// 토큰 저장
  /// @deprecated Use TokenManager.instance.saveTokens() instead
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) =>
      _tokenManager.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

  /// 토큰 조회
  /// @deprecated Use TokenManager.instance.getTokens() instead
  Future<Tokens?> getTokens() => _tokenManager.getTokens();

  /// 로그아웃
  ///
  /// 서버에 로그아웃 요청을 보내 refresh token을 무효화하고,
  /// 로컬 세션과 토큰을 정리합니다.
  Future<void> logout() async {
    try {
      // 서버에 로그아웃 요청 (refresh token 무효화)
      final tokens = await _tokenManager.getTokens();
      if (tokens != null && tokens.refreshToken.isNotEmpty) {
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': tokens.refreshToken}),
        );
      }
    } catch (e) {
      // 서버 로그아웃 실패해도 로컬 정리는 진행
      // 네트워크 오류 등의 경우에도 사용자는 로그아웃되어야 함
    } finally {
      // 세션 종료
      SessionManager.instance.endSession();

      // 토큰 삭제 (TokenManager 위임)
      await _tokenManager.clearTokens();
    }
  }

  /// 토큰 갱신
  /// @deprecated Use TokenManager.instance.refreshTokens() instead
  ///
  /// Note: LoginResult를 반환해야 하므로 TokenManager.refreshTokens()를 사용하고
  /// User 정보를 JWT에서 추출합니다.
  Future<LoginResult> refreshToken(String refreshToken) async {
    final tokens = await _tokenManager.refreshTokens();

    if (tokens == null) {
      throw const TokenRefreshException();
    }

    // Create User from JWT token
    User user = User.fromJwt(tokens.accessToken);

    // 세션 갱신
    SessionManager.instance.refreshSession(tokens.accessToken);

    return LoginResult(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: user,
    );
  }
}

// Custom Exceptions
class UserNotFoundException implements Exception {
  final String message;
  UserNotFoundException(this.message);

  @override
  String toString() => message;
}

class InvalidTokenException implements Exception {
  final String message;
  InvalidTokenException(this.message);

  @override
  String toString() => message;
}

class DuplicateUserException implements Exception {
  final String message;
  DuplicateUserException(this.message);

  @override
  String toString() => message;
}

class InvalidInputException implements Exception {
  final String message;
  InvalidInputException(this.message);

  @override
  String toString() => message;
}
