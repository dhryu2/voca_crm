/// 세션 관리 설정
class SessionConfig {
  SessionConfig._();

  /// 세션 타임아웃 시간 (비활동 시간)
  /// 기본값: 15분
  static const Duration sessionTimeout = Duration(minutes: 15);

  /// 타임아웃 경고 표시 시간 (만료 전)
  /// 기본값: 60초 전
  static const Duration warningBeforeTimeout = Duration(seconds: 60);

  /// 백그라운드 허용 시간 (이 시간 초과 시 재인증 필요)
  /// 기본값: 5분
  static const Duration backgroundGracePeriod = Duration(minutes: 5);

  /// 토큰 갱신 시작 시간 (만료 전)
  /// 기본값: 5분 전
  static const Duration tokenRefreshBefore = Duration(minutes: 5);

  /// 재인증 최대 시도 횟수
  static const int maxReauthAttempts = 3;

  /// 재인증 실패 시 잠금 시간
  static const Duration lockoutDuration = Duration(minutes: 5);

  /// 민감한 작업 목록 (이 작업 수행 시 재인증 필요)
  static const List<String> sensitiveOperations = [
    'delete_member',
    'export_data',
    'change_password',
    'logout_all_devices',
    'modify_permissions',
  ];

  /// 활동으로 간주되는 최소 터치 간격
  static const Duration minActivityInterval = Duration(seconds: 1);
}

/// 세션 상태
enum SessionState {
  /// 활성 상태
  active,

  /// 경고 상태 (타임아웃 임박)
  warning,

  /// 만료됨
  expired,

  /// 잠김 (재인증 실패 횟수 초과)
  locked,

  /// 백그라운드
  background,

  /// 재인증 필요
  requiresReauth,
}

/// 세션 이벤트
enum SessionEvent {
  /// 사용자 활동 감지
  userActivity,

  /// 타임아웃 경고
  timeoutWarning,

  /// 세션 만료
  sessionExpired,

  /// 세션 갱신됨
  sessionRefreshed,

  /// 재인증 성공
  reauthSuccess,

  /// 재인증 실패
  reauthFailed,

  /// 강제 로그아웃
  forcedLogout,

  /// 앱 백그라운드로 전환
  appBackgrounded,

  /// 앱 포그라운드로 전환
  appForegrounded,
}
