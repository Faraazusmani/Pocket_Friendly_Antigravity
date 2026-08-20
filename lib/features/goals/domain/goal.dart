import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

enum GoalType { standard, emi, sip }

enum GoalStatus { active, archived }

class Goal {
  final String id;
  final String profileId;
  final String categoryId; // Linked subcategory 'Goals -> <Goal Name>'
  final GoalType goalType;
  final String name;
  final String icon;
  final int targetAmount; // minor units
  final String currency;
  final DateTime? targetDate;
  final String? description;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Goal({
    required this.id,
    required this.profileId,
    required this.categoryId,
    required this.goalType,
    required this.name,
    required this.icon,
    required this.targetAmount,
    required this.currency,
    this.targetDate,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  /// Factory method to enforce "Always Valid" Goal values.
  static Result<Goal, ValidationFailure> create({
    required String id,
    required String profileId,
    required String categoryId,
    required GoalType goalType,
    required String name,
    required String icon,
    required int targetAmount,
    required String currency,
    DateTime? targetDate,
    String? description,
    required GoalStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(ValidationFailure('Goal ID cannot be empty'));
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (categoryId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Goal category link cannot be empty'),
      );
    }
    if (name.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Goal name cannot be empty'),
      );
    }
    if (icon.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Goal icon cannot be empty'),
      );
    }
    if (targetAmount < 0) {
      return const FailureResult(
        ValidationFailure('Goal target amount cannot be negative'),
      );
    }
    if (currency.trim().length != 3) {
      return const FailureResult(
        ValidationFailure('Currency must be a 3-letter ISO code'),
      );
    }

    return Success(
      Goal(
        id: id,
        profileId: profileId,
        categoryId: categoryId,
        goalType: goalType,
        name: name.trim(),
        icon: icon.trim(),
        targetAmount: targetAmount,
        currency: currency.trim().toUpperCase(),
        targetDate: targetDate,
        description: description?.trim(),
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      ),
    );
  }

  /// Target date projection: default to 1 year from creation if null.
  DateTime get effectiveTargetDate {
    if (targetDate != null) return targetDate!;
    return DateTime(createdAt.year + 1, createdAt.month, createdAt.day);
  }

  /// Verifies if target date has expired relative to a given date.
  bool isExpired(DateTime date) {
    final targetMidnight = DateTime(
      effectiveTargetDate.year,
      effectiveTargetDate.month,
      effectiveTargetDate.day,
    );
    final dateMidnight = DateTime(date.year, date.month, date.day);
    return dateMidnight.isAfter(targetMidnight);
  }

  /// Calculates the required monthly contribution to reach the target amount.
  /// Formula: (targetAmount - currentBalance) / monthsRemaining
  int calculateRequiredMonthlyContribution(int currentBalance, DateTime today) {
    final remainingAmount = targetAmount - currentBalance;
    if (remainingAmount <= 0) return 0;

    final target = effectiveTargetDate;
    final months = (target.year - today.year) * 12 + target.month - today.month;
    if (months <= 0) {
      return remainingAmount;
    }

    // Ceil division to ensure target is reached
    return (remainingAmount + months - 1) ~/ months;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'categoryId': categoryId,
    'goalType': goalType.name,
    'name': name,
    'icon': icon,
    'targetAmount': targetAmount,
    'currency': currency,
    'targetDate': targetDate?.toIso8601String(),
    'description': description,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'archivedAt': archivedAt?.toIso8601String(),
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    categoryId: json['categoryId'] as String,
    goalType: GoalType.values.byName(json['goalType'] as String),
    name: json['name'] as String,
    icon: json['icon'] as String,
    targetAmount: json['targetAmount'] as int,
    currency: json['currency'] as String,
    targetDate: json['targetDate'] != null
        ? DateTime.parse(json['targetDate'] as String)
        : null,
    description: json['description'] as String?,
    status: GoalStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    archivedAt: json['archivedAt'] != null
        ? DateTime.parse(json['archivedAt'] as String)
        : null,
  );
}
