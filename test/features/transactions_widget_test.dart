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
import 'package:pocket_friendly/features/accounts/domain/payment_mode.dart';
import 'package:pocket_friendly/features/accounts/domain/repositories/account_repository.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/domain/repositories/category_repository.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:pocket_friendly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/presentation/widgets/record_transaction_sheet.dart';
import 'package:pocket_friendly/features/transactions/presentation/widgets/split_categories_sheet.dart';

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
    recurringRepo = RecurringRepositoryImpl(database);

    sl.registerLazySingleton<ProfileRepository>(() => profileRepo);
    sl.registerLazySingleton<AccountRepository>(() => accountRepo);
    sl.registerLazySingleton<CategoryRepository>(() => categoryRepo);
    sl.registerLazySingleton<TransactionRepository>(() => transactionRepo);
    sl.registerLazySingleton<GoalRepository>(() => goalRepo);
    sl.registerLazySingleton<RecurringRepository>(() => recurringRepo);

    final now = DateTime.now();
    // 1. Insert Profile
    final profile = Profile.create(
      id: 'p1',
      name: 'John Doe',
      defaultCurrency: 'INR',
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await profileRepo.saveProfile(profile);

    // 2. Insert Account
    final acc = Account.create(
      id: 'acc-hdfc',
      profileId: 'p1',
      type: AccountType.bank,
      name: 'HDFC Checking',
      currency: 'INR',
      icon: 'bank',
      openingBalance: 100000,
      status: AccountStatus.active,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await accountRepo.saveAccount(acc);

    // 3. Insert Category
    final cat = Category.create(
      id: 'cat-grocery',
      profileId: 'p1',
      name: 'Groceries',
      icon: 'shopping-cart',
      status: CategoryStatus.active,
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await categoryRepo.saveCategory(cat);

    // 4. Insert Payment Mode
    final pm = PaymentMode.create(
      id: 'pm-debit-card',
      profileId: 'p1',
      name: 'Debit Card',
      applicableAccountTypes: [AccountType.bank],
      isDefault: true,
      isSystem: true,
      status: PaymentModeStatus.active,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await accountRepo.savePaymentMode(pm);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('RecordTransactionSheet validation works correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RecordTransactionSheet())),
    );
    await tester.pumpAndSettle();

    // Verify loading finish and title is shown
    expect(find.text('RECORD TRANSACTION'), findsOneWidget);

    // Tap SAVE with empty amount -> validates
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('Enter amount'), findsOneWidget);
  });

  testWidgets('SplitCategoriesSheet validation rejects mismatch allocations', (
    WidgetTester tester,
  ) async {
    final cat1 = Category.create(
      id: 'c1',
      profileId: 'p1',
      name: 'Shopping',
      icon: 'gift',
      status: CategoryStatus.active,
      isSystem: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).successOrNull!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplitCategoriesSheet(
            totalAmount: 10000, // 100 INR total
            categories: [cat1],
            initialAllocations: const {},
            currency: 'INR',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter 80 INR in first slot
    await tester.enterText(find.byType(TextFormField).first, '80.00');
    await tester.pumpAndSettle();

    // Tap SAVE SPLIT
    await tester.tap(find.text('SAVE SPLIT'));
    await tester.pumpAndSettle();

    // Validation Snackbar should be triggered since 80 != 100
    expect(
      find.textContaining('must exactly equal transaction total'),
      findsOneWidget,
    );
  });
}
