import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';

import 'package:pocket_friendly/features/transactions/domain/transaction.dart';

void main() {
  group('Domain Entity Validation Tests', () {
    final now = DateTime.now();

    test('Profile name length & currency code validation', () {
      final valid = Profile.create(
        id: 'p1',
        name: 'Faraaz',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      );
      expect(valid.isSuccess, isTrue);

      final invalidName = Profile.create(
        id: 'p1',
        name: 'F',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      );
      expect(invalidName.isFailure, isTrue);
      expect(
        invalidName.failureOrNull?.message,
        contains('at least 2 characters'),
      );

      final invalidCurrency = Profile.create(
        id: 'p1',
        name: 'Faraaz',
        defaultCurrency: 'USDT',
        createdAt: now,
        updatedAt: now,
      );
      expect(invalidCurrency.isFailure, isTrue);
      expect(
        invalidCurrency.failureOrNull?.message,
        contains('3-letter ISO code'),
      );
    });

    test('Account credit card fields validation', () {
      final validAsset = Account.create(
        id: 'a1',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'Chase Checking',
        currency: 'USD',
        icon: 'bank',
        openingBalance: 100000, // $1000.00
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      expect(validAsset.isSuccess, isTrue);

      // Asset accounts must not have CC config
      final invalidAssetWithCC = Account.create(
        id: 'a1',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'Chase Checking',
        currency: 'USD',
        icon: 'bank',
        openingBalance: 100000,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
        creditLimit: 500000,
      );
      expect(invalidAssetWithCC.isFailure, isTrue);

      // CC requires limit, outstanding, and billing day
      final invalidCCMissingFields = Account.create(
        id: 'a2',
        profileId: 'p1',
        type: AccountType.creditCard,
        name: 'Amazon Prime Card',
        currency: 'USD',
        icon: 'card',
        openingBalance: 0,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      expect(invalidCCMissingFields.isFailure, isTrue);

      final validCC = Account.create(
        id: 'a2',
        profileId: 'p1',
        type: AccountType.creditCard,
        name: 'Amazon Prime Card',
        currency: 'USD',
        icon: 'card',
        openingBalance: 0,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
        creditLimit: 1000000, // $10000.00 limit
        openingOutstanding: 50000, // $500.00 initial outstanding
        billGenerationDay: 15,
      );
      expect(validCC.isSuccess, isTrue);

      final invalidCCBillDay = Account.create(
        id: 'a2',
        profileId: 'p1',
        type: AccountType.creditCard,
        name: 'Amazon Prime Card',
        currency: 'USD',
        icon: 'card',
        openingBalance: 0,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
        creditLimit: 1000000,
        openingOutstanding: 50000,
        billGenerationDay: 35, // invalid day
      );
      expect(invalidCCBillDay.isFailure, isTrue);
    });

    test('Category hierarchy depth limits', () {
      final parent = Category.create(
        id: 'cat-parent',
        profileId: 'p1',
        name: 'Food',
        icon: 'food',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;

      final child = Category.create(
        id: 'cat-child',
        profileId: 'p1',
        parentCategoryId: 'cat-parent',
        name: 'Groceries',
        icon: 'groceries',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;

      // Invariant checks
      expect(child.validateHierarchy(parent).isSuccess, isTrue);

      // Create a sub-child which is a third level category
      final subChild = Category.create(
        id: 'cat-subchild',
        profileId: 'p1',
        parentCategoryId: 'cat-child',
        name: 'Organic Milk',
        icon: 'milk',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;

      // Invariant check on subChild relative to child (which is already a subcategory)
      expect(subChild.validateHierarchy(child).isFailure, isTrue);
    });
  });

  group('Transaction & Allocation Validation Invariants', () {
    final now = DateTime.now();

    test('Expense must contain category allocations summing to total', () {
      final ca1 = CategoryAllocation.create(
        id: 'ca1',
        transactionId: 'tx1',
        categoryId: 'c1',
        amount: 300,
        currency: 'USD',
      ).successOrNull!;
      final ca2 = CategoryAllocation.create(
        id: 'ca2',
        transactionId: 'tx1',
        categoryId: 'c2',
        amount: 700,
        currency: 'USD',
      ).successOrNull!;

      final validExpense = Transaction.create(
        id: 'tx1',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'USD',
        totalAmount: 1000,
        paymentModeId: 'pm1',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca1, ca2],
        transferAllocations: [],
      );
      expect(validExpense.isSuccess, isTrue);

      // Failure on category allocations sum mismatch (300+700 != 900)
      final invalidExpenseSum = Transaction.create(
        id: 'tx1',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'USD',
        totalAmount: 900,
        paymentModeId: 'pm1',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca1, ca2],
        transferAllocations: [],
      );
      expect(invalidExpenseSum.isFailure, isTrue);
      expect(
        invalidExpenseSum.failureOrNull?.message,
        contains('does not match transaction total'),
      );
    });

    test(
      'Transfer must contain source & destination allocations summing to total',
      () {
        final taSource = TransferAllocation.create(
          id: 'ta1',
          transactionId: 'tx2',
          role: AllocationRole.source,
          endpointType: EndpointType.account,
          accountId: 'acc-src',
          amount: 2000,
          currency: 'INR',
        ).successOrNull!;

        final taDest = TransferAllocation.create(
          id: 'ta2',
          transactionId: 'tx2',
          role: AllocationRole.destination,
          endpointType: EndpointType.goal,
          goalId: 'goal-dest',
          amount: 2000,
          currency: 'INR',
        ).successOrNull!;

        final validTransfer = Transaction.create(
          id: 'tx2',
          profileId: 'p1',
          type: TransactionType.transfer,
          date: now,
          currency: 'INR',
          totalAmount: 2000,
          paymentModeId: 'pm-transfer',
          status: TransactionStatus.active,
          createdAt: now,
          updatedAt: now,
          categoryAllocations: [],
          transferAllocations: [taSource, taDest],
        );
        expect(validTransfer.isSuccess, isTrue);

        // Failure if transfer contains category allocations
        final ca = CategoryAllocation.create(
          id: 'ca3',
          transactionId: 'tx2',
          categoryId: 'c1',
          amount: 2000,
          currency: 'INR',
        ).successOrNull!;
        final invalidTransferWithCategory = Transaction.create(
          id: 'tx2',
          profileId: 'p1',
          type: TransactionType.transfer,
          date: now,
          currency: 'INR',
          totalAmount: 2000,
          paymentModeId: 'pm-transfer',
          status: TransactionStatus.active,
          createdAt: now,
          updatedAt: now,
          categoryAllocations: [ca],
          transferAllocations: [taSource, taDest],
        );
        expect(invalidTransferWithCategory.isFailure, isTrue);
      },
    );
  });
}
