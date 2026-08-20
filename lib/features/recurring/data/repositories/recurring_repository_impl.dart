import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/database.dart';
import '../../../../core/platform/notification_service.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import '../recurring_rule.dart';
import '../../domain/repositories/recurring_repository.dart';
import '../../../accounts/domain/payment_mode.dart';
import '../../../accounts/domain/account.dart';
import '../../../categories/domain/category.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  final AppDatabase _database;

  RecurringRepositoryImpl(this._database);

  RecurringTransactionRule _ruleToDomain(RecurringTransactionRuleData data) {
    return RecurringTransactionRule.create(
      id: data.id,
      profileId: data.profileId,
      transactionTemplate: data.transactionTemplate,
      frequency: RecurringFrequency.values.byName(data.frequency.toLowerCase()),
      dayOfPeriod: data.dayOfPeriod,
      mode: RecurringMode.values.byName(data.mode),
      nextOccurrence: data.nextOccurrence,
      active: data.active,
      splitFromRuleId: data.splitFromRuleId,
      lastExecutedAt: data.lastExecutedAt,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception('Failed to map database RecurringTransactionRule: ${failure.message}'),
    );
  }

  RecurringOccurrence _occurrenceToDomain(RecurringOccurrenceData data) {
    return RecurringOccurrence.create(
      id: data.id,
      recurringRuleId: data.recurringRuleId,
      scheduledOccurrenceDate: data.scheduledOccurrenceDate,
      status: OccurrenceStatus.values.byName(data.status.toLowerCase()),
      createdTransactionId: data.createdTransactionId,
      executedAt: data.executedAt,
      skippedAt: data.skippedAt,
      failedAt: data.failedAt,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception('Failed to map database RecurringOccurrence: ${failure.message}'),
    );
  }

  @override
  Future<Result<List<RecurringTransactionRule>, Failure>> getActiveRules(String profileId) async {
    try {
      final query = _database.select(_database.recurringTransactionRules)
        ..where((t) => t.profileId.equals(profileId) & t.active.equals(true));
      final results = await query.get();
      return Success(results.map(_ruleToDomain).toList());
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch active rules', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveRule(RecurringTransactionRule rule) async {
    try {
      final companion = RecurringTransactionRulesCompanion(
        id: Value(rule.id),
        profileId: Value(rule.profileId),
        transactionTemplate: Value(rule.transactionTemplate),
        frequency: Value(rule.frequency.name),
        dayOfPeriod: Value(rule.dayOfPeriod),
        mode: Value(rule.mode.name),
        nextOccurrence: Value(rule.nextOccurrence),
        active: Value(rule.active),
        splitFromRuleId: Value(rule.splitFromRuleId),
        lastExecutedAt: Value(rule.lastExecutedAt),
        createdAt: Value(rule.createdAt),
        updatedAt: Value(rule.updatedAt),
      );
      await _database.into(_database.recurringTransactionRules).insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save rule', e));
    }
  }

  @override
  Future<Result<void, Failure>> deactivateRule(String ruleId) async {
    try {
      final query = _database.update(_database.recurringTransactionRules)..where((t) => t.id.equals(ruleId));
      await query.write(RecurringTransactionRulesCompanion(
        active: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to deactivate rule', e));
    }
  }

  @override
  Future<Result<List<RecurringOccurrence>, Failure>> getOccurrences(String ruleId) async {
    try {
      final query = _database.select(_database.recurringOccurrences)
        ..where((t) => t.recurringRuleId.equals(ruleId));
      final results = await query.get();
      return Success(results.map(_occurrenceToDomain).toList());
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch occurrences', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveOccurrence(RecurringOccurrence occurrence) async {
    try {
      final companion = RecurringOccurrencesCompanion(
        id: Value(occurrence.id),
        recurringRuleId: Value(occurrence.recurringRuleId),
        scheduledOccurrenceDate: Value(occurrence.scheduledOccurrenceDate),
        status: Value(occurrence.status.name.toUpperCase()),
        createdTransactionId: Value(occurrence.createdTransactionId),
        executedAt: Value(occurrence.executedAt),
        skippedAt: Value(occurrence.skippedAt),
        failedAt: Value(occurrence.failedAt),
        createdAt: Value(occurrence.createdAt),
        updatedAt: Value(occurrence.updatedAt),
      );
      await _database.into(_database.recurringOccurrences).insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save occurrence', e));
    }
  }

  /// Calculates the next occurrence date based on the current date, frequency, and dayOfPeriod.
  DateTime calculateNextOccurrenceDate(DateTime current, RecurringFrequency frequency, int dayOfPeriod) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return current.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return current.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        int nextMonth = current.month + 1;
        int nextYear = current.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
        final targetDay = dayOfPeriod > lastDay ? lastDay : dayOfPeriod;
        return DateTime(nextYear, nextMonth, targetDay);
      case RecurringFrequency.yearly:
        int nextYear = current.year + 1;
        final lastDayOfFeb = DateTime(nextYear, 3, 0).day;
        if (current.month == 2 && current.day == 29 && lastDayOfFeb == 28) {
          return DateTime(nextYear, 2, 28);
        }
        return DateTime(nextYear, current.month, current.day);
    }
  }

  Transaction? _parseTemplate(
    String templateJsonStr,
    String ruleId,
    DateTime occurrenceDate,
    String profileId,
  ) {
    try {
      final map = jsonDecode(templateJsonStr) as Map<String, dynamic>;
      
      final typeStr = map['type'] as String? ?? 'expense';
      final type = TransactionType.values.byName(typeStr.toLowerCase());

      final subtype = map['subtype'] as String?;
      final totalAmount = map['totalAmount'] as int;
      final currency = map['currency'] as String;
      final paymentModeId = map['paymentModeId'] as String;
      final note = map['note'] as String?;

      final caList = <CategoryAllocation>[];
      final caJson = map['categoryAllocations'] as List<dynamic>?;
      if (caJson != null) {
        for (final item in caJson) {
          final ca = CategoryAllocation.create(
            id: 'ca_rec_${ruleId}_${occurrenceDate.toIso8601String().substring(0, 10)}_${item['categoryId']}',
            transactionId: 'tx_rec_${ruleId}_${occurrenceDate.toIso8601String().substring(0, 10)}',
            categoryId: item['categoryId'] as String,
            amount: item['amount'] as int,
            currency: currency,
          ).successOrNull!;
          caList.add(ca);
        }
      }

      final taList = <TransferAllocation>[];
      final taJson = map['transferAllocations'] as List<dynamic>?;
      if (taJson != null) {
        for (final item in taJson) {
          final ta = TransferAllocation.create(
            id: 'ta_rec_${ruleId}_${occurrenceDate.toIso8601String().substring(0, 10)}_${item['id'] ?? item['role']}',
            transactionId: 'tx_rec_${ruleId}_${occurrenceDate.toIso8601String().substring(0, 10)}',
            role: AllocationRole.values.byName(item['role'].toString().toLowerCase()),
            endpointType: EndpointType.values.byName(item['endpointType'].toString().toLowerCase()),
            accountId: item['accountId'] as String?,
            goalId: item['goalId'] as String?,
            amount: item['amount'] as int,
            currency: currency,
          ).successOrNull!;
          taList.add(ta);
        }
      }

      return Transaction.create(
        id: 'tx_rec_${ruleId}_${occurrenceDate.toIso8601String().substring(0, 10)}',
        profileId: profileId,
        type: type,
        subtype: subtype,
        date: occurrenceDate,
        currency: currency,
        totalAmount: totalAmount,
        paymentModeId: paymentModeId,
        status: TransactionStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        note: note,
        categoryAllocations: caList,
        transferAllocations: taList,
      ).successOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _validateDependencies(
    Transaction tx,
    AccountRepository accountRepository,
    CategoryRepository categoryRepository,
  ) async {
    // 1. Validate payment mode
    final pmRes = await accountRepository.getPaymentMode(tx.paymentModeId, tx.profileId);
    if (pmRes.isFailure || pmRes.successOrNull!.status == PaymentModeStatus.archived) {
      return false;
    }

    // 2. Validate category allocations
    for (final ca in tx.categoryAllocations) {
      final catRes = await categoryRepository.getCategory(ca.categoryId, tx.profileId);
      if (catRes.isFailure || catRes.successOrNull!.status == CategoryStatus.archived) {
        return false;
      }
    }

    // 3. Validate transfer allocations endpoints
    for (final ta in tx.transferAllocations) {
      if (ta.endpointType == EndpointType.account) {
        final accRes = await accountRepository.getAccount(ta.accountId!, tx.profileId);
        if (accRes.isFailure || accRes.successOrNull!.status == AccountStatus.archived) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  Future<Result<void, Failure>> runRecurringExecution({
    required String profileId,
    required DateTime today,
    required TransactionRepository transactionRepository,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required NotificationService notificationService,
  }) async {
    try {
      final rulesRes = await getActiveRules(profileId);
      if (rulesRes.isFailure) return FailureResult(rulesRes.failureOrNull!);
      final rules = rulesRes.successOrNull!;

      final todayMidnight = DateTime(today.year, today.month, today.day);

      for (final rule in rules) {
        DateTime currentOccurrence = rule.nextOccurrence;
        DateTime currentOccurrenceMidnight = DateTime(
          currentOccurrence.year,
          currentOccurrence.month,
          currentOccurrence.day,
        );

        while (!currentOccurrenceMidnight.isAfter(todayMidnight)) {
          final occurrenceDateStr = currentOccurrence.toIso8601String().substring(0, 10);
          final occurrenceId = 'occ_${rule.id}_$occurrenceDateStr';
          final txId = 'tx_rec_${rule.id}_$occurrenceDateStr';

          // 1. Idempotency Check: check if occurrence exists
          final existingQuery = _database.select(_database.recurringOccurrences)
            ..where((t) => t.id.equals(occurrenceId));
          final existing = await existingQuery.getSingleOrNull();

          if (existing != null &&
              (existing.status == OccurrenceStatus.recorded.name.toUpperCase() ||
                  existing.status == OccurrenceStatus.skipped.name.toUpperCase())) {
            // Already handled, advance date and continue
            currentOccurrence = calculateNextOccurrenceDate(currentOccurrence, rule.frequency, rule.dayOfPeriod);
            currentOccurrenceMidnight = DateTime(currentOccurrence.year, currentOccurrence.month, currentOccurrence.day);
            continue;
          }

          // 2. Transaction Repair Check: check if transaction already exists in the database
          final existingTxRes = await transactionRepository.getTransaction(txId, profileId);
          if (existingTxRes.isSuccess) {
            // Transaction exists! Repair by updating occurrence to RECORDED
            final repairOcc = RecurringOccurrence(
              id: occurrenceId,
              recurringRuleId: rule.id,
              scheduledOccurrenceDate: currentOccurrence,
              status: OccurrenceStatus.recorded,
              createdTransactionId: txId,
              executedAt: existingTxRes.successOrNull!.createdAt,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await saveOccurrence(repairOcc);

            currentOccurrence = calculateNextOccurrenceDate(currentOccurrence, rule.frequency, rule.dayOfPeriod);
            currentOccurrenceMidnight = DateTime(currentOccurrence.year, currentOccurrence.month, currentOccurrence.day);
            continue;
          }

          // 3. Process new occurrence
          if (rule.mode == RecurringMode.reminder) {
            // REMINDER MODE: Create pending occurrence and notify
            final occ = RecurringOccurrence(
              id: occurrenceId,
              recurringRuleId: rule.id,
              scheduledOccurrenceDate: currentOccurrence,
              status: OccurrenceStatus.pending,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await saveOccurrence(occ);

            try {
              await notificationService.showNotification(
                rule.id.hashCode + currentOccurrence.day,
                'Upcoming Bill Reminder',
                'Scheduled reminder for occurrence on $occurrenceDateStr.',
              );
            } catch (_) {}
          } else {
            // AUTOMATIC RECORDING MODE: Attempt to record transaction atomically
            final parsedTx = _parseTemplate(rule.transactionTemplate, rule.id, currentOccurrence, profileId);
            bool safeToRecord = false;

            if (parsedTx != null) {
              safeToRecord = await _validateDependencies(parsedTx, accountRepository, categoryRepository);
            }

            if (safeToRecord && parsedTx != null) {
              await _database.transaction(() async {
                // Save the transaction record
                final txResult = await transactionRepository.saveTransaction(parsedTx);
                
                if (txResult.isSuccess) {
                  // Mark occurrence as RECORDED
                  final occ = RecurringOccurrence(
                    id: occurrenceId,
                    recurringRuleId: rule.id,
                    scheduledOccurrenceDate: currentOccurrence,
                    status: OccurrenceStatus.recorded,
                    createdTransactionId: txId,
                    executedAt: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await saveOccurrence(occ);

                  try {
                    await notificationService.showNotification(
                      rule.id.hashCode + currentOccurrence.day,
                      'Automatic Payment Recorded',
                      'Successfully recorded transaction of ${parsedTx.totalAmount} ${parsedTx.currency}.',
                    );
                  } catch (_) {}
                } else {
                  // Transaction failed domain validations (e.g. goal limit violated)
                  final occ = RecurringOccurrence(
                    id: occurrenceId,
                    recurringRuleId: rule.id,
                    scheduledOccurrenceDate: currentOccurrence,
                    status: OccurrenceStatus.failed,
                    failedAt: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await saveOccurrence(occ);

                  try {
                    await notificationService.showNotification(
                      rule.id.hashCode + currentOccurrence.day,
                      'Automatic Payment Failed',
                      'Validation failed while trying to record recurring payment.',
                    );
                  } catch (_) {}
                }
              });
            } else {
              // Dependencies missing/archived or template corrupted -> mark FAILED and notify
              final occ = RecurringOccurrence(
                id: occurrenceId,
                recurringRuleId: rule.id,
                scheduledOccurrenceDate: currentOccurrence,
                status: OccurrenceStatus.failed,
                failedAt: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await saveOccurrence(occ);

              try {
                await notificationService.showNotification(
                  rule.id.hashCode + currentOccurrence.day,
                  'Automatic Payment Failed',
                  'Archived or deleted accounts/categories prevented recording the transaction.',
                );
              } catch (_) {}
            }
          }

          // Advance date to next occurrence
          final nextDate = calculateNextOccurrenceDate(currentOccurrence, rule.frequency, rule.dayOfPeriod);
          
          // Update the rule's nextOccurrence and lastExecutedAt in DB
          final ruleQuery = _database.update(_database.recurringTransactionRules)..where((t) => t.id.equals(rule.id));
          await ruleQuery.write(RecurringTransactionRulesCompanion(
            nextOccurrence: Value(nextDate),
            lastExecutedAt: Value(currentOccurrence),
            updatedAt: Value(DateTime.now()),
          ));

          currentOccurrence = nextDate;
          currentOccurrenceMidnight = DateTime(currentOccurrence.year, currentOccurrence.month, currentOccurrence.day);
        }
      }

      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Recurring execution runner failed', e));
    }
  }
}
