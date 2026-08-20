import 'dart:convert';
import '../../../accounts/domain/account.dart';
import '../../../categories/domain/category.dart';
import '../../../goals/domain/goal.dart';
import '../../../budgets/domain/budget.dart';
import '../../../recurring/domain/recurring_rule.dart';
import '../transaction.dart';
import 'financial_engine.dart';

class InsightData {
  final int totalIncome; // minor units
  final int totalSpending; // minor units
  final int goalSavings; // minor units
  final int accountSavings; // minor units
  final int totalSavings; // minor units
  final double savingsRate; // percent (0 to 100)
  final int averageDailySpending; // minor units

  final Transaction? biggestExpense;
  final List<MonthlyTrendPoint> sixMonthTrend;
  final List<CategorySpentPoint> topCategories;
  final List<SpikePoint> spendingSpikes;
  final List<Transaction> unusualTransactions;
  final List<RecurringExpensePoint> recurringExpenses;
  final List<CategoryTrendPoint> categoryTrends;
  final List<BudgetRiskPoint> budgetRisks;
  final List<GoalRiskPoint> goalRisks;

  // MoM comparisons
  final double incomeChangePercent;
  final double spendingChangePercent;
  final double savingsChangePercent;

  const InsightData({
    required this.totalIncome,
    required this.totalSpending,
    required this.goalSavings,
    required this.accountSavings,
    required this.totalSavings,
    required this.savingsRate,
    required this.averageDailySpending,
    this.biggestExpense,
    required this.sixMonthTrend,
    required this.topCategories,
    required this.spendingSpikes,
    required this.unusualTransactions,
    required this.recurringExpenses,
    required this.categoryTrends,
    required this.budgetRisks,
    required this.goalRisks,
    required this.incomeChangePercent,
    required this.spendingChangePercent,
    required this.savingsChangePercent,
  });
}

class MonthlyTrendPoint {
  final String monthLabel; // e.g. "Aug"
  final int income;
  final int spending;
  final int savings;

  const MonthlyTrendPoint({
    required this.monthLabel,
    required this.income,
    required this.spending,
    required this.savings,
  });
}

class CategorySpentPoint {
  final Category category;
  final int spent;

  const CategorySpentPoint({required this.category, required this.spent});
}

class SpikePoint {
  final DateTime date;
  final int totalSpent;
  final List<Transaction> transactions;

  const SpikePoint({
    required this.date,
    required this.totalSpent,
    required this.transactions,
  });
}

class RecurringExpensePoint {
  final RecurringTransactionRule rule;
  final int amount;

  const RecurringExpensePoint({required this.rule, required this.amount});
}

class CategoryTrendPoint {
  final Category category;
  final int currentSpent;
  final int previousSpent;
  final double changePercent;

  const CategoryTrendPoint({
    required this.category,
    required this.currentSpent,
    required this.previousSpent,
    required this.changePercent,
  });
}

class BudgetRiskPoint {
  final Budget budget;
  final Category category;
  final int spent;
  final double progressPercent;

  const BudgetRiskPoint({
    required this.budget,
    required this.category,
    required this.spent,
    required this.progressPercent,
  });
}

class GoalRiskPoint {
  final Goal goal;
  final int saved;
  final int requiredMonthly;
  final int actualThisMonth;
  final bool isExpired;

  const GoalRiskPoint({
    required this.goal,
    required this.saved,
    required this.requiredMonthly,
    required this.actualThisMonth,
    required this.isExpired,
  });
}

