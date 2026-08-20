import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';

import 'package:pocket_friendly/features/goals/domain/goal.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/domain/services/financial_engine.dart';

void main() {
  group('FinancialEngine Derived Calculations Tests', () {
    final now = DateTime.now();

    // 1. Setup mock asset and CC accounts
    final bankAccount = Account.create(
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

    final ccAccount = Account.create(
      id: 'cc-prime',
      profileId: 'p1',
      type: AccountType.creditCard,
      name: 'Amazon Prime Card',
      currency: 'INR',
      icon: 'card',
      openingBalance: 0,
      status: AccountStatus.active,
      createdAt: now,
      updatedAt: now,
      creditLimit: 50000, // INR 500.00 limit
      openingOutstanding: 5000, // INR 50.00 initial outstanding
      billGenerationDay: 15,
    ).successOrNull!;

    // 2. Setup mock goals
    final goalCar = Goal.create(
      id: 'goal-car',
      profileId: 'p1',
      categoryId: 'cat-goal-car',
      goalType: GoalType.standard,
      name: 'Buy Car',
      icon: 'car',
      targetAmount: 500000,
      currency: 'INR',
      status: GoalStatus.active,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;

    // 3. Transactions List setup
    final txList = <Transaction>[];

    setUp(() {
      txList.clear();
    });

    test('Derived Asset Account Balance after Income and Expense', () {
      // Intial: 10000 (INR 100)
      expect(
        FinancialEngine.calculateAccountBalance(bankAccount, txList),
        10000,
      );

      // Income transaction of 5000 (INR 50)
      final incomeCa = CategoryAllocation.create(
        id: 'ca1',
        transactionId: 'tx-inc',
        categoryId: 'cat-salary',
        amount: 5000,
        currency: 'INR',
      ).successOrNull!;
      final incomeTa = TransferAllocation.create(
        id: 'ta1',
        transactionId: 'tx-inc',
        role: AllocationRole.destination,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 5000,
        currency: 'INR',
      ).successOrNull!;
      final incomeTx = Transaction.create(
        id: 'tx-inc',
        profileId: 'p1',
        type: TransactionType.income,
        date: now,
        currency: 'INR',
        totalAmount: 5000,
        paymentModeId: 'pm-bank',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [incomeCa],
        transferAllocations: [incomeTa],
      ).successOrNull!;
      txList.add(incomeTx);

      expect(
        FinancialEngine.calculateAccountBalance(bankAccount, txList),
        15000,
      );

      // Expense transaction of 3000 (INR 30)
      final expenseCa = CategoryAllocation.create(
        id: 'ca2',
        transactionId: 'tx-exp',
        categoryId: 'cat-food',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;
      final expenseTa = TransferAllocation.create(
        id: 'ta2',
        transactionId: 'tx-exp',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;
      final expenseTx = Transaction.create(
        id: 'tx-exp',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 3000,
        paymentModeId: 'pm-bank',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [expenseCa],
        transferAllocations: [expenseTa],
      ).successOrNull!;
      txList.add(expenseTx);

      expect(
        FinancialEngine.calculateAccountBalance(bankAccount, txList),
        12000,
      );
    });

    test('Derived Credit Card Outstanding & Available Credit', () {
      // Initial: outstanding = 5000 (INR 50), limit = 50000 (INR 500), available = 45000
      expect(
        FinancialEngine.calculateCreditCardOutstanding(ccAccount, txList),
        5000,
      );
      expect(
        FinancialEngine.calculateCreditCardAvailableCredit(ccAccount, txList),
        45000,
      );

      // Expense on credit card: 2000 (INR 20)
      final expenseCa = CategoryAllocation.create(
        id: 'ca3',
        transactionId: 'tx-cc-exp',
        categoryId: 'cat-shopping',
        amount: 2000,
        currency: 'INR',
      ).successOrNull!;
      final expenseTa = TransferAllocation.create(
        id: 'ta3',
        transactionId: 'tx-cc-exp',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'cc-prime',
        amount: 2000,
        currency: 'INR',
      ).successOrNull!;
      final ccExpenseTx = Transaction.create(
        id: 'tx-cc-exp',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 2000,
        paymentModeId: 'pm-cc',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [expenseCa],
        transferAllocations: [expenseTa],
      ).successOrNull!;
      txList.add(ccExpenseTx);

      // Outstanding should increase to 7000, available credit drops to 43000
      expect(
        FinancialEngine.calculateCreditCardOutstanding(ccAccount, txList),
        7000,
      );
      expect(
        FinancialEngine.calculateCreditCardAvailableCredit(ccAccount, txList),
        43000,
      );

      // CC Bill Repayment: 4000 (INR 40) transfer from HDFC Bank to CC
      final repaymentTaSource = TransferAllocation.create(
        id: 'ta4-src',
        transactionId: 'tx-cc-repay',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 4000,
        currency: 'INR',
      ).successOrNull!;
      final repaymentTaDest = TransferAllocation.create(
        id: 'ta4-dst',
        transactionId: 'tx-cc-repay',
        role: AllocationRole.destination,
        endpointType: EndpointType.account,
        accountId: 'cc-prime',
        amount: 4000,
        currency: 'INR',
      ).successOrNull!;
      final repaymentTx = Transaction.create(
        id: 'tx-cc-repay',
        profileId: 'p1',
        type: TransactionType.transfer,
        date: now,
        currency: 'INR',
        totalAmount: 4000,
        paymentModeId: 'pm-transfer',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [repaymentTaSource, repaymentTaDest],
      ).successOrNull!;
      txList.add(repaymentTx);

      // Outstanding should drop to 3000 (7000 - 4000), available credit rises to 47000
      expect(
        FinancialEngine.calculateCreditCardOutstanding(ccAccount, txList),
        3000,
      );
      expect(
        FinancialEngine.calculateCreditCardAvailableCredit(ccAccount, txList),
        47000,
      );
    });

    test('Derived Goal Balance after Deposit and Withdrawal', () {
      expect(FinancialEngine.calculateGoalBalance(goalCar, txList), 0);

      // Deposit to Goal: Transfer from Bank (10000) to Goal (10000)
      final depositSrc = TransferAllocation.create(
        id: 'ta5-src',
        transactionId: 'tx-goal-dep',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 10000,
        currency: 'INR',
      ).successOrNull!;
      final depositDst = TransferAllocation.create(
        id: 'ta5-dst',
        transactionId: 'tx-goal-dep',
        role: AllocationRole.destination,
        endpointType: EndpointType.goal,
        goalId: 'goal-car',
        amount: 10000,
        currency: 'INR',
      ).successOrNull!;
      final depositTx = Transaction.create(
        id: 'tx-goal-dep',
        profileId: 'p1',
        type: TransactionType.transfer,
        date: now,
        currency: 'INR',
        totalAmount: 10000,
        paymentModeId: 'pm-transfer',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [depositSrc, depositDst],
      ).successOrNull!;
      txList.add(depositTx);

      expect(FinancialEngine.calculateGoalBalance(goalCar, txList), 10000);

      // Withdrawal from Goal: Transfer from Goal (3000) to Bank (3000)
      final withdrawSrc = TransferAllocation.create(
        id: 'ta6-src',
        transactionId: 'tx-goal-wdr',
        role: AllocationRole.source,
        endpointType: EndpointType.goal,
        goalId: 'goal-car',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;
      final withdrawDst = TransferAllocation.create(
        id: 'ta6-dst',
        transactionId: 'tx-goal-wdr',
        role: AllocationRole.destination,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;
      final withdrawTx = Transaction.create(
        id: 'tx-goal-wdr',
        profileId: 'p1',
        type: TransactionType.transfer,
        date: now,
        currency: 'INR',
        totalAmount: 3000,
        paymentModeId: 'pm-transfer',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [withdrawSrc, withdrawDst],
      ).successOrNull!;
      txList.add(withdrawTx);

      expect(FinancialEngine.calculateGoalBalance(goalCar, txList), 7000);
    });

    test('Net Worth and Net Available Balance calculations', () {
      // Bank balance: 10000, CC outstanding: 5000, Goal: 0
      // NAB: 10000 - 5000 = 5000. NW: 5000 + 0 = 5000.
      expect(
        FinancialEngine.calculateNetAvailableBalance(
          accounts: [bankAccount, ccAccount],
          transactions: txList,
          currency: 'INR',
        ),
        5000,
      );
      expect(
        FinancialEngine.calculateNetWorth(
          accounts: [bankAccount, ccAccount],
          goals: [goalCar],
          transactions: txList,
          currency: 'INR',
        ),
        5000,
      );

      // Add a goal deposit of 10000 from Bank.
      // Bank balance becomes 0 (10000 - 10000). CC outstanding: 5000. Goal balance: 10000.
      // NAB: 0 - 5000 = -5000.
      // NW: NAB (-5000) + Goal (10000) = 5000 (net worth is unchanged by internal transfer).
      final depositSrc = TransferAllocation.create(
        id: 'ta7-src',
        transactionId: 'tx-nw-dep',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 10000,
        currency: 'INR',
      ).successOrNull!;
      final depositDst = TransferAllocation.create(
        id: 'ta7-dst',
        transactionId: 'tx-nw-dep',
        role: AllocationRole.destination,
        endpointType: EndpointType.goal,
        goalId: 'goal-car',
        amount: 10000,
        currency: 'INR',
      ).successOrNull!;
      final depositTx = Transaction.create(
        id: 'tx-nw-dep',
        profileId: 'p1',
        type: TransactionType.transfer,
        date: now,
        currency: 'INR',
        totalAmount: 10000,
        paymentModeId: 'pm-transfer',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [depositSrc, depositDst],
      ).successOrNull!;
      txList.add(depositTx);

      expect(
        FinancialEngine.calculateNetAvailableBalance(
          accounts: [bankAccount, ccAccount],
          transactions: txList,
          currency: 'INR',
        ),
        -5000,
      );
      expect(
        FinancialEngine.calculateNetWorth(
          accounts: [bankAccount, ccAccount],
          goals: [goalCar],
          transactions: txList,
          currency: 'INR',
        ),
        5000,
      );
    });

    test('Category spending is correct and excludes income/transfers', () {
      // 1. Expense transaction: 3000
      final expenseCa = CategoryAllocation.create(
        id: 'ca-c1',
        transactionId: 'tx-e',
        categoryId: 'cat-food',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;
      final expenseTa = TransferAllocation.create(
        id: 'ta-e',
        transactionId: 'tx-e',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 3000,
        currency: 'INR',
      ).successOrNull!;
      final expenseTx = Transaction.create(
        id: 'tx-e',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 3000,
        paymentModeId: 'pm-bank',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [expenseCa],
        transferAllocations: [expenseTa],
      ).successOrNull!;
      txList.add(expenseTx);

      // 2. Income transaction linking to same category id (e.g. refund/cashback)
      final incomeCa = CategoryAllocation.create(
        id: 'ca-i',
        transactionId: 'tx-i',
        categoryId: 'cat-food',
        amount: 1500,
        currency: 'INR',
      ).successOrNull!;
      final incomeTa = TransferAllocation.create(
        id: 'ta-i',
        transactionId: 'tx-i',
        role: AllocationRole.destination,
        endpointType: EndpointType.account,
        accountId: 'bank-hdfc',
        amount: 1500,
        currency: 'INR',
      ).successOrNull!;
      final incomeTx = Transaction.create(
        id: 'tx-i',
        profileId: 'p1',
        type: TransactionType.income,
        date: now,
        currency: 'INR',
        totalAmount: 1500,
        paymentModeId: 'pm-bank',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [incomeCa],
        transferAllocations: [incomeTa],
      ).successOrNull!;
      txList.add(incomeTx);

      // Category spending must be 3000, NOT 1500 (since income is tracked separately)
      expect(
        FinancialEngine.calculateCategorySpent(
          categoryId: 'cat-food',
          transactions: txList,
        ),
        3000,
      );
    });
  });
}
