import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/privacy_mode_service.dart';
import '../../../accounts/domain/account.dart';
import '../../../categories/domain/category.dart';
import '../../../goals/domain/goal.dart';
import '../../../budgets/domain/budget.dart';
import '../../../recurring/domain/recurring_rule.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../budgets/domain/repositories/budget_repository.dart';
import '../../../recurring/domain/repositories/recurring_repository.dart';
import '../../../transactions/domain/services/insights_service.dart';
import 'insights_event.dart';
import 'insights_state.dart';

class InsightsBloc extends Bloc<InsightsEvent, InsightsState> {
  final ProfileRepository profileRepository;
  final AccountRepository accountRepository;
  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final GoalRepository goalRepository;
  final BudgetRepository budgetRepository;
  final RecurringRepository recurringRepository;

  InsightsBloc({
    required this.profileRepository,
    required this.accountRepository,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.goalRepository,
    required this.budgetRepository,
    required this.recurringRepository,
  }) : super(const InsightsInitial()) {
    on<LoadInsights>(_onLoadInsights);
  }

  Future<void> _onLoadInsights(
    LoadInsights event,
    Emitter<InsightsState> emit,
  ) async {
    emit(const InsightsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const InsightsError('No active profile found'));
        return;
      }
      final profile = profilesRes.successOrNull!.first;
      final profileId = profile.id;

      // Fetch all required data series
      final txsRes = await transactionRepository.getTransactions(profileId);
      final accountsRes = await accountRepository.getAccounts(
        profileId,
        includeArchived: false,
      );
      final categoriesRes = await categoryRepository.getCategories(
        profileId,
        includeArchived: false,
      );
      final goalsRes = await goalRepository.getGoals(
        profileId,
        includeArchived: false,
      );
      final budgetsRes = await budgetRepository.getCategoryBudgets(
        profileId,
        event.monthYear.month,
        event.monthYear.year,
      );
      final recurringRes = await recurringRepository.getActiveRules(profileId);

      final List<Transaction> transactions = txsRes.isSuccess
          ? txsRes.successOrNull!
          : [];
      final List<Account> accounts = accountsRes.isSuccess
          ? accountsRes.successOrNull!
          : [];
      final List<Category> categories = categoriesRes.isSuccess
          ? categoriesRes.successOrNull!
          : [];
      final List<Goal> goals = goalsRes.isSuccess
          ? goalsRes.successOrNull!
          : [];
      final List<Budget> budgets = budgetsRes.isSuccess
          ? budgetsRes.successOrNull!
          : [];
      final List<RecurringTransactionRule> recurringRules =
          recurringRes.isSuccess ? recurringRes.successOrNull! : [];

      final data = InsightsService.generate(
        selectedMonth: event.monthYear,
        transactions: transactions,
        accounts: accounts,
        categories: categories,
        goals: goals,
        budgets: budgets,
        recurringRules: recurringRules,
      );

      emit(
        InsightsLoaded(
          data: data,
          selectedMonth: event.monthYear,
          privacyModeEnabled: sl.isRegistered<PrivacyModeService>() && sl<PrivacyModeService>().isEnabled,
          defaultCurrency: profile.defaultCurrency,
        ),
      );
    } catch (e) {
      emit(InsightsError('Failed to generate insights: $e'));
    }
  }
}
