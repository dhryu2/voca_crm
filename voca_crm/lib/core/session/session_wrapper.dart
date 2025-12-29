import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voca_crm/core/session/activity_detector.dart';
import 'package:voca_crm/core/session/session_config.dart';
import 'package:voca_crm/core/session/session_manager.dart';
import 'package:voca_crm/presentation/widgets/session_dialogs.dart';

/// 세션 관리 래퍼 위젯
///
/// 앱 전체를 감싸서 세션 관리 기능을 제공합니다.
/// - 사용자 활동 감지
/// - 세션 타임아웃 경고
/// - 재인증 다이얼로그
/// - 세션 잠금 화면
///
/// 사용 예:
/// ```dart
/// SessionWrapper(
///   onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
///   child: MaterialApp(...),
/// )
/// ```
class SessionWrapper extends StatefulWidget {
  final Widget child;

  /// 로그아웃 시 호출될 콜백
  final VoidCallback? onLogout;

  /// 세션 만료 시 호출될 콜백
  final VoidCallback? onSessionExpired;

  const SessionWrapper({
    super.key,
    required this.child,
    this.onLogout,
    this.onSessionExpired,
  });

  @override
  State<SessionWrapper> createState() => _SessionWrapperState();
}

class _SessionWrapperState extends State<SessionWrapper> {
  StreamSubscription<SessionInfo>? _stateSubscription;
  StreamSubscription<SessionEvent>? _eventSubscription;
  bool _isShowingDialog = false;
  bool _isLocked = false;

  /// 세션이 활성화되어 있는지 확인
  bool get _isSessionActive => SessionManager.instance.isActive;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _disposeSession();
    super.dispose();
  }

  void _initializeSession() {
    final sessionManager = SessionManager.instance;

    // 콜백 등록
    sessionManager.onSessionExpired = _handleSessionExpired;
    sessionManager.onReauthRequired = _handleReauthRequired;
    sessionManager.onForcedLogout = _handleForcedLogout;

    // 상태 변경 리스너
    _stateSubscription = sessionManager.onStateChange.listen(_handleStateChange);

    // 이벤트 리스너
    _eventSubscription = sessionManager.onEvent.listen(_handleEvent);
  }

  void _disposeSession() {
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    _stateSubscription = null;
    _eventSubscription = null;
  }

  void _handleStateChange(SessionInfo info) {
    if (!mounted) return;

    switch (info.state) {
      case SessionState.warning:
        _showTimeoutWarning();
        break;
      case SessionState.locked:
        _showLockedScreen();
        break;
      case SessionState.expired:
        // 다이얼로그 닫기
        if (_isShowingDialog) {
          Navigator.of(context).pop();
          _isShowingDialog = false;
        }
        break;
      default:
        break;
    }
  }

  void _handleEvent(SessionEvent event) {
    if (!mounted) return;

    switch (event) {
      case SessionEvent.timeoutWarning:
        _showTimeoutWarning();
        break;
      case SessionEvent.sessionExpired:
        _handleSessionExpired();
        break;
      case SessionEvent.forcedLogout:
        _handleForcedLogout();
        break;
      default:
        break;
    }
  }

  void _handleSessionExpired() {
    if (_isShowingDialog) {
      Navigator.of(context).pop();
      _isShowingDialog = false;
    }
    widget.onSessionExpired?.call();
    widget.onLogout?.call();
  }

  void _handleReauthRequired() {
    if (_isShowingDialog) return;

    _showReauthDialog();
  }

  void _handleForcedLogout() {
    if (_isShowingDialog) {
      Navigator.of(context).pop();
      _isShowingDialog = false;
    }

    if (_isLocked) {
      setState(() {
        _isLocked = false;
      });
    }

    widget.onLogout?.call();
  }

  void _showTimeoutWarning() {
    if (_isShowingDialog || _isLocked) return;

    _isShowingDialog = true;
    SessionTimeoutWarningDialog.show(
      context,
      onExtend: () {
        _isShowingDialog = false;
        SessionManager.instance.extendSession();
      },
      onLogout: () {
        _isShowingDialog = false;
        _performLogout();
      },
    ).then((_) {
      _isShowingDialog = false;
    });
  }

  void _showReauthDialog() {
    if (_isShowingDialog || _isLocked) return;

    _isShowingDialog = true;
    ReauthenticationDialog.show(
      context,
      onSuccess: () {
        _isShowingDialog = false;
        // 세션 연장됨
      },
      onCancel: () {
        _isShowingDialog = false;
        // 취소 시 이전 화면 유지
      },
      onLogout: () {
        _isShowingDialog = false;
        _performLogout();
      },
    ).then((_) {
      _isShowingDialog = false;
    });
  }

  void _showLockedScreen() {
    if (_isLocked) return;

    setState(() {
      _isLocked = true;
    });
  }

  void _performLogout() {
    SessionManager.instance.endSession();
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    // 잠금 화면 표시
    if (_isLocked) {
      return SessionLockedScreen(
        lockDuration: SessionConfig.lockoutDuration,
        onUnlocked: () {
          setState(() {
            _isLocked = false;
          });
          // 잠금 해제 후 재인증 요청
          _showReauthDialog();
        },
        onLogout: () {
          setState(() {
            _isLocked = false;
          });
          _performLogout();
        },
      );
    }

    // 세션이 비활성 상태면 그냥 자식 위젯 반환
    if (!_isSessionActive) {
      return widget.child;
    }

    // 활동 감지 래퍼로 감싸기
    return ActivityDetector(
      child: widget.child,
    );
  }
}

