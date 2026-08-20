import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/domain/payment_mode.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/budgets/domain/budget.dart';
import 'package:pocket_friendly/features/budgets/domain/unallocated_budget_pool.dart';
import 'package:pocket_friendly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:pocket_friendly/features/budgets/domain/services/budget_calculations.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/recurring/domain/recurring_rule.dart';

void main() {
  group('Budget Calculations Domain Tests', () {
    final now = DateTime.now();

    test(
      'calculateTotalMonthlyBudget combines category budgets and unallocated pool',
      () {
        final b1 = Budget.create(
          id: 'b1',
          profileId: 'p1',
          categoryId: 'cat1',
          month: 8,
          year: 2026,
          baseAmount: 10000,
          carryForwardAmount: 2000,
          currency: 'INR',
          createdAt: now,
          updatedAt: now,
        ).successOrNull!;

        final b2 = Budget.create(
          id: 'b2',
          profileId: 'p1',
          categoryId: 'cat2',
          month: 8,
          year: 2026,
          baseAmount: 15000,
          carryForwardAmount: 0,
          currency: 'INR',
          createdAt: now,
          updatedAt: now,
        ).successOrNull!;

        final pool = UnallocatedBudgetPool.create(
          id: 'pool1',
          profileId: 'p1',
          month: 8,
          year: 2026,
          amount: 5000,
          currency: 'INR',
        ).successOrNull!;

        final total = BudgetCalculations.calculateTotalMonthlyBudget(
          categoryBudgets: [b1, b2],
          pool: pool,
        );
        // Category total: (10000 + 2000) + 15000 = 27000
        // Pool: 5000. Grand total: 32000.
        expect(total, 32000);
      },
    );

    test('Days remaining in month calculations (standard vs leap years)', () {
      // August 20, 2026 -> 31 days. Remaining: 31 - 20 + 1 = 12 days
      expect(
        BudgetCalculations.calculateDaysRemainingInclusive(
          DateTime(2026, 8, 20),
        ),
        12,
      );

      // Feb 20, 2024 (Leap year) -> 29 days. Remaining: 29 - 20 + 1 = 10 days
      expect(
        BudgetCalculations.calculateDaysRemainingInclusive(
          DateTime(2024, 2, 20),
        ),
        10,
      );

      // Feb 20, 2026 (Non-leap year) -> 28 days. Remaining: 28 - 20 + 1 = 9 days
      expect(
        BudgetCalculations.calculateDaysRemainingInclusive(
          DateTime(2026, 2, 20),
        ),
        9,
      );

      // Edge case: targetDate is past month end (e.g. day 32) -> returns 0
      expect(
        BudgetCalculations.calculateDaysRemainingInclusive(
          DateTime(2026, 8, 32),
        ),
        30,
      );
    });

    test('Safe-to-Spend excludes future recurring budgeted expenses', () {
      final b1 = Budget.create(
        id: 'b1',
        profileId: 'p1',
        categoryId: 'cat-food',
        month: 8,
        year: 2026,
        baseAmount: 12000,
        carryForwardAmount: 0,
        currency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;

      // 1. Transaction: Spent 2000 in food
      final ca = CategoryAllocation.create(
        id: 'ca1',
        transactionId: 'tx1',
        categoryId: 'cat-food',
        amount: 2000,
        currency: 'INR',
      ).successOrNull!;
      final tx = Transaction.create(
        id: 'tx1',
        profileId: 'p1',
        type: TransactionType.expense,
        date: DateTime(2026, 8, 10),
        currency: 'INR',
        totalAmount: 2000,
        paymentModeId: 'pm1',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca],
        transferAllocations: [
          TransferAllocation.create(
            id: 'ta1',
            transactionId: 'tx1',
            role: AllocationRole.source,
            endpointType: EndpointType.account,
            accountId: 'acc1',
            amount: 2000,
            currency: 'INR',
          ).successOrNull!,
        ],
      ).successOrNull!;

      // 2. Pending recurring occurrence: Food expense of 4000 scheduled for the 25th
      final rule = RecurringTransactionRule.create(
        id: 'rule1',
        profileId: 'p1',
        transactionTemplate: jsonEncode({
          'categoryAllocations': [
            {'categoryId': 'cat-food', 'amount': 4000},
          ],
        }),
        frequency: RecurringFrequency.monthly,
        dayOfPeriod: 25,
        mode: RecurringMode.reminder,
        nextOccurrence: DateTime(2026, 8, 25),
        active: true,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;

      final occurrence = RecurringOccurrence.create(
        id: 'occ1',
        recurringRuleId: 'rule1',
        scheduledOccurrenceDate: DateTime(2026, 8, 25),
        status: OccurrenceStatus.pending,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;

      // Safe to spend on August 10, 2026:
      // Total Budget: 12000
      // Spent: 2000
      // Future Recurring: 4000
      // Remaining Budgeted money: 12000 - 2000 - 4000 = 6000
      // Days remaining (inclusive of Aug 10): 31 - 10 + 1 = 22 days
      // Safe to Spend per day = 6000 / 22 = 272 (floor)
      final safeToSpend = BudgetCalculations.calculateSafeToSpend(
        categoryBudgets: [b1],
        pool: null,
        transactions: [tx],
        pendingOccurrences: [occurrence],
        recurringRules: [rule],
        targetDate: DateTime(2026, 8, 10),
      );
      expect(safeToSpend, 272);
    });
  });

  group('Budget Integration & Carry-Forward Tests', () {
    late AppDatabase database;
    late ProfileRepositoryImpl profileRepo;
    late CategoryRepositoryImpl categoryRepo;
    late AccountRepositoryImpl accountRepo;
    late TransactionRepositoryImpl transactionRepo;
    late BudgetRepositoryImpl budgetRepo;

    final now = DateTime.now();

    setUp(() async {
      final key = List<int>.generate(32, (i) => i);
      database = AppDatabase(openEncryptedConnection(key, inMemory: true));

      profileRepo = ProfileRepositoryImpl(database);
      categoryRepo = CategoryRepositoryImpl(database);
      accountRepo = AccountRepositoryImpl(database);
      transactionRepo = TransactionRepositoryImpl(database);
      budgetRepo = BudgetRepositoryImpl(database);

      // Create base data
      final profile = Profile.create(
        id: 'p1',
        name: 'User',
        defaultCurrency: 'USD',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await profileRepo.saveProfile(profile);

      final account = Account.create(
        id: 'acc1',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'Chase Checking',
        currency: 'USD',
        icon: 'bank',
        openingBalance: 10000,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(account);

      final pm = PaymentMode.create(
        id: 'pm1',
        profileId: 'p1',
        name: 'Debit Card',
        applicableAccountTypes: [AccountType.bank],
        isDefault: true,
        isSystem: false,
        status: PaymentModeStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.savePaymentMode(pm);

      final cat = Category.create(
        id: 'cat-grocery',
        profileId: 'p1',
        name: 'Grocery',
        icon: 'food',
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
      'Carry-forward transition adds unused category budgets to next month\'s unallocated pool',
      () async {
        // 1. Create a category budget for August 2026: 3000 USD
        final budget = Budget.create(
          id: 'b-grocery-aug',
          profileId: 'p1',
          categoryId: 'cat-grocery',
          month: 8,
          year: 2026,
          baseAmount: 3000,
          carryForwardAmount: 0,
          currency: 'USD',
          createdAt: now,
          updatedAt: now,
        ).successOrNull!;
        await budgetRepo.saveCategoryBudget(budget);

        // 2. Add spent transaction in August: 1200 USD
        final ca = CategoryAllocation.create(
          id: 'ca1',
          transactionId: 'tx-aug',
          categoryId: 'cat-grocery',
          amount: 1200,
          currency: 'USD',
        ).successOrNull!;
        final ta = TransferAllocation.create(
          id: 'ta1',
          transactionId: 'tx-aug',
          role: AllocationRole.source,
          endpointType: EndpointType.account,
          accountId: 'acc1',
          amount: 1200,
          currency: 'USD',
        ).successOrNull!;
        final txAug = Transaction.create(
          id: 'tx-aug',
          profileId: 'p1',
          type: TransactionType.expense,
          date: DateTime(2026, 8, 15),
          currency: 'USD',
          totalAmount: 1200,
          paymentModeId: 'pm1',
          status: TransactionStatus.active,
          createdAt: now,
          updatedAt: now,
          categoryAllocations: [ca],
          transferAllocations: [ta],
        ).successOrNull!;
        await transactionRepo.saveTransaction(txAug);

        // Unused budget: 3000 - 1200 = 1800 USD.

        // 3. Execute Carry-forward from August 2026 to September 2026
        final carryResult = await budgetRepo.carryForward(
          profileId: 'p1',
          sourceMonth: 8,
          sourceYear: 2026,
          targetMonth: 9,
          targetYear: 2026,
          currency: 'USD',
        );
        expect(carryResult.isSuccess, isTrue);

        // 4. Retrieve September 2026 unallocated pool and verify it has 1800 USD
        final poolResult = await budgetRepo.getUnallocatedBudgetPool(
          profileId: 'p1',
          month: 9,
          year: 2026,
          currency: 'USD',
        );
        expect(poolResult.isSuccess, isTrue);

        final pool = poolResult.successOrNull!;
        expect(pool.amount, 1800);
        expect(pool.currency, 'USD');
      },
    );
  });
}
