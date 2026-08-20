import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

class UnallocatedBudgetPool {
  final String id;
  final String profileId;
  final int month;
  final int year;
  final int amount; // minor units
  final String currency;
  final int carriedForwardAmount;

  const UnallocatedBudgetPool({
    required this.id,
    required this.profileId,
    required this.month,
    required this.year,
    required this.amount,
    required this.currency,
    this.carriedForwardAmount = 0,
  });

  /// Factory method to enforce "Always Valid" UnallocatedBudgetPool values.
  static Result<UnallocatedBudgetPool, ValidationFailure> create({
    required String id,
    required String profileId,
    required int month,
    required int year,
    required int amount,
    required String currency,
    int carriedForwardAmount = 0,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(ValidationFailure('Pool ID cannot be empty'));
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
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
    if (currency.trim().length != 3) {
      return const FailureResult(
        ValidationFailure('Currency must be a 3-letter ISO code'),
      );
    }

    return Success(
      UnallocatedBudgetPool(
        id: id,
        profileId: profileId,
        month: month,
        year: year,
        amount: amount,
        currency: currency.trim().toUpperCase(),
        carriedForwardAmount: carriedForwardAmount,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'month': month,
    'year': year,
    'amount': amount,
    'currency': currency,
    'carriedForwardAmount': carriedForwardAmount,
  };

  factory UnallocatedBudgetPool.fromJson(Map<String, dynamic> json) =>
      UnallocatedBudgetPool(
        id: json['id'] as String,
        profileId: json['profileId'] as String,
        month: json['month'] as int,
        year: json['year'] as int,
        amount: json['amount'] as int,
        currency: json['currency'] as String,
        carriedForwardAmount: json['carriedForwardAmount'] as int? ?? 0,
      );
}
