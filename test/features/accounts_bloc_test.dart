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
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/presentation/bloc/accounts_bloc.dart';
import 'package:pocket_friendly/features/accounts/presentation/bloc/accounts_event.dart';
import 'package:pocket_friendly/features/accounts/presentation/bloc/accounts_state.dart';

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

    profileRepo = ProfileRepositoryImpl(database);
    accountRepo = AccountRepositoryImpl(database);
    categoryRepo = CategoryRepositoryImpl(database);
    transactionRepo = TransactionRepositoryImpl(database);
    goalRepo = GoalRepositoryImpl(database);

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

    // Insert sample category (needed for goal links)
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
  });

  tearDown(() async {
    await database.close();
  });

  blocTest<AccountsBloc, AccountsState>(
    'LoadAccounts emits AccountsLoaded state with calculated stats',
    build: () => AccountsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
    ),
    act: (bloc) async {
      // 1. Create a Bank account
      final now = DateTime.now();
      final bank = Account.create(
        id: 'acc-hdfc',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'HDFC Bank',
        currency: 'INR',
        icon: 'bank',
        openingBalance: 100000, // 1000 INR
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(bank);

      // 2. Dispatch LoadAccounts
      bloc.add(const LoadAccounts());
    },
    expect: () => [
      const AccountsLoading(),
      isA<AccountsLoaded>()
          .having((s) => s.accounts.length, 'accounts length', 1)
          .having(
            (s) => s.currencyStats['INR']?['netWorth'],
            'netWorth',
            100000,
          )
          .having((s) => s.currencyStats['INR']?['assets'], 'assets', 100000)
          .having(
            (s) => s.currencyStats['INR']?['liabilities'],
            'liabilities',
            0,
          ),
    ],
  );

  blocTest<AccountsBloc, AccountsState>(
    'CreateAccount saves account and triggers ActionSuccess',
    build: () => AccountsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
    ),
    act: (bloc) => bloc.add(
      const CreateAccount(
        name: 'Wallet Cash',
        type: AccountType.cash,
        openingBalance: 5000,
        currency: 'INR',
        icon: 'wallet',
      ),
    ),
    expect: () => [
      const AccountsLoading(),
      const AccountActionSuccess('Account created successfully'),
    ],
    verify: (_) async {
      final accs = await accountRepo.getAccounts('p1');
      expect(accs.successOrNull?.length, 1);
      expect(accs.successOrNull?.first.name, 'Wallet Cash');
    },
  );

  blocTest<AccountsBloc, AccountsState>(
    'ArchiveAccount updates account status and archives it',
    build: () => AccountsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
    ),
    act: (bloc) async {
      final now = DateTime.now();
      final bank = Account.create(
        id: 'acc-hdfc',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'HDFC Bank',
        currency: 'INR',
        icon: 'bank',
        openingBalance: 100000,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(bank);

      bloc.add(const ArchiveAccount('acc-hdfc'));
    },
    expect: () => [
      const AccountsLoading(),
      const AccountActionSuccess('Account archived successfully'),
    ],
    verify: (_) async {
      final activeAccs = await accountRepo.getAccounts(
        'p1',
        includeArchived: false,
      );
      final archivedAccs = await accountRepo.getAccounts(
        'p1',
        includeArchived: true,
      );
      expect(activeAccs.successOrNull?.length, 0);
      expect(archivedAccs.successOrNull?.length, 1);
      expect(archivedAccs.successOrNull?.first.status, AccountStatus.archived);
    },
  );

  blocTest<AccountsBloc, AccountsState>(
    'AdjustAccountBalance (Asset Positive) creates Income Balance Adjustment transaction',
    build: () => AccountsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
    ),
    act: (bloc) async {
      final now = DateTime.now();
      final bank = Account.create(
        id: 'acc-hdfc',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'HDFC Bank',
        currency: 'INR',
        icon: 'bank',
        openingBalance: 10000, // 100 INR
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(bank);

      // Adjust balance from 100 INR to 150 INR (actual balance 15000 minor units)
      bloc.add(
        const AdjustAccountBalance(accountId: 'acc-hdfc', actualBalance: 15000),
      );
    },
    expect: () => [
      const AccountsLoading(),
      const AccountActionSuccess('Balance adjusted successfully'),
    ],
    verify: (_) async {
      final txs = (await transactionRepo.getTransactions('p1')).successOrNull!;
      expect(txs.length, 1);
      expect(txs.first.type, TransactionType.income);
      expect(txs.first.subtype, 'balanceAdjustment');
      expect(txs.first.totalAmount, 5000); // +50 INR
      expect(
        txs.first.transferAllocations.first.role,
        AllocationRole.destination,
      );
    },
  );

  blocTest<AccountsBloc, AccountsState>(
    'AdjustAccountBalance (Credit Card negative available credit) increases Card Outstanding',
    build: () => AccountsBloc(
      profileRepository: profileRepo,
      accountRepository: accountRepo,
      transactionRepository: transactionRepo,
      goalRepository: goalRepo,
    ),
    act: (bloc) async {
      final now = DateTime.now();
      final cc = Account.create(
        id: 'acc-card',
        profileId: 'p1',
        type: AccountType.creditCard,
        name: 'Amazon ICICI',
        currency: 'INR',
        icon: 'card',
        openingBalance: 0,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
        creditLimit: 100000,
        openingOutstanding: 5000, // 50 INR debt
        billGenerationDay: 15,
      ).successOrNull!;
      await accountRepo.saveAccount(cc);

      // Adjust outstanding debt from 50 INR to 80 INR (actual outstanding 8000 minor units)
      // Increasing debt is an Expense balance adjustment transaction (+30 INR)
      bloc.add(
        const AdjustAccountBalance(accountId: 'acc-card', actualBalance: 8000),
      );
    },
    expect: () => [
      const AccountsLoading(),
      const AccountActionSuccess('Balance adjusted successfully'),
    ],
    verify: (_) async {
      final txs = (await transactionRepo.getTransactions('p1')).successOrNull!;
      expect(txs.length, 1);
      expect(txs.first.type, TransactionType.expense);
      expect(txs.first.subtype, 'balanceAdjustment');
      expect(txs.first.totalAmount, 3000); // 30 INR
      expect(txs.first.transferAllocations.first.role, AllocationRole.source);
    },
  );
}
