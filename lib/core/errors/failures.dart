import 'package:equatable/equatable.dart';

/// Base class for all domain-level failures in the application.
abstract class Failure extends Equatable {
  final String message;
  final dynamic error;

  const Failure(this.message, [this.error]);

  @override
  List<Object?> get props => [message, error];

  @override
  String toString() => '$runtimeType: $message';
}

/// Represents errors during database operations.
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, [super.error]);
}

/// Represents errors in secure storage or encryption operations.
class SecurityFailure extends Failure {
  const SecurityFailure(super.message, [super.error]);
}

/// Represents validation errors for user inputs or invariants.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.error]);
}

/// Represents failures related to platform integrations (file system, notifications, share, etc).
class PlatformFailure extends Failure {
  const PlatformFailure(super.message, [super.error]);
}

/// Represents failures in recurring transaction automation execution.
class RecurringFailure extends Failure {
  const RecurringFailure(super.message, [super.error]);
}
