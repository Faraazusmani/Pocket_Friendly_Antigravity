import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/domain/payment_mode.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/goals/domain/goal.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/services/financial_engine.dart';

void main() {
  group('Goal Domain & Required Contribution Calculations Tests', () {
    final now = DateTime(2026, 8, 20);

    test('Goal default target date projection (1 year from creation)', () {
      final goal = Goal.create(
        id: 'g1',
        profileId: 'p1',
        categoryId: 'cat-g1',
        goalType: GoalType.standard,
        name: 'Car Fund',
        icon: 'car',
        targetAmount: 500000,
        currency: 'INR',
        targetDate: null, // Null target date
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;

      expect(goal.effectiveTargetDate, DateTime(2027, 8, 20));
      expect(goal.isExpired(DateTime(2027, 8, 21)), isTrue);
      expect(goal.isExpired(DateTime(2027, 8, 19)), isFalse);
    });

    test(
      'Goal calculateRequiredMonthlyContribution projects correct SIP requirements',
      () {
        final goal = Goal.create(
          id: 'g1',
          profileId: 'p1',
          categoryId: 'cat-g1',
          goalType: GoalType.sip,
          name: 'House Downpayment',
          icon: 'house',
          targetAmount: 120000,
          currency: 'INR',
          targetDate: DateTime(2027, 8, 20), // Exactly 12 months from now
          status: GoalStatus.active,
          createdAt: now,
          updatedAt: now,
        ).successOrNull!;

        // 1. Starting at 0 balance, 12 months remaining
        expect(
          goal.calculateRequiredMonthlyContribution(0, now),
          10000,
        ); // 120000 / 12 = 10000

        // 2. balance is 40000, 8 months remaining (say in December 2026, which is 4 months later)
        final dec2026 = DateTime(2026, 12, 20);
        // months remaining = (2027 - 2026)*12 + 8 - 12 = 8
        expect(
          goal.calculateRequiredMonthlyContribution(40000, dec2026),
          10000,
        ); // (120000 - 40000) / 8 = 10000

        // 3. balance is 100000, 2 months remaining (June 2027)
        final june2027 = DateTime(2027, 6, 20);
        expect(
          goal.calculateRequiredMonthlyContribution(100000, june2027),
          10000,
        ); // (120000 - 100000) / 2 = 10000

        // 4. Past target date (expired) -> returns remaining amount directly
        expect(
          goal.calculateRequiredMonthlyContribution(
            110000,
            DateTime(2027, 9, 20),
          ),
          10000,
        );
      },
    );
  });

  group('Goal Contributions and Withdrawals Integration Tests', () {
    late AppDatabase database;
    late ProfileRepositoryImpl profileRepo;
    late CategoryRepositoryImpl categoryRepo;
    late AccountRepositoryImpl accountRepo;
    late TransactionRepositoryImpl transactionRepo;
    late GoalRepositoryImpl goalRepo;

    final now = DateTime.now();

    setUp(() async {
      final key = List<int>.generate(32, (i) => i);
      database = AppDatabase(openEncryptedConnection(key, inMemory: true));

      profileRepo = ProfileRepositoryImpl(database);
      categoryRepo = CategoryRepositoryImpl(database);
      accountRepo = AccountRepositoryImpl(database);
      transactionRepo = TransactionRepositoryImpl(database);
      goalRepo = GoalRepositoryImpl(database);

      // Save initial profile
      final profile = Profile.create(
        id: 'p1',
        name: 'Faraaz',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await profileRepo.saveProfile(profile);

      // Save checking account
      final account = Account.create(
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
      await accountRepo.saveAccount(account);

      // Save payment mode
      final pm = PaymentMode.create(
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
      await accountRepo.savePaymentMode(pm);

      // Create linked Goal subcategory
      final goalCategory = Category.create(
        id: 'cat-goal-car',
        profileId: 'p1',
        name: 'Goal: New Car',
        icon: 'car',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(goalCategory);

      // Save Goal
      final goal = Goal.create(
        id: 'goal-car',
        profileId: 'p1',
        categoryId: 'cat-goal-car',
        goalType: GoalType.standard,
        name: 'New Car',
        icon: 'car',
        targetAmount: 500000,
        currency: 'INR',
        targetDate: null,
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await goalRepo.saveGoal(goal);
    });

    tearDown(() async {
      await database.close();
    });

    test('Goal contributions are EXPENSES, withdrawals are TRANSFERS', () async {
      final goal = (await goalRepo.getGoal('goal-car', 'p1')).successOrNull!;

      // 1. Verify initial state
      var txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      expect(FinancialEngine.calculateGoalBalance(goal, txns), 0);
      expect(FinancialEngine.calculateGoalProgressPercent(goal, txns), 0.0);

      // 2. Perform contribution (EXPENSE transaction)
      final contribCa = CategoryAllocation.create(
        id: 'ca-c1',
        transactionId: 'tx-c1',
        categoryId: 'cat-goal-car',
        amount: 30000,
        currency: 'INR',
      ).successOrNull!;
      final contribTa = TransferAllocation.create(
        id: 'ta-c1',
        transactionId: 'tx-c1',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'acc-hdfc',
        amount: 30000,
        currency: 'INR',
      ).successOrNull!;

      final contributionTx = Transaction.create(
        id: 'tx-c1',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 30000,
        paymentModeId: 'pm-upi',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [contribCa],
        transferAllocations: [contribTa],
      ).successOrNull!;

      final contribResult = await transactionRepo.saveTransaction(
        contributionTx,
      );
      expect(contribResult.isSuccess, isTrue);

      // Verify that HDFC Account balance decreases
      final acc = (await accountRepo.getAccount(
        'acc-hdfc',
        'p1',
      )).successOrNull!;
      txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      expect(
        FinancialEngine.calculateAccountBalance(acc, txns),
        70000,
      ); // 100000 - 30000 = 70000

      // Verify that Goal balance and progress increases
      expect(FinancialEngine.calculateGoalBalance(goal, txns), 30000);
      expect(
        FinancialEngine.calculateGoalProgressPercent(goal, txns),
        6.0,
      ); // (30000 / 500000) * 100 = 6%

      // Verify that it increases category spending
      expect(
        FinancialEngine.calculateCategorySpent(
          categoryId: 'cat-goal-car',
          transactions: txns,
        ),
        30000,
      );

      // 3. Perform withdrawal (TRANSFER transaction from Goal to HDFC Account)
      final withdrawSrc = TransferAllocation.create(
        id: 'ta-w1-src',
        transactionId: 'tx-w1',
        role: AllocationRole.source,
        endpointType: EndpointType.goal,
        goalId: 'goal-car',
        amount: 10000,
        currency: 'INR',
      ).successOrNull!;

      final withdrawDst = TransferAllocation.create(
        id: 'ta-w1-dst',
        transactionId: 'tx-w1',
        role: AllocationRole.destination,
        endpointType: EndpointType.account,
        accountId: 'acc-hdfc',
        amount: 10000,
        currency: 'INR',
      ).successOrNull!;

      final withdrawalTx = Transaction.create(
        id: 'tx-w1',
        profileId: 'p1',
        type: TransactionType.transfer,
        date: now,
        currency: 'INR',
        totalAmount: 10000,
        paymentModeId: 'pm-upi',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [withdrawSrc, withdrawDst],
      ).successOrNull!;

      final withdrawResult = await transactionRepo.saveTransaction(
        withdrawalTx,
      );
      expect(withdrawResult.isSuccess, isTrue);

      // Verify HDFC account increases (70000 + 10000 = 80000)
      txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      expect(FinancialEngine.calculateAccountBalance(acc, txns), 80000);

      // Verify Goal balance decreases (30000 - 10000 = 20000)
      expect(FinancialEngine.calculateGoalBalance(goal, txns), 20000);
      expect(FinancialEngine.calculateGoalProgressPercent(goal, txns), 4.0);

      // Verify withdrawal never increases category spending (stays at 30000 contribution)
      expect(
        FinancialEngine.calculateCategorySpent(
          categoryId: 'cat-goal-car',
          transactions: txns,
        ),
        30000,
      );

      // 4. Test Goal withdrawal limit invariant block
      final badWithdrawSrc = TransferAllocation.create(
        id: 'ta-w2-src',
        transactionId: 'tx-w2',
        role: AllocationRole.source,
        endpointType: EndpointType.goal,
        goalId: 'goal-car',
        amount: 25000, // Exceeds current Goal balance of 20000
        currency: 'INR',
      ).successOrNull!;

      final badWithdrawDst = TransferAllocation.create(
        id: 'ta-w2-dst',
        transactionId: 'tx-w2',
        role: AllocationRole.destination,
        endpointType: EndpointType.account,
        accountId: 'acc-hdfc',
        amount: 25000,
        currency: 'INR',
      ).successOrNull!;

      final badWithdrawalTx = Transaction.create(
        id: 'tx-w2',
        profileId: 'p1',
        type: TransactionType.transfer,
        date: now,
        currency: 'INR',
        totalAmount: 25000,
        paymentModeId: 'pm-upi',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [badWithdrawSrc, badWithdrawDst],
      ).successOrNull!;

      final badResult = await transactionRepo.saveTransaction(badWithdrawalTx);
      expect(badResult.isFailure, isTrue);
      expect(
        badResult.failureOrNull?.message,
        contains('exceeds available goal balance'),
      );
    });
  });
}
