import 'package:equatable/equatable.dart';
import '../../../profiles/domain/profile.dart';
import '../../../accounts/domain/account.dart';
import '../../../categories/domain/category.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../goals/domain/goal.dart';
import '../../../budgets/domain/budget.dart';
import '../../../budgets/domain/unallocated_budget_pool.dart';
import '../../../recurring/domain/recurring_rule.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

class DashboardLoaded extends DashboardState {
  final DateTime selectedMonth;
  final bool privacyModeEnabled;
  final String selectedCurrency;

  final Profile profile;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Transaction> transactions;
  final List<Goal> goals;
  final List<Budget> budgets;
  final UnallocatedBudgetPool? pool;
  final List<RecurringTransactionRule> recurringRules;
  final List<RecurringOccurrence> pendingOccurrences;

  // Derived Calculations
  final int availableBudget;
  final int totalBudget;
  final int eligibleSpentToDate;

  final int netAvailableBalance;
  final int monthlyIncome;
  final int monthlySpent;

  final int safeToSpend;
  final List<Budget> overspentBudgets;
  final List<String> availableCurrencies;
  final List<Transaction> recentTransactions;

  const DashboardLoaded({
    required this.selectedMonth,
    required this.privacyModeEnabled,
    required this.selectedCurrency,
    required this.profile,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.goals,
    required this.budgets,
    this.pool,
    required this.recurringRules,
    required this.pendingOccurrences,
    required this.availableBudget,
    required this.totalBudget,
    required this.eligibleSpentToDate,
    required this.netAvailableBalance,
    required this.monthlyIncome,
    required this.monthlySpent,
    required this.safeToSpend,
    required this.overspentBudgets,
    required this.availableCurrencies,
    required this.recentTransactions,
  });

  DashboardLoaded copyWith({
    DateTime? selectedMonth,
    bool? privacyModeEnabled,
    String? selectedCurrency,
    Profile? profile,
    List<Account>? accounts,
    List<Category>? categories,
    List<Transaction>? transactions,
    List<Goal>? goals,
    List<Budget>? budgets,
    UnallocatedBudgetPool? pool,
    List<RecurringTransactionRule>? recurringRules,
    List<RecurringOccurrence>? pendingOccurrences,
    int? availableBudget,
    int? totalBudget,
    int? eligibleSpentToDate,
    int? netAvailableBalance,
    int? monthlyIncome,
    int? monthlySpent,
    int? safeToSpend,
    List<Budget>? overspentBudgets,
    List<String>? availableCurrencies,
    List<Transaction>? recentTransactions,
  }) {
    return DashboardLoaded(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      privacyModeEnabled: privacyModeEnabled ?? this.privacyModeEnabled,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      profile: profile ?? this.profile,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      transactions: transactions ?? this.transactions,
      goals: goals ?? this.goals,
      budgets: budgets ?? this.budgets,
      pool: pool ?? this.pool,
      recurringRules: recurringRules ?? this.recurringRules,
      pendingOccurrences: pendingOccurrences ?? this.pendingOccurrences,
      availableBudget: availableBudget ?? this.availableBudget,
      totalBudget: totalBudget ?? this.totalBudget,
      eligibleSpentToDate: eligibleSpentToDate ?? this.eligibleSpentToDate,
      netAvailableBalance: netAvailableBalance ?? this.netAvailableBalance,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlySpent: monthlySpent ?? this.monthlySpent,
      safeToSpend: safeToSpend ?? this.safeToSpend,
      overspentBudgets: overspentBudgets ?? this.overspentBudgets,
      availableCurrencies: availableCurrencies ?? this.availableCurrencies,
      recentTransactions: recentTransactions ?? this.recentTransactions,
    );
  }

  @override
  List<Object?> get props => [
    selectedMonth,
    privacyModeEnabled,
    selectedCurrency,
    profile,
    accounts,
    categories,
    transactions,
    goals,
    budgets,
    pool,
    recurringRules,
    pendingOccurrences,
    availableBudget,
    totalBudget,
    eligibleSpentToDate,
    netAvailableBalance,
    monthlyIncome,
    monthlySpent,
    safeToSpend,
    overspentBudgets,
    availableCurrencies,
    recentTransactions,
  ];
}
