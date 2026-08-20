import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

enum AccountType { bank, cash, creditCard }

enum AccountStatus { active, archived }

class Account {
  final String id;
  final String profileId;
  final AccountType type;
  final String name;
  final String currency;
  final String icon;
  final int openingBalance; // minor units
  final AccountStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  // Credit card specific configuration fields
  final int? creditLimit; // minor units
  final int? openingOutstanding; // minor units
  final int? billGenerationDay;

  const Account({
    required this.id,
    required this.profileId,
    required this.type,
    required this.name,
    required this.currency,
    required this.icon,
    required this.openingBalance,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.creditLimit,
    this.openingOutstanding,
    this.billGenerationDay,
  });

  /// Factory method to enforce "Always Valid" Account instantiation.
  static Result<Account, ValidationFailure> create({
    required String id,
    required String profileId,
    required AccountType type,
    required String name,
    required String currency,
    required String icon,
    required int openingBalance,
    required AccountStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
    int? creditLimit,
    int? openingOutstanding,
    int? billGenerationDay,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Account ID cannot be empty'),
      );
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (name.trim().length < 2) {
      return const FailureResult(
        ValidationFailure('Account name must be at least 2 characters long'),
      );
    }
    if (currency.trim().length != 3) {
      return const FailureResult(
        ValidationFailure('Currency must be a 3-letter ISO code'),
      );
    }
    if (icon.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Account icon cannot be empty'),
      );
    }

    if (type == AccountType.creditCard) {
      if (creditLimit == null || creditLimit < 0) {
        return const FailureResult(
          ValidationFailure('Credit card requires a non-negative credit limit'),
        );
      }
      if (openingOutstanding == null || openingOutstanding < 0) {
        return const FailureResult(
          ValidationFailure(
            'Credit card requires a non-negative opening outstanding liability',
          ),
        );
      }
      if (billGenerationDay == null ||
          billGenerationDay < 1 ||
          billGenerationDay > 31) {
        return const FailureResult(
          ValidationFailure(
            'Credit card bill generation day must be between 1 and 31',
          ),
        );
      }
    } else {
      if (creditLimit != null ||
          openingOutstanding != null ||
          billGenerationDay != null) {
        return const FailureResult(
          ValidationFailure(
            'Credit card configuration fields must be null for asset accounts',
          ),
        );
      }
    }

    return Success(
      Account(
        id: id,
        profileId: profileId,
        type: type,
        name: name.trim(),
        currency: currency.trim().toUpperCase(),
        icon: icon.trim(),
        openingBalance: openingBalance,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        creditLimit: creditLimit,
        openingOutstanding: openingOutstanding,
        billGenerationDay: billGenerationDay,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'type': type.name,
    'name': name,
    'currency': currency,
    'icon': icon,
    'openingBalance': openingBalance,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'archivedAt': archivedAt?.toIso8601String(),
    'creditLimit': creditLimit,
    'openingOutstanding': openingOutstanding,
    'billGenerationDay': billGenerationDay,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    type: AccountType.values.byName(json['type'] as String),
    name: json['name'] as String,
    currency: json['currency'] as String,
    icon: json['icon'] as String,
    openingBalance: json['openingBalance'] as int,
    status: AccountStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    archivedAt: json['archivedAt'] != null
        ? DateTime.parse(json['archivedAt'] as String)
        : null,
    creditLimit: json['creditLimit'] as int?,
    openingOutstanding: json['openingOutstanding'] as int?,
    billGenerationDay: json['billGenerationDay'] as int?,
  );
}