class InsightsService {
  static InsightData generate({
    required DateTime selectedMonth,
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Goal> goals,
    required List<Budget> budgets,
    required List<RecurringTransactionRule> recurringRules,
  }) {
    final activeTxs = transactions
        .where((tx) => tx.status == TransactionStatus.active)
        .toList();

    // 1. Current Month Bounds
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    final monthTxs = activeTxs
        .where(
          (tx) =>
              tx.date.isAfter(
                startOfMonth.subtract(const Duration(seconds: 1)),
              ) &&
              tx.date.isBefore(endOfMonth.add(const Duration(seconds: 1))),
        )
        .toList();

    // 2. Total Income (excluding Balance Adjustments)
    int totalIncome = 0;
    for (final tx in monthTxs) {
      if (tx.type == TransactionType.income &&
          tx.subtype != 'balanceAdjustment') {
        totalIncome += tx.totalAmount;
      }
    }

    // 3. Total Spending (excluding Goal Transfers)
    int totalSpending = 0;
    for (final tx in monthTxs) {
      if (tx.type == TransactionType.expense) {
        // Exclude Goal transfer allocations (ordinary expenses have no Goal link)
        final hasGoalAllocation = tx.transferAllocations.any(
          (ta) => ta.endpointType == EndpointType.goal,
        );
        if (!hasGoalAllocation) {
          totalSpending += tx.totalAmount;
        }
      }
    }

    // 4. Goal Savings (net transfers into Goals in this month)
    int goalSavings = 0;
    for (final tx in monthTxs) {
      if (tx.type == TransactionType.transfer) {
        for (final ta in tx.transferAllocations) {
          if (ta.endpointType == EndpointType.goal) {
            if (ta.role == AllocationRole.destination) {
              goalSavings += ta.amount;
            } else if (ta.role == AllocationRole.source) {
              goalSavings -= ta.amount;
            }
          }
        }
      }
    }

    // 5. Account Savings & Total Savings
    final totalSavings = totalIncome - totalSpending;
    final accountSavings = totalSavings - goalSavings;

    // 6. Savings Rate
    final double savingsRate = totalIncome > 0
        ? (totalSavings / totalIncome) * 100.0
        : 0.0;

    // 7. Average Daily Spending
    final int daysInMonth = endOfMonth.day;
    final int passedDays =
        (selectedMonth.year == DateTime.now().year &&
            selectedMonth.month == DateTime.now().month)
        ? DateTime.now().day
        : daysInMonth;
    final int averageDailySpending = passedDays > 0
        ? totalSpending ~/ passedDays
        : 0;

    // 8. Biggest Expense
    Transaction? biggestExpense;
    final expenses = monthTxs
        .where((tx) => tx.type == TransactionType.expense)
        .toList();
    if (expenses.isNotEmpty) {
      expenses.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      biggestExpense = expenses.first;
    }

    // 9. Six-Month Trend
    final List<MonthlyTrendPoint> sixMonthTrend = [];
    final monthsAbbr = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    for (int i = 5; i >= 0; i--) {
      final trendMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month - i,
        1,
      );
      final trendStart = DateTime(trendMonth.year, trendMonth.month, 1);
      final trendEnd = DateTime(
        trendMonth.year,
        trendMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final tTxs = activeTxs
          .where(
            (tx) =>
                tx.date.isAfter(
                  trendStart.subtract(const Duration(seconds: 1)),
                ) &&
                tx.date.isBefore(trendEnd.add(const Duration(seconds: 1))),
          )
          .toList();

      int tIncome = 0;
      int tSpend = 0;
      for (final tx in tTxs) {
        if (tx.type == TransactionType.income &&
            tx.subtype != 'balanceAdjustment') {
          tIncome += tx.totalAmount;
        } else if (tx.type == TransactionType.expense) {
          tSpend += tx.totalAmount;
        }
      }
      sixMonthTrend.add(
        MonthlyTrendPoint(
          monthLabel: monthsAbbr[trendMonth.month - 1],
          income: tIncome,
          spending: tSpend,
          savings: tIncome - tSpend,
        ),
      );
    }

    // 10. Top Categories
    final categorySpentMap = <String, int>{};
    for (final tx in expenses) {
      for (final ca in tx.categoryAllocations) {
        categorySpentMap[ca.categoryId] =
            (categorySpentMap[ca.categoryId] ?? 0) + ca.amount;
      }
    }
    final List<CategorySpentPoint> topCategories = [];
    categorySpentMap.forEach((catId, spent) {
      final cat = categories.where((c) => c.id == catId).firstOrNull;
      if (cat != null) {
        topCategories.add(CategorySpentPoint(category: cat, spent: spent));
      }
    });
    topCategories.sort((a, b) => b.spent.compareTo(a.spent));

    // 11. Spending Spikes (> 2.5x average daily spend)
    final List<SpikePoint> spendingSpikes = [];
    final dailySpendMap = <int, List<Transaction>>{};
    for (final tx in expenses) {
      final day = tx.date.day;
      dailySpendMap[day] = (dailySpendMap[day] ?? [])..add(tx);
    }
    final double spikeThreshold = averageDailySpending * 2.5;
    dailySpendMap.forEach((day, txs) {
      final dayTotal = txs.fold<int>(0, (sum, tx) => sum + tx.totalAmount);
      if (dayTotal > spikeThreshold && dayTotal > 0) {
        spendingSpikes.add(
          SpikePoint(
            date: DateTime(selectedMonth.year, selectedMonth.month, day),
            totalSpent: dayTotal,
            transactions: txs,
          ),
        );
      }
    });
    spendingSpikes.sort((a, b) => b.date.compareTo(a.date));

    // 12. Unusual Transactions (> 3x category average over last 6 months)
    final List<Transaction> unusualTransactions = [];
    final sixMonthsAgo = DateTime(
      selectedMonth.year,
      selectedMonth.month - 6,
      1,
    );
    final historyTxs = activeTxs
        .where(
          (tx) =>
              tx.date.isAfter(sixMonthsAgo) &&
              tx.type == TransactionType.expense,
        )
        .toList();

    final catHistoryTotals = <String, int>{};
    final catHistoryCounts = <String, int>{};
    for (final tx in historyTxs) {
      for (final ca in tx.categoryAllocations) {
        catHistoryTotals[ca.categoryId] =
            (catHistoryTotals[ca.categoryId] ?? 0) + ca.amount;
        catHistoryCounts[ca.categoryId] =
            (catHistoryCounts[ca.categoryId] ?? 0) + 1;
      }
    }

    for (final tx in expenses) {
      for (final ca in tx.categoryAllocations) {
        final total = catHistoryTotals[ca.categoryId] ?? 0;
        final count = catHistoryCounts[ca.categoryId] ?? 0;
        if (count > 0) {
          final average = total / count;
          if (ca.amount > average * 3.0) {
            unusualTransactions.add(tx);
            break;
          }
        }
      }
    }

    // 13. Recurring Expenses
    final List<RecurringExpensePoint> recurringExpenses = [];
    for (final rule in recurringRules) {
      if (rule.active) {
        // Compute estimated monthly contribution from the template
        try {
          final dynamic template = rule.transactionTemplate.isNotEmpty
              ? jsonDecode(rule.transactionTemplate)
              : {};
          final int amount = template['totalAmount'] as int? ?? 0;
          recurringExpenses.add(
            RecurringExpensePoint(rule: rule, amount: amount),
          );
        } catch (_) {}
      }
    }

    // 14. Category Trends (MoM change)
    final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    final prevStart = DateTime(prevMonth.year, prevMonth.month, 1);
    final prevEnd = DateTime(
      prevMonth.year,
      prevMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    final prevExpenses = activeTxs
        .where(
          (tx) =>
              tx.type == TransactionType.expense &&
              tx.date.isAfter(prevStart.subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(prevEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    final prevCategorySpentMap = <String, int>{};
    for (final tx in prevExpenses) {
      for (final ca in tx.categoryAllocations) {
        prevCategorySpentMap[ca.categoryId] =
            (prevCategorySpentMap[ca.categoryId] ?? 0) + ca.amount;
      }
    }

    final List<CategoryTrendPoint> categoryTrends = [];
    categorySpentMap.forEach((catId, current) {
      final prev = prevCategorySpentMap[catId] ?? 0;
      final cat = categories.where((c) => c.id == catId).firstOrNull;
      if (cat != null) {
        final double change = prev > 0
            ? ((current - prev) / prev) * 100.0
            : 100.0;
        categoryTrends.add(
          CategoryTrendPoint(
            category: cat,
            currentSpent: current,
            previousSpent: prev,
            changePercent: change,
          ),
        );
      }
    });

    // 15. Budget Risks (Category Spent >= 90% of Budget)
    final List<BudgetRiskPoint> budgetRisks = [];
    for (final b in budgets) {
      if (b.year == selectedMonth.year && b.month == selectedMonth.month) {
        final spent = categorySpentMap[b.categoryId] ?? 0;
        if (spent >= b.totalAmount * 0.9) {
          final cat = categories.where((c) => c.id == b.categoryId).firstOrNull;
          if (cat != null) {
            budgetRisks.add(
              BudgetRiskPoint(
                budget: b,
                category: cat,
                spent: spent,
                progressPercent: b.totalAmount > 0
                    ? (spent / b.totalAmount) * 100.0
                    : 100.0,
              ),
            );
          }
        }
      }
    }

    // 16. Goal Risks (Behind projected savings rate needed to reach target)
    final List<GoalRiskPoint> goalRisks = [];
    for (final goal in goals) {
      final bal = FinancialEngine.calculateGoalBalance(goal, activeTxs);
      final isExpired = goal.isExpired(DateTime.now());
      final reqMonthly = goal.calculateRequiredMonthlyContribution(
        bal,
        DateTime.now(),
      );

      // Get contributions made in this specific month
      int actualThisMonth = 0;
      for (final tx in monthTxs) {
        if (tx.type == TransactionType.transfer) {
          for (final ta in tx.transferAllocations) {
            if (ta.endpointType == EndpointType.goal &&
                ta.goalId == goal.id &&
                ta.role == AllocationRole.destination) {
              actualThisMonth += ta.amount;
            }
          }
        }
      }

      if (isExpired && bal < goal.targetAmount) {
        goalRisks.add(
          GoalRiskPoint(
            goal: goal,
            saved: bal,
            requiredMonthly: goal.targetAmount - bal,
            actualThisMonth: actualThisMonth,
            isExpired: true,
          ),
        );
      } else if (actualThisMonth < reqMonthly && bal < goal.targetAmount) {
        goalRisks.add(
          GoalRiskPoint(
            goal: goal,
            saved: bal,
            requiredMonthly: reqMonthly,
            actualThisMonth: actualThisMonth,
            isExpired: false,
          ),
        );
      }
    }

    // 17. MoM changes for Total Income, Spending, Savings
    int prevIncome = 0;
    int prevSpending = 0;
    final prevTxs = activeTxs
        .where(
          (tx) =>
              tx.date.isAfter(prevStart.subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(prevEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    for (final tx in prevTxs) {
      if (tx.type == TransactionType.income &&
          tx.subtype != 'balanceAdjustment') {
        prevIncome += tx.totalAmount;
      } else if (tx.type == TransactionType.expense) {
        prevSpending += tx.totalAmount;
      }
    }
    final prevSavings = prevIncome - prevSpending;

    final double incomeChangePercent = prevIncome > 0
        ? ((totalIncome - prevIncome) / prevIncome) * 100.0
        : 0.0;
    final double spendingChangePercent = prevSpending > 0
        ? ((totalSpending - prevSpending) / prevSpending) * 100.0
        : 0.0;
    final double savingsChangePercent = prevSavings > 0
        ? ((totalSavings - prevSavings) / prevSavings) * 100.0
        : 0.0;

    return InsightData(
      totalIncome: totalIncome,
      totalSpending: totalSpending,
      goalSavings: goalSavings,
      accountSavings: accountSavings,
      totalSavings: totalSavings,
      savingsRate: savingsRate,
      averageDailySpending: averageDailySpending,
      biggestExpense: biggestExpense,
      sixMonthTrend: sixMonthTrend,
      topCategories: topCategories,
      spendingSpikes: spendingSpikes,
      unusualTransactions: unusualTransactions,
      recurringExpenses: recurringExpenses,
      categoryTrends: categoryTrends,
      budgetRisks: budgetRisks,
      goalRisks: goalRisks,
      incomeChangePercent: incomeChangePercent,
      spendingChangePercent: spendingChangePercent,
      savingsChangePercent: savingsChangePercent,
    );
  }
}
