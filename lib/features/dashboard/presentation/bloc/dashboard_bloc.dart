import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/privacy_mode_service.dart';
import '../../../profiles/domain/profile.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../budgets/domain/budget.dart';
import '../../../budgets/domain/repositories/budget_repository.dart';
import '../../../budgets/domain/services/budget_calculations.dart';
import '../../../recurring/domain/recurring_rule.dart';
import '../../../recurring/domain/repositories/recurring_repository.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final ProfileRepository profileRepository;
  final AccountRepository accountRepository;
  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final GoalRepository goalRepository;
  final BudgetRepository budgetRepository;
  final RecurringRepository recurringRepository;

  DashboardBloc({
    required this.profileRepository,
    required this.accountRepository,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.goalRepository,
    required this.budgetRepository,
    required this.recurringRepository,
  }) : super(const DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<ChangeMonth>(_onChangeMonth);
    on<TogglePrivacyMode>(_onTogglePrivacyMode);
    on<ChangeCurrency>(_onChangeCurrency);
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());
    final isPrivacyEnabled = sl.isRegistered<PrivacyModeService>() && sl<PrivacyModeService>().isEnabled;
    await _loadDashboardData(
      selectedMonth: DateTime.now(),
      privacyModeEnabled: isPrivacyEnabled,
      selectedCurrency: null,
      emit: emit,
    );
  }

  Future<void> _onChangeMonth(
    ChangeMonth event,
    Emitter<DashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is DashboardLoaded) {
      emit(const DashboardLoading());
      await _loadDashboardData(
        selectedMonth: event.month,
        privacyModeEnabled: currentState.privacyModeEnabled,
        selectedCurrency: currentState.selectedCurrency,
        emit: emit,
      );
    }
  }

  Future<void> _onTogglePrivacyMode(
    TogglePrivacyMode event,
    Emitter<DashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is DashboardLoaded) {
      final newMode = !currentState.privacyModeEnabled;
      if (sl.isRegistered<PrivacyModeService>()) {
        await sl<PrivacyModeService>().setEnabled(newMode);
      }
      emit(
        currentState.copyWith(
          privacyModeEnabled: newMode,
        ),
      );
    }
  }

  Future<void> _onChangeCurrency(
    ChangeCurrency event,
    Emitter<DashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is DashboardLoaded) {
      emit(const DashboardLoading());
      await _loadDashboardData(
        selectedMonth: currentState.selectedMonth,
        privacyModeEnabled: currentState.privacyModeEnabled,
        selectedCurrency: event.currency,
        emit: emit,
      );
    }
  }

  Future<void> _loadDashboardData({
    required DateTime selectedMonth,
    required bool privacyModeEnabled,
    required String? selectedCurrency,
    required Emitter<DashboardState> emit,
  }) async {
    try {
      // 1. Fetch profiles. If empty, create default 'p1'
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure) {
        emit(
          DashboardError(
            'Failed to load profiles: ${profilesRes.failureOrNull?.message}',
          ),
        );
        return;
      }

      var profiles = profilesRes.successOrNull!;
      if (profiles.isEmpty) {
        final defaultProfile = Profile.create(
          id: 'p1',
          name: 'Pocket Owner',
          defaultCurrency: 'INR',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).successOrNull!;
        await profileRepository.saveProfile(defaultProfile);
        profiles = [defaultProfile];
      }

      final profile = profiles.first;
      final profileId = profile.id;
      final targetCurrency = selectedCurrency ?? profile.defaultCurrency;

      // 2. Fetch Accounts
      final accountsRes = await accountRepository.getAccounts(profileId);
      if (accountsRes.isFailure) {
        emit(
          DashboardError(
            'Failed to load accounts: ${accountsRes.failureOrNull?.message}',
          ),
        );
        return;
      }
      final accounts = accountsRes.successOrNull!;

      // 3. Fetch Categories
      final categoriesRes = await categoryRepository.getCategories(profileId);
      if (categoriesRes.isFailure) {
        emit(
          DashboardError(
            'Failed to load categories: ${categoriesRes.failureOrNull?.message}',
          ),
        );
        return;
      }
      final categories = categoriesRes.successOrNull!;

      // 4. Fetch Transactions
      final transactionsRes = await transactionRepository.getTransactions(
        profileId,
      );
      if (transactionsRes.isFailure) {
        emit(
          DashboardError(
            'Failed to load transactions: ${transactionsRes.failureOrNull?.message}',
          ),
        );
        return;
      }
      final transactions = transactionsRes.successOrNull!;

      // 5. Fetch Goals
      final goalsRes = await goalRepository.getGoals(profileId);
      if (goalsRes.isFailure) {
        emit(
          DashboardError(
            'Failed to load goals: ${goalsRes.failureOrNull?.message}',
          ),
        );
        return;
      }
      final goals = goalsRes.successOrNull!;

      // 6. Fetch Budgets for target month
      final budgetsRes = await budgetRepository.getCategoryBudgets(
        profileId,
        selectedMonth.month,
        selectedMonth.year,
      );
      if (budgetsRes.isFailure) {
        emit(
          DashboardError(
            'Failed to load budgets: ${budgetsRes.failureOrNull?.message}',
          ),
        );
        return;
      }
      final budgets = budgetsRes.successOrNull!;

      // 7. Fetch Unallocated Pool for target month
      final poolRes = await budgetRepository.getUnallocatedBudgetPool(
        profileId: profileId,
        month: selectedMonth.month,
        year: selectedMonth.year,
        currency: targetCurrency,
      );
      final pool = poolRes.isSuccess ? poolRes.successOrNull : null;

      // 8. Fetch Recurring Rules & Occurrences
      final rulesRes = await recurringRepository.getActiveRules(profileId);
      final recurringRules = rulesRes.isSuccess
          ? rulesRes.successOrNull!
          : <RecurringTransactionRule>[];

      final pendingOccurrences = <RecurringOccurrence>[];
      for (final rule in recurringRules) {
        final occRes = await recurringRepository.getOccurrences(rule.id);
        if (occRes.isSuccess) {
          pendingOccurrences.addAll(
            occRes.successOrNull!.where(
              (occ) => occ.status == OccurrenceStatus.pending,
            ),
          );
        }
      }

      // --- DERIVED CALCULATIONS ---

      // A. Available Currencies list (extracted from accounts and transactions)
      final currenciesSet = <String>{};
      for (final acc in accounts) {
        currenciesSet.add(acc.currency.toUpperCase());
      }
      for (final tx in transactions) {
        currenciesSet.add(tx.currency.toUpperCase());
      }
      if (currenciesSet.isEmpty) {
        currenciesSet.add(targetCurrency.toUpperCase());
      }
      final availableCurrencies = currenciesSet.toList()..sort();

      // B. Budget Snapshot Calculations
      // Note: We only filter category budgets and pool that match selectedCurrency
      final currencyBudgets = budgets
          .where(
            (b) => b.currency.toUpperCase() == targetCurrency.toUpperCase(),
          )
          .toList();

      final eligibleSpent = BudgetCalculations.calculateEligibleSpentToDate(
        categoryBudgets: currencyBudgets,
        transactions: transactions
            .where(
              (t) =>
                  t.date.year == selectedMonth.year &&
                  t.date.month == selectedMonth.month,
            )
            .toList(),
      );

      final totalBudget = BudgetCalculations.calculateTotalMonthlyBudget(
        categoryBudgets: currencyBudgets,
        pool: pool,
      );

      final availableBudget = totalBudget - eligibleSpent;

      // C. Balance Snapshot Calculations (Bank + Cash current balances only)
      int netAvailableBalance = 0;
      for (final acc in accounts) {
        if ((acc.type == AccountType.bank || acc.type == AccountType.cash) &&
            acc.currency.toUpperCase() == targetCurrency.toUpperCase() &&
            acc.status == AccountStatus.active) {
          netAvailableBalance += FinancialEngine.calculateAccountBalance(
            acc,
            transactions,
          );
        }
      }

      // Monthly Income & Monthly Spent
      int monthlyIncome = 0;
      int monthlySpent = 0;
      for (final tx in transactions) {
        if (tx.status == TransactionStatus.archived) continue;
        if (tx.currency.toUpperCase() != targetCurrency.toUpperCase()) continue;
        if (tx.date.year == selectedMonth.year &&
            tx.date.month == selectedMonth.month) {
          if (tx.type == TransactionType.income) {
            monthlyIncome += tx.totalAmount;
          } else if (tx.type == TransactionType.expense) {
            monthlySpent += tx.totalAmount;
          }
        }
      }

      // D. Safe-to-Spend
      final safeToSpend = BudgetCalculations.calculateSafeToSpend(
        categoryBudgets: currencyBudgets,
        pool: pool,
        transactions: transactions
            .where(
              (t) =>
                  t.date.year == selectedMonth.year &&
                  t.date.month == selectedMonth.month,
            )
            .toList(),
        pendingOccurrences: pendingOccurrences,
        recurringRules: recurringRules,
        targetDate: selectedMonth,
      );

      // E. Overspent Budgets
      final overspentBudgets = <Budget>[];
      for (final budget in currencyBudgets) {
        int spent = 0;
        for (final tx in transactions) {
          if (tx.status == TransactionStatus.archived) continue;
          if (tx.type != TransactionType.expense) continue;
          if (tx.date.year == selectedMonth.year &&
              tx.date.month == selectedMonth.month) {
            for (final ca in tx.categoryAllocations) {
              if (ca.categoryId == budget.categoryId) {
                spent += ca.amount;
              }
            }
          }
        }
        if (spent > budget.totalAmount) {
          overspentBudgets.add(budget);
        }
      }

      // F. Recent Transactions (First 5, active, sorted by date desc)
      final recentTransactions =
          transactions
              .where((t) => t.status == TransactionStatus.active)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      final limitedRecent = recentTransactions.take(5).toList();

      emit(
        DashboardLoaded(
          selectedMonth: selectedMonth,
          privacyModeEnabled: privacyModeEnabled,
          selectedCurrency: targetCurrency,
          profile: profile,
          accounts: accounts,
          categories: categories,
          transactions: transactions,
          goals: goals,
          budgets: budgets,
          pool: pool,
          recurringRules: recurringRules,
          pendingOccurrences: pendingOccurrences,
          availableBudget: availableBudget,
          totalBudget: totalBudget,
          eligibleSpentToDate: eligibleSpent,
          netAvailableBalance: netAvailableBalance,
          monthlyIncome: monthlyIncome,
          monthlySpent: monthlySpent,
          safeToSpend: safeToSpend,
          overspentBudgets: overspentBudgets,
          availableCurrencies: availableCurrencies,
          recentTransactions: limitedRecent,
        ),
      );
    } catch (e) {
      emit(DashboardError('An unexpected error occurred: $e'));
    }
  }
}
