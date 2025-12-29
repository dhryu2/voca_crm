import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:local_auth/local_auth.dart';
import 'package:voca_crm/core/constants/auth_constants.dart';
import 'package:voca_crm/core/network/api_client.dart';

import 'session_config.dart';

/// 세션 정보
class SessionInfo {
  final SessionState state;
  final DateTime? lastActivity;
  final DateTime? expiresAt;
  final Duration? timeUntilExpiry;
  final int reauthAttempts;

  const SessionInfo({
    required this.state,
    this.lastActivity,
    this.expiresAt,
    this.timeUntilExpiry,
    this.reauthAttempts = 0,
  });

  bool get isActive => state == SessionState.active;
  bool get isWarning => state == SessionState.warning;
  bool get isExpired => state == SessionState.expired;
  bool get needsReauth => state == SessionState.requiresReauth;

  @override
  String toString() => 'SessionInfo(state: $state, expiresAt: $expiresAt)';
}

/// 세션 관리자
///
/// 사용자 세션의 타임아웃, 재인증, 토큰 갱신을 관리합니다.
///
/// 사용 예:
/// ```dart
/// // 초기화
/// await SessionManager.instance.initialize();
///
/// // 세션 시작 (로그인 후)
/// SessionManager.instance.startSession();
///
/// // 사용자 활동 기록
/// SessionManager.instance.recordActivity();
///
/// // 상태 변경 리스너
/// SessionManager.instance.onStateChange.listen((info) {
///   if (info.isWarning) {
///     showTimeoutWarningDialog();
///   }
/// });
/// ```
class SessionManager extends ChangeNotifier with WidgetsBindingObserver {
  static SessionManager? _instance;
  static SessionManager get instance => _instance ??= SessionManager._();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  SessionManager._()
    : _storage = const FlutterSecureStorage(),
      _localAuth = LocalAuthentication();

  // ============ 상태 ============

  SessionState _state = SessionState.expired;
  DateTime? _lastActivity;
  DateTime? _sessionStartedAt;
  DateTime? _tokenExpiresAt;
  DateTime? _backgroundedAt;
  int _reauthAttempts = 0;

  Timer? _timeoutTimer;
  Timer? _warningTimer;
  Timer? _tokenRefreshTimer;
  bool _isRefreshingToken = false;

  final StreamController<SessionInfo> _stateController =
      StreamController<SessionInfo>.broadcast();

  final StreamController<SessionEvent> _eventController =
      StreamController<SessionEvent>.broadcast();

  // ============ Getters ============

  SessionState get state => _state;
  DateTime? get lastActivity => _lastActivity;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  bool get isActive => _state == SessionState.active;
  bool get isExpired => _state == SessionState.expired;
  bool get needsReauth => _state == SessionState.requiresReauth;

  /// 세션 상태 변경 스트림
  Stream<SessionInfo> get onStateChange => _stateController.stream;

  /// 세션 이벤트 스트림
  Stream<SessionEvent> get onEvent => _eventController.stream;

  /// 현재 세션 정보
  SessionInfo get currentInfo => SessionInfo(
    state: _state,
    lastActivity: _lastActivity,
    expiresAt: _tokenExpiresAt,
    timeUntilExpiry: _tokenExpiresAt?.difference(DateTime.now()),
    reauthAttempts: _reauthAttempts,
  );

  // ============ 콜백 ============

  /// 세션 만료 시 호출될 콜백 (로그아웃 처리)
  VoidCallback? onSessionExpired;

  /// 재인증 필요 시 호출될 콜백
  VoidCallback? onReauthRequired;

  /// 강제 로그아웃 시 호출될 콜백
  VoidCallback? onForcedLogout;

  // ============ 초기화 ============

