import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/import_export/domain/services/import_export_service.dart';

void main() {
  late AppDatabase database;
  late ImportExportService service;
  final keyBytes = List<int>.generate(32, (i) => i);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = ImportExportService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('Lossless Round-Trip Backup and Restore (Replace Everything)', () async {
    // 1. Create a dummy dataset
    final now = DateTime.now();
    await database
        .into(database.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: 'p1',
            name: 'Test Profile',
            defaultCurrency: 'INR',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'a1',
            profileId: 'p1',
            type: 'Bank',
            name: 'Savings Bank',
            currency: 'INR',
            icon: 'account_balance',
            openingBalance: 1000000,
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'c1',
            profileId: 'p1',
            name: 'Utilities',
            icon: 'electric',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 't1',
            profileId: 'p1',
            type: 'Expense',
            date: now,
            currency: 'INR',
            paymentModeId: 'pm1',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.categoryAllocations)
        .insert(
          CategoryAllocationsCompanion.insert(
            id: 'ca1',
            transactionId: 't1',
            categoryId: 'c1',
            amount: 50000,
            currency: 'INR',
          ),
        );

    // 2. Export lossless backup
    final backupStr = await service.exportBackup('p1', keyBytes);
    expect(backupStr, isNotEmpty);

    // 3. Clear database
    await database.delete(database.categoryAllocations).go();
    await database.delete(database.transactions).go();
    await database.delete(database.categories).go();
    await database.delete(database.accounts).go();
    await database.delete(database.profiles).go();

    final profilesCountBefore = await database.select(database.profiles).get();
    expect(profilesCountBefore, isEmpty);

    // 4. Import / Restore
    final success = await service.importReplaceEverything(backupStr, keyBytes);
    expect(success, isTrue);

    // 5. Compare financial state
    final profilesAfter = await database.select(database.profiles).get();
    expect(profilesAfter.length, 1);
    expect(profilesAfter.first.name, 'Test Profile');

    final accountsAfter = await database.select(database.accounts).get();
    expect(accountsAfter.length, 1);
    expect(accountsAfter.first.openingBalance, 1000000);

    final transactionsAfter = await database
        .select(database.transactions)
        .get();
    expect(transactionsAfter.length, 1);

    final allocationsAfter = await database
        .select(database.categoryAllocations)
        .get();
    expect(allocationsAfter.length, 1);
    expect(allocationsAfter.first.amount, 50000);
  });

  test('Merge Import prevents duplicates and resolves updates', () async {
    final now = DateTime.now();
    await database
        .into(database.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: 'p1',
            name: 'Test Profile',
            defaultCurrency: 'INR',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'a1',
            profileId: 'p1',
            type: 'Bank',
            name: 'Original Account Name',
            currency: 'INR',
            icon: 'bank',
            openingBalance: 50000,
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Prepare backup containing a new name and newer updatedAt
    final exportedBackup = {
      'format': 'pocket_friendly_backup',
      'formatVersion': 1,
      'exportedAt': now.toIso8601String(),
      'profileId': 'p1',
      'data': {
        'profiles': [
          {
            'id': 'p1',
            'name': 'Test Profile',
            'defaultCurrency': 'INR',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        ],
        'accounts': [
          {
            'id': 'a1',
            'profileId': 'p1',
            'type': 'Bank',
            'name': 'Updated Account Name',
            'currency': 'INR',
            'icon': 'bank',
            'openingBalance': 50000,
            'status': 'active',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.add(const Duration(minutes: 5)).toIso8601String(),
            'creditLimit': null,
            'openingOutstanding': null,
            'billGenerationDay': null,
          },
        ],
        'categories': [],
        'tags': [],
        'paymentModes': [],
        'goals': [],
        'transactions': [],
        'categoryAllocations': [],
        'transferAllocations': [],
        'budgets': [],
        'recurringTransactionRules': [],
        'recurringOccurrences': [],
        'notifications': [],
        'mergeConflictAudits': [],
        'unallocatedBudgetPools': [],
        'creditCardStatements': [],
      },
    };

    final encryptedBackup = ImportExportService.encryptPayload(
      jsonDataAsString(exportedBackup),
      keyBytes,
    );

    // Merge
    final success = await service.importMerge(encryptedBackup, keyBytes);
    expect(success, isTrue);

    // Assert that we don't have duplicate records and the fields were merged correctly
    final accounts = await database.select(database.accounts).get();
    expect(accounts.length, 1);
    expect(accounts.first.name, 'Updated Account Name');
  });

  test('Merge Import triggers conflict audit when values differ', () async {
    final now = DateTime.now();
    await database
        .into(database.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: 'p1',
            name: 'Test Profile',
            defaultCurrency: 'INR',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Current transaction
    await database
        .into(database.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 't1',
            profileId: 'p1',
            type: 'Expense',
            date: now,
            currency: 'INR',
            paymentModeId: 'pm1',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Prepare backup containing a transaction with different type (Income)
    final exportedBackup = {
      'format': 'pocket_friendly_backup',
      'formatVersion': 1,
      'exportedAt': now.toIso8601String(),
      'profileId': 'p1',
      'data': {
        'profiles': [],
        'accounts': [],
        'categories': [],
        'tags': [],
        'paymentModes': [],
        'goals': [],
        'transactions': [
          {
            'id': 't1',
            'profileId': 'p1',
            'type': 'Income', // Conflict: Type mismatch
            'subtype': null,
            'date': now.toIso8601String(),
            'currency': 'INR',
            'note': 'Freelance',
            'tagId': null,
            'paymentModeId': 'pm1',
            'recurringRuleId': null,
            'recurringOccurrenceId': null,
            'status': 'active',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
            'archivedAt': null,
          },
        ],
        'categoryAllocations': [],
        'transferAllocations': [],
        'budgets': [],
        'recurringTransactionRules': [],
        'recurringOccurrences': [],
        'notifications': [],
        'mergeConflictAudits': [],
        'unallocatedBudgetPools': [],
        'creditCardStatements': [],
      },
    };

    final encryptedBackup = ImportExportService.encryptPayload(
      jsonDataAsString(exportedBackup),
      keyBytes,
    );

    // Merge
    final success = await service.importMerge(encryptedBackup, keyBytes);
    expect(success, isTrue);

    // Assert that a merge conflict audit record was created
    final audits = await database.select(database.mergeConflictAudits).get();
    expect(audits.length, 1);
    expect(audits.first.entityId, 't1');
    expect(audits.first.userDecision, 'KEEP_CURRENT');
  });

  test(
    'Importing to a new profile generates new profile ID and isolates data',
    () async {
      final now = DateTime.now();

      final exportedBackup = {
        'format': 'pocket_friendly_backup',
        'formatVersion': 1,
        'exportedAt': now.toIso8601String(),
        'profileId': 'p1_old',
        'data': {
          'profiles': [
            {
              'id': 'p1_old',
              'name': 'Old Profile Name',
              'defaultCurrency': 'INR',
              'createdAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            },
          ],
          'accounts': [
            {
              'id': 'a1',
              'profileId': 'p1_old',
              'type': 'Bank',
              'name': 'HDFC Savings',
              'currency': 'INR',
              'icon': 'bank',
              'openingBalance': 20000,
              'status': 'active',
              'createdAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
              'creditLimit': null,
              'openingOutstanding': null,
              'billGenerationDay': null,
            },
          ],
          'categories': [],
          'tags': [],
          'paymentModes': [],
          'goals': [],
          'transactions': [],
          'categoryAllocations': [],
          'transferAllocations': [],
          'budgets': [],
          'recurringTransactionRules': [],
          'recurringOccurrences': [],
          'notifications': [],
          'mergeConflictAudits': [],
          'unallocatedBudgetPools': [],
          'creditCardStatements': [],
        },
      };

      final encryptedBackup = ImportExportService.encryptPayload(
        jsonDataAsString(exportedBackup),
        keyBytes,
      );

      final success = await service.importToNewProfile(
        encryptedBackup,
        keyBytes,
      );
      expect(success, isTrue);

      // Assert that we have a new profile and account belonging to the new profile ID
      final profiles = await database.select(database.profiles).get();
      expect(profiles.length, 1);
      expect(profiles.first.id, isNot('p1_old'));
      expect(profiles.first.id, startsWith('profile_new_'));

      final accounts = await database.select(database.accounts).get();
      expect(accounts.length, 1);
      expect(accounts.first.profileId, profiles.first.id);
    },
  );
}

String jsonDataAsString(Map<String, dynamic> data) => jsonEncode(data);
