import '../../../accounts/domain/account.dart';
import '../../../goals/domain/goal.dart';
import '../transaction.dart';

class FinancialEngine {
  /// Calculates the active balance of an asset account (Bank, Cash, etc.).
  /// Formula: openingBalance + sum(DESTINATION allocations) - sum(SOURCE allocations)
  static int calculateAccountBalance(Account account, List<Transaction> transactions) {
    if (account.type == AccountType.creditCard) {
      return calculateCreditCardAvailableCredit(account, transactions);
    }

    int balance = account.openingBalance;

    for (final tx in transactions) {
      if (tx.status == TransactionStatus.archived) continue;

      for (final ta in tx.transferAllocations) {
        if (ta.endpointType == EndpointType.account && ta.accountId == account.id) {
          if (ta.role == AllocationRole.destination) {
            balance += ta.amount;
          } else if (ta.role == AllocationRole.source) {
            balance -= ta.amount;
          }
        }
      }
    }

    return balance;
  }

  /// Calculates the outstanding balance of a Credit Card account.
  /// Formula: openingOutstanding + sum(SOURCE allocations) - sum(DESTINATION allocations)
  static int calculateCreditCardOutstanding(Account card, List<Transaction> transactions) {
    if (card.type != AccountType.creditCard) return 0;

    int outstanding = card.openingOutstanding ?? 0;

    for (final tx in transactions) {
      if (tx.status == TransactionStatus.archived) continue;

      for (final ta in tx.transferAllocations) {
        if (ta.endpointType == EndpointType.account && ta.accountId == card.id) {
          if (ta.role == AllocationRole.source) {
            outstanding += ta.amount;
          } else if (ta.role == AllocationRole.destination) {
            outstanding -= ta.amount;
          }
        }
      }
    }

    return outstanding;
  }

  /// Calculates the remaining available credit on a Credit Card.
  /// Formula: creditLimit - outstanding
  static int calculateCreditCardAvailableCredit(Account card, List<Transaction> transactions) {
    if (card.type != AccountType.creditCard) return 0;
    final limit = card.creditLimit ?? 0;
    final outstanding = calculateCreditCardOutstanding(card, transactions);
    return limit - outstanding;
  }

  /// Calculates the active balance of a Goal.
  /// Formula: sum(DESTINATION allocations) - sum(SOURCE allocations)
  static int calculateGoalBalance(Goal goal, List<Transaction> transactions) {
    int balance = 0;

    for (final tx in transactions) {
      if (tx.status == TransactionStatus.archived) continue;

      for (final ta in tx.transferAllocations) {
        if (ta.endpointType == EndpointType.goal && ta.goalId == goal.id) {
          if (ta.role == AllocationRole.destination) {
            balance += ta.amount;
          } else if (ta.role == AllocationRole.source) {
            balance -= ta.amount;
          }
        }
      }
    }

    return balance;
  }

  /// Calculates the Net Available Balance (NAB) for a profile in a given currency.
  /// Formula: sum(Asset Account Balances) - sum(Credit Card Outstanding Balances)
  static int calculateNetAvailableBalance({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required String currency,
  }) {
    int total = 0;
    final uppercaseCurrency = currency.toUpperCase();

    for (final acc in accounts) {
      if (acc.currency != uppercaseCurrency || acc.status == AccountStatus.archived) {
        continue;
      }

      if (acc.type == AccountType.creditCard) {
        total -= calculateCreditCardOutstanding(acc, transactions);
      } else {
        total += calculateAccountBalance(acc, transactions);
      }
    }

    return total;
  }

  /// Calculates the Net Worth (NW) for a profile in a given currency.
  /// Formula: Net Available Balance + sum(Goal Balances)
  static int calculateNetWorth({
    required List<Account> accounts,
    required List<Goal> goals,
    required List<Transaction> transactions,
    required String currency,
  }) {
    final uppercaseCurrency = currency.toUpperCase();
    int netAvailable = calculateNetAvailableBalance(
      accounts: accounts,
      transactions: transactions,
      currency: uppercaseCurrency,
    );

    int goalsTotal = 0;
    for (final goal in goals) {
      if (goal.currency != uppercaseCurrency || goal.status == GoalStatus.archived) {
        continue;
      }
      goalsTotal += calculateGoalBalance(goal, transactions);
    }

    return netAvailable + goalsTotal;
  }

  /// Calculates the total spending for a specific category.
  /// Formula: sum(CategoryAllocation amount where transaction is EXPENSE)
  static int calculateCategorySpent({
    required String categoryId,
    required List<Transaction> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    int total = 0;

    for (final tx in transactions) {
      if (tx.status == TransactionStatus.archived) continue;
      if (tx.type != TransactionType.expense) continue;

      // Filter by optional dates (useful for monthly budgets)
      if (startDate != null && tx.date.isBefore(startDate)) continue;
      if (endDate != null && tx.date.isAfter(endDate)) continue;

      for (final ca in tx.categoryAllocations) {
        if (ca.categoryId == categoryId) {
          total += ca.amount;
        }
      }
    }

    return total;
  }
}
