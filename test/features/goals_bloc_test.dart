import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/domain/repositories/profile_repository.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/domain/repositories/account_repository.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/domain/repositories/category_repository.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/goals/domain/goal.dart';
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/goals/presentation/bloc/goals_bloc.dart';
import 'package:pocket_friendly/features/goals/presentation/bloc/goals_event.dart';
import 'package:pocket_friendly/features/goals/presentation/bloc/goals_state.dart';

void main() {
  late AppDatabase database;
  late ProfileRepository profileRepo;
  late GoalRepository goalRepo;
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;

  setUp(() async {
    final key = List<int>.generate(32, (i) => i);
    database = AppDatabase(openEncryptedConnection(key, inMemory: true));

    profileRepo = ProfileRepositoryImpl(database);
    goalRepo = GoalRepositoryImpl(database);
    accountRepo = AccountRepositoryImpl(database);
    categoryRepo = CategoryRepositoryImpl(database);
    transactionRepo = TransactionRepositoryImpl(database);

    // Insert active mock profile
    final now = DateTime.now();
    final profile = Profile.create(
      id: 'p1',
      name: 'John Doe',
      defaultCurrency: 'INR',
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await profileRepo.saveProfile(profile);

    // Insert Source Account
    final acc = Account.create(
      id: 'acc-hdfc',
      profileId: 'p1',
      type: AccountType.bank,
      name: 'HDFC Checking',
      currency: 'INR',
      icon: 'bank',
      openingBalance: 100000, // 1000 INR
      status: AccountStatus.active,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await accountRepo.saveAccount(acc);
  });

  tearDown(() async {
    await database.close();
  });

  blocTest<GoalsBloc, GoalsState>(
    'CreateGoal generates Goal and auto-creates subcategory',
    build: () => GoalsBloc(
      profileRepository: profileRepo,
      goalRepository: goalRepo,
      accountRepository: accountRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
    ),
    act: (bloc) => bloc.add(
      const CreateGoal(
        name: 'Europe Trip',
        icon: 'plane',
        goalType: GoalType.standard,
        targetAmount: 500000, // 5000 INR
      ),
    ),
    expect: () => [
      const GoalsLoading(),
      const GoalActionSuccess('Goal created successfully'),
    ],
    verify: (_) async {
      final goals = await goalRepo.getGoals('p1');
      expect(goals.successOrNull?.length, 1);
      expect(goals.successOrNull?.first.name, 'Europe Trip');

      // Verify that subcategory Goals -> Europe Trip exists
      final cats = await categoryRepo.getCategories('p1');
      // Should contain 2 categories: parent 'Goals' and child 'Europe Trip'
      expect(cats.successOrNull?.length, 2);
      expect(cats.successOrNull?.any((c) => c.name == 'Europe Trip'), true);
    },
  );

  blocTest<GoalsBloc, GoalsState>(
    'ContributeToGoal spawns transfer transaction and increases progress balance',
    build: () => GoalsBloc(
      profileRepository: profileRepo,
      goalRepository: goalRepo,
      accountRepository: accountRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
    ),
    act: (bloc) async {
      final now = DateTime.now();

      // 1. Create a Category linked to Goal
      final cat = Category.create(
        id: 'cat-trip',
        profileId: 'p1',
        name: 'Europe Trip',
        icon: 'plane',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(cat);

      // 2. Save Goal
      final goal = Goal.create(
        id: 'goal-trip',
        profileId: 'p1',
        categoryId: 'cat-trip',
        goalType: GoalType.standard,
        name: 'Europe Trip',
        icon: 'plane',
        targetAmount: 500000,
        currency: 'INR',
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await goalRepo.saveGoal(goal);

      // 3. Contribute 2,000 minor units (20 INR)
      bloc.add(
        ContributeToGoal(
          goalId: 'goal-trip',
          sourceAccountId: 'acc-hdfc',
          amount: 2000,
          date: now,
        ),
      );
    },
    expect: () => [
      const GoalsLoading(),
      const GoalActionSuccess('Contribution completed successfully'),
    ],
    verify: (_) async {
      final txs = await transactionRepo.getTransactions('p1');
      expect(txs.successOrNull?.length, 1);
      expect(txs.successOrNull?.first.type, TransactionType.transfer);
      expect(txs.successOrNull?.first.totalAmount, 2000);
    },
  );

  blocTest<GoalsBloc, GoalsState>(
    'WithdrawFromGoal rejects withdrawal if amount exceeds balance',
    build: () => GoalsBloc(
      profileRepository: profileRepo,
      goalRepository: goalRepo,
      accountRepository: accountRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
    ),
    act: (bloc) async {
      final now = DateTime.now();

      final cat = Category.create(
        id: 'cat-trip',
        profileId: 'p1',
        name: 'Europe Trip',
        icon: 'plane',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(cat);

      final goal = Goal.create(
        id: 'goal-trip',
        profileId: 'p1',
        categoryId: 'cat-trip',
        goalType: GoalType.standard,
        name: 'Europe Trip',
        icon: 'plane',
        targetAmount: 500000,
        currency: 'INR',
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await goalRepo.saveGoal(goal);

      // Try to withdraw 1,000 minor units (10 INR) when balance is 0 -> Should fail!
      bloc.add(
        WithdrawFromGoal(
          goalId: 'goal-trip',
          destinationAccountId: 'acc-hdfc',
          amount: 1000,
          date: now,
        ),
      );
    },
    expect: () => [
      const GoalsLoading(),
      const GoalsError(
        'Withdrawal rejected. Amount exceeds current balance. Max available: ₹0',
      ),
    ],
  );
}
