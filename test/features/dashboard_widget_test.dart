import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pocket_friendly/core/errors/failures.dart';
import 'package:pocket_friendly/core/result/result.dart';
import 'package:pocket_friendly/core/di/service_locator.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/core/platform/haptic_service.dart';
import 'package:pocket_friendly/core/security/privacy_mode_service.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/domain/repositories/profile_repository.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/domain/repositories/account_repository.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/domain/repositories/category_repository.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/goals/domain/goal.dart';
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/budgets/domain/budget.dart';
import 'package:pocket_friendly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:pocket_friendly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:pocket_friendly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:pocket_friendly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:pocket_friendly/features/dashboard/presentation/screens/dashboard_screen.dart';

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

  setUp(() async {
    final key = List<int>.generate(32, (i) => i);
    database = AppDatabase(openEncryptedConnection(key, inMemory: true));

    await sl.reset();
    sl.registerSingleton<AppDatabase>(database);
    sl.registerLazySingleton<HapticService>(() => MockHapticService());
    sl.registerSingleton<PrivacyModeService>(FakePrivacyModeService());

    final profileRepo = ProfileRepositoryImpl(database);
    final accountRepo = AccountRepositoryImpl(database);
    final categoryRepo = CategoryRepositoryImpl(database);
    final transactionRepo = TransactionRepositoryImpl(database);
    final goalRepo = GoalRepositoryImpl(database);
    final budgetRepo = BudgetRepositoryImpl(database);
    final recurringRepo = RecurringRepositoryImpl(database);

    sl.registerLazySingleton<ProfileRepository>(() => profileRepo);
    sl.registerLazySingleton<AccountRepository>(() => accountRepo);
    sl.registerLazySingleton<CategoryRepository>(() => categoryRepo);
    sl.registerLazySingleton<TransactionRepository>(() => transactionRepo);
    sl.registerLazySingleton<GoalRepository>(() => goalRepo);
    sl.registerLazySingleton<BudgetRepository>(() => budgetRepo);
    sl.registerLazySingleton<RecurringRepository>(() => recurringRepo);

    // Insert mock data
    final now = DateTime.now();
    final profile = Profile.create(
      id: 'p1',
      name: 'John Doe',
      defaultCurrency: 'INR',
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await profileRepo.saveProfile(profile);

    final bank = Account.create(
      id: 'acc-hdfc',
      profileId: 'p1',
      type: AccountType.bank,
      name: 'HDFC Checking',
      currency: 'INR',
      icon: 'bank',
      openingBalance: 5000000, // 50,000 INR
      status: AccountStatus.active,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await accountRepo.saveAccount(bank);

    final category = Category.create(
      id: 'cat-grocery',
      profileId: 'p1',
      name: 'Grocery',
      icon: 'shopping-cart',
      status: CategoryStatus.active,
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await categoryRepo.saveCategory(category);

    // Budget of 100 INR
    final budget = Budget.create(
      id: 'b-grocery',
      profileId: 'p1',
      categoryId: 'cat-grocery',
      month: now.month,
      year: now.year,
      baseAmount: 10000,
      carryForwardAmount: 0,
      currency: 'INR',
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await budgetRepo.saveCategoryBudget(budget);

    // Goal of 200 INR
    final goal = Goal.create(
      id: 'goal-macbook',
      profileId: 'p1',
      categoryId: 'cat-grocery', // reuse category
      goalType: GoalType.standard,
      name: 'MacBook Air',
      icon: 'target',
      targetAmount: 20000,
      currency: 'INR',
      status: GoalStatus.active,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await goalRepo.saveGoal(goal);

    // Expense transaction of 15 INR
    final ca = CategoryAllocation.create(
      id: 'ca1',
      transactionId: 'tx1',
      categoryId: 'cat-grocery',
      amount: 1500,
      currency: 'INR',
    ).successOrNull!;
    final ta = TransferAllocation.create(
      id: 'ta1',
      transactionId: 'tx1',
      role: AllocationRole.source,
      endpointType: EndpointType.account,
      accountId: 'acc-hdfc',
      amount: 1500,
      currency: 'INR',
    ).successOrNull!;

    final tx = Transaction.create(
      id: 'tx1',
      profileId: 'p1',
      type: TransactionType.expense,
      date: now,
      currency: 'INR',
      totalAmount: 1500,
      paymentModeId: 'acc-hdfc',
      status: TransactionStatus.active,
      createdAt: now,
      updatedAt: now,
      categoryAllocations: [ca],
      transferAllocations: [ta],
      note: 'Grocery Shopping',
    ).successOrNull!;
    await transactionRepo.saveTransaction(tx);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('Dashboard renders loaded state and respects Privacy Mode toggle', (
    WidgetTester tester,
  ) async {
    // 1. Pump the DashboardScreen
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    // 3. Wait for data to load
    await tester.pumpAndSettle();

    // 4. Verify elements are rendered
    expect(find.text('POCKET FRIENDLY'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);

    // Verify budget info is visible
    expect(find.text('AVAILABLE BUDGET'), findsOneWidget);
    expect(find.text('Total Budget'), findsOneWidget);

    // Total budget: 100 INR, spent: 15 INR -> Available: 85 INR (8500 minor units)
    expect(find.text('₹85'), findsOneWidget);
    expect(find.text('₹100'), findsOneWidget);

    // Verify Safe-To-Spend is visible
    expect(find.text('SAFE-TO-SPEND TODAY'), findsOneWidget);

    // Verify Goals progress is visible
    expect(find.text('GOALS PROGRESS'), findsOneWidget);
    expect(find.text('MacBook Air'), findsOneWidget);
    // Since MacBook goal uses the same Grocery category, the contribution is 15 INR (7.5% progress)
    expect(find.text('8%'), findsOneWidget);

    // Verify Recent Transactions are visible
    expect(find.text('RECENT TRANSACTIONS'), findsOneWidget);
    expect(find.text('Grocery'), findsWidgets);
    expect(find.text('-₹15'), findsOneWidget);

    // 5. Toggle Privacy Mode (tap eye icon button)
    final privacyButton = find.widgetWithIcon(IconButton, LucideIcons.eye);
    expect(privacyButton, findsOneWidget);

    await tester.tap(privacyButton);
    await tester.pumpAndSettle();

    // Verify monetary values are replaced by dots
    expect(find.text('••••'), findsWidgets);
    expect(find.text('₹85'), findsNothing);
    expect(find.text('₹100'), findsNothing);
    expect(find.text('-₹15'), findsNothing);

    // 6. Toggle back
    final privacyButtonOff = find.widgetWithIcon(
      IconButton,
      LucideIcons.eyeOff,
    );
    expect(privacyButtonOff, findsOneWidget);

    await tester.tap(privacyButtonOff);
    await tester.pumpAndSettle();

    // Values restored
    expect(find.text('₹85'), findsOneWidget);
    expect(find.text('₹100'), findsOneWidget);
    expect(find.text('-₹15'), findsOneWidget);
  });
}

class FakePrivacyModeService implements PrivacyModeService {
  bool _enabled = false;
  @override
  bool get isEnabled => _enabled;
  @override
  Future<void> setEnabled(bool enabled) async => _enabled = enabled;
  @override
  Future<void> init() async {}
}
