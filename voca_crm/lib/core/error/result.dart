import 'app_exception.dart';

/// 함수형 에러 처리를 위한 Result 패턴
///
/// 성공(Success) 또는 실패(Failure)를 명시적으로 표현합니다.
/// try-catch 대신 사용하여 에러 처리를 강제합니다.
///
/// 사용 예:
/// ```dart
/// Future<Result<Member>> getMember(String id) async {
///   try {
///     final member = await api.getMember(id);
///     return Success(member);
///   } catch (e) {
///     return Failure(NotFoundException(message: '회원을 찾을 수 없습니다'));
///   }
/// }
///
/// final result = await getMember('123');
/// result.when(
///   success: (member) => print('회원: ${member.name}'),
///   failure: (error) => print('에러: ${error.userMessage}'),
/// );
/// ```
sealed class Result<T> {
  const Result();

  /// 성공 여부
  bool get isSuccess => this is Success<T>;

  /// 실패 여부
  bool get isFailure => this is Failure<T>;

  /// 성공 시 값 반환, 실패 시 null
  T? get valueOrNull {
    if (this is Success<T>) {
      return (this as Success<T>).value;
    }
    return null;
  }

  /// 실패 시 에러 반환, 성공 시 null
  AppException? get errorOrNull {
    if (this is Failure<T>) {
      return (this as Failure<T>).error;
    }
    return null;
  }

  /// 성공 시 값 반환, 실패 시 기본값
  T getOrElse(T defaultValue) {
    if (this is Success<T>) {
      return (this as Success<T>).value;
    }
    return defaultValue;
  }

  /// 성공 시 값 반환, 실패 시 함수 실행 결과
  T getOrElseDo(T Function(AppException error) onError) {
    if (this is Success<T>) {
      return (this as Success<T>).value;
    }
    return onError((this as Failure<T>).error);
  }

  /// 성공 시 값 반환, 실패 시 예외 throw
  T getOrThrow() {
    if (this is Success<T>) {
      return (this as Success<T>).value;
    }
    throw (this as Failure<T>).error;
  }

  /// 패턴 매칭 (필수 처리)
  R when<R>({
    required R Function(T value) success,
    required R Function(AppException error) failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).value);
    }
    return failure((this as Failure<T>).error);
  }

  /// 패턴 매칭 (선택적 처리)
  R? whenOrNull<R>({
    R Function(T value)? success,
    R Function(AppException error)? failure,
  }) {
    if (this is Success<T> && success != null) {
      return success((this as Success<T>).value);
    }
    if (this is Failure<T> && failure != null) {
      return failure((this as Failure<T>).error);
    }
    return null;
  }

  /// 성공 시에만 실행
  Result<T> onSuccess(void Function(T value) action) {
    if (this is Success<T>) {
      action((this as Success<T>).value);
    }
    return this;
  }

  /// 실패 시에만 실행
  Result<T> onFailure(void Function(AppException error) action) {
    if (this is Failure<T>) {
      action((this as Failure<T>).error);
    }
    return this;
  }

  /// 값 변환 (성공 시만)
  Result<R> map<R>(R Function(T value) transform) {
    if (this is Success<T>) {
      return Success(transform((this as Success<T>).value));
    }
    return Failure((this as Failure<T>).error);
  }

  /// 비동기 값 변환 (성공 시만)
  Future<Result<R>> mapAsync<R>(Future<R> Function(T value) transform) async {
    if (this is Success<T>) {
      final newValue = await transform((this as Success<T>).value);
      return Success(newValue);
    }
    return Failure((this as Failure<T>).error);
  }

  /// Result 체이닝 (성공 시만)
  Result<R> flatMap<R>(Result<R> Function(T value) transform) {
    if (this is Success<T>) {
      return transform((this as Success<T>).value);
    }
    return Failure((this as Failure<T>).error);
  }

  /// 비동기 Result 체이닝 (성공 시만)
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T value) transform,
  ) async {
    if (this is Success<T>) {
      return transform((this as Success<T>).value);
    }
    return Failure((this as Failure<T>).error);
  }

  /// 에러 변환 (실패 시만)
  Result<T> mapError(AppException Function(AppException error) transform) {
    if (this is Failure<T>) {
      return Failure(transform((this as Failure<T>).error));
    }
    return this;
  }

  /// 에러 복구 시도 (실패 시만)
  Result<T> recover(Result<T> Function(AppException error) recovery) {
    if (this is Failure<T>) {
      return recovery((this as Failure<T>).error);
    }
    return this;
  }

  /// 비동기 에러 복구 시도 (실패 시만)
  Future<Result<T>> recoverAsync(
    Future<Result<T>> Function(AppException error) recovery,
  ) async {
    if (this is Failure<T>) {
      return recovery((this as Failure<T>).error);
    }
    return this;
  }
}

