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
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/domain/repositories/account_repository.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/repositories/category_repository.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:pocket_friendly/features/accounts/presentation/screens/create_edit_account_screen.dart';
import 'package:pocket_friendly/features/accounts/presentation/widgets/adjust_balance_dialog.dart';

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

    sl.registerLazySingleton<ProfileRepository>(() => profileRepo);
    sl.registerLazySingleton<AccountRepository>(() => accountRepo);
    sl.registerLazySingleton<CategoryRepository>(() => categoryRepo);
    sl.registerLazySingleton<TransactionRepository>(() => transactionRepo);
    sl.registerLazySingleton<GoalRepository>(() => goalRepo);

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

    // Insert Bank Account
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
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'AccountsScreen renders grouped list and Net Worth totals correctly',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AccountsScreen()));
      await tester.pumpAndSettle();

      // Verify Title and Hero card
      expect(find.text('ACCOUNTS'), findsOneWidget);
      expect(find.text('NET WORTH'), findsOneWidget);
      expect(find.text('TOTAL ASSETS'), findsOneWidget);
      expect(find.text('LIABILITIES'), findsOneWidget);

      // Tracked bank account is 50,000 INR
      expect(find.text('₹50,000'), findsWidgets);
      expect(find.text('HDFC Checking'), findsOneWidget);
    },
  );

  testWidgets('CreateEditAccountScreen fields validate correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateEditAccountScreen()));
    await tester.pumpAndSettle();

    // Verify page title
    expect(find.text('NEW ACCOUNT'), findsOneWidget);

    // Tap Create button without inputting name -> triggers validation
    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter account name'), findsOneWidget);

    // Enter name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account Name'),
      'Salary Account',
    );

    // Switch Account Type to Credit Card
    await tester.tap(find.text('BANK'));
    await tester.pumpAndSettle();

    // Select Credit Card
    await tester.tap(find.text('CREDITCARD'));
    await tester.pumpAndSettle();

    // Try to create -> requires credit limit
    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter credit limit'), findsOneWidget);
  });

  testWidgets('AdjustBalanceDialog calculates difference dynamically', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final bank = Account.create(
      id: 'acc-hdfc',
      profileId: 'p1',
      type: AccountType.bank,
      name: 'HDFC Checking',
      currency: 'INR',
      icon: 'bank',
      openingBalance: 5000000,
      status: AccountStatus.active,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;

    int submittedVal = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdjustBalanceDialog(
            account: bank,
            trackedBalance: 5000000, // 50,000 INR
            onAdjust: (val) {
              submittedVal = val;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify tracked balance label
    expect(find.text('₹50,000'), findsOneWidget);

    // Enter new actual balance of 52,000 INR
    await tester.enterText(find.byType(TextFormField), '52000');
    await tester.pumpAndSettle();

    // Calculated adjustment should be +₹2,000
    expect(find.text('+₹2,000'), findsOneWidget);

    // Click Save
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // Verify onAdjust was called with 52,000 INR minor units (5,200,000)
    expect(submittedVal, 5200000);
  });
}
