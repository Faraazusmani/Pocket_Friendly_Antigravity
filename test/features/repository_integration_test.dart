import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/accounts/domain/account.dart';
import 'package:pocket_friendly/features/accounts/domain/payment_mode.dart';
import 'package:pocket_friendly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';

import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';

import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';

void main() {
  group('Drift Repositories Integration & Invariant Tests', () {
    late AppDatabase database;
    late ProfileRepositoryImpl profileRepo;
    late AccountRepositoryImpl accountRepo;
    late CategoryRepositoryImpl categoryRepo;

    late TransactionRepositoryImpl transactionRepo;

    setUp(() {
      final key = List<int>.generate(32, (i) => i);
      database = AppDatabase(openEncryptedConnection(key, inMemory: true));

      profileRepo = ProfileRepositoryImpl(database);
      accountRepo = AccountRepositoryImpl(database);
      categoryRepo = CategoryRepositoryImpl(database);

      transactionRepo = TransactionRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('Strict Profile Isolation Invariant Test', () async {
      final now = DateTime.now();

      // 1. Setup Profile A and Profile B
      final profileA = Profile.create(
        id: 'profile-a',
        name: 'Profile A',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      final profileB = Profile.create(
        id: 'profile-b',
        name: 'Profile B',
        defaultCurrency: 'USD',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await profileRepo.saveProfile(profileA);
      await profileRepo.saveProfile(profileB);

      // 2. Save items under Profile A
      final accountA = Account.create(
        id: 'acc-a',
        profileId: 'profile-a',
        type: AccountType.bank,
        name: 'HDFC Bank',
        currency: 'INR',
        icon: 'bank',
        openingBalance: 1000000,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(accountA);

      final categoryA = Category.create(
        id: 'cat-a',
        profileId: 'profile-a',
        name: 'Dining Out',
        icon: 'restaurant',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(categoryA);

      // 3. Query under Profile B and assert isolation
      final accountsBResult = await accountRepo.getAccounts('profile-b');
      expect(
        accountsBResult.successOrNull,
        isEmpty,
        reason: 'Profile A accounts must not leak into Profile B',
      );

      final categoriesBResult = await categoryRepo.getCategories('profile-b');
      expect(
        categoriesBResult.successOrNull,
        isEmpty,
        reason: 'Profile A categories must not leak into Profile B',
      );

      // Query under Profile A and assert availability
      final accountsAResult = await accountRepo.getAccounts('profile-a');
      expect(accountsAResult.successOrNull?.length, 1);
      expect(accountsAResult.successOrNull?.first.id, 'acc-a');
    });

    test('Recursive Category Deletion/Archiving Invariant Test', () async {
      final now = DateTime.now();

      // Create profile
      final profile = Profile.create(
        id: 'p1',
        name: 'Faraaz',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await profileRepo.saveProfile(profile);

      // Parent category
      final parentCat = Category.create(
        id: 'parent-cat',
        profileId: 'p1',
        name: 'Automobile',
        icon: 'car',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(parentCat);

      // Child category
      final childCat = Category.create(
        id: 'child-cat',
        profileId: 'p1',
        parentCategoryId: 'parent-cat',
        name: 'Fuel',
        icon: 'fuel',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(childCat);

      // Verify both are active
      final activeList1 = await categoryRepo.getCategories(
        'p1',
        includeArchived: false,
      );
      expect(activeList1.successOrNull?.length, 2);

      // Archive Parent
      await categoryRepo.archiveCategory('parent-cat', 'p1');

      // Verify neither parent nor child is returned in active queries
      final activeList2 = await categoryRepo.getCategories(
        'p1',
        includeArchived: false,
      );
      expect(activeList2.successOrNull, isEmpty);

      // Verify both remain in historical queries
      final historicalList = await categoryRepo.getCategories(
        'p1',
        includeArchived: true,
      );
      expect(historicalList.successOrNull?.length, 2);

      final archivedParent = historicalList.successOrNull?.firstWhere(
        (c) => c.id == 'parent-cat',
      );
      final archivedChild = historicalList.successOrNull?.firstWhere(
        (c) => c.id == 'child-cat',
      );

      expect(archivedParent?.status, CategoryStatus.archived);
      expect(archivedChild?.status, CategoryStatus.archived);
    });

    test('Transaction & Allocation ID Stability Test', () async {
      final now = DateTime.now();

      // Create profile, account, and category
      final profile = Profile.create(
        id: 'p1',
        name: 'User',
        defaultCurrency: 'INR',
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await profileRepo.saveProfile(profile);

      final account = Account.create(
        id: 'acc1',
        profileId: 'p1',
        type: AccountType.bank,
        name: 'HDFC',
        currency: 'INR',
        icon: 'bank',
        openingBalance: 1000,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await accountRepo.saveAccount(account);

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

      final category = Category.create(
        id: 'cat1',
        profileId: 'p1',
        name: 'Snacks',
        icon: 'food',
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ).successOrNull!;
      await categoryRepo.saveCategory(category);

      // 1. Define allocations with stable explicit IDs
      final ca = CategoryAllocation.create(
        id: 'stable-allocation-id',
        transactionId: 'stable-txn-id',
        categoryId: 'cat1',
        amount: 500,
        currency: 'INR',
      ).successOrNull!;

      final ta = TransferAllocation.create(
        id: 'stable-transfer-id',
        transactionId: 'stable-txn-id',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'acc1',
        amount: 500,
        currency: 'INR',
      ).successOrNull!;

      final txn = Transaction.create(
        id: 'stable-txn-id',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 500,
        paymentModeId: 'pm-upi',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [ca],
        transferAllocations: [ta],
      ).successOrNull!;

      // 2. Save
      await transactionRepo.saveTransaction(txn);

      // 3. Retrieve and assert ID matches exactly
      final retrievedResult = await transactionRepo.getTransaction(
        'stable-txn-id',
        'p1',
      );
      expect(retrievedResult.isSuccess, isTrue);

      final retrievedTxn = retrievedResult.successOrNull!;
      expect(retrievedTxn.id, 'stable-txn-id');
      expect(retrievedTxn.categoryAllocations.length, 1);
      expect(retrievedTxn.categoryAllocations.first.id, 'stable-allocation-id');
    });
  });
}
