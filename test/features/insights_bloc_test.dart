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
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:pocket_friendly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:pocket_friendly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:pocket_friendly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:pocket_friendly/features/insights/presentation/bloc/insights_event.dart';
import 'package:pocket_friendly/features/insights/presentation/bloc/insights_state.dart';
import 'package:pocket_friendly/features/transactions/domain/services/insights_service.dart';
import 'package:pocket_friendly/core/di/service_locator.dart';
import 'package:pocket_friendly/core/security/privacy_mode_service.dart';

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
    await sl.reset();
    sl.registerSingleton<PrivacyModeService>(FakePrivacyModeService());

    final key = List<int>.generate(32, (i) => i);
    database = AppDatabase(openEncryptedConnection(key, inMemory: true));

    profileRepo = ProfileRepositoryImpl(database);
    accountRepo = AccountRepositoryImpl(database);
    categoryRepo = CategoryRepositoryImpl(database);
    transactionRepo = TransactionRepositoryImpl(database);
    goalRepo = GoalRepositoryImpl(database);
    budgetRepo = BudgetRepositoryImpl(database);
    recurringRepo = RecurringRepositoryImpl(database);

    final now = DateTime.now();
    // Insert Mock Profile
    final profile = Profile.create(
      id: 'p1',
      name: 'John',
      defaultCurrency: 'INR',
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await profileRepo.saveProfile(profile);

    // Insert Category
    final cat = Category.create(
      id: 'cat-fun',
      profileId: 'p1',
      name: 'Fun',
      icon: 'smile',
      status: CategoryStatus.active,
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await categoryRepo.saveCategory(cat);

    // Insert Account
    final acc = Account.create(
      id: 'acc-savings',
      profileId: 'p1',
      type: AccountType.bank,
      name: 'Checking Account',
      currency: 'INR',
      icon: 'bank',
      openingBalance: 500000,
      status: AccountStatus.active,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await accountRepo.saveAccount(acc);
  });

  tearDown(() async {
    await database.close();
  });

  test('InsightsService calculates deterministic metrics correctly', () {
    final now = DateTime.now();

    // 1. Create Mock Income (₹1000)
    final tx1 = Transaction.create(
      id: 'tx1',
      profileId: 'p1',
      type: TransactionType.income,
      date: now,
      currency: 'INR',
      totalAmount: 100000, // ₹1000
      paymentModeId: 'pm-cash',
      status: TransactionStatus.active,
      createdAt: now,
      updatedAt: now,
      categoryAllocations: [
        CategoryAllocation.create(
          id: 'ca0',
          transactionId: 'tx1',
          categoryId: 'cat-fun',
          amount: 100000,
          currency: 'INR',
        ).successOrNull!,
      ],
      transferAllocations: [
        TransferAllocation.create(
          id: 'ta0',
          transactionId: 'tx1',
          role: AllocationRole.destination,
          endpointType: EndpointType.account,
          accountId: 'acc-savings',
          amount: 100000,
          currency: 'INR',
        ).successOrNull!,
      ],
    ).successOrNull!;

    // 2. Create Mock Expense (₹200)
    final tx2 = Transaction.create(
      id: 'tx2',
      profileId: 'p1',
      type: TransactionType.expense,
      date: now,
      currency: 'INR',
      totalAmount: 20000, // ₹200
      paymentModeId: 'pm-cash',
      status: TransactionStatus.active,
      createdAt: now,
      updatedAt: now,
      categoryAllocations: [
        CategoryAllocation.create(
          id: 'ca1',
          transactionId: 'tx2',
          categoryId: 'cat-fun',
          amount: 20000,
          currency: 'INR',
        ).successOrNull!,
      ],
      transferAllocations: [
        TransferAllocation.create(
          id: 'ta1',
          transactionId: 'tx2',
          role: AllocationRole.source,
          endpointType: EndpointType.account,
          accountId: 'acc-savings',
          amount: 20000,
          currency: 'INR',
        ).successOrNull!,
      ],
    ).successOrNull!;

    final data = InsightsService.generate(
      selectedMonth: now,
      transactions: [tx1, tx2],
      accounts: const [],
      categories: const [],
      goals: const [],
      budgets: const [],
      recurringRules: const [],
    );

    // Assert: Savings = 1000 - 200 = 800 (80000 minor)
    expect(data.totalIncome, 100000);
    expect(data.totalSpending, 20000);
    expect(data.totalSavings, 80000);
    // Savings Rate = (800 / 1000) * 100 = 80%
    expect(data.savingsRate, 80.0);
  });

  blocTest<InsightsBloc, InsightsState>(
    'InsightsBloc loads and emits InsightsLoaded',
    build: () => InsightsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
      budgetRepository: budgetRepo,
      recurringRepository: recurringRepo,
    ),
    act: (bloc) => bloc.add(LoadInsights(DateTime.now())),
    expect: () => [
      const InsightsLoading(),
      isA<InsightsLoaded>()
          .having((s) => s.defaultCurrency, 'currency', 'INR')
          .having((s) => s.privacyModeEnabled, 'privacyMode', false),
    ],
  );
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
