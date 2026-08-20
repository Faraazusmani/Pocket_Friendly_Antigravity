import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../domain/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import 'goals_event.dart';
import 'goals_state.dart';

class GoalsBloc extends Bloc<GoalsEvent, GoalsState> {
  final ProfileRepository profileRepository;
  final GoalRepository goalRepository;
  final AccountRepository accountRepository;
  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;

  GoalsBloc({
    required this.profileRepository,
    required this.goalRepository,
    required this.accountRepository,
    required this.categoryRepository,
    required this.transactionRepository,
  }) : super(const GoalsInitial()) {
    on<LoadGoals>(_onLoadGoals);
    on<CreateGoal>(_onCreateGoal);
    on<UpdateGoal>(_onUpdateGoal);
    on<ArchiveGoal>(_onArchiveGoal);
    on<ContributeToGoal>(_onContributeToGoal);
    on<WithdrawFromGoal>(_onWithdrawFromGoal);
  }

  Future<void> _onLoadGoals(LoadGoals event, Emitter<GoalsState> emit) async {
    emit(const GoalsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const GoalsError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final goalsRes = await goalRepository.getGoals(
        profileId,
        includeArchived: false,
      );
      final accountsRes = await accountRepository.getAccounts(
        profileId,
        includeArchived: false,
      );
      final categoriesRes = await categoryRepository.getCategories(
        profileId,
        includeArchived: false,
      );
      final transactionsRes = await transactionRepository.getTransactions(
        profileId,
      );

      final goals = goalsRes.isSuccess ? goalsRes.successOrNull! : <Goal>[];
      final accounts = accountsRes.isSuccess
          ? accountsRes.successOrNull!
          : <Account>[];
      final categories = categoriesRes.isSuccess
          ? categoriesRes.successOrNull!
          : <Category>[];
      final transactions = transactionsRes.isSuccess
          ? transactionsRes.successOrNull!
          : <Transaction>[];

      // Pre-calculate balances and progress percentages
      final goalBalances = <String, int>{};
      final goalProgressPercents = <String, double>{};

      for (final goal in goals) {
        goalBalances[goal.id] = FinancialEngine.calculateGoalBalance(
          goal,
          transactions,
        );
        goalProgressPercents[goal.id] =
            FinancialEngine.calculateGoalProgressPercent(goal, transactions);
      }

      emit(
        GoalsLoaded(
          goals: goals,
          accounts: accounts,
          categories: categories,
          transactions: transactions,
          goalBalances: goalBalances,
          goalProgressPercents: goalProgressPercents,
        ),
      );
    } catch (e) {
      emit(GoalsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onCreateGoal(CreateGoal event, Emitter<GoalsState> emit) async {
    emit(const GoalsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const GoalsError('No active profile found'));
        return;
      }
      final profile = profilesRes.successOrNull!.first;
      final profileId = profile.id;

      // 1. Find or create Goals parent category
      final allCatsRes = await categoryRepository.getCategories(
        profileId,
        includeArchived: false,
      );
      final allCats = allCatsRes.isSuccess
          ? allCatsRes.successOrNull!
          : <Category>[];
      Category? parent = allCats
          .where(
            (c) =>
                c.name.toLowerCase() == 'goals' && c.parentCategoryId == null,
          )
          .firstOrNull;

      final now = DateTime.now();

      if (parent == null) {
        final parentId = const Uuid().v4();
        final newParentRes = Category.create(
          id: parentId,
          profileId: profileId,
          name: 'Goals',
          icon: 'folder',
          status: CategoryStatus.active,
          isSystem: true,
          createdAt: now,
          updatedAt: now,
        );
        if (newParentRes.isFailure) {
          emit(
            GoalsError(
              newParentRes.failureOrNull?.message ??
                  'Failed to create Goals parent category',
            ),
          );
          return;
        }
        parent = newParentRes.successOrNull!;
        await categoryRepository.saveCategory(parent);
      }

      // 2. Create subcategory Goals -> <Goal Name>
      final childId = const Uuid().v4();
      final childRes = Category.create(
        id: childId,
        profileId: profileId,
        parentCategoryId: parent.id,
        name: event.name,
        icon: event.icon,
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      );
      if (childRes.isFailure) {
        emit(
          GoalsError(
            childRes.failureOrNull?.message ?? 'Failed to create subcategory',
          ),
        );
        return;
      }
      await categoryRepository.saveCategory(childRes.successOrNull!);

      // 3. Create the Goal entity
      final goalRes = Goal.create(
        id: const Uuid().v4(),
        profileId: profileId,
        categoryId: childId,
        goalType: event.goalType,
        name: event.name,
        icon: event.icon,
        targetAmount: event.targetAmount,
        currency: profile.defaultCurrency,
        targetDate: event.targetDate,
        description: event.description,
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      if (goalRes.isFailure) {
        emit(
          GoalsError(goalRes.failureOrNull?.message ?? 'Failed to create Goal'),
        );
        return;
      }
      await goalRepository.saveGoal(goalRes.successOrNull!);

      emit(const GoalActionSuccess('Goal created successfully'));
    } catch (e) {
      emit(GoalsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onUpdateGoal(UpdateGoal event, Emitter<GoalsState> emit) async {
    emit(const GoalsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const GoalsError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final existingRes = await goalRepository.getGoal(event.goalId, profileId);
      if (existingRes.isFailure) {
        emit(const GoalsError('Goal not found'));
        return;
      }
      final existing = existingRes.successOrNull!;

      final now = DateTime.now();

      // Update linked category
      final catRes = await categoryRepository.getCategory(
        existing.categoryId,
        profileId,
      );
      if (catRes.isSuccess) {
        final cat = catRes.successOrNull!;
        final updatedCatRes = Category.create(
          id: cat.id,
          profileId: cat.profileId,
          parentCategoryId: cat.parentCategoryId,
          name: event.name,
          icon: event.icon,
          status: cat.status,
          isSystem: cat.isSystem,
          createdAt: cat.createdAt,
          updatedAt: now,
        );
        if (updatedCatRes.isSuccess) {
          await categoryRepository.saveCategory(updatedCatRes.successOrNull!);
        }
      }

      // Update the Goal entity
      final goalRes = Goal.create(
        id: existing.id,
        profileId: existing.profileId,
        categoryId: existing.categoryId,
        goalType: event.goalType,
        name: event.name,
        icon: event.icon,
        targetAmount: event.targetAmount,
        currency: existing.currency,
        targetDate: event.targetDate,
        description: event.description,
        status: existing.status,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      if (goalRes.isFailure) {
        emit(
          GoalsError(goalRes.failureOrNull?.message ?? 'Failed to update Goal'),
        );
        return;
      }
      await goalRepository.saveGoal(goalRes.successOrNull!);

      emit(const GoalActionSuccess('Goal updated successfully'));
    } catch (e) {
      emit(GoalsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onArchiveGoal(
    ArchiveGoal event,
    Emitter<GoalsState> emit,
  ) async {
    emit(const GoalsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const GoalsError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final existingRes = await goalRepository.getGoal(event.goalId, profileId);
      if (existingRes.isFailure) {
        emit(const GoalsError('Goal not found'));
        return;
      }
      final existing = existingRes.successOrNull!;

      // Archive linked category
      await categoryRepository.archiveCategory(existing.categoryId, profileId);

      // Archive Goal entity
      await goalRepository.archiveGoal(event.goalId, profileId);

      emit(const GoalActionSuccess('Goal deleted successfully'));
    } catch (e) {
      emit(GoalsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onContributeToGoal(
    ContributeToGoal event,
    Emitter<GoalsState> emit,
  ) async {
    emit(const GoalsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const GoalsError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final goalRes = await goalRepository.getGoal(event.goalId, profileId);
      final accountRes = await accountRepository.getAccount(
        event.sourceAccountId,
        profileId,
      );

      if (goalRes.isFailure || accountRes.isFailure) {
        emit(const GoalsError('Goal or Account not found'));
        return;
      }
      final goal = goalRes.successOrNull!;
      final account = accountRes.successOrNull!;

      final now = DateTime.now();
      final txId = const Uuid().v4();

      final sourceTa = TransferAllocation.create(
        id: const Uuid().v4(),
        transactionId: txId,
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: account.id,
        amount: event.amount,
        currency: account.currency,
      );

      final destTa = TransferAllocation.create(
        id: const Uuid().v4(),
        transactionId: txId,
        role: AllocationRole.destination,
        endpointType: EndpointType.goal,
        goalId: goal.id,
        amount: event.amount,
        currency: account.currency,
      );

      if (sourceTa.isFailure || destTa.isFailure) {
        emit(const GoalsError('Allocation validation failed'));
        return;
      }

      final txRes = Transaction.create(
        id: txId,
        profileId: profileId,
        type: TransactionType.transfer,
        date: event.date,
        currency: account.currency,
        totalAmount: event.amount,
        paymentModeId: account.id,
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [sourceTa.successOrNull!, destTa.successOrNull!],
        note: 'Savings Contribution: ${goal.name}',
      );

      if (txRes.isFailure) {
        emit(
          GoalsError(
            txRes.failureOrNull?.message ?? 'Failed to create transaction',
          ),
        );
        return;
      }

      await transactionRepository.saveTransaction(txRes.successOrNull!);
      emit(const GoalActionSuccess('Contribution completed successfully'));
    } catch (e) {
      emit(GoalsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onWithdrawFromGoal(
    WithdrawFromGoal event,
    Emitter<GoalsState> emit,
  ) async {
    emit(const GoalsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const GoalsError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final goalRes = await goalRepository.getGoal(event.goalId, profileId);
      final accountRes = await accountRepository.getAccount(
        event.destinationAccountId,
        profileId,
      );

      if (goalRes.isFailure || accountRes.isFailure) {
        emit(const GoalsError('Goal or Account not found'));
        return;
      }
      final goal = goalRes.successOrNull!;
      final account = accountRes.successOrNull!;

      final transactionsRes = await transactionRepository.getTransactions(
        profileId,
      );
      final transactions = transactionsRes.isSuccess
          ? transactionsRes.successOrNull!
          : <Transaction>[];

      // Invariant: Goal balance cannot go negative
      final currentBalance = FinancialEngine.calculateGoalBalance(
        goal,
        transactions,
      );
      if (event.amount > currentBalance) {
        final double maxMajor = currentBalance / 100.0;
        emit(
          GoalsError(
            'Withdrawal rejected. Amount exceeds current balance. Max available: ₹${maxMajor.toStringAsFixed(0)}',
          ),
        );
        return;
      }

      final now = DateTime.now();
      final txId = const Uuid().v4();

      final sourceTa = TransferAllocation.create(
        id: const Uuid().v4(),
        transactionId: txId,
        role: AllocationRole.source,
        endpointType: EndpointType.goal,
        goalId: goal.id,
        amount: event.amount,
        currency: account.currency,
      );

      final destTa = TransferAllocation.create(
        id: const Uuid().v4(),
        transactionId: txId,
        role: AllocationRole.destination,
        endpointType: EndpointType.account,
        accountId: account.id,
        amount: event.amount,
        currency: account.currency,
      );

      if (sourceTa.isFailure || destTa.isFailure) {
        emit(const GoalsError('Allocation validation failed'));
        return;
      }

      final txRes = Transaction.create(
        id: txId,
        profileId: profileId,
        type: TransactionType.transfer,
        date: event.date,
        currency: account.currency,
        totalAmount: event.amount,
        paymentModeId: account.id,
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [sourceTa.successOrNull!, destTa.successOrNull!],
        note: 'Savings Withdrawal: ${goal.name}',
      );

      if (txRes.isFailure) {
        emit(
          GoalsError(
            txRes.failureOrNull?.message ?? 'Failed to create transaction',
          ),
        );
        return;
      }

      await transactionRepository.saveTransaction(txRes.successOrNull!);
      emit(const GoalActionSuccess('Withdrawal completed successfully'));
    } catch (e) {
      emit(GoalsError('An unexpected error occurred: $e'));
    }
  }
}
