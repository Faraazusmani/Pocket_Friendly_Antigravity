import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

enum RecurringFrequency { daily, weekly, monthly, yearly }

enum RecurringMode { reminder, automaticRecording }

enum OccurrenceStatus { pending, recorded, skipped, failed }

class RecurringTransactionRule {
  final String id;
  final String profileId;
  final String transactionTemplate; // JSON string representing the template
  final RecurringFrequency frequency;
  final int dayOfPeriod;
  final RecurringMode mode;
  final DateTime nextOccurrence;
  final bool active;
  final String? splitFromRuleId;
  final DateTime? lastExecutedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringTransactionRule({
    required this.id,
    required this.profileId,
    required this.transactionTemplate,
    required this.frequency,
    required this.dayOfPeriod,
    required this.mode,
    required this.nextOccurrence,
    required this.active,
    this.splitFromRuleId,
    this.lastExecutedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static Result<RecurringTransactionRule, ValidationFailure> create({
    required String id,
    required String profileId,
    required String transactionTemplate,
    required RecurringFrequency frequency,
    required int dayOfPeriod,
    required RecurringMode mode,
    required DateTime nextOccurrence,
    required bool active,
    String? splitFromRuleId,
    DateTime? lastExecutedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(ValidationFailure('Rule ID cannot be empty'));
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (transactionTemplate.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Transaction template cannot be empty'),
      );
    }
    if (dayOfPeriod < 1 || dayOfPeriod > 31) {
      return const FailureResult(
        ValidationFailure('Day of period must be between 1 and 31'),
      );
    }

    return Success(
      RecurringTransactionRule(
        id: id,
        profileId: profileId,
        transactionTemplate: transactionTemplate.trim(),
        frequency: frequency,
        dayOfPeriod: dayOfPeriod,
        mode: mode,
        nextOccurrence: nextOccurrence,
        active: active,
        splitFromRuleId: splitFromRuleId,
        lastExecutedAt: lastExecutedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'transactionTemplate': transactionTemplate,
    'frequency': frequency.name,
    'dayOfPeriod': dayOfPeriod,
    'mode': mode.name,
    'nextOccurrence': nextOccurrence.toIso8601String(),
    'active': active,
    'splitFromRuleId': splitFromRuleId,
    'lastExecutedAt': lastExecutedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory RecurringTransactionRule.fromJson(Map<String, dynamic> json) =>
      RecurringTransactionRule(
        id: json['id'] as String,
        profileId: json['profileId'] as String,
        transactionTemplate: json['transactionTemplate'] as String,
        frequency: RecurringFrequency.values.byName(
          json['frequency'] as String,
        ),
        dayOfPeriod: json['dayOfPeriod'] as int,
        mode: RecurringMode.values.byName(json['mode'] as String),
        nextOccurrence: DateTime.parse(json['nextOccurrence'] as String),
        active: json['active'] as bool,
        splitFromRuleId: json['splitFromRuleId'] as String?,
        lastExecutedAt: json['lastExecutedAt'] != null
            ? DateTime.parse(json['lastExecutedAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class RecurringOccurrence {
  final String id;
  final String recurringRuleId;
  final DateTime scheduledOccurrenceDate;
  final OccurrenceStatus status;
  final String? createdTransactionId;
  final DateTime? executedAt;
  final DateTime? skippedAt;
  final DateTime? failedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringOccurrence({
    required this.id,
    required this.recurringRuleId,
    required this.scheduledOccurrenceDate,
    required this.status,
    this.createdTransactionId,
    this.executedAt,
    this.skippedAt,
    this.failedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static Result<RecurringOccurrence, ValidationFailure> create({
    required String id,
    required String recurringRuleId,
    required DateTime scheduledOccurrenceDate,
    required OccurrenceStatus status,
    String? createdTransactionId,
    DateTime? executedAt,
    DateTime? skippedAt,
    DateTime? failedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Occurrence ID cannot be empty'),
      );
    }
    if (recurringRuleId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Recurring rule ID cannot be empty'),
      );
    }

    return Success(
      RecurringOccurrence(
        id: id,
        recurringRuleId: recurringRuleId,
        scheduledOccurrenceDate: scheduledOccurrenceDate,
        status: status,
        createdTransactionId: createdTransactionId,
        executedAt: executedAt,
        skippedAt: skippedAt,
        failedAt: failedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'recurringRuleId': recurringRuleId,
    'scheduledOccurrenceDate': scheduledOccurrenceDate.toIso8601String(),
    'status': status.name,
    'createdTransactionId': createdTransactionId,
    'executedAt': executedAt?.toIso8601String(),
    'skippedAt': skippedAt?.toIso8601String(),
    'failedAt': failedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory RecurringOccurrence.fromJson(Map<String, dynamic> json) =>
      RecurringOccurrence(
        id: json['id'] as String,
        recurringRuleId: json['recurringRuleId'] as String,
        scheduledOccurrenceDate: DateTime.parse(
          json['scheduledOccurrenceDate'] as String,
        ),
        status: OccurrenceStatus.values.byName(json['status'] as String),
        createdTransactionId: json['createdTransactionId'] as String?,
        executedAt: json['executedAt'] != null
            ? DateTime.parse(json['executedAt'] as String)
            : null,
        skippedAt: json['skippedAt'] != null
            ? DateTime.parse(json['skippedAt'] as String)
            : null,
        failedAt: json['failedAt'] != null
            ? DateTime.parse(json['failedAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
