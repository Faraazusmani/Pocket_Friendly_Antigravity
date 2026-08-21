import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:pocket_friendly/features/budgets/domain/budget.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/domain/services/financial_engine.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';

void main() {
  late AppDatabase database;
  late BudgetRepositoryImpl budgetRepository;

  setUp(() {
    // Open memory connection with openEncryptedConnection setup to enable foreign keys
    final keyBytes = List<int>.generate(32, (i) => i);
    database = AppDatabase(openEncryptedConnection(keyBytes, inMemory: true));
    budgetRepository = BudgetRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('Profile deletion cascades to delete all associated records', () async {
    final now = DateTime.now();

    // 1. Insert Profile
    await database
        .into(database.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: 'p_test',
            name: 'Test Profile',
            defaultCurrency: 'USD',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 2. Insert Account referencing Profile
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'a_test',
            profileId: 'p_test',
            type: 'Bank',
            name: 'My Bank',
            currency: 'USD',
            icon: 'bank',
            openingBalance: 10000,
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Assert account exists
    var accounts = await database.select(database.accounts).get();
    expect(accounts.length, 1);

    // 3. Delete Profile
    await database.delete(database.profiles).go();

    // Assert cascade deleted the account
    accounts = await database.select(database.accounts).get();
    expect(accounts.length, 0);
  });

  test(
    'Budget carry-forward is fully idempotent and doesn\'t double count',
    () async {
      final now = DateTime.now();

      // Setup base tables
      await database
          .into(database.profiles)
          .insert(
            ProfilesCompanion.insert(
              id: 'p_budget',
              name: 'Budget Profile',
              defaultCurrency: 'USD',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'c_food',
              profileId: 'p_budget',
              name: 'Food',
              icon: 'fastfood',
              status: 'active',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Source Month: August 2026, Target Month: September 2026
      // Save Category Budget in Source Month
      final budgetRes = Budget.create(
        id: 'b_august',
        profileId: 'p_budget',
        categoryId: 'c_food',
        month: 8,
        year: 2026,
        baseAmount: 10000, // $100.00
        carryForwardAmount: 0,
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      );
      await budgetRepository.saveCategoryBudget(budgetRes.successOrNull!);

      // Run carry forward once
      final cf1 = await budgetRepository.carryForward(
        profileId: 'p_budget',
        sourceMonth: 8,
        sourceYear: 2026,
        targetMonth: 9,
        targetYear: 2026,
        currency: 'USD',
      );
      expect(cf1.isSuccess, true);

      // Get Target Pool
      var poolRes = await budgetRepository.getUnallocatedBudgetPool(
        profileId: 'p_budget',
        month: 9,
        year: 2026,
        currency: 'USD',
      );
      expect(poolRes.successOrNull!.amount, 10000);
      expect(poolRes.successOrNull!.carriedForwardAmount, 10000);

      // Run carry forward again (should overwrite/deduplicate and keep target at 10000)
      final cf2 = await budgetRepository.carryForward(
        profileId: 'p_budget',
        sourceMonth: 8,
        sourceYear: 2026,
        targetMonth: 9,
        targetYear: 2026,
        currency: 'USD',
      );
      expect(cf2.isSuccess, true);

      poolRes = await budgetRepository.getUnallocatedBudgetPool(
        profileId: 'p_budget',
        month: 9,
        year: 2026,
        currency: 'USD',
      );
      expect(poolRes.successOrNull!.amount, 10000); // Idempotent!
    },
  );

  test('FinancialEngine isolates calculations by currency', () async {
    final account = Account.create(
      id: 'acc_usd',
      profileId: 'p1',
      type: AccountType.bank,
      name: 'USD Account',
      currency: 'USD',
      icon: 'attach_money',
      openingBalance: 1000,
      status: AccountStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).successOrNull!;

    final txUsd = Transaction.create(
      id: 'tx_usd',
      profileId: 'p1',
      type: TransactionType.expense,
      date: DateTime.now(),
      currency: 'USD',
      totalAmount: 200,
      paymentModeId: 'pm1',
      status: TransactionStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      categoryAllocations: [
        CategoryAllocation.create(
          id: 'ca_usd',
          transactionId: 'tx_usd',
          categoryId: 'cat_dummy',
          amount: 200,
          currency: 'USD',
        ).successOrNull!,
      ],
      transferAllocations: [
        TransferAllocation.create(
          id: 'ta1',
          transactionId: 'tx_usd',
          role: AllocationRole.source,
          endpointType: EndpointType.account,
          accountId: 'acc_usd',
          amount: 200,
          currency: 'USD',
        ).successOrNull!,
      ],
    ).successOrNull!;

    final txEur = Transaction.create(
      id: 'tx_eur',
      profileId: 'p1',
      type: TransactionType.expense,
      date: DateTime.now(),
      currency: 'EUR',
      totalAmount: 150,
      paymentModeId: 'pm1',
      status: TransactionStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      categoryAllocations: [
        CategoryAllocation.create(
          id: 'ca_eur',
          transactionId: 'tx_eur',
          categoryId: 'cat_dummy',
          amount: 150,
          currency: 'EUR',
        ).successOrNull!,
      ],
      transferAllocations: [
        TransferAllocation.create(
          id: 'ta2',
          transactionId: 'tx_eur',
          role: AllocationRole.source,
          endpointType: EndpointType.account,
          accountId: 'acc_usd',
          amount: 150,
          currency: 'EUR',
        ).successOrNull!,
      ],
    ).successOrNull!;

    // Calculates balance by ignoring the EUR allocation and subtracting only the USD allocation
    final balance = FinancialEngine.calculateAccountBalance(account, [
      txUsd,
      txEur,
    ]);
    expect(balance, 800); // 1000 - 200
  });
}