  /// 세션 매니저 초기화
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
  }

  /// 리소스 해제
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllTimers();
    _stateController.close();
    _eventController.close();
    super.dispose();
  }

  // ============ 세션 시작/종료 ============

  void startSession({String? accessToken}) {
    _sessionStartedAt = DateTime.now();
    _lastActivity = DateTime.now();
    _reauthAttempts = 0;

    if (accessToken != null) {
      try {
        _updateTokenExpiry(accessToken);
      } catch (e) {
        endSession();
        rethrow;
      }
    }

    _updateState(SessionState.active);
    _startTimers();
    _emitEvent(SessionEvent.sessionRefreshed);
  }

  /// 세션 종료 (로그아웃)
  void endSession() {
    _cancelAllTimers();
    _sessionStartedAt = null;
    _lastActivity = null;
    _tokenExpiresAt = null;
    _reauthAttempts = 0;

    _updateState(SessionState.expired);
  }

  void refreshSession(String newAccessToken) {
    try {
      _updateTokenExpiry(newAccessToken);
    } catch (e) {
      endSession();
      rethrow;
    }

    _lastActivity = DateTime.now();

    if (_state != SessionState.active) {
      _updateState(SessionState.active);
    }

    _restartTimers();
    _emitEvent(SessionEvent.sessionRefreshed);
  }

  // ============ 사용자 활동 ============

  /// 사용자 활동 기록
  ///
  /// 터치, 스크롤, 키보드 입력 등 사용자 활동 시 호출합니다.
  void recordActivity() {
    final now = DateTime.now();

    // 최소 활동 간격 체크
    if (_lastActivity != null) {
      final elapsed = now.difference(_lastActivity!);
      if (elapsed < SessionConfig.minActivityInterval) {
        return;
      }
    }

    _lastActivity = now;

    // 경고 상태에서 활동 시 활성 상태로 복귀
    if (_state == SessionState.warning) {
      _updateState(SessionState.active);
      _restartTimers();
    }

    _emitEvent(SessionEvent.userActivity);
  }

  // ============ 재인증 ============

  /// 생체 인증으로 재인증
  Future<bool> reauthenticateWithBiometrics() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      if (!canAuth) {
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: '세션을 연장하려면 인증해주세요',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        _reauthAttempts = 0;
        _lastActivity = DateTime.now();
        _updateState(SessionState.active);
        _restartTimers();
        _emitEvent(SessionEvent.reauthSuccess);
        return true;
      } else {
        _handleReauthFailure();
        return false;
      }
    } catch (e) {
      _handleReauthFailure();
      return false;
    }
  }

  /// 재인증 실패 처리
  void _handleReauthFailure() {
    _reauthAttempts++;
    _emitEvent(SessionEvent.reauthFailed);

    if (_reauthAttempts >= SessionConfig.maxReauthAttempts) {
      _updateState(SessionState.locked);
      _handleForcedLogout();
    }
  }

  /// 민감한 작업 수행 전 재인증
  Future<bool> reauthenticateForSensitiveOperation(String operation) async {
    if (!SessionConfig.sensitiveOperations.contains(operation)) {
      return true; // 민감한 작업이 아니면 바로 허용
    }

    return reauthenticateWithBiometrics();
  }

  // ============ 앱 상태 감지 ============

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        _onAppForegrounded();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onAppBackgrounded() {
    if (_state == SessionState.expired) return;

    _backgroundedAt = DateTime.now();
    _cancelAllTimers();
    _updateState(SessionState.background);

    _emitEvent(SessionEvent.appBackgrounded);
  }

  void _onAppForegrounded() {
    if (_state != SessionState.background) return;

    final now = DateTime.now();

    // 백그라운드 시간 확인
    if (_backgroundedAt != null) {
      final backgroundDuration = now.difference(_backgroundedAt!);

      if (backgroundDuration > SessionConfig.backgroundGracePeriod) {
        // 백그라운드 허용 시간 초과 - 재인증 필요
        _updateState(SessionState.requiresReauth);
        _emitEvent(SessionEvent.appForegrounded);
        onReauthRequired?.call();
        return;
      }
    }

    // 토큰 만료 확인
    if (_tokenExpiresAt != null && now.isAfter(_tokenExpiresAt!)) {
      _handleSessionExpired();
      return;
    }

    // 정상 복귀
    _lastActivity = now;
    _backgroundedAt = null;
    _updateState(SessionState.active);
    _startTimers();

    _emitEvent(SessionEvent.appForegrounded);
  }

  // ============ 타이머 관리 ============

  void _startTimers() {
    _cancelAllTimers();

    // 세션 타임아웃 타이머
    _timeoutTimer = Timer(SessionConfig.sessionTimeout, _handleSessionTimeout);

    // 경고 타이머 (타임아웃 - 경고 시간)
    final warningDelay =
        SessionConfig.sessionTimeout - SessionConfig.warningBeforeTimeout;
    if (warningDelay.inSeconds > 0) {
      _warningTimer = Timer(warningDelay, _handleTimeoutWarning);
    }

    // 토큰 갱신 타이머
    _scheduleTokenRefresh();
  }

  void _restartTimers() {
    _startTimers();
  }

  void _cancelAllTimers() {
    _timeoutTimer?.cancel();
    _warningTimer?.cancel();
    _tokenRefreshTimer?.cancel();
    _timeoutTimer = null;
    _warningTimer = null;
    _tokenRefreshTimer = null;
  }

  void _scheduleTokenRefresh() {
    if (_tokenExpiresAt == null) return;

    final now = DateTime.now();
    final refreshTime = _tokenExpiresAt!.subtract(
      SessionConfig.tokenRefreshBefore,
    );

    if (refreshTime.isAfter(now)) {
      final delay = refreshTime.difference(now);
      _tokenRefreshTimer = Timer(delay, _handleTokenRefresh);
    } else if (_tokenExpiresAt!.isAfter(now)) {
      // 이미 갱신 시간이 지났지만 아직 만료 전이면 즉시 갱신
      _handleTokenRefresh();
    }
  }

  // ============ 이벤트 핸들러 ============

  void _handleTimeoutWarning() {
    if (_state != SessionState.active) return;

    _updateState(SessionState.warning);
    _emitEvent(SessionEvent.timeoutWarning);
  }

  void _handleSessionTimeout() {
    if (_state == SessionState.expired || _state == SessionState.locked) return;

    _updateState(SessionState.requiresReauth);
    onReauthRequired?.call();
  }

  void _handleSessionExpired() {
    _cancelAllTimers();
    _updateState(SessionState.expired);
    _emitEvent(SessionEvent.sessionExpired);
    onSessionExpired?.call();
  }

  void _handleForcedLogout() {
    _cancelAllTimers();
    _updateState(SessionState.expired);
    _emitEvent(SessionEvent.forcedLogout);
    onForcedLogout?.call();
  }

  Future<void> _handleTokenRefresh() async {
    // Race Condition 방지: 이미 갱신 중이면 무시
    if (_isRefreshingToken) return;
    _isRefreshingToken = true;

    try {
      final refreshToken = await _storage.read(
        key: AuthConstants.refreshTokenKey,
      );
      if (refreshToken == null) {
        _handleSessionExpired();
        return;
      }

      // ApiClient를 통해 토큰 갱신
      final response = await ApiClient.instance.requestWithoutAuth(
        'POST',
        '/api/auth/refresh',
        body: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        // 토큰 저장은 ApiClient에서 처리됨
        final accessToken = await _storage.read(
          key: AuthConstants.accessTokenKey,
        );
        if (accessToken != null) {
          refreshSession(accessToken);
        }
      } else {
        // 갱신 실패 시 다음 시도 예약 (1분 후)
        _tokenRefreshTimer = Timer(
          const Duration(minutes: 1),
          _handleTokenRefresh,
        );
      }
    } catch (e) {
      // Token refresh error
    } finally {
      _isRefreshingToken = false;
    }
  }

  // ============ 유틸리티 ============

  void _updateState(SessionState newState) {
    if (_state == newState) return;

    _state = newState;
    _stateController.add(currentInfo);
    notifyListeners();
  }

  void _emitEvent(SessionEvent event) {
    _eventController.add(event);
  }

  void _updateTokenExpiry(String accessToken) {
    try {
      final decodedToken = JwtDecoder.decode(accessToken);
      final exp = decodedToken['exp'] as int?;

      if (exp == null) {
        throw Exception('JWT token missing exp claim');
      }

      final expireTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();

      if (expireTime.isBefore(now)) {
        throw Exception('JWT token has expired');
      }

      final maxValidDuration = const Duration(days: 30);
      if (expireTime.isAfter(now.add(maxValidDuration))) {
        throw Exception('JWT token expiry is too far in the future');
      }

      _tokenExpiresAt = expireTime;
    } catch (e) {
      _tokenExpiresAt = null;
      throw Exception('Invalid JWT token: $e');
    }
  }

  /// 남은 세션 시간 (초)
  int? get remainingSeconds {
    if (_lastActivity == null) return null;

    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = SessionConfig.sessionTimeout - elapsed;

    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  /// 세션 연장
  void extendSession() {
    if (_state == SessionState.warning || _state == SessionState.active) {
      recordActivity();
      _restartTimers();
      _updateState(SessionState.active);
    }
  }

  /// 싱글톤 리셋 (테스트용)
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }
}
