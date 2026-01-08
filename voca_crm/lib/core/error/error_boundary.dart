import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:voca_crm/core/utils/app_error_reporter.dart';
import 'package:voca_crm/domain/entity/error_log.dart';

import 'app_exception.dart';
import 'exception_parser.dart';

/// 글로벌 에러 핸들러 설정
///
/// Firebase Crashlytics와 자체 서버(AppErrorReporter)에 에러를 동시에 보고합니다.
/// 인증 에러, 네트워크 에러를 자동으로 감지하고 적절한 콜백을 호출합니다.
///
/// 사용 예:
/// ```dart
/// void main() {
///   runZonedGuarded(() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     await Firebase.initializeApp();
///
///     GlobalErrorHandler.instance.initialize(
///       onAuthenticationFailed: () => navigateToLogin(),
///     );
///
///     runApp(MyApp());
///   }, GlobalErrorHandler.instance.handleZoneError);
/// }
/// ```
class GlobalErrorHandler {
  static GlobalErrorHandler? _instance;
  static GlobalErrorHandler get instance => _instance ??= GlobalErrorHandler._();

  GlobalErrorHandler._();

  /// 인증 실패 콜백 (로그인 화면 이동 등)
  VoidCallback? onAuthenticationFailed;

  /// 네트워크 에러 콜백
  void Function(AppException error)? onNetworkError;

  /// 추가 에러 리포팅 콜백 (선택적)
  void Function(AppException error, StackTrace? stackTrace)? onAdditionalReport;

  /// 초기화 여부
  bool _initialized = false;

  /// 초기화
  ///
  /// 앱 시작 시 main()에서 호출합니다.
  /// Firebase 초기화 이후에 호출해야 합니다.
  void initialize({
    VoidCallback? onAuthenticationFailed,
    void Function(AppException error)? onNetworkError,
    void Function(AppException error, StackTrace? stackTrace)? onAdditionalReport,
  }) {
    if (_initialized) {
      if (kDebugMode) {
        debugPrint('[GlobalErrorHandler] Already initialized');
      }
      return;
    }

    this.onAuthenticationFailed = onAuthenticationFailed;
    this.onNetworkError = onNetworkError;
    this.onAdditionalReport = onAdditionalReport;

    // Flutter 에러 핸들러 설정
    FlutterError.onError = _handleFlutterError;

    // 플랫폼 디스패처 에러 핸들러 설정
    PlatformDispatcher.instance.onError = _handlePlatformError;

    _initialized = true;
    if (kDebugMode) {
      debugPrint('[GlobalErrorHandler] Initialized');
    }
  }

  /// Flutter 프레임워크 에러 처리
  void _handleFlutterError(FlutterErrorDetails details) {
    final error = ExceptionParser.fromException(
      details.exception,
      details.stack,
    );

    // 에러 리포팅
    _reportError(
      error: error,
      originalError: details.exception,
      stackTrace: details.stack,
      screenName: 'FlutterError',
      action: 'Framework Error',
      isFatal: true,
    );

    // 디버그 모드에서는 콘솔에 출력
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// 플랫폼 레벨 에러 처리 (Dart 비동기 에러 등)
  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    final appError = ExceptionParser.fromException(error, stackTrace);

    // 에러 리포팅
    _reportError(
      error: appError,
      originalError: error,
      stackTrace: stackTrace,
      screenName: 'PlatformError',
      action: 'Uncaught Error',
      isFatal: true,
    );

    // true를 반환하면 에러가 처리되었음을 의미
    return true;
  }

  /// 에러 리포팅 (Firebase Crashlytics + AppErrorReporter)
  void _reportError({
    required AppException error,
    required Object originalError,
    StackTrace? stackTrace,
    required String screenName,
    required String action,
    bool isFatal = false,
  }) {
    // 1. Firebase Crashlytics로 전송 (프로덕션 모드에서만)
    if (!kDebugMode) {
      if (isFatal) {
        FirebaseCrashlytics.instance.recordError(
          originalError,
          stackTrace,
          fatal: true,
        );
      } else {
        FirebaseCrashlytics.instance.recordError(
          originalError,
          stackTrace,
          fatal: false,
        );
      }
    }

    // 2. 자체 서버로 전송
    final severity = isFatal ? ErrorSeverity.critical : ErrorSeverity.error;
    AppErrorReporter.report(
      screenName: screenName,
      action: action,
      error: originalError,
      stackTrace: stackTrace,
      severity: severity,
    );

    // 3. 추가 콜백 호출
    onAdditionalReport?.call(error, stackTrace);

    // 4. 에러 유형별 처리
    _handleErrorByType(error);
  }

