import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

enum TransactionType { expense, income, transfer }

enum TransactionStatus { active, archived }

enum AllocationRole { source, destination }

enum EndpointType { account, goal }

class CategoryAllocation {
  final String id;
  final String transactionId;
  final String categoryId;
  final int amount; // positive minor units (> 0)
  final String currency;

  const CategoryAllocation({
    required this.id,
    required this.transactionId,
    required this.categoryId,
    required this.amount,
    required this.currency,
  });

  static Result<CategoryAllocation, ValidationFailure> create({
    required String id,
    required String transactionId,
    required String categoryId,
    required int amount,
    required String currency,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Allocation ID cannot be empty'),
      );
    }
    if (transactionId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Transaction ID cannot be empty'),
      );
    }
    if (categoryId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Category ID cannot be empty'),
      );
    }
    if (amount <= 0) {
      return const FailureResult(
        ValidationFailure('Allocation amount must be greater than zero'),
      );
    }
    if (currency.trim().length != 3) {
      return const FailureResult(
        ValidationFailure('Currency must be a 3-letter ISO code'),
      );
    }

    return Success(
      CategoryAllocation(
        id: id,
        transactionId: transactionId,
        categoryId: categoryId,
        amount: amount,
        currency: currency.trim().toUpperCase(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'transactionId': transactionId,
    'categoryId': categoryId,
    'amount': amount,
    'currency': currency,
  };

  factory CategoryAllocation.fromJson(Map<String, dynamic> json) =>
      CategoryAllocation(
        id: json['id'] as String,
        transactionId: json['transactionId'] as String,
        categoryId: json['categoryId'] as String,
        amount: json['amount'] as int,
        currency: json['currency'] as String,
      );
}

class TransferAllocation {
  final String id;
  final String transactionId;
  final AllocationRole role;
  final EndpointType endpointType;
  final String? accountId;
  final String? goalId;
  final int amount; // positive minor units (> 0)
  final String currency;

  const TransferAllocation({
    required this.id,
    required this.transactionId,
    required this.role,
    required this.endpointType,
    this.accountId,
    this.goalId,
    required this.amount,
    required this.currency,
  });

  static Result<TransferAllocation, ValidationFailure> create({
    required String id,
    required String transactionId,
    required AllocationRole role,
    required EndpointType endpointType,
    String? accountId,
    String? goalId,
    required int amount,
    required String currency,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Allocation ID cannot be empty'),
      );
    }
    if (transactionId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Transaction ID cannot be empty'),
      );
    }
    if (amount <= 0) {
      return const FailureResult(
        ValidationFailure('Allocation amount must be greater than zero'),
      );
    }
    if (currency.trim().length != 3) {
      return const FailureResult(
        ValidationFailure('Currency must be a 3-letter ISO code'),
      );
    }

    if (endpointType == EndpointType.account) {
      if (accountId == null || accountId.trim().isEmpty) {
        return const FailureResult(
          ValidationFailure('Account ID is required for account endpoints'),
        );
      }
      if (goalId != null) {
        return const FailureResult(
          ValidationFailure('Goal ID must be null for account endpoints'),
        );
      }
    }

    if (endpointType == EndpointType.goal) {
      if (goalId == null || goalId.trim().isEmpty) {
        return const FailureResult(
          ValidationFailure('Goal ID is required for goal endpoints'),
        );
      }
      if (accountId != null) {
        return const FailureResult(
          ValidationFailure('Account ID must be null for goal endpoints'),
        );
      }
    }

    return Success(
      TransferAllocation(
        id: id,
        transactionId: transactionId,
        role: role,
        endpointType: endpointType,
        accountId: accountId,
        goalId: goalId,
        amount: amount,
        currency: currency.trim().toUpperCase(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'transactionId': transactionId,
    'role': role.name,
    'endpointType': endpointType.name,
    'accountId': accountId,
    'goalId': goalId,
    'amount': amount,
    'currency': currency,
  };

  factory TransferAllocation.fromJson(Map<String, dynamic> json) =>
      TransferAllocation(
        id: json['id'] as String,
        transactionId: json['transactionId'] as String,
        role: AllocationRole.values.byName(json['role'] as String),
        endpointType: EndpointType.values.byName(
          json['endpointType'] as String,
        ),
        accountId: json['accountId'] as String?,
        goalId: json['goalId'] as String?,
        amount: json['amount'] as int,
        currency: json['currency'] as String,
      );
}

class Transaction {
  final String id;
  final String profileId;
  final TransactionType type;
  final String? subtype; // balanceAdjustment, creditCardSettlement
  final DateTime date;
  final String currency;
  final int totalAmount; // minor units
  final String? note;
  final String? tagId;
  final String paymentModeId;
  final String? recurringRuleId;
  final String? recurringOccurrenceId;
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  // Embedded allocations (authoritative structures)
  final List<CategoryAllocation> categoryAllocations;
  final List<TransferAllocation> transferAllocations;

  const Transaction({
    required this.id,
    required this.profileId,
    required this.type,
    this.subtype,
    required this.date,
    required this.currency,
    required this.totalAmount,
    this.note,
    this.tagId,
    required this.paymentModeId,
    this.recurringRuleId,
    this.recurringOccurrenceId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    required this.categoryAllocations,
    required this.transferAllocations,
  });

  /// Factory method to enforce "Always Valid" Transaction values and invariants.
  static Result<Transaction, ValidationFailure> create({
    required String id,
    required String profileId,
    required TransactionType type,
    String? subtype,
    required DateTime date,
    required String currency,
    required int totalAmount,
    String? note,
    String? tagId,
    required String paymentModeId,
    String? recurringRuleId,
    String? recurringOccurrenceId,
    required TransactionStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
    required List<CategoryAllocation> categoryAllocations,
    required List<TransferAllocation> transferAllocations,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Transaction ID cannot be empty'),
      );
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (currency.trim().length != 3) {
      return const FailureResult(
        ValidationFailure('Currency must be a 3-letter ISO code'),
      );
    }
    if (totalAmount <= 0) {
      return const FailureResult(
        ValidationFailure('Transaction total amount must be greater than zero'),
      );
    }
    if (paymentModeId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Payment mode ID cannot be empty'),
      );
    }

    final isBalanceAdjustment = subtype == 'balanceAdjustment';

    // --- Validation Invariants by Type ---

    if (type == TransactionType.expense || type == TransactionType.income) {
      if (isBalanceAdjustment) {
        // 1. Balance adjustments must NOT have category allocations
        if (categoryAllocations.isNotEmpty) {
          return const FailureResult(
            ValidationFailure(
              'Balance adjustment must not contain category allocations',
            ),
          );
        }
        // 2. Must contain exactly one transfer allocation
        if (transferAllocations.length != 1) {
          return const FailureResult(
            ValidationFailure(
              'Balance adjustment must contain exactly one account transfer allocation',
            ),
          );
        }
        final allocation = transferAllocations.first;
        if (allocation.endpointType != EndpointType.account) {
          return const FailureResult(
            ValidationFailure(
              'Balance adjustment must be performed on an Account',
            ),
          );
        }
        if (allocation.amount != totalAmount) {
          return const FailureResult(
            ValidationFailure(
              'Balance adjustment allocation amount must match transaction total',
            ),
          );
        }
      } else {
        // Normal Expense or Income
        // 1. Must contain category allocations summing to total
        if (categoryAllocations.isEmpty) {
          return FailureResult(
            ValidationFailure(
              '${type.name.toUpperCase()} must contain at least one category allocation',
            ),
          );
        }
        int categorySum = 0;
        for (final ca in categoryAllocations) {
          if (ca.currency != currency) {
            return const FailureResult(
              ValidationFailure('Category allocation currency mismatch'),
            );
          }
          categorySum += ca.amount;
        }
        if (categorySum != totalAmount) {
          return FailureResult(
            ValidationFailure(
              'Sum of category allocations ($categorySum) does not match transaction total ($totalAmount)',
            ),
          );
        }

        // 2. Must contain account funding transfer allocations summing to total
        if (transferAllocations.isEmpty) {
          return FailureResult(
            ValidationFailure(
              '${type.name.toUpperCase()} must contain account funding allocations',
            ),
          );
        }

        final expectedRole = type == TransactionType.expense
            ? AllocationRole.source
            : AllocationRole.destination;
        int fundingSum = 0;
        for (final ta in transferAllocations) {
          if (ta.currency != currency) {
            return const FailureResult(
              ValidationFailure('Funding allocation currency mismatch'),
            );
          }
          if (ta.endpointType != EndpointType.account) {
            return const FailureResult(
              ValidationFailure('Funding allocations must be Accounts only'),
            );
          }
          if (ta.role != expectedRole) {
            return FailureResult(
              ValidationFailure(
                'Funding allocation role must be ${expectedRole.name.toUpperCase()} for ${type.name.toUpperCase()}',
              ),
            );
          }
          fundingSum += ta.amount;
        }
        if (fundingSum != totalAmount) {
          return FailureResult(
            ValidationFailure(
              'Sum of funding allocations ($fundingSum) does not match transaction total ($totalAmount)',
            ),
          );
        }
      }
    }

    if (type == TransactionType.transfer) {
      // 1. Must NOT have category allocations
      if (categoryAllocations.isNotEmpty) {
        return const FailureResult(
          ValidationFailure('Transfer must not contain category allocations'),
        );
      }
      // 2. Must contain transfer allocations
      if (transferAllocations.isEmpty) {
        return const FailureResult(
          ValidationFailure(
            'Transfer must contain source and destination allocations',
          ),
        );
      }
      // 3. Must contain at least one source and one destination
      final sources = transferAllocations
          .where((ta) => ta.role == AllocationRole.source)
          .toList();
      final destinations = transferAllocations
          .where((ta) => ta.role == AllocationRole.destination)
          .toList();

      if (sources.isEmpty) {
        return const FailureResult(
          ValidationFailure(
            'Transfer must contain at least one SOURCE allocation',
          ),
        );
      }
      if (destinations.isEmpty) {
        return const FailureResult(
          ValidationFailure(
            'Transfer must contain at least one DESTINATION allocation',
          ),
        );
      }

      // 4. Sum of sources must equal sum of destinations and both must equal the transaction total
      int sourceSum = 0;
      int destSum = 0;
      for (final ta in transferAllocations) {
        if (ta.currency != currency) {
          return const FailureResult(
            ValidationFailure('Transfer allocation currency mismatch'),
          );
        }
        if (ta.role == AllocationRole.source) {
          sourceSum += ta.amount;
        } else {
          destSum += ta.amount;
        }
      }

      if (sourceSum != destSum) {
        return FailureResult(
          ValidationFailure(
            'Transfer source sum ($sourceSum) does not match destination sum ($destSum)',
          ),
        );
      }
      if (sourceSum != totalAmount) {
        return FailureResult(
          ValidationFailure(
            'Transfer allocations sum ($sourceSum) does not match transaction total ($totalAmount)',
          ),
        );
      }
    }

    return Success(
      Transaction(
        id: id,
        profileId: profileId,
        type: type,
        subtype: subtype,
        date: date,
        currency: currency.trim().toUpperCase(),
        totalAmount: totalAmount,
        note: note?.trim(),
        tagId: tagId,
        paymentModeId: paymentModeId,
        recurringRuleId: recurringRuleId,
        recurringOccurrenceId: recurringOccurrenceId,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        categoryAllocations: List.unmodifiable(categoryAllocations),
        transferAllocations: List.unmodifiable(transferAllocations),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'type': type.name,
    'subtype': subtype,
    'date': date.toIso8601String(),
    'currency': currency,
    'totalAmount': totalAmount,
    'note': note,
    'tagId': tagId,
    'paymentModeId': paymentModeId,
    'recurringRuleId': recurringRuleId,
    'recurringOccurrenceId': recurringOccurrenceId,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'archivedAt': archivedAt?.toIso8601String(),
    'categoryAllocations': categoryAllocations.map((e) => e.toJson()).toList(),
    'transferAllocations': transferAllocations.map((e) => e.toJson()).toList(),
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    type: TransactionType.values.byName(json['type'] as String),
    subtype: json['subtype'] as String?,
    date: DateTime.parse(json['date'] as String),
    currency: json['currency'] as String,
    totalAmount: json['totalAmount'] as int,
    note: json['note'] as String?,
    tagId: json['tagId'] as String?,
    paymentModeId: json['paymentModeId'] as String,
    recurringRuleId: json['recurringRuleId'] as String?,
    recurringOccurrenceId: json['recurringOccurrenceId'] as String?,
    status: TransactionStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    archivedAt: json['archivedAt'] != null
        ? DateTime.parse(json['archivedAt'] as String)
        : null,
    categoryAllocations: (json['categoryAllocations'] as List<dynamic>)
        .map((e) => CategoryAllocation.fromJson(e as Map<String, dynamic>))
        .toList(),
    transferAllocations: (json['transferAllocations'] as List<dynamic>)
        .map((e) => TransferAllocation.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
