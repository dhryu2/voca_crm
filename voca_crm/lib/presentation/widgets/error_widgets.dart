import 'package:flutter/material.dart';
import 'package:voca_crm/core/error/app_exception.dart';
import 'package:voca_crm/core/theme/theme_color.dart';

/// 에러 타입별 아이콘 및 색상
class _ErrorStyle {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _ErrorStyle({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  static _ErrorStyle fromException(AppException error) {
    if (error is NoInternetException) {
      return _ErrorStyle(
        icon: Icons.wifi_off_rounded,
        color: ThemeColor.warning,
        backgroundColor: ThemeColor.warningSurface,
      );
    }

    if (error is NetworkException) {
      return _ErrorStyle(
        icon: Icons.cloud_off_rounded,
        color: ThemeColor.error,
        backgroundColor: ThemeColor.errorSurface,
      );
    }

    if (error is UnauthorizedException || error is TokenExpiredException) {
      return _ErrorStyle(
        icon: Icons.lock_outline_rounded,
        color: ThemeColor.warning,
        backgroundColor: ThemeColor.warningSurface,
      );
    }

    if (error is ForbiddenException) {
      return _ErrorStyle(
        icon: Icons.block_rounded,
        color: ThemeColor.error,
        backgroundColor: ThemeColor.errorSurface,
      );
    }

    if (error is NotFoundException) {
      return _ErrorStyle(
        icon: Icons.search_off_rounded,
        color: ThemeColor.info,
        backgroundColor: ThemeColor.infoSurface,
      );
    }

    if (error is RateLimitException) {
      return _ErrorStyle(
        icon: Icons.speed_rounded,
        color: ThemeColor.warning,
        backgroundColor: ThemeColor.warningSurface,
      );
    }

    if (error is ServerException || error is ServiceUnavailableException) {
      return _ErrorStyle(
        icon: Icons.dns_rounded,
        color: ThemeColor.error,
        backgroundColor: ThemeColor.errorSurface,
      );
    }

    if (error is ValidationException || error is BadRequestException) {
      return _ErrorStyle(
        icon: Icons.warning_amber_rounded,
        color: ThemeColor.warning,
        backgroundColor: ThemeColor.warningSurface,
      );
    }

    return _ErrorStyle(
      icon: Icons.error_outline_rounded,
      color: ThemeColor.error,
      backgroundColor: ThemeColor.errorSurface,
    );
  }
}

/// 전체 화면 에러 표시 위젯
///
/// 화면 전체를 차지하는 에러 표시에 사용합니다.
class FullScreenErrorWidget extends StatelessWidget {
  final AppException error;
  final VoidCallback? onRetry;
  final String? retryText;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionText;

  const FullScreenErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.retryText,
    this.onSecondaryAction,
    this.secondaryActionText,
  });

  @override
  Widget build(BuildContext context) {
    final style = _ErrorStyle.fromException(error);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: style.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                style.icon,
                size: 48,
                color: style.color,
              ),
            ),
            const SizedBox(height: 24),

            // 제목
            Text(
              _getTitle(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ThemeColor.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // 메시지
            Text(
              error.userMessage,
              style: TextStyle(
                fontSize: 15,
                color: ThemeColor.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // 에러 코드 (디버그 모드에서만)
            if (error.code != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${error.code}',
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeColor.textTertiary,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 재시도 버튼
            if (onRetry != null) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(retryText ?? '다시 시도'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: style.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            // 보조 액션 버튼
            if (onSecondaryAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(
                  secondaryActionText ?? '뒤로 가기',
                  style: TextStyle(
                    color: ThemeColor.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    if (error is NoInternetException) return '인터넷 연결 없음';
    if (error is NetworkException) return '네트워크 오류';
    if (error is UnauthorizedException) return '로그인 필요';
    if (error is ForbiddenException) return '접근 권한 없음';
    if (error is NotFoundException) return '찾을 수 없음';
    if (error is RateLimitException) return '요청 제한';
    if (error is ServerException) return '서버 오류';
    if (error is ValidationException) return '입력 오류';
    return '오류 발생';
  }
}

/// 인라인 에러 표시 위젯
///
/// 컨텐츠 내부에 작게 표시되는 에러 메시지입니다.
class InlineErrorWidget extends StatelessWidget {
  final AppException error;
  final VoidCallback? onRetry;
  final bool compact;

  const InlineErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = _ErrorStyle.fromException(error);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 16, color: style.color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                error.userMessage,
                style: TextStyle(fontSize: 13, color: style.color),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRetry,
                child: Icon(Icons.refresh, size: 16, color: style.color),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(style.icon, size: 24, color: style.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.userMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: style.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (error.isRetryable && onRetry != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onRetry,
                    child: Text(
                      '다시 시도',
                      style: TextStyle(
                        fontSize: 13,
                        color: style.color,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 에러 스낵바 위젯
///
/// 화면 하단에 잠시 표시되는 에러 메시지입니다.
class ErrorSnackBarContent extends StatelessWidget {
  final AppException error;
  final VoidCallback? onRetry;

  const ErrorSnackBarContent({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final style = _ErrorStyle.fromException(error);

    return Row(
      children: [
        Icon(style.icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            error.userMessage,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        if (error.isRetryable && onRetry != null)
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              onRetry?.call();
            },
            child: const Text(
              '재시도',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  /// 에러 스낵바 표시
  static void show(
    BuildContext context, {
    required AppException error,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final style = _ErrorStyle.fromException(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ErrorSnackBarContent(error: error, onRetry: onRetry),
        backgroundColor: style.color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// 네트워크 상태 배너
///
/// 네트워크 연결이 끊겼을 때 화면 상단에 표시되는 배너입니다.
class NetworkStatusBanner extends StatelessWidget {
  final bool isOffline;
  final VoidCallback? onRetry;

  const NetworkStatusBanner({
    super.key,
    required this.isOffline,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: ThemeColor.warning,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '인터넷 연결이 끊겼습니다',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null)
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '재연결',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 빈 상태 위젯
///
/// 데이터가 없을 때 표시되는 위젯입니다.
class EmptyDataWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyDataWidget({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    this.message,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThemeColor.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: ThemeColor.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ThemeColor.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeColor.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColor.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 로딩 중 에러 표시 (리스트 아이템용)
class ListItemErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ListItemErrorWidget({
    super.key,
    this.message = '데이터를 불러올 수 없습니다',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: ThemeColor.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ThemeColor.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('재시도'),
            ),
        ],
      ),
    );
  }
}
