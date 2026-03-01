import 'failures.dart';

/// A discriminated union representing either a successful value [T] or a
/// [Failure].
///
/// Use [Success] to wrap a value and [AppError] to wrap a [Failure].
sealed class Result<T> {
  const Result();

  /// Returns `true` when this result is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Returns `true` when this result is an [AppError].
  bool get isError => this is AppError<T>;
}

/// Represents a successful outcome carrying [data] of type [T].
final class Success<T> extends Result<T> {
  const Success(this.data);

  /// The wrapped successful value.
  final T data;
}

/// Represents a failed outcome carrying a [failure] description.
final class AppError<T> extends Result<T> {
  const AppError(this.failure);

  /// The wrapped [Failure] instance describing the error.
  final Failure failure;
}