/// 세션 상태에 따른 위젯 빌더
///
/// 세션 상태에 따라 다른 위젯을 표시할 때 사용합니다.
///
/// 사용 예:
/// ```dart
/// SessionStateBuilder(
///   builder: (context, info) {
///     if (info.isExpired) {
///       return LoginScreen();
///     }
///     return HomeScreen();
///   },
/// )
/// ```
class SessionStateBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, SessionInfo info) builder;

  const SessionStateBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionInfo>(
      stream: SessionManager.instance.onStateChange,
      initialData: SessionManager.instance.currentInfo,
      builder: (context, snapshot) {
        final info = snapshot.data ?? SessionManager.instance.currentInfo;
        return builder(context, info);
      },
    );
  }
}

/// 세션 상태 표시 위젯
///
/// 디버그 모드에서 현재 세션 상태를 표시합니다.
class SessionStatusIndicator extends StatelessWidget {
  final bool showOnlyInDebug;

  const SessionStatusIndicator({
    super.key,
    this.showOnlyInDebug = true,
  });

  @override
  Widget build(BuildContext context) {
    // 릴리스 모드에서는 표시하지 않음
    if (showOnlyInDebug) {
      bool isDebug = false;
      assert(() {
        isDebug = true;
        return true;
      }());
      if (!isDebug) return const SizedBox.shrink();
    }

    return StreamBuilder<SessionInfo>(
      stream: SessionManager.instance.onStateChange,
      initialData: SessionManager.instance.currentInfo,
      builder: (context, snapshot) {
        final info = snapshot.data ?? SessionManager.instance.currentInfo;
        final remaining = SessionManager.instance.remainingSeconds;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(info.state).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(info.state),
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '${_getStatusText(info.state)}${remaining != null ? ' ($remaining초)' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(SessionState state) {
    switch (state) {
      case SessionState.active:
        return Colors.green;
      case SessionState.warning:
        return Colors.orange;
      case SessionState.expired:
        return Colors.red;
      case SessionState.locked:
        return Colors.red.shade900;
      case SessionState.background:
        return Colors.blue;
      case SessionState.requiresReauth:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(SessionState state) {
    switch (state) {
      case SessionState.active:
        return Icons.check_circle;
      case SessionState.warning:
        return Icons.timer;
      case SessionState.expired:
        return Icons.cancel;
      case SessionState.locked:
        return Icons.lock;
      case SessionState.background:
        return Icons.visibility_off;
      case SessionState.requiresReauth:
        return Icons.fingerprint;
    }
  }

  String _getStatusText(SessionState state) {
    switch (state) {
      case SessionState.active:
        return '활성';
      case SessionState.warning:
        return '만료 임박';
      case SessionState.expired:
        return '만료됨';
      case SessionState.locked:
        return '잠김';
      case SessionState.background:
        return '백그라운드';
      case SessionState.requiresReauth:
        return '재인증 필요';
    }
  }
}

/// 민감한 작업 보호 위젯
///
/// 민감한 작업 수행 시 재인증을 요구합니다.
///
/// 사용 예:
/// ```dart
/// SensitiveActionGuard(
///   operation: 'delete_member',
///   onAuthenticated: () {
///     // 회원 삭제 로직
///   },
///   child: ElevatedButton(
///     onPressed: null, // SensitiveActionGuard가 처리
///     child: Text('회원 삭제'),
///   ),
/// )
/// ```
class SensitiveActionGuard extends StatelessWidget {
  final String operation;
  final VoidCallback onAuthenticated;
  final Widget child;

  const SensitiveActionGuard({
    super.key,
    required this.operation,
    required this.onAuthenticated,
    required this.child,
  });

  Future<void> _handleTap(BuildContext context) async {
    final success = await SessionManager.instance
        .reauthenticateForSensitiveOperation(operation);

    if (success) {
      onAuthenticated();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증이 필요합니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: AbsorbPointer(child: child),
    );
  }
}
