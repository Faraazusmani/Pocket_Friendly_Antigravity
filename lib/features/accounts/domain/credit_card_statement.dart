import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

class CreditCardStatement {
  final String id;
  final String profileId;
  final String accountId;
  final String statementCycle; // e.g. "2026-08"
  final DateTime statementPeriodStart;
  final DateTime statementPeriodEnd;
  final int outstandingAmount; // minor units
  final bool isSettled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditCardStatement({
    required this.id,
    required this.profileId,
    required this.accountId,
    required this.statementCycle,
    required this.statementPeriodStart,
    required this.statementPeriodEnd,
    required this.outstandingAmount,
    required this.isSettled,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory method to enforce "Always Valid" CreditCardStatement values.
  static Result<CreditCardStatement, ValidationFailure> create({
    required String id,
    required String profileId,
    required String accountId,
    required String statementCycle,
    required DateTime statementPeriodStart,
    required DateTime statementPeriodEnd,
    required int outstandingAmount,
    required bool isSettled,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Statement ID cannot be empty'),
      );
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (accountId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Account ID cannot be empty'),
      );
    }
    if (statementCycle.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Statement cycle cannot be empty'),
      );
    }
    if (statementPeriodStart.isAfter(statementPeriodEnd)) {
      return const FailureResult(
        ValidationFailure(
          'Statement period start must be before or equal to end',
        ),
      );
    }
    if (outstandingAmount < 0) {
      return const FailureResult(
        ValidationFailure('Statement outstanding amount cannot be negative'),
      );
    }

    return Success(
      CreditCardStatement(
        id: id,
        profileId: profileId,
        accountId: accountId,
        statementCycle: statementCycle.trim(),
        statementPeriodStart: statementPeriodStart,
        statementPeriodEnd: statementPeriodEnd,
        outstandingAmount: outstandingAmount,
        isSettled: isSettled,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'accountId': accountId,
    'statementCycle': statementCycle,
    'statementPeriodStart': statementPeriodStart.toIso8601String(),
    'statementPeriodEnd': statementPeriodEnd.toIso8601String(),
    'outstandingAmount': outstandingAmount,
    'isSettled': isSettled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CreditCardStatement.fromJson(Map<String, dynamic> json) =>
      CreditCardStatement(
        id: json['id'] as String,
        profileId: json['profileId'] as String,
        accountId: json['accountId'] as String,
        statementCycle: json['statementCycle'] as String,
        statementPeriodStart: DateTime.parse(
          json['statementPeriodStart'] as String,
        ),
        statementPeriodEnd: DateTime.parse(
          json['statementPeriodEnd'] as String,
        ),
        outstandingAmount: json['outstandingAmount'] as int,
        isSettled: json['isSettled'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
