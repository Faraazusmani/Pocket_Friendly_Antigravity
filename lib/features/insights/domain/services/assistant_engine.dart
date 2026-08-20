import '../../../accounts/domain/account.dart';
import '../../../categories/domain/category.dart';
import '../../../goals/domain/goal.dart';
import '../../../budgets/domain/budget.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import '../../../transactions/domain/services/insights_service.dart';

abstract class AssistantIntent {
  const AssistantIntent();
}

class QueryIntent extends AssistantIntent {
  final String
  concept; // 'spending', 'income', 'savings', 'savings_rate', 'budget_remaining', 'goal_progress'
  final String timeframe; // 'current_month', 'last_month'
  final String? categoryName;
  final String? accountName;
  final String? goalName;

  const QueryIntent({
    required this.concept,
    required this.timeframe,
    this.categoryName,
    this.accountName,
    this.goalName,
  });
}

class ActionIntent extends AssistantIntent {
  final TransactionType type;
  final int amountMinor;
  final String? categoryName;
  final String? accountName;
  final String? destinationGoalName;
  final String? note;

  const ActionIntent({
    required this.type,
    required this.amountMinor,
    this.categoryName,
    this.accountName,
    this.destinationGoalName,
    this.note,
  });
}

class UnknownIntent extends AssistantIntent {
  const UnknownIntent();
}

class AssistantResponse {
  final String message;
  final ActionIntent? preparedAction;

  const AssistantResponse({required this.message, this.preparedAction});
}

class AssistantEngine {
  static AssistantIntent parse(String input) {
    final clean = input.toLowerCase().trim();

    // 1. Action Intent parsing (Command: Add, Spend, Record, Transfer, Spent)
    if (clean.startsWith('add') ||
        clean.startsWith('spend') ||
        clean.startsWith('spent') ||
        clean.startsWith('record') ||
        clean.startsWith('transfer')) {
      return _parseAction(clean);
    }

    // 2. Query Intent parsing (Question: How much, What is, savings, budget, etc.)
    return _parseQuery(clean);
  }

