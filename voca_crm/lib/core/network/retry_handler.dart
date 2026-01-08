import 'dart:async';
import 'dart:math';

import '../error/app_exception.dart';
import 'network_monitor.dart';

/// 재시도 설정
class RetryConfig {
  /// 최대 재시도 횟수
  final int maxRetries;

  /// 초기 지연 시간
  final Duration initialDelay;

  /// 최대 지연 시간
  final Duration maxDelay;

  /// 지연 시간 증가 배수
  final double multiplier;

  /// 지터(무작위성) 추가 여부
  final bool addJitter;

  /// 재시도 가능 여부 판단 함수
  final bool Function(AppException)? shouldRetry;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.addJitter = true,
    this.shouldRetry,
  });

  /// 기본 설정
  static const standard = RetryConfig();

  /// 공격적인 재시도 (더 많은 재시도, 짧은 지연)
  static const aggressive = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 10),
  );

  /// 보수적인 재시도 (적은 재시도, 긴 지연)
  static const conservative = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 60),
  );

  /// 재시도 없음
  static const none = RetryConfig(maxRetries: 0);
}

/// 재시도 상태
class RetryState {
  final int attempt;
  final int maxAttempts;
  final Duration? nextDelay;
  final AppException? lastError;

  const RetryState({
    required this.attempt,
    required this.maxAttempts,
    this.nextDelay,
    this.lastError,
  });

  bool get isFirstAttempt => attempt == 1;
  bool get isLastAttempt => attempt >= maxAttempts;
  bool get hasMoreAttempts => attempt < maxAttempts;
  double get progress => attempt / maxAttempts;

  @override
  String toString() => 'RetryState(attempt: $attempt/$maxAttempts)';
}

/// 재시도 핸들러
///
/// Exponential Backoff 알고리즘을 사용하여 실패한 작업을 재시도합니다.
///
/// 사용 예:
/// ```dart
/// final result = await RetryHandler.execute(
///   () => api.fetchData(),
///   config: RetryConfig.standard,
///   onRetry: (state) => print('재시도 ${state.attempt}/${state.maxAttempts}'),
/// );
/// ```
class RetryHandler {
  static final Random _random = Random();

  const RetryHandler._();

  /// 재시도 로직으로 작업 실행
  ///
  /// [action] 실행할 비동기 작업
  /// [config] 재시도 설정
  /// [onRetry] 재시도 시 콜백
  /// [onError] 에러 발생 시 콜백
  static Future<T> execute<T>(
    Future<T> Function() action, {
    RetryConfig config = RetryConfig.standard,
    void Function(RetryState state)? onRetry,
    void Function(AppException error)? onError,
  }) async {
    int attempt = 0;
    Duration delay = config.initialDelay;

    while (true) {
      attempt++;

      try {
        return await action();
      } catch (e, stackTrace) {
        // AppException으로 변환
        final error = e is AppException
            ? e
            : UnknownException(
                message: e.toString(),
                originalError: e,
                stackTrace: stackTrace,
              );

        onError?.call(error);

        // 재시도 가능 여부 확인
        final canRetry = _shouldRetry(error, config, attempt);

        if (!canRetry) {
          throw error;
        }

        // 재시도 콜백 호출
        onRetry?.call(RetryState(
          attempt: attempt,
          maxAttempts: config.maxRetries + 1,
          nextDelay: delay,
          lastError: error,
        ));

        // 지연 후 재시도
        await Future.delayed(delay);

        // 다음 지연 시간 계산 (Exponential Backoff)
        delay = _calculateNextDelay(delay, config);
      }
    }
  }

  /// 재시도 가능 여부 판단
  static bool _shouldRetry(
    AppException error,
    RetryConfig config,
    int attempt,
  ) {
    // 최대 재시도 횟수 초과
    if (attempt > config.maxRetries) {
      return false;
    }

    // 사용자 정의 재시도 조건
    if (config.shouldRetry != null) {
      return config.shouldRetry!(error);
    }

    // 기본 재시도 조건: 재시도 가능한 에러인 경우
    return error.isRetryable;
  }

  /// 다음 지연 시간 계산 (Exponential Backoff with Jitter)
  static Duration _calculateNextDelay(Duration current, RetryConfig config) {
    // 기본 증가
    var nextMs = (current.inMilliseconds * config.multiplier).toInt();

    // 최대 지연 시간 제한
    nextMs = min(nextMs, config.maxDelay.inMilliseconds);

    // 지터 추가 (±25%)
    if (config.addJitter) {
      final jitter = nextMs * 0.25;
      nextMs = (nextMs + (_random.nextDouble() * jitter * 2) - jitter).toInt();
    }

    return Duration(milliseconds: max(nextMs, 0));
  }

  /// 네트워크 연결 대기 후 실행
  ///
  /// 네트워크가 연결될 때까지 대기한 후 작업을 실행합니다.
  static Future<T> executeWhenOnline<T>(
    Future<T> Function() action, {
    RetryConfig config = RetryConfig.standard,
    Duration networkTimeout = const Duration(seconds: 30),
    void Function(RetryState state)? onRetry,
    void Function()? onWaitingForNetwork,
  }) async {
    // 네트워크 연결 확인
    final networkMonitor = NetworkMonitor.instance;

    if (!networkMonitor.isConnected) {
      onWaitingForNetwork?.call();

      final connected = await networkMonitor.waitForConnection(
        timeout: networkTimeout,
      );

      if (!connected) {
        throw const NoInternetException();
      }
    }

    // 네트워크 연결됨 - 작업 실행
    return execute(
      action,
      config: config,
      onRetry: onRetry,
    );
  }

  /// 점진적 재시도 (각 시도 사이에 콜백 실행)
  ///
  /// 각 재시도 전에 사용자에게 상태를 알리고 싶을 때 사용합니다.
  static Future<T> executeWithProgress<T>(
    Future<T> Function() action, {
    required void Function(RetryState state) onProgress,
    RetryConfig config = RetryConfig.standard,
  }) async {
    int attempt = 0;
    Duration delay = config.initialDelay;

    // 첫 시도 알림
    onProgress(RetryState(
      attempt: 1,
      maxAttempts: config.maxRetries + 1,
    ));

    while (true) {
      attempt++;

      try {
        return await action();
      } catch (e, stackTrace) {
        final error = e is AppException
            ? e
            : UnknownException(
                message: e.toString(),
                originalError: e,
                stackTrace: stackTrace,
              );

        if (!_shouldRetry(error, config, attempt)) {
          throw error;
        }

        // 진행 상태 알림
        onProgress(RetryState(
          attempt: attempt + 1,
          maxAttempts: config.maxRetries + 1,
          nextDelay: delay,
          lastError: error,
        ));

        await Future.delayed(delay);
        delay = _calculateNextDelay(delay, config);
      }
    }
  }
}

/// 재시도 가능한 작업을 위한 믹스인
mixin RetryableMixin {
  /// 재시도 설정
  RetryConfig get retryConfig => RetryConfig.standard;

  /// 재시도로 작업 실행
  Future<T> withRetry<T>(
    Future<T> Function() action, {
    void Function(RetryState state)? onRetry,
  }) {
    return RetryHandler.execute(
      action,
      config: retryConfig,
      onRetry: onRetry,
    );
  }
}
