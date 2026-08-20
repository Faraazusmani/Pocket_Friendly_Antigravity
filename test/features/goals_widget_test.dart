import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/errors/failures.dart';
import 'package:pocket_friendly/core/result/result.dart';
import 'package:pocket_friendly/core/di/service_locator.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/core/platform/haptic_service.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/domain/repositories/profile_repository.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/repositories/account_repository.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/repositories/category_repository.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/goals/domain/goal.dart';
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/goals/presentation/screens/goals_screen.dart';
import 'package:pocket_friendly/features/goals/presentation/screens/create_edit_goal_screen.dart';
import 'package:pocket_friendly/features/goals/presentation/widgets/goal_transfer_dialogs.dart';

class MockHapticService implements HapticService {
  @override
  Future<Result<void, PlatformFailure>> lightImpact() async =>
      const Success(null);
  @override
  Future<Result<void, PlatformFailure>> mediumImpact() async =>
      const Success(null);
  @override
  Future<Result<void, PlatformFailure>> heavyImpact() async =>
      const Success(null);
  @override
  Future<Result<void, PlatformFailure>> selectionClick() async =>
      const Success(null);
  @override
  Future<Result<void, PlatformFailure>> vibrate() async => const Success(null);
}

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

    await sl.reset();
    sl.registerSingleton<AppDatabase>(database);
    sl.registerLazySingleton<HapticService>(() => MockHapticService());

    profileRepo = ProfileRepositoryImpl(database);
    goalRepo = GoalRepositoryImpl(database);
    accountRepo = AccountRepositoryImpl(database);
    categoryRepo = CategoryRepositoryImpl(database);
    transactionRepo = TransactionRepositoryImpl(database);

    sl.registerLazySingleton<ProfileRepository>(() => profileRepo);
    sl.registerLazySingleton<GoalRepository>(() => goalRepo);
    sl.registerLazySingleton<AccountRepository>(() => accountRepo);
    sl.registerLazySingleton<CategoryRepository>(() => categoryRepo);
    sl.registerLazySingleton<TransactionRepository>(() => transactionRepo);

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

    // Insert Goal
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
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('GoalsScreen renders listing cards correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GoalsScreen()));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('GOALS'), findsOneWidget);
    expect(find.text('Europe Trip'), findsOneWidget);
    expect(find.text('STANDARD'), findsOneWidget);
  });

  testWidgets('CreateEditGoalScreen validates inputs correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateEditGoalScreen()));
    await tester.pumpAndSettle();

    expect(find.text('NEW GOAL'), findsOneWidget);

    // Tap Create button with empty inputs -> fails
    await tester.ensureVisible(find.text('CREATE GOAL'));
    await tester.tap(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter goal name'), findsOneWidget);

    // Enter name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Goal Name'),
      'Retirement',
    );

    // Tap Create -> target fails
    await tester.tap(find.text('CREATE GOAL'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter target'), findsOneWidget);
  });

  testWidgets(
    'WithdrawGoalDialog blocks submission if amount exceeds balance',
    (WidgetTester tester) async {
      final now = DateTime.now();
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WithdrawGoalDialog(
              goal: goal,
              currentBalance: 5000, // 50 INR available
              accounts: const [],
              onSave: (dest, amount, date) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 80 INR
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount (INR)'),
        '80',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      // Verification check should trigger validation error
      expect(find.text('Exceeds Goal balance. Max: ₹50'), findsOneWidget);
    },
  );
}
