import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

class Budget {
  final String id;
  final String profileId;
  final String categoryId;
  final int month; // 1-12
  final int year;
  final int baseAmount; // minor units
  final int carryForwardAmount; // minor units
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.profileId,
    required this.categoryId,
    required this.month,
    required this.year,
    required this.baseAmount,
    required this.carryForwardAmount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory method to enforce "Always Valid" Budget values.
  static Result<Budget, ValidationFailure> create({
    required String id,
    required String profileId,
    required String categoryId,
    required int month,
    required int year,
    required int baseAmount,
    required int carryForwardAmount,
    required String currency,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Budget ID cannot be empty'),
      );
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (categoryId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Category ID cannot be empty'),
      );
    }
    if (month < 1 || month > 12) {
      return const FailureResult(
        ValidationFailure('Month must be between 1 and 12'),
      );
    }
    if (year < 2000 || year > 2100) {
      return const FailureResult(
        ValidationFailure('Year must be between 2000 and 2100'),
      );
    }
    if (baseAmount < 0) {
      return const FailureResult(
        ValidationFailure('Base budget amount cannot be negative'),
      );
    }
    if (carryForwardAmount < 0) {
      return const FailureResult(
        ValidationFailure('Carry-forward budget amount cannot be negative'),
      );
    }
    if (currency.trim().length != 3) {
      return const FailureResult(
        ValidationFailure('Currency must be a 3-letter ISO code'),
      );
    }

    return Success(
      Budget(
        id: id,
        profileId: profileId,
        categoryId: categoryId,
        month: month,
        year: year,
        baseAmount: baseAmount,
        carryForwardAmount: carryForwardAmount,
        currency: currency.trim().toUpperCase(),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  int get totalAmount => baseAmount + carryForwardAmount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'categoryId': categoryId,
    'month': month,
    'year': year,
    'baseAmount': baseAmount,
    'carryForwardAmount': carryForwardAmount,
    'currency': currency,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    categoryId: json['categoryId'] as String,
    month: json['month'] as int,
    year: json['year'] as int,
    baseAmount: json['baseAmount'] as int,
    carryForwardAmount: json['carryForwardAmount'] as int,
    currency: json['currency'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
