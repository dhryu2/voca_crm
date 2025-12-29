import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:voca_crm/core/session/session_config.dart';
import 'package:voca_crm/core/session/session_manager.dart';
import 'package:voca_crm/core/theme/theme_color.dart';

/// 세션 타임아웃 경고 다이얼로그
///
/// 세션이 곧 만료됨을 알리고 연장 옵션을 제공합니다.
class SessionTimeoutWarningDialog extends StatefulWidget {
  final VoidCallback onExtend;
  final VoidCallback onLogout;

  const SessionTimeoutWarningDialog({
    super.key,
    required this.onExtend,
    required this.onLogout,
  });

  /// 다이얼로그 표시
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onExtend,
    required VoidCallback onLogout,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionTimeoutWarningDialog(
        onExtend: onExtend,
        onLogout: onLogout,
      ),
    );
  }

  @override
  State<SessionTimeoutWarningDialog> createState() =>
      _SessionTimeoutWarningDialogState();
}

class _SessionTimeoutWarningDialogState
    extends State<SessionTimeoutWarningDialog> {
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = SessionConfig.warningBeforeTimeout.inSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        Navigator.of(context).pop();
        widget.onLogout();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThemeColor.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timer_outlined,
                size: 40,
                color: ThemeColor.warning,
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              '세션 만료 예정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 메시지
            Text(
              '보안을 위해 일정 시간 동안 활동이 없으면\n자동으로 로그아웃됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // 카운트다운
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: ThemeColor.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    color: ThemeColor.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_remainingSeconds초 후 로그아웃',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ThemeColor.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onLogout();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '로그아웃',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onExtend();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColor.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '연장하기',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 재인증 다이얼로그
///
/// 생체 인증 또는 비밀번호로 세션을 재인증합니다.
class ReauthenticationDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final VoidCallback onLogout;

  const ReauthenticationDialog({
    super.key,
    required this.onSuccess,
    required this.onCancel,
    required this.onLogout,
  });

  /// 다이얼로그 표시
  static Future<bool?> show(
    BuildContext context, {
    required VoidCallback onSuccess,
    required VoidCallback onCancel,
    required VoidCallback onLogout,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReauthenticationDialog(
        onSuccess: onSuccess,
        onCancel: onCancel,
        onLogout: onLogout,
      ),
    );
  }

  @override
  State<ReauthenticationDialog> createState() => _ReauthenticationDialogState();
}

class _ReauthenticationDialogState extends State<ReauthenticationDialog> {
  bool _isAuthenticating = false;
  String? _errorMessage;
  int _attemptCount = 0;
  bool _hasBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final localAuth = LocalAuthentication();
    final available = await localAuth.canCheckBiometrics;
    setState(() {
      _hasBiometrics = available;
    });

    // 생체 인증 가능하면 자동 시작
    if (available) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final success = await SessionManager.instance.reauthenticateWithBiometrics();

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(true);
          widget.onSuccess();
        }
      } else {
        _attemptCount++;
        setState(() {
          _isAuthenticating = false;
          _errorMessage = '인증에 실패했습니다. ($_attemptCount/${SessionConfig.maxReauthAttempts})';
        });

        if (_attemptCount >= SessionConfig.maxReauthAttempts) {
          if (mounted) {
            Navigator.of(context).pop(false);
            widget.onLogout();
          }
        }
      }
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
        _errorMessage = '인증 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThemeColor.primaryPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _isAuthenticating
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: ThemeColor.primaryPurple,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      Icons.fingerprint,
                      size: 40,
                      color: ThemeColor.primaryPurple,
                    ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              '재인증 필요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 메시지
            Text(
              _isAuthenticating
                  ? '인증 중입니다...'
                  : '세션이 만료되었습니다.\n계속하려면 다시 인증해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),

            // 에러 메시지
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 버튼들
            if (!_isAuthenticating) ...[
              if (_hasBiometrics)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('생체 인증'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColor.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        widget.onCancel();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        widget.onLogout();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '로그아웃',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 세션 잠금 화면
///
/// 재인증 실패 횟수 초과 시 표시되는 잠금 화면입니다.
class SessionLockedScreen extends StatefulWidget {
  final Duration lockDuration;
  final VoidCallback onUnlocked;
  final VoidCallback onLogout;

  const SessionLockedScreen({
    super.key,
    required this.lockDuration,
    required this.onUnlocked,
    required this.onLogout,
  });

  @override
  State<SessionLockedScreen> createState() => _SessionLockedScreenState();
}

class _SessionLockedScreenState extends State<SessionLockedScreen> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.lockDuration.inSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        widget.onUnlocked();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 50,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                '계정 잠금',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                '인증 시도 횟수를 초과했습니다.\n잠시 후 다시 시도해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // 남은 시간
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '남은 시간',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onLogout,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
