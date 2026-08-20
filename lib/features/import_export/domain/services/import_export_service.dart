import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:csv/csv.dart';
import '../../../../core/storage/database.dart';

class ImportExportService {
  final AppDatabase database;

  ImportExportService({required this.database});

  static String encryptPayload(String plainText, List<int> keyBytes) {
    final key = enc.Key(Uint8List.fromList(keyBytes));
    final iv = enc.IV(
      Uint8List(16),
    ); // stable zero-filled IV for lossless offline compatibility
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  static String decryptPayload(String base64Text, List<int> keyBytes) {
    final key = enc.Key(Uint8List.fromList(keyBytes));
    final iv = enc.IV(Uint8List(16));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(base64Text, iv: iv);
  }

  /// Lossless Export: returns encrypted Base64 string of JSON payload
  Future<String> exportBackup(String profileId, List<int> keyBytes) async {
    final profiles = await (database.select(
      database.profiles,
    )..where((t) => t.id.equals(profileId))).get();
    final accounts = await (database.select(
      database.accounts,
    )..where((t) => t.profileId.equals(profileId))).get();
    final categories = await (database.select(
      database.categories,
    )..where((t) => t.profileId.equals(profileId))).get();
    final tags = await (database.select(
      database.tags,
    )..where((t) => t.profileId.equals(profileId))).get();
    final paymentModes = await (database.select(
      database.paymentModes,
    )..where((t) => t.profileId.equals(profileId))).get();
    final goals = await (database.select(
      database.goals,
    )..where((t) => t.profileId.equals(profileId))).get();
    final transactions = await (database.select(
      database.transactions,
    )..where((t) => t.profileId.equals(profileId))).get();
    final budgets = await (database.select(
      database.budgets,
    )..where((t) => t.profileId.equals(profileId))).get();
    final recurringRules = await (database.select(
      database.recurringTransactionRules,
    )..where((t) => t.profileId.equals(profileId))).get();
    final notifications = await (database.select(
      database.notifications,
    )..where((t) => t.profileId.equals(profileId))).get();
    final mergeConflictAudits = await (database.select(
      database.mergeConflictAudits,
    )..where((t) => t.profileId.equals(profileId))).get();
    final unallocatedBudgetPools = await (database.select(
      database.unallocatedBudgetPools,
    )..where((t) => t.profileId.equals(profileId))).get();
    final creditCardStatements = await (database.select(
      database.creditCardStatements,
    )..where((t) => t.profileId.equals(profileId))).get();

    // Fetch allocations for the transactions
    final txIds = transactions.map((tx) => tx.id).toList();
    final List<CategoryAllocationData> categoryAllocations = [];
    final List<TransferAllocationData> transferAllocations = [];

    if (txIds.isNotEmpty) {
      final allCatAllocations = await database
          .select(database.categoryAllocations)
          .get();
      categoryAllocations.addAll(
        allCatAllocations.where((ca) => txIds.contains(ca.transactionId)),
      );

      final allTransAllocations = await database
          .select(database.transferAllocations)
          .get();
      transferAllocations.addAll(
        allTransAllocations.where((ta) => txIds.contains(ta.transactionId)),
      );
    }

    // Occurrences for recurring rules
    final ruleIds = recurringRules.map((r) => r.id).toList();
    final List<RecurringOccurrenceData> recurringOccurrences = [];
    if (ruleIds.isNotEmpty) {
      final allOccurrences = await database
          .select(database.recurringOccurrences)
          .get();
      recurringOccurrences.addAll(
        allOccurrences.where((o) => ruleIds.contains(o.recurringRuleId)),
      );
    }

    final backupPayload = {
      'format': 'pocket_friendly_backup',
      'formatVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'profileId': profileId,
      'data': {
        'profiles': profiles.map((e) => e.toJson()).toList(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'tags': tags.map((e) => e.toJson()).toList(),
        'paymentModes': paymentModes.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'categoryAllocations': categoryAllocations
            .map((e) => e.toJson())
            .toList(),
        'transferAllocations': transferAllocations
            .map((e) => e.toJson())
            .toList(),
        'budgets': budgets.map((e) => e.toJson()).toList(),
        'recurringTransactionRules': recurringRules
            .map((e) => e.toJson())
            .toList(),
        'recurringOccurrences': recurringOccurrences
            .map((e) => e.toJson())
            .toList(),
        'notifications': notifications.map((e) => e.toJson()).toList(),
        'mergeConflictAudits': mergeConflictAudits
            .map((e) => e.toJson())
            .toList(),
        'unallocatedBudgetPools': unallocatedBudgetPools
            .map((e) => e.toJson())
            .toList(),
        'creditCardStatements': creditCardStatements
            .map((e) => e.toJson())
            .toList(),
      },
    };

    final plainText = jsonEncode(backupPayload);
    return encryptPayload(plainText, keyBytes);
  }

  /// Export as CSV: Returns standard CSV string format
  Future<String> exportCSV(String profileId) async {
    final transactions = await (database.select(
      database.transactions,
    )..where((t) => t.profileId.equals(profileId))).get();
    final allCats = await (database.select(
      database.categories,
    )..where((t) => t.profileId.equals(profileId))).get();
    final allAccounts = await (database.select(
      database.accounts,
    )..where((t) => t.profileId.equals(profileId))).get();
    final allModes = await (database.select(
      database.paymentModes,
    )..where((t) => t.profileId.equals(profileId))).get();
    final allTags = await (database.select(
      database.tags,
    )..where((t) => t.profileId.equals(profileId))).get();

    final header = [
      'Date',
      'Type',
      'Subtype',
      'Amount',
      'Currency',
      'Note',
      'Category',
      'Account',
      'Payment Mode',
      'Tag',
    ];
    final rows = <List<dynamic>>[header];

    for (final tx in transactions) {
      final double majorAmount = tx.type.toLowerCase() == 'expense'
          ? -1.0
          : 1.0;
      final category =
          allCats.where((c) => c.id == tx.id).firstOrNull?.name ?? '';
      final mode =
          allModes.where((m) => m.id == tx.paymentModeId).firstOrNull?.name ??
          '';
      final tag =
          allTags.where((t) => t.id == tx.tagId).firstOrNull?.name ?? '';

      rows.add([
        tx.date.toIso8601String(),
        tx.type,
        tx.subtype ?? '',
        majorAmount,
        tx.currency,
        tx.note ?? '',
        category,
        '',
        mode,
        tag,
      ]);
    }

    return const CsvEncoder().convert(rows);
  }

  /// Export as Excel (TSV formatted text)
  Future<String> exportExcel(String profileId) async {
    final csvContent = await exportCSV(profileId);
    // Replace commas with tabs for basic clean Excel TSV import/export compatibility
    return csvContent.replaceAll(',', '\t');
  }

  /// Import: REPLACE EVERYTHING
  Future<bool> importReplaceEverything(
    String backupData,
    List<int> keyBytes,
  ) async {
    try {
      final plainText = decryptPayload(backupData, keyBytes);
      final payload = jsonDecode(plainText) as Map<String, dynamic>;

      if (payload['format'] != 'pocket_friendly_backup') {
        throw Exception('Invalid backup format');
      }

      final data = payload['data'] as Map<String, dynamic>;

      await database.transaction(() async {
        // Drop all data safely (dependencies first)
        await database.delete(database.creditCardStatements).go();
        await database.delete(database.unallocatedBudgetPools).go();
        await database.delete(database.mergeConflictAudits).go();
        await database.delete(database.notifications).go();
        await database.delete(database.recurringOccurrences).go();
        await database.delete(database.recurringTransactionRules).go();
        await database.delete(database.budgets).go();
        await database.delete(database.transferAllocations).go();
        await database.delete(database.categoryAllocations).go();
        await database.delete(database.transactions).go();
        await database.delete(database.goals).go();
        await database.delete(database.paymentModes).go();
        await database.delete(database.tags).go();
        await database.delete(database.categories).go();
        await database.delete(database.accounts).go();
        await database.delete(database.profiles).go();

        // Restore
        final profiles = data['profiles'] as List;
        for (final item in profiles) {
          await database
              .into(database.profiles)
              .insert(ProfileData.fromJson(item as Map<String, dynamic>));
        }

        final accounts = data['accounts'] as List;
        for (final item in accounts) {
          await database
              .into(database.accounts)
              .insert(AccountData.fromJson(item as Map<String, dynamic>));
        }

        final categories = data['categories'] as List;
        for (final item in categories) {
          await database
              .into(database.categories)
              .insert(CategoryData.fromJson(item as Map<String, dynamic>));
        }

        final tags = data['tags'] as List;
        for (final item in tags) {
          await database
              .into(database.tags)
              .insert(TagData.fromJson(item as Map<String, dynamic>));
        }

        final paymentModes = data['paymentModes'] as List;
        for (final item in paymentModes) {
          await database
              .into(database.paymentModes)
              .insert(PaymentModeData.fromJson(item as Map<String, dynamic>), mode: InsertMode.insertOrReplace);
        }

        final goals = data['goals'] as List;
        for (final item in goals) {
          await database
              .into(database.goals)
              .insert(GoalData.fromJson(item as Map<String, dynamic>));
        }

        final transactions = data['transactions'] as List;
        for (final item in transactions) {
          await database
              .into(database.transactions)
              .insert(TransactionData.fromJson(item as Map<String, dynamic>));
        }

        final categoryAllocations = data['categoryAllocations'] as List;
        for (final item in categoryAllocations) {
          await database
              .into(database.categoryAllocations)
              .insert(
                CategoryAllocationData.fromJson(item as Map<String, dynamic>),
              );
        }

        final transferAllocations = data['transferAllocations'] as List;
        for (final item in transferAllocations) {
          await database
              .into(database.transferAllocations)
              .insert(
                TransferAllocationData.fromJson(item as Map<String, dynamic>),
              );
        }

        final budgets = data['budgets'] as List;
        for (final item in budgets) {
          await database
              .into(database.budgets)
              .insert(BudgetData.fromJson(item as Map<String, dynamic>));
        }

        final recurringRules = data['recurringTransactionRules'] as List;
        for (final item in recurringRules) {
          await database
              .into(database.recurringTransactionRules)
              .insert(
                RecurringTransactionRuleData.fromJson(
                  item as Map<String, dynamic>,
                ),
              );
        }

        final recurringOccurrences = data['recurringOccurrences'] as List;
        for (final item in recurringOccurrences) {
          await database
              .into(database.recurringOccurrences)
              .insert(
                RecurringOccurrenceData.fromJson(item as Map<String, dynamic>),
              );
        }

        final notifications = data['notifications'] as List;
        for (final item in notifications) {
          await database
              .into(database.notifications)
              .insert(NotificationData.fromJson(item as Map<String, dynamic>));
        }

        final mergeConflictAudits = data['mergeConflictAudits'] as List;
        for (final item in mergeConflictAudits) {
          await database
              .into(database.mergeConflictAudits)
              .insert(
                MergeConflictAuditData.fromJson(item as Map<String, dynamic>),
              );
        }

        final unallocatedBudgetPools = data['unallocatedBudgetPools'] as List;
        for (final item in unallocatedBudgetPools) {
          await database
              .into(database.unallocatedBudgetPools)
              .insert(
                UnallocatedBudgetPoolData.fromJson(
                  item as Map<String, dynamic>,
                ),
              );
        }

        final creditCardStatements = data['creditCardStatements'] as List;
        for (final item in creditCardStatements) {
          await database
              .into(database.creditCardStatements)
              .insert(
                CreditCardStatementData.fromJson(item as Map<String, dynamic>),
              );
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Import: MERGE
  Future<bool> importMerge(String backupData, List<int> keyBytes) async {
    try {
      final plainText = decryptPayload(backupData, keyBytes);
      final payload = jsonDecode(plainText) as Map<String, dynamic>;

      if (payload['format'] != 'pocket_friendly_backup') {
        throw Exception('Invalid backup format');
      }

      final data = payload['data'] as Map<String, dynamic>;

      await database.transaction(() async {
        // Resolve Profiles
        final profiles = data['profiles'] as List;
        for (final item in profiles) {
          final p = ProfileData.fromJson(item as Map<String, dynamic>);
          final existing = await (database.select(
            database.profiles,
          )..where((t) => t.id.equals(p.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.profiles).insert(p);
          }
        }

        // Resolve Accounts
        final accounts = data['accounts'] as List;
        for (final item in accounts) {
          final a = AccountData.fromJson(item as Map<String, dynamic>);
          final existing = await (database.select(
            database.accounts,
          )..where((t) => t.id.equals(a.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.accounts).insert(a);
          } else {
            // Keep current or newer updatedAt
            if (a.updatedAt.isAfter(existing.updatedAt)) {
              await (database.update(
                database.accounts,
              )..where((t) => t.id.equals(a.id))).write(a);
            }
          }
        }

        // Resolve Categories
        final categories = data['categories'] as List;
        for (final item in categories) {
          final c = CategoryData.fromJson(item as Map<String, dynamic>);
          final existing = await (database.select(
            database.categories,
          )..where((t) => t.id.equals(c.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.categories).insert(c);
          }
        }

        // Resolve Goals
        final goals = data['goals'] as List;
        for (final item in goals) {
          final g = GoalData.fromJson(item as Map<String, dynamic>);
          final existing = await (database.select(
            database.goals,
          )..where((t) => t.id.equals(g.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.goals).insert(g);
          }
        }

        // Resolve Tags
        final tags = data['tags'] as List;
        for (final item in tags) {
          final tg = TagData.fromJson(item as Map<String, dynamic>);
          final existing = await (database.select(
            database.tags,
          )..where((t) => t.id.equals(tg.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.tags).insert(tg);
          }
        }

        // Resolve Payment Modes
        final modes = data['paymentModes'] as List;
        for (final item in modes) {
          final pm = PaymentModeData.fromJson(item as Map<String, dynamic>);
          final existing = await (database.select(
            database.paymentModes,
          )..where((t) => t.id.equals(pm.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.paymentModes).insert(pm);
          }
        }

        // Resolve Transactions
        final transactions = data['transactions'] as List;
        for (final item in transactions) {
          final tx = TransactionData.fromJson(item as Map<String, dynamic>);
          final existing = await (database.select(
            database.transactions,
          )..where((t) => t.id.equals(tx.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.transactions).insert(tx);
          } else {
            // Check for amount/type conflict (Material conflicts trigger MergeConflictAudits)
            final bool amountDiff =
                tx.type != existing.type || tx.currency != existing.currency;
            if (amountDiff) {
              final audit = MergeConflictAuditData(
                id: 'audit_${tx.id}',
                profileId: tx.profileId,
                entityType: 'transaction',
                entityId: tx.id,
                localPayload: jsonEncode(existing.toJson()),
                importedPayload: jsonEncode(tx.toJson()),
                userDecision: 'KEEP_CURRENT',
                decidedAt: DateTime.now(),
              );
              await database.into(database.mergeConflictAudits).insert(audit);
            } else if (tx.updatedAt.isAfter(existing.updatedAt)) {
              await (database.update(
                database.transactions,
              )..where((t) => t.id.equals(tx.id))).write(tx);
            }
          }
        }

        // Category allocations
        final categoryAllocations = data['categoryAllocations'] as List;
        for (final item in categoryAllocations) {
          final ca = CategoryAllocationData.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (database.select(
            database.categoryAllocations,
          )..where((t) => t.id.equals(ca.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.categoryAllocations).insert(ca);
          }
        }

        // Transfer allocations
        final transferAllocations = data['transferAllocations'] as List;
        for (final item in transferAllocations) {
          final ta = TransferAllocationData.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (database.select(
            database.transferAllocations,
          )..where((t) => t.id.equals(ta.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.transferAllocations).insert(ta);
          }
        }

        // Budgets
        final budgets = data['budgets'] as List;
        for (final item in budgets) {
          final b = BudgetData.fromJson(item as Map<String, dynamic>);
          final existing = await (database.select(
            database.budgets,
          )..where((t) => t.id.equals(b.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.budgets).insert(b);
          }
        }

        // Recurring Rules
        final rules = data['recurringTransactionRules'] as List;
        for (final item in rules) {
          final r = RecurringTransactionRuleData.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (database.select(
            database.recurringTransactionRules,
          )..where((t) => t.id.equals(r.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.recurringTransactionRules).insert(r);
          }
        }

        // Recurring Occurrences
        final occs = data['recurringOccurrences'] as List;
        for (final item in occs) {
          final o = RecurringOccurrenceData.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (database.select(
            database.recurringOccurrences,
          )..where((t) => t.id.equals(o.id))).getSingleOrNull();
          if (existing == null) {
            await database.into(database.recurringOccurrences).insert(o);
          }
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Import: TO A NEW PROFILE
  Future<bool> importToNewProfile(String backupData, List<int> keyBytes) async {
    try {
      final plainText = decryptPayload(backupData, keyBytes);
      final payload = jsonDecode(plainText) as Map<String, dynamic>;

      if (payload['format'] != 'pocket_friendly_backup') {
        throw Exception('Invalid backup format');
      }

      final data = payload['data'] as Map<String, dynamic>;
      final oldProfileId = payload['profileId'] as String;
      final newProfileId =
          'profile_new_${DateTime.now().millisecondsSinceEpoch}';

      await database.transaction(() async {
        // Resolve profile
        final profiles = data['profiles'] as List;
        for (final item in profiles) {
          final p = ProfileData.fromJson(item as Map<String, dynamic>);
          final remapped = p.copyWith(id: newProfileId);
          await database.into(database.profiles).insert(remapped);
        }

        // Resolve Accounts
        final accounts = data['accounts'] as List;
        for (final item in accounts) {
          final a = AccountData.fromJson(item as Map<String, dynamic>);
          if (a.profileId == oldProfileId) {
            final remapped = a.copyWith(profileId: newProfileId);
            await database.into(database.accounts).insert(remapped);
          }
        }

        // Resolve Categories
        final categories = data['categories'] as List;
        for (final item in categories) {
          final c = CategoryData.fromJson(item as Map<String, dynamic>);
          if (c.profileId == oldProfileId) {
            final remapped = c.copyWith(profileId: newProfileId);
            await database.into(database.categories).insert(remapped);
          }
        }

        // Resolve Goals
        final goals = data['goals'] as List;
        for (final item in goals) {
          final g = GoalData.fromJson(item as Map<String, dynamic>);
          if (g.profileId == oldProfileId) {
            final remapped = g.copyWith(profileId: newProfileId);
            await database.into(database.goals).insert(remapped);
          }
        }

        // Resolve Tags
        final tags = data['tags'] as List;
        for (final item in tags) {
          final tg = TagData.fromJson(item as Map<String, dynamic>);
          if (tg.profileId == oldProfileId) {
            final remapped = tg.copyWith(profileId: newProfileId);
            await database.into(database.tags).insert(remapped);
          }
        }

        // Resolve Payment Modes
        final modes = data['paymentModes'] as List;
        for (final item in modes) {
          final pm = PaymentModeData.fromJson(item as Map<String, dynamic>);
          if (pm.profileId == oldProfileId) {
            final remapped = pm.copyWith(profileId: newProfileId);
            await database.into(database.paymentModes).insert(remapped, mode: InsertMode.insertOrReplace);
          }
        }

        // Resolve Transactions
        final transactions = data['transactions'] as List;
        for (final item in transactions) {
          final tx = TransactionData.fromJson(item as Map<String, dynamic>);
          if (tx.profileId == oldProfileId) {
            final remapped = tx.copyWith(profileId: newProfileId);
            await database.into(database.transactions).insert(remapped);
          }
        }

        // Category allocations
        final categoryAllocations = data['categoryAllocations'] as List;
        for (final item in categoryAllocations) {
          final ca = CategoryAllocationData.fromJson(
            item as Map<String, dynamic>,
          );
          await database.into(database.categoryAllocations).insert(ca);
        }

        // Transfer allocations
        final transferAllocations = data['transferAllocations'] as List;
        for (final item in transferAllocations) {
          final ta = TransferAllocationData.fromJson(
            item as Map<String, dynamic>,
          );
          await database.into(database.transferAllocations).insert(ta);
        }

        // Budgets
        final budgets = data['budgets'] as List;
        for (final item in budgets) {
          final b = BudgetData.fromJson(item as Map<String, dynamic>);
          if (b.profileId == oldProfileId) {
            final remapped = b.copyWith(profileId: newProfileId);
            await database.into(database.budgets).insert(remapped);
          }
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }
}