  /// 에러 유형별 처리
  void _handleErrorByType(AppException error) {
    // 인증 필요 에러
    if (error.requiresLogin) {
      onAuthenticationFailed?.call();
    }

    // 네트워크 에러
    if (error is NetworkException) {
      onNetworkError?.call(error);
    }
  }

  /// 수동 에러 핸들링
  ///
  /// 코드에서 직접 에러를 처리할 때 사용합니다.
  void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    String? screenName,
    String? action,
    bool report = true,
    bool isFatal = false,
  }) {
    final appError = error is AppException
        ? error
        : ExceptionParser.fromException(error, stackTrace);

    // 로깅
    ErrorLogger.log(appError, context: context);

    // 에러 리포팅
    if (report) {
      _reportError(
        error: appError,
        originalError: error,
        stackTrace: stackTrace,
        screenName: screenName ?? context ?? 'Unknown',
        action: action ?? 'Error',
        isFatal: isFatal,
      );
    } else {
      // 리포팅 없이 유형별 처리만
      _handleErrorByType(appError);
    }
  }

  /// Zone에서 에러 캐치
  ///
  /// main()에서 runZonedGuarded와 함께 사용합니다.
  ///
  /// ```dart
  /// void main() {
  ///   runZonedGuarded(() async {
  ///     GlobalErrorHandler.instance.initialize();
  ///     runApp(MyApp());
  ///   }, GlobalErrorHandler.instance.handleZoneError);
  /// }
  /// ```
  void handleZoneError(Object error, StackTrace stackTrace) {
    final appError = ExceptionParser.fromException(error, stackTrace);

    _reportError(
      error: appError,
      originalError: error,
      stackTrace: stackTrace,
      screenName: 'ZoneError',
      action: 'Uncaught Zone Error',
      isFatal: true,
    );
  }

  /// 인스턴스 리셋 (테스트용)
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }
}

/// 에러 바운더리 위젯
///
/// 자식 위젯에서 발생하는 에러를 캡처하고 대체 UI를 표시합니다.
///
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   onError: (error) => ErrorLogger.log(error),
///   fallback: (error, reset) => ErrorFallbackWidget(
///     error: error,
///     onRetry: reset,
///   ),
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(AppException error, VoidCallback reset)? fallback;
  final void Function(AppException error)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppException? _error;

  @override
  void initState() {
    super.initState();
  }

  void _reset() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback?.call(_error!, _reset) ??
          _DefaultErrorFallback(error: _error!, onReset: _reset);
    }

    return widget.child;
  }
}

/// 기본 에러 대체 UI
class _DefaultErrorFallback extends StatelessWidget {
  final AppException error;
  final VoidCallback onReset;

  const _DefaultErrorFallback({
    required this.error,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '오류가 발생했습니다',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.userMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 비동기 에러 바운더리
///
/// Future 실행 중 발생하는 에러를 처리합니다.
class AsyncErrorBoundary extends StatefulWidget {
  final Future<Widget> Function() builder;
  final Widget loading;
  final Widget Function(AppException error, VoidCallback retry)? errorBuilder;

  const AsyncErrorBoundary({
    super.key,
    required this.builder,
    this.loading = const Center(child: CircularProgressIndicator()),
    this.errorBuilder,
  });

  @override
  State<AsyncErrorBoundary> createState() => _AsyncErrorBoundaryState();
}

class _AsyncErrorBoundaryState extends State<AsyncErrorBoundary> {
  late Future<Widget> _future;

  @override
  void initState() {
    super.initState();
    _loadWidget();
  }

  void _loadWidget() {
    _future = widget.builder();
  }

  void _retry() {
    setState(() {
      _loadWidget();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loading;
        }

        if (snapshot.hasError) {
          final error = ExceptionParser.fromException(
            snapshot.error,
            snapshot.stackTrace,
          );

          return widget.errorBuilder?.call(error, _retry) ??
              _DefaultErrorFallback(error: error, onReset: _retry);
        }

        return snapshot.data ?? const SizedBox.shrink();
      },
    );
  }
}
