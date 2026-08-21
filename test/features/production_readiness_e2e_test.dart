import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/budgets/domain/budget.dart';
import 'package:pocket_friendly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/services/financial_engine.dart';
import 'package:pocket_friendly/features/transactions/domain/services/insights_service.dart';
import 'package:pocket_friendly/features/goals/domain/goal.dart';
import 'package:pocket_friendly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:pocket_friendly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:pocket_friendly/features/recurring/domain/recurring_rule.dart';
import 'package:pocket_friendly/features/insights/domain/services/assistant_engine.dart';
import 'package:pocket_friendly/features/import_export/domain/services/import_export_service.dart';
import 'package:pocket_friendly/core/security/security_service.dart';
import 'package:pocket_friendly/core/utilities/currency_formatter.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('Pocket Friendly Production Readiness E2E Scenarios', () {
    late AppDatabase database;
    late ProfileRepositoryImpl profileRepo;
    late AccountRepositoryImpl accountRepo;
    late CategoryRepositoryImpl categoryRepo;
    late BudgetRepositoryImpl budgetRepo;
    late TransactionRepositoryImpl transactionRepo;
    late GoalRepositoryImpl goalRepo;
    late RecurringRepositoryImpl recurringRepo;
    late ImportExportService importExportService;
    late SecurityServiceImpl securityService;
    late MockFlutterSecureStorage mockSecureStorage;
    final keyBytes = List<int>.generate(32, (i) => i);

    setUp(() async {
      final key = List<int>.generate(32, (i) => i);
      database = AppDatabase(openEncryptedConnection(key, inMemory: true));

      profileRepo = ProfileRepositoryImpl(database);
      accountRepo = AccountRepositoryImpl(database);
      categoryRepo = CategoryRepositoryImpl(database);
      budgetRepo = BudgetRepositoryImpl(database);
      transactionRepo = TransactionRepositoryImpl(database);
      goalRepo = GoalRepositoryImpl(database);
      recurringRepo = RecurringRepositoryImpl(database);
      importExportService = ImportExportService(database: database);

      mockSecureStorage = MockFlutterSecureStorage();
      securityService = SecurityServiceImpl(secureStorage: mockSecureStorage);
    });

    tearDown(() async {
      await database.close();
    });

    test('Runs all 26 production readiness scenarios successfully', () async {
      final now = DateTime.now();

      // 1. Onboarding
      final profile = Profile.create(
        id: 'p1',
        name: 'Alice',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      final saveProfileRes = await profileRepo.saveProfile(profile);
      expect(saveProfileRes.isSuccess, isTrue);

      // 2. Create bank account
      final checking = Account.create(
        id: 'acc-checking',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'Checking Account',
        currency: 'INR',
        icon: 'bank',
        openingBalance: 500000, // 5,000 INR
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      final saveAccRes = await accountRepo.saveAccount(checking);
      expect(saveAccRes.isSuccess, isTrue);

      // 3. Create category
      final foodCat = Category.create(
        id: 'cat-food',
        profileId: 'p1',
        name: 'Food',
        icon: 'coffee',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      final saveCatRes = await categoryRepo.saveCategory(foodCat);
      expect(saveCatRes.isSuccess, isTrue);

      // 4. Create budget
      final budget = Budget.create(
        id: 'b-food',
        profileId: 'p1',
        categoryId: 'cat-food',
        year: now.year,
        month: now.month,
        baseAmount: 200000, // 2,000 INR
        carryForwardAmount: 0,
        currency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      final saveBudgetRes = await budgetRepo.saveCategoryBudget(budget);
      expect(saveBudgetRes.isSuccess, isTrue);

      // 5. Record expense
      final expenseTx = Transaction.create(
        id: 'tx-exp1',
        profileId: 'p1',
        type: TransactionType.expense,
        totalAmount: 10000, // 100 INR
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-checking',
        note: 'Lunch',
        categoryAllocations: [
          CategoryAllocation.create(
            id: 'ca-exp1',
            transactionId: 'tx-exp1',
            categoryId: 'cat-food',
            amount: 10000,
            currency: 'INR',
          ).successOrNull!,
        ],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-exp1',
            transactionId: 'tx-exp1',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc-checking',
            amount: 10000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(expenseTx);

      // Verify bank balance decreases
      final checkBal1 = FinancialEngine.calculateAccountBalance(
        checking,
        [expenseTx],
      );
      expect(checkBal1, 490000); // 500000 - 10000

      // 6. Record income
      final incomeCat = Category.create(
        id: 'cat-salary',
        profileId: 'p1',
        name: 'Salary',
        icon: 'briefcase',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      final saveIncCatRes = await categoryRepo.saveCategory(incomeCat);
      expect(saveIncCatRes.isSuccess, isTrue);

      final incomeTx = Transaction.create(
        id: 'tx-inc1',
        profileId: 'p1',
        type: TransactionType.income,
        totalAmount: 30000, // 300 INR
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-checking',
        note: 'Part-time payment',
        categoryAllocations: [
          CategoryAllocation.create(
            id: 'ca-inc1',
            transactionId: 'tx-inc1',
            categoryId: 'cat-salary',
            amount: 30000,
            currency: 'INR',
          ).successOrNull!,
        ],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-inc1',
            transactionId: 'tx-inc1',
            role: AllocationRole.destination,
            endpointType: EndpointType.account,
            accountId: 'acc-checking',
            amount: 30000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(incomeTx);

      // Verify balance increases
      final checkBal2 = FinancialEngine.calculateAccountBalance(
        checking,
        [expenseTx, incomeTx],
      );
      expect(checkBal2, 520000); // 490000 + 30000

      // 7. Record transfer
      final savings = Account.create(
        id: 'acc-savings',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'Savings Pot',
        currency: 'INR',
        icon: 'piggy',
        openingBalance: 0,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(savings);

      final transferTx = Transaction.create(
        id: 'tx-transfer1',
        profileId: 'p1',
        type: TransactionType.transfer,
        totalAmount: 50000, // 500 INR
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-checking',
        note: 'Move to savings',
        categoryAllocations: [],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-src',
            transactionId: 'tx-transfer1',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc-checking',
            amount: 50000,
            currency: 'INR',
          ).successOrNull!,
          TransferAllocation.create(
            id: 'ta-dest',
            transactionId: 'tx-transfer1',
            role: AllocationRole.destination,
            endpointType: EndpointType.account,
            accountId: 'acc-savings',
            amount: 50000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(transferTx);

      final checkBal3 = FinancialEngine.calculateAccountBalance(
        checking,
        [expenseTx, incomeTx, transferTx],
      );
      final savingsBal1 = FinancialEngine.calculateAccountBalance(
        savings,
        [expenseTx, incomeTx, transferTx],
      );
      expect(checkBal3, 470000); // 520000 - 50000
      expect(savingsBal1, 50000); // 0 + 50000

      // 8. Split expense by category
      final rentCat = Category.create(
        id: 'cat-rent',
        profileId: 'p1',
        name: 'Rent',
        icon: 'home',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(rentCat);

      final splitCatTx = Transaction.create(
        id: 'tx-splitcat',
        profileId: 'p1',
        type: TransactionType.expense,
        totalAmount: 15000, // 150 INR
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-checking',
        note: 'Split Expense',
        categoryAllocations: [
          CategoryAllocation.create(
            id: 'ca-split1',
            transactionId: 'tx-splitcat',
            categoryId: 'cat-food',
            amount: 10000,
            currency: 'INR',
          ).successOrNull!,
          CategoryAllocation.create(
            id: 'ca-split2',
            transactionId: 'tx-splitcat',
            categoryId: 'cat-rent',
            amount: 5000,
            currency: 'INR',
          ).successOrNull!,
        ],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-split-src',
            transactionId: 'tx-splitcat',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc-checking',
            amount: 15000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(splitCatTx);

      // Verify category spending values
      final activeTxs = [expenseTx, incomeTx, transferTx, splitCatTx];
      final spentOnFood = FinancialEngine.calculateCategorySpent(
        categoryId: foodCat.id,
        transactions: activeTxs,
      );
      final spentOnRent = FinancialEngine.calculateCategorySpent(
        categoryId: rentCat.id,
        transactions: activeTxs,
      );
      expect(spentOnFood, 20000); // 10000 (Lunch) + 10000 (split)
      expect(spentOnRent, 5000);

      // 9. Split expense by account (split-account)
      final splitAccTx = Transaction.create(
        id: 'tx-splitacc',
        profileId: 'p1',
        type: TransactionType.expense,
        totalAmount: 20000,
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-checking',
        note: 'Duo Pay Split',
        categoryAllocations: [
          CategoryAllocation.create(
            id: 'ca-splitacc',
            transactionId: 'tx-splitacc',
            categoryId: 'cat-food',
            amount: 20000,
            currency: 'INR',
          ).successOrNull!,
        ],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-splitacc-src1',
            transactionId: 'tx-splitacc',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc-checking',
            amount: 15000,
            currency: 'INR',
          ).successOrNull!,
          TransferAllocation.create(
            id: 'ta-splitacc-src2',
            transactionId: 'tx-splitacc',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc-savings',
            amount: 5000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(splitAccTx);

      final activeTxs2 = [...activeTxs, splitAccTx];
      final checkBal4 = FinancialEngine.calculateAccountBalance(
        checking,
        activeTxs2,
      );
      final savingsBal2 = FinancialEngine.calculateAccountBalance(
        savings,
        activeTxs2,
      );
      expect(checkBal4, 440000); // 470000 - 15000 (splitCatTx) - 15000 (splitAccTx)
      expect(savingsBal2, 45000); // 50000 - 5000

      // 10. Goal contribution
      final carGoalCat = Category.create(
        id: 'cat-car-goal',
        profileId: 'p1',
        name: 'Car Fund Category',
        icon: 'car',
        status: CategoryStatus.active,
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(carGoalCat);

      final carGoal = Goal.create(
        id: 'goal-car',
        profileId: 'p1',
        categoryId: 'cat-car-goal',
        goalType: GoalType.standard,
        name: 'Car Fund',
        targetAmount: 100000, // 1,000 INR
        targetDate: now.add(const Duration(days: 365)),
        currency: 'INR',
        icon: 'car',
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await goalRepo.saveGoal(carGoal);

      final contributionTx = Transaction.create(
        id: 'tx-contrib1',
        profileId: 'p1',
        type: TransactionType.expense, // Goal contributions are expenses
        totalAmount: 20000,
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-checking',
        note: 'Goal Contribution',
        categoryAllocations: [
          CategoryAllocation.create(
            id: 'ca-contrib',
            transactionId: 'tx-contrib1',
            categoryId: 'cat-car-goal',
            amount: 20000,
            currency: 'INR',
          ).successOrNull!,
        ],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-contrib-src',
            transactionId: 'tx-contrib1',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc-checking',
            amount: 20000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(contributionTx);

      final activeTxs3 = [...activeTxs2, contributionTx];
      final carBal1 = FinancialEngine.calculateGoalBalance(carGoal, activeTxs3);
      expect(carBal1, 20000);

      // 11. Goal withdrawal
      final withdrawalTx = Transaction.create(
        id: 'tx-withdraw1',
        profileId: 'p1',
        type: TransactionType.transfer, // Goal withdrawals are transfers
        totalAmount: 5000,
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-checking',
        note: 'Goal Withdrawal',
        categoryAllocations: [],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-with-src',
            transactionId: 'tx-withdraw1',
            role: AllocationRole.source,
            endpointType: EndpointType.goal,
            goalId: 'goal-car',
            amount: 5000,
            currency: 'INR',
          ).successOrNull!,
          TransferAllocation.create(
            id: 'ta-with-dest',
            transactionId: 'tx-withdraw1',
            role: AllocationRole.destination,
            endpointType: EndpointType.account,
            accountId: 'acc-checking',
            amount: 5000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(withdrawalTx);

      final activeTxs4 = [...activeTxs3, withdrawalTx];
      final carBal2 = FinancialEngine.calculateGoalBalance(carGoal, activeTxs4);
      final checkBal5 = FinancialEngine.calculateAccountBalance(checking, activeTxs4);
      expect(carBal2, 15000); // 20000 - 5000
      expect(checkBal5, 425000); // 440000 - 20000 (contrib) + 5000 (withdraw)

      // 12. Credit-card purchase
      final cc = Account.create(
        id: 'acc-cc',
        profileId: 'p1',
        type: AccountType.creditCard,
        name: 'Credit Card',
        currency: 'INR',
        icon: 'credit-card',
        openingBalance: 0,
        creditLimit: 1000000, // 10,000 INR
        openingOutstanding: 0,
        billGenerationDay: 15,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(cc);

      final ccPurchaseTx = Transaction.create(
        id: 'tx-cc-purchase',
        profileId: 'p1',
        type: TransactionType.expense,
        totalAmount: 15000,
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-cc',
        note: 'CC Food',
        categoryAllocations: [
          CategoryAllocation.create(
            id: 'ca-cc-purchase',
            transactionId: 'tx-cc-purchase',
            categoryId: 'cat-food',
            amount: 15000,
            currency: 'INR',
          ).successOrNull!,
        ],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-cc-purchase',
            transactionId: 'tx-cc-purchase',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc-cc',
            amount: 15000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(ccPurchaseTx);

      final activeTxs5 = [...activeTxs4, ccPurchaseTx];
      final outstanding = FinancialEngine.calculateCreditCardOutstanding(cc, activeTxs5);
      final availableCredit = cc.creditLimit! - outstanding;
      expect(outstanding, 15000);
      expect(availableCredit, 985000);

      // 13. Credit-card settlement
      final ccSettleTx = Transaction.create(
        id: 'tx-cc-settle',
        profileId: 'p1',
        type: TransactionType.transfer,
        totalAmount: 15000,
        date: now,
        currency: 'INR',
        paymentModeId: 'acc-checking',
        note: 'Settle Card',
        categoryAllocations: [],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta-settle-src',
            transactionId: 'tx-cc-settle',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc-checking',
            amount: 15000,
            currency: 'INR',
          ).successOrNull!,
          TransferAllocation.create(
            id: 'ta-settle-dest',
            transactionId: 'tx-cc-settle',
            role: AllocationRole.destination,
            endpointType: EndpointType.account,
            accountId: 'acc-cc',
            amount: 15000,
            currency: 'INR',
          ).successOrNull!,
        ],
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await transactionRepo.saveTransaction(ccSettleTx);

      final activeTxs6 = [...activeTxs5, ccSettleTx];
      final outstandingAfter = FinancialEngine.calculateCreditCardOutstanding(cc, activeTxs6);
      expect(outstandingAfter, 0);

      // 14. Recurring transaction
      final rule = RecurringTransactionRule.create(
        id: 'rec-rule1',
        profileId: 'p1',
        transactionTemplate: jsonEncode({
          'type': 'expense',
          'amount': 1000,
          'note': 'Weekly coffee',
        }),
        frequency: RecurringFrequency.weekly,
        dayOfPeriod: 1,
        mode: RecurringMode.automaticRecording,
        nextOccurrence: now,
        active: true,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await recurringRepo.saveRule(rule);
      final activeRules = await recurringRepo.getActiveRules('p1');
      expect(activeRules.successOrNull!.length, 1);

      // 15. Budget carry-forward
      final prevMonthDate = DateTime(now.year, now.month - 1, 15);
      final prevBudget = Budget.create(
        id: 'b-prev',
        profileId: 'p1',
        categoryId: 'cat-food',
        year: prevMonthDate.year,
        month: prevMonthDate.month,
        baseAmount: 100000, // 1,000 INR
        carryForwardAmount: 0,
        currency: 'INR',
        createdAt: prevMonthDate,
        updatedAt: prevMonthDate,
      ).successOrNull!;
      await budgetRepo.saveCategoryBudget(prevBudget);

      // Carry forward the surplus (1,000 INR) idempotently
      final carryRes = await budgetRepo.carryForward(
        profileId: 'p1',
        sourceMonth: prevMonthDate.month,
        sourceYear: prevMonthDate.year,
        targetMonth: now.month,
        targetYear: now.year,
        currency: 'INR',
      );
      expect(carryRes.isSuccess, isTrue);
      
      final poolRes = await budgetRepo.getUnallocatedBudgetPool(
        profileId: 'p1',
        month: now.month,
        year: now.year,
        currency: 'INR',
      );
      expect(poolRes.isSuccess, isTrue);

      // 16. Search
      final searchRes = await transactionRepo.getTransactions('p1');
      final found = searchRes.successOrNull!.where((tx) => tx.note != null && tx.note!.contains('Lunch')).toList();
      expect(found.length, 1);

      // 17. Insights
      final insights = InsightsService.generate(
        selectedMonth: now,
        transactions: activeTxs6,
        accounts: [checking, savings, cc],
        categories: [foodCat, rentCat],
        goals: [carGoal],
        budgets: [budget],
        recurringRules: [rule],
      );
      expect(insights.savingsRate, isNotNull);

      // 18. Natural-language query
      final queryIntent = AssistantEngine.parse('How much did I spend on food last month?');
      expect(queryIntent, isA<QueryIntent>());
      expect((queryIntent as QueryIntent).concept, 'spending');
      expect(queryIntent.categoryName, 'food');

      // 19. Natural-language transaction preparation
      final actionIntent = AssistantEngine.parse('Add 500 income from freelancing');
      expect(actionIntent, isA<ActionIntent>());
      expect((actionIntent as ActionIntent).type, TransactionType.income);
      expect(actionIntent.amountMinor, 50000);

      // 20. Export
      final exportRes = await importExportService.exportBackup('p1', keyBytes);
      expect(exportRes, isNotEmpty);

      // 21. Import (Replace Everything)
      final importRes = await importExportService.importReplaceEverything(
        exportRes,
        keyBytes,
      );
      expect(importRes, isTrue);

      // 22. Merge
      final mergeRes = await importExportService.importMerge(
        exportRes,
        keyBytes,
      );
      expect(mergeRes, isTrue);

      // 23. Restore backup
      final restoreRes = await importExportService.importReplaceEverything(
        exportRes,
        keyBytes,
      );
      expect(restoreRes, isTrue);

      // 24. Profile switching
      final profile2 = Profile.create(
        id: 'p2',
        name: 'Bob',
        defaultCurrency: 'USD',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await profileRepo.saveProfile(profile2);

      // Verify Bob's accounts are isolated from Alice
      final bobAccounts = await accountRepo.getAccounts('p2');
      expect(bobAccounts.successOrNull!.isEmpty, isTrue);

      // 25. Privacy Mode
      final formattedVal = CurrencyFormatter.format(125000, 'INR', privacyMode: true);
      expect(formattedVal, '••••');

      // 26. App lock
      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((_) async => {});
      final keyResult = await securityService.getDatabaseKey();
      expect(keyResult.isSuccess, isTrue);
      expect(keyResult.successOrNull!.length, 32);
    });
  });
}
