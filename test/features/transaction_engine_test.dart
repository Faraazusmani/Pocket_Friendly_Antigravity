import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/domain/payment_mode.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/goals/domain/goal.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/services/financial_engine.dart';

void main() {
  group('Transaction Engine Mutations & Invariant Integration Tests', () {
    late AppDatabase database;
    late ProfileRepositoryImpl profileRepo;
    late AccountRepositoryImpl accountRepo;
    late CategoryRepositoryImpl categoryRepo;
    late GoalRepositoryImpl goalRepo;
    late TransactionRepositoryImpl transactionRepo;

    final now = DateTime.now();

    setUp(() async {
      final key = List<int>.generate(32, (i) => i);
      database = AppDatabase(openEncryptedConnection(key, inMemory: true));

      profileRepo = ProfileRepositoryImpl(database);
      accountRepo = AccountRepositoryImpl(database);
      categoryRepo = CategoryRepositoryImpl(database);
      goalRepo = GoalRepositoryImpl(database);
      transactionRepo = TransactionRepositoryImpl(database);

      // Initialize base structures
      final profile = Profile.create(
        id: 'p1',
        name: 'User',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await profileRepo.saveProfile(profile);

      final bankHdfc = Account.create(
        id: 'bank-hdfc',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'HDFC Bank',
        currency: 'INR',
        icon: 'bank',
        openingBalance: 10000, // INR 100.00
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(bankHdfc);

      final bankSbi = Account.create(
        id: 'bank-sbi',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'SBI Bank',
        currency: 'INR',
        icon: 'bank',
        openingBalance: 5000, // INR 50.00
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(bankSbi);

      final paymentMode = PaymentMode.create(
        id: 'pm-upi',
        profileId: 'p1',
        name: 'UPI',
        applicableAccountTypes: [AccountType.bank],
        isDefault: true,
        isSystem: false,
        status: PaymentModeStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.savePaymentMode(paymentMode);

      final catFood = Category.create(
        id: 'cat-food',
        profileId: 'p1',
        name: 'Food',
        icon: 'food',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(catFood);

      final catRent = Category.create(
        id: 'cat-rent',
        profileId: 'p1',
        name: 'Rent',
        icon: 'home',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(catRent);

      final goalHouse = Goal.create(
        id: 'goal-house',
        profileId: 'p1',
        categoryId: 'cat-goal-house',
        goalType: GoalType.standard,
        name: 'New House',
        icon: 'home',
        targetAmount: 100000,
        currency: 'INR',
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      // Need to save the Goal Category first because Goal has foreign key to Categories
      final goalCategory = Category.create(
        id: 'cat-goal-house',
        profileId: 'p1',
        name: 'Goals -> New House',
        icon: 'home',
        status: CategoryStatus.active,
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(goalCategory);
      await goalRepo.saveGoal(goalHouse);
    });

    tearDown(() async {
      await database.close();
    });

    test('Split transaction: multiple categories + multiple accounts', () async {
      // Setup Expense transaction: Rent & Food, paid split between HDFC (4000) and SBI (3000)
      // Total: 7000.
      final ca1 = CategoryAllocation.create(
        id: 'ca1',
        transactionId: 'tx-split',
        categoryId: 'cat-food',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;
      final ca2 = CategoryAllocation.create(
        id: 'ca2',
        transactionId: 'tx-split',
        categoryId: 'cat-rent',
        amount: 4000,
        currency: 'INR',
      ).successOrNull!;

      final ta1 = TransferAllocation.create(
        id: 'ta1',
        transactionId: 'tx-split',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 4000,
        currency: 'INR',
      ).successOrNull!;
      final ta2 = TransferAllocation.create(
        id: 'ta2',
        transactionId: 'tx-split',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-sbi',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;

      final tx = Transaction.create(
        id: 'tx-split',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 7000,
        paymentModeId: 'pm-upi',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca1, ca2],
        transferAllocations: [ta1, ta2],
      ).successOrNull!;

      // Save Transaction
      final saveResult = await transactionRepo.saveTransaction(tx);
      expect(saveResult.isSuccess, isTrue);

      // Verify balances
      final txnsResult = await transactionRepo.getTransactions('p1');
      final txns = txnsResult.successOrNull!;
      expect(txns.length, 1);

      final hdfc = (await accountRepo.getAccount(
        'bank-hdfc',
        'p1',
      )).successOrNull!;
      final sbi = (await accountRepo.getAccount(
        'bank-sbi',
        'p1',
      )).successOrNull!;

      // HDFC balance: 10000 - 4000 = 6000
      expect(FinancialEngine.calculateAccountBalance(hdfc, txns), 6000);
      // SBI balance: 5000 - 3000 = 2000
      expect(FinancialEngine.calculateAccountBalance(sbi, txns), 2000);
    });

    test('Transaction Editing reverses old and applies new atomically', () async {
      // 1. Create initial transaction: Expense 3000 from HDFC on Food
      final ca = CategoryAllocation.create(
        id: 'ca-init',
        transactionId: 'tx-mutable',
        categoryId: 'cat-food',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;
      final ta = TransferAllocation.create(
        id: 'ta-init',
        transactionId: 'tx-mutable',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;

      final txInit = Transaction.create(
        id: 'tx-mutable',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 3000,
        paymentModeId: 'pm-upi',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca],
        transferAllocations: [ta],
      ).successOrNull!;
      await transactionRepo.saveTransaction(txInit);

      var txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      var hdfc = (await accountRepo.getAccount(
        'bank-hdfc',
        'p1',
      )).successOrNull!;
      expect(
        FinancialEngine.calculateAccountBalance(hdfc, txns),
        7000,
      ); // 10000 - 3000 = 7000

      // 2. Edit transaction: Change amount to 6000 (Expense on Rent, from HDFC)
      final caNew = CategoryAllocation.create(
        id: 'ca-new',
        transactionId: 'tx-mutable',
        categoryId: 'cat-rent',
        amount: 6000,
        currency: 'INR',
      ).successOrNull!;
      final taNew = TransferAllocation.create(
        id: 'ta-new',
        transactionId: 'tx-mutable',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 6000,
        currency: 'INR',
      ).successOrNull!;

      final txEdit = Transaction.create(
        id: 'tx-mutable',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 6000,
        paymentModeId: 'pm-upi',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [caNew],
        transferAllocations: [taNew],
      ).successOrNull!;
      await transactionRepo.saveTransaction(txEdit);

      // Verify rollback & apply occurred: previous HDFC balance change is completely reversed, and 6000 is applied
      txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      hdfc = (await accountRepo.getAccount('bank-hdfc', 'p1')).successOrNull!;
      expect(
        FinancialEngine.calculateAccountBalance(hdfc, txns),
        4000,
      ); // 10000 - 6000 = 4000
    });

    test('Transaction deletion rolls back all financial effects', () async {
      final ca = CategoryAllocation.create(
        id: 'ca-del',
        transactionId: 'tx-delete',
        categoryId: 'cat-food',
        amount: 4000,
        currency: 'INR',
      ).successOrNull!;
      final ta = TransferAllocation.create(
        id: 'ta-del',
        transactionId: 'tx-delete',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 4000,
        currency: 'INR',
      ).successOrNull!;

      final tx = Transaction.create(
        id: 'tx-delete',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 4000,
        paymentModeId: 'pm-upi',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca],
        transferAllocations: [ta],
      ).successOrNull!;
      await transactionRepo.saveTransaction(tx);

      var txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      var hdfc = (await accountRepo.getAccount(
        'bank-hdfc',
        'p1',
      )).successOrNull!;
      expect(
        FinancialEngine.calculateAccountBalance(hdfc, txns),
        6000,
      ); // 10000 - 4000 = 6000

      // Delete
      await transactionRepo.deleteTransaction('tx-delete', 'p1');

      // Verify HDFC balance is fully restored to 10000
      txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      hdfc = (await accountRepo.getAccount('bank-hdfc', 'p1')).successOrNull!;
      expect(FinancialEngine.calculateAccountBalance(hdfc, txns), 10000);
    });

    test(
      'Balance adjustment behaves correctly and does not affect category spending',
      () async {
        // Make a positive balance adjustment on HDFC of +3000 (destination)
        final taAdj = TransferAllocation.create(
          id: 'ta-adj',
          transactionId: 'tx-adj',
          role: AllocationRole.destination,
          endpointType: EndpointType.account,
          accountId: 'bank-hdfc',
          amount: 3000,
          currency: 'INR',
        ).successOrNull!;

        final txAdj = Transaction.create(
          id: 'tx-adj',
          profileId: 'p1',
          type: TransactionType.income,
          subtype: 'balanceAdjustment',
          date: now,
          currency: 'INR',
          totalAmount: 3000,
          paymentModeId: 'pm-upi',
          status: TransactionStatus.active,
          createdAt: now,
          updatedAt: now,
          categoryAllocations: [],
          transferAllocations: [taAdj],
        ).successOrNull!;

        await transactionRepo.saveTransaction(txAdj);

        final txns = (await transactionRepo.getTransactions(
          'p1',
        )).successOrNull!;
        final hdfc = (await accountRepo.getAccount(
          'bank-hdfc',
          'p1',
        )).successOrNull!;

        // HDFC balance increases to 13000 (10000 + 3000)
        expect(FinancialEngine.calculateAccountBalance(hdfc, txns), 13000);

        // Verify category spending remains 0 for any categories (e.g. food/rent)
        expect(
          FinancialEngine.calculateCategorySpent(
            categoryId: 'cat-food',
            transactions: txns,
          ),
          0,
        );
        expect(
          FinancialEngine.calculateCategorySpent(
            categoryId: 'cat-rent',
            transactions: txns,
          ),
          0,
        );
      },
    );

    test(
      'Goal withdrawal limit invariant: Goal balance cannot drop below zero',
      () async {
        // 1. Initial Deposit to Goal: 5000 from HDFC Bank
        final depositSrc = TransferAllocation.create(
          id: 'ta-dep-src',
          transactionId: 'tx-goal-deposit',
          role: AllocationRole.source,
          endpointType: EndpointType.account,
          accountId: 'bank-hdfc',
          amount: 5000,
          currency: 'INR',
        ).successOrNull!;
        final depositDst = TransferAllocation.create(
          id: 'ta-dep-dst',
          transactionId: 'tx-goal-deposit',
          role: AllocationRole.destination,
          endpointType: EndpointType.goal,
          goalId: 'goal-house',
          amount: 5000,
          currency: 'INR',
        ).successOrNull!;
        final depositTx = Transaction.create(
          id: 'tx-goal-deposit',
          profileId: 'p1',
          type: TransactionType.transfer,
          date: now,
          currency: 'INR',
          totalAmount: 5000,
          paymentModeId: 'pm-upi',
          status: TransactionStatus.active,
          createdAt: now,
          updatedAt: now,
          categoryAllocations: [],
          transferAllocations: [depositSrc, depositDst],
        ).successOrNull!;
        await transactionRepo.saveTransaction(depositTx);

        final goal = (await goalRepo.getGoal(
          'goal-house',
          'p1',
        )).successOrNull!;
        var txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
        expect(FinancialEngine.calculateGoalBalance(goal, txns), 5000);

        // 2. Try to withdraw 6000 from Goal (exceeding balance). Should fail!
        final badWithdrawSrc = TransferAllocation.create(
          id: 'ta-wdr-src-bad',
          transactionId: 'tx-goal-withdraw-bad',
          role: AllocationRole.source,
          endpointType: EndpointType.goal,
          goalId: 'goal-house',
          amount: 6000,
          currency: 'INR',
        ).successOrNull!;
        final badWithdrawDst = TransferAllocation.create(
          id: 'ta-wdr-dst-bad',
          transactionId: 'tx-goal-withdraw-bad',
          role: AllocationRole.destination,
          endpointType: EndpointType.account,
          accountId: 'bank-hdfc',
          amount: 6000,
          currency: 'INR',
        ).successOrNull!;
        final badWithdrawTx = Transaction.create(
          id: 'tx-goal-withdraw-bad',
          profileId: 'p1',
          type: TransactionType.transfer,
          date: now,
          currency: 'INR',
          totalAmount: 6000,
          paymentModeId: 'pm-upi',
          status: TransactionStatus.active,
          createdAt: now,
          updatedAt: now,
          categoryAllocations: [],
          transferAllocations: [badWithdrawSrc, badWithdrawDst],
        ).successOrNull!;

        final badResult = await transactionRepo.saveTransaction(badWithdrawTx);
        expect(badResult.isFailure, isTrue);
        expect(
          badResult.failureOrNull?.message,
          contains('exceeds available goal balance'),
        );

        // 3. Withdraw 4000 from Goal. Should succeed!
        final okWithdrawSrc = TransferAllocation.create(
          id: 'ta-wdr-src-ok',
          transactionId: 'tx-goal-withdraw-ok',
          role: AllocationRole.source,
          endpointType: EndpointType.goal,
          goalId: 'goal-house',
          amount: 4000,
          currency: 'INR',
        ).successOrNull!;
        final okWithdrawDst = TransferAllocation.create(
          id: 'ta-wdr-dst-ok',
          transactionId: 'tx-goal-withdraw-ok',
          role: AllocationRole.destination,
          endpointType: EndpointType.account,
          accountId: 'bank-hdfc',
          amount: 4000,
          currency: 'INR',
        ).successOrNull!;
        final okWithdrawTx = Transaction.create(
          id: 'tx-goal-withdraw-ok',
          profileId: 'p1',
          type: TransactionType.transfer,
          date: now,
          currency: 'INR',
          totalAmount: 4000,
          paymentModeId: 'pm-upi',
          status: TransactionStatus.active,
          createdAt: now,
          updatedAt: now,
          categoryAllocations: [],
          transferAllocations: [okWithdrawSrc, okWithdrawDst],
        ).successOrNull!;

        final okResult = await transactionRepo.saveTransaction(okWithdrawTx);
        expect(okResult.isSuccess, isTrue);

        txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
        expect(
          FinancialEngine.calculateGoalBalance(goal, txns),
          1000,
        ); // 5000 - 4000 = 1000
      },
    );
  });
}