/// 성공 결과
class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Success<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// 실패 결과
class Failure<T> extends Result<T> {
  final AppException error;

  const Failure(this.error);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure<T> && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure(${error.message})';
}

// ============================================================
// Result 유틸리티 함수
// ============================================================

/// try-catch를 Result로 변환
Future<Result<T>> runCatching<T>(Future<T> Function() action) async {
  try {
    final value = await action();
    return Success(value);
  } on AppException catch (e) {
    return Failure(e);
  } catch (e, stackTrace) {
    return Failure(UnknownException(
      message: e.toString(),
      originalError: e,
      stackTrace: stackTrace,
    ));
  }
}

/// 동기 try-catch를 Result로 변환
Result<T> runCatchingSync<T>(T Function() action) {
  try {
    final value = action();
    return Success(value);
  } on AppException catch (e) {
    return Failure(e);
  } catch (e, stackTrace) {
    return Failure(UnknownException(
      message: e.toString(),
      originalError: e,
      stackTrace: stackTrace,
    ));
  }
}

/// 여러 Result를 결합
Result<List<T>> combineResults<T>(List<Result<T>> results) {
  final values = <T>[];

  for (final result in results) {
    if (result is Failure<T>) {
      return Failure(result.error);
    }
    values.add((result as Success<T>).value);
  }

  return Success(values);
}

/// 여러 Result 중 첫 번째 성공 반환
Result<T> firstSuccess<T>(List<Result<T>> results) {
  AppException? lastError;

  for (final result in results) {
    if (result is Success<T>) {
      return result;
    }
    lastError = (result as Failure<T>).error;
  }

  return Failure(lastError ?? const UnknownException());
}

// ============================================================
// Result Extension
// ============================================================

extension FutureResultExtension<T> on Future<Result<T>> {
  /// 성공 시에만 실행 (비동기)
  Future<Result<T>> onSuccessAsync(
    Future<void> Function(T value) action,
  ) async {
    final result = await this;
    if (result is Success<T>) {
      await action(result.value);
    }
    return result;
  }

  /// 실패 시에만 실행 (비동기)
  Future<Result<T>> onFailureAsync(
    Future<void> Function(AppException error) action,
  ) async {
    final result = await this;
    if (result is Failure<T>) {
      await action(result.error);
    }
    return result;
  }
}

extension ResultListExtension<T> on List<Result<T>> {
  /// 모든 성공 값만 추출
  List<T> get successValues {
    return whereType<Success<T>>().map((s) => s.value).toList();
  }

  /// 모든 실패 에러만 추출
  List<AppException> get failureErrors {
    return whereType<Failure<T>>().map((f) => f.error).toList();
  }

  /// 성공 개수
  int get successCount => whereType<Success<T>>().length;

  /// 실패 개수
  int get failureCount => whereType<Failure<T>>().length;

  /// 모두 성공 여부
  bool get allSuccess => every((r) => r.isSuccess);

  /// 모두 실패 여부
  bool get allFailure => every((r) => r.isFailure);
}