  static AssistantResponse execute({
    required AssistantIntent intent,
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Goal> goals,
    required List<Budget> budgets,
    required String currency,
  }) {
    if (intent is UnknownIntent) {
      return const AssistantResponse(
        message:
            "I didn't quite catch that. Try asking about your spending, goals, or say 'Add 500 income from freelancing'.",
      );
    }

    final symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';

    if (intent is ActionIntent) {
      final double major = intent.amountMinor / 100.0;
      final typeLabel = intent.type.name.toUpperCase();
      final categoryLabel = intent.categoryName ?? 'Uncategorized';

      return AssistantResponse(
        message:
            "Action prepared: Record $typeLabel of $symbol${major.toStringAsFixed(0)} under $categoryLabel.",
        preparedAction: intent,
      );
    }

    if (intent is QueryIntent) {
      final now = DateTime.now();
      final targetMonth = intent.timeframe == 'last_month'
          ? DateTime(now.year, now.month - 1, 1)
          : now;

      final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
      final endOfMonth = DateTime(
        targetMonth.year,
        targetMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final activeTxs = transactions
          .where((tx) => tx.status == TransactionStatus.active)
          .toList();
      final monthTxs = activeTxs
          .where(
            (tx) =>
                tx.date.isAfter(
                  startOfMonth.subtract(const Duration(seconds: 1)),
                ) &&
                tx.date.isBefore(endOfMonth.add(const Duration(seconds: 1))),
          )
          .toList();

      // Query: Spending
      if (intent.concept == 'spending') {
        int total = 0;
        final catName = intent.categoryName;
        if (catName != null) {
          final cat = categories
              .where((c) => c.name.toLowerCase() == catName)
              .firstOrNull;
          if (cat == null) {
            return AssistantResponse(
              message:
                  "I couldn't find a category named '${intent.categoryName}'.",
            );
          }
          for (final tx in monthTxs) {
            if (tx.type == TransactionType.expense) {
              for (final ca in tx.categoryAllocations) {
                if (ca.categoryId == cat.id) {
                  total += ca.amount;
                }
              }
            }
          }
          final double major = total / 100.0;
          final timeLabel = intent.timeframe == 'last_month'
              ? 'last month'
              : 'this month';
          return AssistantResponse(
            message:
                "You spent $symbol${major.toStringAsFixed(0)} on **${cat.name}** $timeLabel.",
          );
        } else {
          // Total actual spending
          for (final tx in monthTxs) {
            if (tx.type == TransactionType.expense) {
              final hasGoalAllocation = tx.transferAllocations.any(
                (ta) => ta.endpointType == EndpointType.goal,
              );
              if (!hasGoalAllocation) {
                total += tx.totalAmount;
              }
            }
          }
          final double major = total / 100.0;
          final timeLabel = intent.timeframe == 'last_month'
              ? 'last month'
              : 'this month';
          return AssistantResponse(
            message:
                "Your total spending $timeLabel was $symbol${major.toStringAsFixed(0)}.",
          );
        }
      }

      // Query: Income
      if (intent.concept == 'income') {
        int total = 0;
        for (final tx in monthTxs) {
          if (tx.type == TransactionType.income &&
              tx.subtype != 'balanceAdjustment') {
            total += tx.totalAmount;
          }
        }
        final double major = total / 100.0;
        final timeLabel = intent.timeframe == 'last_month'
            ? 'last month'
            : 'this month';
        return AssistantResponse(
          message:
              "Your total income $timeLabel was $symbol${major.toStringAsFixed(0)}.",
        );
      }

      // Query: Savings Rate
      if (intent.concept == 'savings_rate') {
        final data = InsightsService.generate(
          selectedMonth: targetMonth,
          transactions: transactions,
          accounts: accounts,
          categories: categories,
          goals: goals,
          budgets: budgets,
          recurringRules: const [],
        );
        final timeLabel = intent.timeframe == 'last_month'
            ? 'last month'
            : 'this month';
        return AssistantResponse(
          message:
              "Your savings rate $timeLabel was **${data.savingsRate.toStringAsFixed(0)}%**.",
        );
      }

      // Query: Budget Remaining
      if (intent.concept == 'budget_remaining') {
        final catName = intent.categoryName;
        if (catName != null) {
          final cat = categories
              .where((c) => c.name.toLowerCase() == catName)
              .firstOrNull;
          if (cat == null) {
            return AssistantResponse(
              message:
                  "I couldn't find a category named '${intent.categoryName}'.",
            );
          }
          final budget = budgets
              .where(
                (b) =>
                    b.categoryId == cat.id &&
                    b.year == targetMonth.year &&
                    b.month == targetMonth.month,
              )
              .firstOrNull;
          if (budget == null) {
            return AssistantResponse(
              message:
                  "You don't have a budget set up for **${cat.name}** this month.",
            );
          }
          int spent = 0;
          for (final tx in monthTxs) {
            if (tx.type == TransactionType.expense) {
              for (final ca in tx.categoryAllocations) {
                if (ca.categoryId == cat.id) {
                  spent += ca.amount;
                }
              }
            }
          }
          final remaining = budget.totalAmount - spent;
          final double majorRemaining = remaining / 100.0;
          return AssistantResponse(
            message:
                "You have $symbol${majorRemaining.toStringAsFixed(0)} remaining of your **${cat.name}** budget.",
          );
        }
      }

      // Query: Goal Progress
      if (intent.concept == 'goal_progress') {
        final goalName = intent.goalName;
        if (goalName != null) {
          final goal = goals
              .where((g) => g.name.toLowerCase().contains(goalName))
              .firstOrNull;
          if (goal == null) {
            return AssistantResponse(
              message: "I couldn't find a goal named '${intent.goalName}'.",
            );
          }
          final progress = FinancialEngine.calculateGoalBalance(
            goal,
            activeTxs,
          );
          final double majorProgress = progress / 100.0;
          final double majorTarget = goal.targetAmount / 100.0;
          return AssistantResponse(
            message:
                "You saved $symbol${majorProgress.toStringAsFixed(0)} out of your target $symbol${majorTarget.toStringAsFixed(0)} for **${goal.name}**.",
          );
        }
      }
    }

    return const AssistantResponse(
      message:
          "I processed your request but couldn't compute a specific summary answer. Try rephrasing.",
    );
  }

  static AssistantIntent _parseAction(String clean) {
    // Determine type
    TransactionType type = TransactionType.expense;
    if (clean.contains('income') ||
        clean.contains('received') ||
        clean.contains('earned')) {
      type = TransactionType.income;
    } else if (clean.contains('transfer') || clean.contains('send')) {
      type = TransactionType.transfer;
    }

    // Match amount
    final amountReg = RegExp(r'\d+');
    final match = amountReg.firstMatch(clean);
    if (match == null) return const UnknownIntent();
    final amountVal = int.parse(match.group(0)!);
    final amountMinor = amountVal * 100;

    // Guess category / note
    String? categoryName;
    if (clean.contains(RegExp(r'\bfrom\b'))) {
      categoryName = clean.split(RegExp(r'\bfrom\b')).last.trim();
    } else if (clean.contains(RegExp(r'\bon\b'))) {
      categoryName = clean.split(RegExp(r'\bon\b')).last.trim();
    } else if (clean.contains(RegExp(r'\bfor\b'))) {
      categoryName = clean.split(RegExp(r'\bfor\b')).last.trim();
    }

    // Capitalize category name for search matching
    if (categoryName != null && categoryName.length > 1) {
      categoryName = categoryName[0].toUpperCase() + categoryName.substring(1);
    }

    return ActionIntent(
      type: type,
      amountMinor: amountMinor,
      categoryName: categoryName,
      note: categoryName,
    );
  }

  static AssistantIntent _parseQuery(String clean) {
    // 1. Spending queries
    if (clean.contains('spend') ||
        clean.contains('spent') ||
        clean.contains('cost')) {
      final timeframe = clean.contains('last month')
          ? 'last_month'
          : 'current_month';
      String? categoryName;

      // Extract category if it matches "on <category>"
      if (clean.contains(RegExp(r'\bon\b'))) {
        categoryName = clean
            .split(RegExp(r'\bon\b'))
            .last
            .replaceAll(RegExp(r'\?|\.'), '')
            .replaceAll('last month', '')
            .replaceAll('this month', '')
            .trim();
      }

      return QueryIntent(
        concept: 'spending',
        timeframe: timeframe,
        categoryName: categoryName,
      );
    }

    // 2. Savings rate queries
    if (clean.contains('savings rate') || clean.contains('saving rate')) {
      final timeframe = clean.contains('last month')
          ? 'last_month'
          : 'current_month';
      return QueryIntent(concept: 'savings_rate', timeframe: timeframe);
    }

    // 3. Goal queries
    if (clean.contains('goal') ||
        clean.contains('save towards') ||
        clean.contains('saved towards')) {
      String? goalName;
      if (clean.contains(RegExp(r'\bfor\b'))) {
        goalName = clean
            .split(RegExp(r'\bfor\b'))
            .last
            .replaceAll(RegExp(r'\?|\.'), '')
            .replaceAll('last month', '')
            .replaceAll('this month', '')
            .trim();
      }
      return QueryIntent(
        concept: 'goal_progress',
        timeframe: 'current_month',
        goalName: goalName,
      );
    }

    // 4. Budget queries
    if (clean.contains('budget')) {
      String? categoryName;
      if (clean.contains(RegExp(r'\bfor\b'))) {
        categoryName = clean
            .split(RegExp(r'\bfor\b'))
            .last
            .replaceAll(RegExp(r'\?|\.'), '')
            .replaceAll('last month', '')
            .replaceAll('this month', '')
            .trim();
      }
      return QueryIntent(
        concept: 'budget_remaining',
        timeframe: 'current_month',
        categoryName: categoryName,
      );
    }

    return const UnknownIntent();
  }
}
