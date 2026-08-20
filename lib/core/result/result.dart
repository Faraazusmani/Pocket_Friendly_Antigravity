import '../errors/failures.dart';

/// A functional utility for returning either a success value or a Failure.
abstract class Result<S, F extends Failure> {
  const Result();

  /// Folds the result into a single value by executing the appropriate callback.
  R fold<R>(R Function(S success) onSuccess, R Function(F failure) onFailure);

  /// Helper getters to check status.
  bool get isSuccess => fold((_) => true, (_) => false);
  bool get isFailure => fold((_) => false, (_) => true);

  /// Retrieve values safely.
  S? get successOrNull => fold((success) => success, (_) => null);
  F? get failureOrNull => fold((_) => null, (failure) => failure);
}

/// Represents a successful computation.
class Success<S, F extends Failure> extends Result<S, F> {
  final S value;

  const Success(this.value);

  @override
  R fold<R>(R Function(S success) onSuccess, R Function(F failure) onFailure) {
    return onSuccess(value);
  }
}

/// Represents a failed computation.
class FailureResult<S, F extends Failure> extends Result<S, F> {
  final F failure;

  const FailureResult(this.failure);

  @override
  R fold<R>(R Function(S success) onSuccess, R Function(F failure) onFailure) {
    return onFailure(failure);
  }
}
