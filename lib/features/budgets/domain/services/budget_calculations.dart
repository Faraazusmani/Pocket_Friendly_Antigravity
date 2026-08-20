import 'dart:convert';
import '../../../recurring/domain/recurring_rule.dart';
import '../../domain/budget.dart';
import '../../domain/unallocated_budget_pool.dart';
import '../../../transactions/domain/transaction.dart';

class BudgetCalculations {
  /// Computes the Total Monthly Budget.
  /// Formula: sum of category budgets + unallocated pool.
  static int calculateTotalMonthlyBudget({
    required List<Budget> categoryBudgets,
    required UnallocatedBudgetPool? pool,
  }) {
    int categorySum = categoryBudgets.fold(0, (sum, b) => sum + b.totalAmount);
    int poolAmount = pool?.amount ?? 0;
    return categorySum + poolAmount;
  }

  /// Calculates the total eligible spent to date in budgeted categories.
  static int calculateEligibleSpentToDate({
    required List<Budget> categoryBudgets,
    required List<Transaction> transactions,
  }) {
    int eligibleSpent = 0;
    final budgetedCategoryIds = categoryBudgets
        .map((b) => b.categoryId)
        .toSet();

    for (final tx in transactions) {
      if (tx.status == TransactionStatus.archived) continue;
      if (tx.type != TransactionType.expense) continue;

      for (final ca in tx.categoryAllocations) {
        if (budgetedCategoryIds.contains(ca.categoryId)) {
          eligibleSpent += ca.amount;
        }
      }
    }

    return eligibleSpent;
  }

  /// Calculates the Available Budget.
  /// Formula: TotalMonthlyBudget - EligibleSpentToDate
  static int calculateAvailableBudget({
    required List<Budget> categoryBudgets,
    required UnallocatedBudgetPool? pool,
    required List<Transaction> transactions,
  }) {
    final totalBudget = calculateTotalMonthlyBudget(
      categoryBudgets: categoryBudgets,
      pool: pool,
    );
    final eligibleSpent = calculateEligibleSpentToDate(
      categoryBudgets: categoryBudgets,
      transactions: transactions,
    );
    return totalBudget - eligibleSpent;
  }

  /// Calculates the remaining days in the month, inclusive of the target date.
  static int calculateDaysRemainingInclusive(DateTime date) {
    final lastDay = DateTime(date.year, date.month + 1, 0);
    // Standardize to midnight for integer day comparison
    final todayMidnight = DateTime(date.year, date.month, date.day);
    final lastMidnight = DateTime(lastDay.year, lastDay.month, lastDay.day);

    final difference = lastMidnight.difference(todayMidnight).inDays;
    return difference >= 0 ? difference + 1 : 0;
  }

  /// Calculates the sum of remaining scheduled recurring expenses for budgeted categories in this month.
  static int calculateRemainingScheduledBudgetedRecurring({
    required List<Budget> categoryBudgets,
    required List<RecurringOccurrence> pendingOccurrences,
    required List<RecurringTransactionRule> recurringRules,
    required DateTime targetDate,
  }) {
    int total = 0;
    final budgetedCategoryIds = categoryBudgets
        .map((b) => b.categoryId)
        .toSet();

    // Group rules by ID for quick lookup
    final ruleMap = {for (final r in recurringRules) r.id: r};

    for (final occurrence in pendingOccurrences) {
      // 1. Must be pending and scheduled for today or in the future
      if (occurrence.status != OccurrenceStatus.pending) continue;

      final scheduled = occurrence.scheduledOccurrenceDate;
      // Must be in the current calendar month
      if (scheduled.month != targetDate.month ||
          scheduled.year != targetDate.year) {
        continue;
      }

      // Must be today or in the future
      final scheduledMidnight = DateTime(
        scheduled.year,
        scheduled.month,
        scheduled.day,
      );
      final targetMidnight = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      if (scheduledMidnight.isBefore(targetMidnight)) continue;

      // 2. Fetch the corresponding rule and its category allocations
      final rule = ruleMap[occurrence.recurringRuleId];
      if (rule == null) continue;

      try {
        final templateJson =
            jsonDecode(rule.transactionTemplate) as Map<String, dynamic>;
        final categoryAllocationsJson =
            templateJson['categoryAllocations'] as List<dynamic>?;
        if (categoryAllocationsJson != null) {
          for (final ca in categoryAllocationsJson) {
            final catId = ca['categoryId'] as String;
            final amt = ca['amount'] as int;
            if (budgetedCategoryIds.contains(catId)) {
              total += amt;
            }
          }
        }
      } catch (_) {
        // Safe-ignore corrupted templates in rules
      }
    }

    return total;
  }

  /// Calculates Safe-to-Spend.
  /// Formula: MAX(0, (TotalMonthlyBudget - EligibleSpentToDate - RemainingScheduledBudgetedRecurring) / DaysRemainingInclusive)
  static int calculateSafeToSpend({
    required List<Budget> categoryBudgets,
    required UnallocatedBudgetPool? pool,
    required List<Transaction> transactions,
    required List<RecurringOccurrence> pendingOccurrences,
    required List<RecurringTransactionRule> recurringRules,
    required DateTime targetDate,
  }) {
    final daysRemaining = calculateDaysRemainingInclusive(targetDate);
    if (daysRemaining <= 0) return 0;

    final totalBudget = calculateTotalMonthlyBudget(
      categoryBudgets: categoryBudgets,
      pool: pool,
    );

    final eligibleSpent = calculateEligibleSpentToDate(
      categoryBudgets: categoryBudgets,
      transactions: transactions,
    );

    final remainingScheduled = calculateRemainingScheduledBudgetedRecurring(
      categoryBudgets: categoryBudgets,
      pendingOccurrences: pendingOccurrences,
      recurringRules: recurringRules,
      targetDate: targetDate,
    );

    final numerator = totalBudget - eligibleSpent - remainingScheduled;
    if (numerator <= 0) return 0;

    return (numerator / daysRemaining).floor();
  }

  /// Computes the total unused budget for carry-forward.
  /// Formula: sum of MAX(0, CategoryBudget - CategorySpend)
  static int calculateTotalUnusedBudget({
    required List<Budget> categoryBudgets,
    required List<Transaction> transactions,
  }) {
    int totalUnused = 0;

    for (final budget in categoryBudgets) {
      int categorySpent = 0;
      for (final tx in transactions) {
        if (tx.status == TransactionStatus.archived) continue;
        if (tx.type != TransactionType.expense) continue;

        for (final ca in tx.categoryAllocations) {
          if (ca.categoryId == budget.categoryId) {
            categorySpent += ca.amount;
          }
        }
      }

      final unused = budget.totalAmount - categorySpent;
      if (unused > 0) {
        totalUnused += unused;
      }
    }

    return totalUnused;
  }
}
