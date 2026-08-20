import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/domain/payment_mode.dart';
import 'package:pocket_friendly/features/accounts/domain/credit_card_statement.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/services/credit_card_service.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/services/financial_engine.dart';

void main() {
  group('Credit Card Engine & Calculations Tests', () {
    late AppDatabase database;
    late ProfileRepositoryImpl profileRepo;
    late CategoryRepositoryImpl categoryRepo;
    late AccountRepositoryImpl accountRepo;
    late TransactionRepositoryImpl transactionRepo;

    final now = DateTime(2026, 8, 20);

    setUp(() async {
      final key = List<int>.generate(32, (i) => i);
      database = AppDatabase(openEncryptedConnection(key, inMemory: true));

      profileRepo = ProfileRepositoryImpl(database);
      categoryRepo = CategoryRepositoryImpl(database);
      accountRepo = AccountRepositoryImpl(database);
      transactionRepo = TransactionRepositoryImpl(database);

      // 1. Setup profile
      final profile = Profile.create(
        id: 'p1',
        name: 'User',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await profileRepo.saveProfile(profile);

      // 2. Setup Bank Account
      final bank = Account.create(
        id: 'acc-bank',
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
      await accountRepo.saveAccount(bank);

      // 3. Setup Cash Account
      final cash = Account.create(
        id: 'acc-cash',
        profileId: 'p1',
        type: AccountType.cash,
        name: 'Wallet Cash',
        currency: 'INR',
        icon: 'cash',
        openingBalance: 20000,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(cash);

      // 4. Setup Credit Card Account (Limit: 150,000, Bill Generation Day: 15)
      final cc = Account.create(
        id: 'acc-card',
        profileId: 'p1',
        type: AccountType.creditCard,
        name: 'Amazon ICICI',
        currency: 'INR',
        icon: 'card',
        openingBalance: 0,
        status: AccountStatus.active,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        creditLimit: 150000,
        openingOutstanding: 0,
        billGenerationDay: 15,
      ).successOrNull!;
      await accountRepo.saveAccount(cc);

      // 5. Setup Payment Modes
      final pmBank = PaymentMode.create(
        id: 'pm-bank',
        profileId: 'p1',
        name: 'Bank Direct',
        applicableAccountTypes: [AccountType.bank],
        isDefault: false,
        isSystem: false,
        status: PaymentModeStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.savePaymentMode(pmBank);

      final pmCard = PaymentMode.create(
        id: 'pm-card',
        profileId: 'p1',
        name: 'ICICI Card',
        applicableAccountTypes: [AccountType.creditCard],
        isDefault: true,
        isSystem: false,
        status: PaymentModeStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.savePaymentMode(pmCard);

      // 6. Setup Category
      final cat = Category.create(
        id: 'cat-shopping',
        profileId: 'p1',
        name: 'Shopping',
        icon: 'bag',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(cat);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'Purchase increases outstanding, decreases available credit, and decreases net worth',
      () async {
        final card = (await accountRepo.getAccount(
          'acc-card',
          'p1',
        )).successOrNull!;
        final bank = (await accountRepo.getAccount(
          'acc-bank',
          'p1',
        )).successOrNull!;
        final cash = (await accountRepo.getAccount(
          'acc-cash',
          'p1',
        )).successOrNull!;

        // 1. Purchase transaction (Expense on Card): 15000 INR
        final ca = CategoryAllocation.create(
          id: 'ca1',
          transactionId: 'tx-p1',
          categoryId: 'cat-shopping',
          amount: 15000,
          currency: 'INR',
        ).successOrNull!;
        // An expense on a credit card uses the credit card ID as the source account allocation
        final ta = TransferAllocation.create(
          id: 'ta1',
          transactionId: 'tx-p1',
          role: AllocationRole.source,
          endpointType: EndpointType.account,
          accountId: 'acc-card',
          amount: 15000,
          currency: 'INR',
        ).successOrNull!;

        final purchaseTx = Transaction.create(
          id: 'tx-p1',
          profileId: 'p1',
          type: TransactionType.expense,
          date: DateTime(2026, 8, 10),
          currency: 'INR',
          totalAmount: 15000,
          paymentModeId:
              'acc-card', // Purchases are paid using the card account ID
          status: TransactionStatus.active,
          createdAt: now,
          updatedAt: now,
          categoryAllocations: [ca],
          transferAllocations: [ta],
        ).successOrNull!;

        final saveResult = await transactionRepo.saveTransaction(purchaseTx);
        expect(saveResult.isSuccess, isTrue);

        final txns = (await transactionRepo.getTransactions(
          'p1',
        )).successOrNull!;
        expect(
          FinancialEngine.calculateCreditCardOutstanding(card, txns),
          15000,
        );
        expect(
          FinancialEngine.calculateCreditCardAvailableCredit(card, txns),
          135000,
        ); // 150000 - 15000 = 135000

        // Net Worth: Bank (100000) + Cash (20000) - Card Outstanding (15000) = 105000 INR
        expect(
          FinancialEngine.calculateNetWorth(
            accounts: [bank, cash, card],
            goals: [],
            transactions: txns,
            currency: 'INR',
          ),
          105000,
        );
      },
    );

    test(
      'Repayment warning correctly evaluates bank balances and excludes cash',
      () async {
        final card = (await accountRepo.getAccount(
          'acc-card',
          'p1',
        )).successOrNull!;
        final bank = (await accountRepo.getAccount(
          'acc-bank',
          'p1',
        )).successOrNull!;
        final cash = (await accountRepo.getAccount(
          'acc-cash',
          'p1',
        )).successOrNull!;

        // Bank has 100k, CC outstanding is 0.
        // Purchase is 80k. Sum is 80k. Bank balance is 100k. No warning.
        final warnNull = CreditCardService.evaluateRepaymentFunds(
          card: card,
          purchaseAmount: 80000,
          accounts: [bank, cash, card],
          transactions: [],
        );
        expect(warnNull, isNull);

        // Purchase is 110k. Sum is 110k. Bank balance is 100k.
        // Note: Cash balance is 20k, but excluded. So we expect a warning!
        final warningMsg = CreditCardService.evaluateRepaymentFunds(
          card: card,
          purchaseAmount: 110000,
          accounts: [bank, cash, card],
          transactions: [],
        );
        expect(warningMsg, isNotNull);
        expect(warningMsg, contains('insufficient to cover'));
      },
    );

    test('Monthly bill statement generation and Guided settlement flow', () async {
      final card = (await accountRepo.getAccount(
        'acc-card',
        'p1',
      )).successOrNull!;
      final bank = (await accountRepo.getAccount(
        'acc-bank',
        'p1',
      )).successOrNull!;

      // 1. Purchase on August 10: 20000 INR
      final ca = CategoryAllocation.create(
        id: 'ca1',
        transactionId: 'tx-p1',
        categoryId: 'cat-shopping',
        amount: 20000,
        currency: 'INR',
      ).successOrNull!;
      final ta = TransferAllocation.create(
        id: 'ta1',
        transactionId: 'tx-p1',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'acc-card',
        amount: 20000,
        currency: 'INR',
      ).successOrNull!;
      final purchaseTx = Transaction.create(
        id: 'tx-p1',
        profileId: 'p1',
        type: TransactionType.expense,
        date: DateTime(2026, 8, 10),
        currency: 'INR',
        totalAmount: 20000,
        paymentModeId: 'acc-card',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca],
        transferAllocations: [ta],
      ).successOrNull!;
      await transactionRepo.saveTransaction(purchaseTx);

      // 2. Generate Statement snapshot on August 16 (since bill generation day is 15th)
      final genResult = await accountRepo.generateStatementIfNeeded(
        'acc-card',
        'p1',
        DateTime(2026, 8, 16),
      );
      expect(
        genResult.isSuccess,
        isTrue,
        reason: 'Failed: ${genResult.failureOrNull?.message} (${genResult.failureOrNull})',
      );

      final stmtResult = await accountRepo.getCreditCardStatements(
        'acc-card',
        'p1',
      );
      expect(stmtResult.isSuccess, isTrue);

      final statements = stmtResult.successOrNull!;
      expect(statements.length, 2);

      final CreditCardStatement statement = statements.first;
      expect(statement.statementCycle, '2026-08');
      expect(statement.outstandingAmount, 20000);
      expect(statement.isSettled, isFalse);

      // 3. Purchase on August 18 (belongs to NEXT billing cycle, cycle 2026-09)
      final ca2 = CategoryAllocation.create(
        id: 'ca2',
        transactionId: 'tx-p2',
        categoryId: 'cat-shopping',
        amount: 15000,
        currency: 'INR',
      ).successOrNull!;
      final ta2 = TransferAllocation.create(
        id: 'ta2',
        transactionId: 'tx-p2',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'acc-card',
        amount: 15000,
        currency: 'INR',
      ).successOrNull!;
      final purchaseTx2 = Transaction.create(
        id: 'tx-p2',
        profileId: 'p1',
        type: TransactionType.expense,
        date: DateTime(2026, 8, 18),
        currency: 'INR',
        totalAmount: 15000,
        paymentModeId: 'acc-card',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca2],
        transferAllocations: [ta2],
      ).successOrNull!;
      await transactionRepo.saveTransaction(purchaseTx2);

      // Verify overall CC outstanding is now 35000
      var txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      expect(FinancialEngine.calculateCreditCardOutstanding(card, txns), 35000);

      // 4. Settle the 2026-08 statement (20000 INR)
      final settleResult = await CreditCardService.settleCreditCardStatement(
        statement: statement,
        bankAccountId: 'acc-bank',
        paymentModeId: 'pm-bank',
        transactionRepository: transactionRepo,
        accountRepository: accountRepo,
        settlementDate: DateTime(2026, 8, 20),
      );
      expect(settleResult.isSuccess, isTrue);

      // 5. Verify balances after settlement:
      txns = (await transactionRepo.getTransactions('p1')).successOrNull!;
      // Bank balance: 100000 - 20000 = 80000 INR
      expect(FinancialEngine.calculateAccountBalance(bank, txns), 80000);
      // Credit card outstanding: 35000 - 20000 = 15000 INR (credit restored!)
      expect(FinancialEngine.calculateCreditCardOutstanding(card, txns), 15000);
      expect(
        FinancialEngine.calculateCreditCardAvailableCredit(card, txns),
        135000,
      ); // 150000 - 15000 = 135000

      // Statement should be marked settled
      final updatedStmts = (await accountRepo.getCreditCardStatements(
        'acc-card',
        'p1',
      )).successOrNull!;
      expect(updatedStmts.first.isSettled, isTrue);
    });
  });
}
