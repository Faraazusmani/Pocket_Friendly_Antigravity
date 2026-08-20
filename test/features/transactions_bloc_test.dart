import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
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
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:pocket_friendly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/presentation/bloc/transactions_bloc.dart';
import 'package:pocket_friendly/features/transactions/presentation/bloc/transactions_event.dart';
import 'package:pocket_friendly/features/transactions/presentation/bloc/transactions_state.dart';

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

    profileRepo = ProfileRepositoryImpl(database);
    accountRepo = AccountRepositoryImpl(database);
    categoryRepo = CategoryRepositoryImpl(database);
    transactionRepo = TransactionRepositoryImpl(database);
    goalRepo = GoalRepositoryImpl(database);
    recurringRepo = RecurringRepositoryImpl(database);

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

  blocTest<TransactionsBloc, TransactionsState>(
    'LoadTransactionFormMetadata fetches all relevant database models',
    build: () => TransactionsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
      recurringRepository: recurringRepo,
    ),
    act: (bloc) => bloc.add(const LoadTransactionFormMetadata()),
    expect: () => [
      const TransactionFormLoading(),
      isA<TransactionFormMetadataLoaded>()
          .having((s) => s.accounts.length, 'accounts length', 1)
          .having((s) => s.categories.length, 'categories length', 1)
          .having((s) => s.paymentModes.length, 'payment modes length', 1)
          .having((s) => s.profileId, 'profileId', 'p1')
          .having((s) => s.defaultCurrency, 'defaultCurrency', 'INR'),
    ],
  );

  blocTest<TransactionsBloc, TransactionsState>(
    'SaveTransaction creates standard Expense transaction successfully',
    build: () => TransactionsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
      recurringRepository: recurringRepo,
    ),
    seed: () => const TransactionFormMetadataLoaded(
      accounts: [],
      categories: [],
      goals: [],
      tags: [],
      paymentModes: [],
      profileId: 'p1',
      defaultCurrency: 'INR',
    ),
    act: (bloc) => bloc.add(
      SaveTransaction(
        type: TransactionType.expense,
        totalAmount: 1500, // 15 INR
        date: DateTime.now(),
        paymentModeId: 'pm-debit-card',
        categoryAllocations: const [
          CategoryAllocationInput(categoryId: 'cat-grocery', amount: 1500),
        ],
        transferAllocations: const [
          TransferAllocationInput(
            role: 'source',
            endpointType: 'account',
            accountId: 'acc-hdfc',
            amount: 1500,
          ),
        ],
      ),
    ),
    expect: () => [
      const TransactionFormLoading(),
      const TransactionSaveSuccess('Transaction recorded successfully'),
    ],
    verify: (_) async {
      final txs = await transactionRepo.getTransactions('p1');
      expect(txs.successOrNull?.length, 1);
      expect(txs.successOrNull?.first.totalAmount, 1500);
      expect(txs.successOrNull?.first.type, TransactionType.expense);
    },
  );

  blocTest<TransactionsBloc, TransactionsState>(
    'SaveTransaction rejects transaction if splits sum mismatch',
    build: () => TransactionsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
      recurringRepository: recurringRepo,
    ),
    seed: () => const TransactionFormMetadataLoaded(
      accounts: [],
      categories: [],
      goals: [],
      tags: [],
      paymentModes: [],
      profileId: 'p1',
      defaultCurrency: 'INR',
    ),
    act: (bloc) => bloc.add(
      SaveTransaction(
        type: TransactionType.expense,
        totalAmount: 2000, // Total is 20 INR
        date: DateTime.now(),
        paymentModeId: 'pm-debit-card',
        categoryAllocations: const [
          CategoryAllocationInput(
            categoryId: 'cat-grocery',
            amount: 1500,
          ), // sum is 15 INR (mismatch!)
        ],
        transferAllocations: const [
          TransferAllocationInput(
            role: 'source',
            endpointType: 'account',
            accountId: 'acc-hdfc',
            amount: 2000,
          ),
        ],
      ),
    ),
    expect: () => [
      const TransactionFormLoading(),
      isA<TransactionFormError>().having(
        (s) => s.message,
        'error message',
        contains('does not match transaction total'),
      ),
    ],
  );
}
