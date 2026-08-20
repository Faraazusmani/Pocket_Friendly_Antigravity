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
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:pocket_friendly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:pocket_friendly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:pocket_friendly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/insights/presentation/screens/insights_screen.dart';

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
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;
  late GoalRepository goalRepo;
  late BudgetRepository budgetRepo;
  late RecurringRepository recurringRepo;

  setUp(() async {
    final key = List<int>.generate(32, (i) => i);
    database = AppDatabase(openEncryptedConnection(key, inMemory: true));

    await sl.reset();
    sl.registerSingleton<AppDatabase>(database);
    sl.registerLazySingleton<HapticService>(() => MockHapticService());

    profileRepo = ProfileRepositoryImpl(database);
    accountRepo = AccountRepositoryImpl(database);
    categoryRepo = CategoryRepositoryImpl(database);
    transactionRepo = TransactionRepositoryImpl(database);
    goalRepo = GoalRepositoryImpl(database);
    budgetRepo = BudgetRepositoryImpl(database);
    recurringRepo = RecurringRepositoryImpl(database);

    sl.registerLazySingleton<ProfileRepository>(() => profileRepo);
    sl.registerLazySingleton<AccountRepository>(() => accountRepo);
    sl.registerLazySingleton<CategoryRepository>(() => categoryRepo);
    sl.registerLazySingleton<TransactionRepository>(() => transactionRepo);
    sl.registerLazySingleton<GoalRepository>(() => goalRepo);
    sl.registerLazySingleton<BudgetRepository>(() => budgetRepo);
    sl.registerLazySingleton<RecurringRepository>(() => recurringRepo);

    final now = DateTime.now();
    final profile = Profile.create(
      id: 'p1',
      name: 'John',
      defaultCurrency: 'INR',
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await profileRepo.saveProfile(profile);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('Assistant chat flow works successfully in InsightsScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: InsightsScreen()));
    await tester.pumpAndSettle();

    // 1. Submit text query
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    await tester.enterText(
      inputFinder,
      'How much did I spend on food this month?',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Assert chat bubbles are shown
    expect(
      find.text('How much did I spend on food this month?'),
      findsOneWidget,
    );
    expect(find.textContaining('Your spending this month was'), findsOneWidget);

    // 2. Submit action command
    await tester.enterText(inputFinder, 'Add 500 income from Freelancing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Prepared Action card check
    expect(
      find.textContaining('Action prepared: Record INCOME of ₹500'),
      findsOneWidget,
    );
    expect(find.text('OPEN FORM'), findsOneWidget);

    // 3. Mic button offline tap check
    final micFinder = find.byIcon(Icons.mic);
    if (micFinder.evaluate().isNotEmpty) {
      await tester.tap(micFinder);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('speech recognition is unavailable'),
        findsOneWidget,
      );
    }
  });
}
