import 'package:drift/drift.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/database.dart';
import '../../domain/account.dart';
import '../../domain/credit_card_statement.dart';
import '../../domain/payment_mode.dart';
import '../../domain/repositories/account_repository.dart';
import '../../../../features/transactions/domain/transaction.dart';
import '../../../../features/transactions/domain/services/financial_engine.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AppDatabase _database;

  AccountRepositoryImpl(this._database);

  Account _toDomain(AccountData data) {
    return Account.create(
      id: data.id,
      profileId: data.profileId,
      type: AccountType.values.byName(data.type),
      name: data.name,
      currency: data.currency,
      icon: data.icon,
      openingBalance: data.openingBalance,
      status: AccountStatus.values.byName(data.status),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      archivedAt: data.archivedAt,
      creditLimit: data.creditLimit,
      openingOutstanding: data.openingOutstanding,
      billGenerationDay: data.billGenerationDay,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database Account to Domain: ${failure.message}',
      ),
    );
  }

  PaymentMode _pmToDomain(PaymentModeData data) {
    final typesList = data.applicableAccountTypes
        .split(',')
        .where((s) => s.isNotEmpty)
        .map((s) => AccountType.values.byName(s))
        .toList();

    return PaymentMode.create(
      id: data.id,
      profileId: data.profileId,
      name: data.name,
      applicableAccountTypes: typesList,
      isDefault: data.isDefault,
      isSystem: data.isSystem,
      status: PaymentModeStatus.values.byName(data.status),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      archivedAt: data.archivedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database PaymentMode to Domain: ${failure.message}',
      ),
    );
  }

  CreditCardStatement _statementToDomain(CreditCardStatementData data) {
    return CreditCardStatement.create(
      id: data.id,
      profileId: data.profileId,
      accountId: data.accountId,
      statementCycle: data.statementCycle,
      statementPeriodStart: data.statementPeriodStart,
      statementPeriodEnd: data.statementPeriodEnd,
      outstandingAmount: data.outstandingAmount,
      isSettled: data.isSettled,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database CreditCardStatement: ${failure.message}',
      ),
    );
  }

  @override
  Future<Result<Account, Failure>> getAccount(
    String accountId,
    String profileId,
  ) async {
    try {
      final query = _database.select(_database.accounts)
        ..where((t) => t.id.equals(accountId) & t.profileId.equals(profileId));
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(
          DatabaseFailure(
            'Account not found with ID: $accountId for profile: $profileId',
          ),
        );
      }
      return Success(_toDomain(result));
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch account', e));
    }
  }

  @override
  Future<Result<List<Account>, Failure>> getAccounts(
    String profileId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _database.select(_database.accounts)
        ..where((t) => t.profileId.equals(profileId));

      if (!includeArchived) {
        query.where((t) => t.status.equals(AccountStatus.active.name));
      }

      final results = await query.get();
      final accounts = results.map(_toDomain).toList();
      return Success(accounts);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch accounts', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveAccount(Account account) async {
    try {
      final companion = AccountsCompanion(
        id: Value(account.id),
        profileId: Value(account.profileId),
        type: Value(account.type.name),
        name: Value(account.name),
        currency: Value(account.currency),
        icon: Value(account.icon),
        openingBalance: Value(account.openingBalance),
        status: Value(account.status.name),
        createdAt: Value(account.createdAt),
        updatedAt: Value(account.updatedAt),
        archivedAt: Value(account.archivedAt),
        creditLimit: Value(account.creditLimit),
        openingOutstanding: Value(account.openingOutstanding),
        billGenerationDay: Value(account.billGenerationDay),
      );
      await _database
          .into(_database.accounts)
          .insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save account', e));
    }
  }

  @override
  Future<Result<void, Failure>> archiveAccount(
    String accountId,
    String profileId,
  ) async {
    try {
      final now = DateTime.now();
      final query = _database.update(_database.accounts)
        ..where((t) => t.id.equals(accountId) & t.profileId.equals(profileId));

      await query.write(
        AccountsCompanion(
          status: Value(AccountStatus.archived.name),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to archive account', e));
    }
  }

  @override
  Future<Result<List<CreditCardStatement>, Failure>> getCreditCardStatements(
    String accountId,
    String profileId,
  ) async {
    try {
      final query = _database.select(_database.creditCardStatements)
        ..where(
          (t) => t.accountId.equals(accountId) & t.profileId.equals(profileId),
        )
        ..orderBy([
          (t) => OrderingTerm(
            expression: t.statementPeriodEnd,
            mode: OrderingMode.desc,
          ),
        ]);
      final results = await query.get();
      return Success(results.map(_statementToDomain).toList());
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to fetch credit card statements', e),
      );
    }
  }

  @override
  Future<Result<void, Failure>> saveCreditCardStatement(
    CreditCardStatement statement,
  ) async {
    try {
      final companion = CreditCardStatementsCompanion(
        id: Value(statement.id),
        profileId: Value(statement.profileId),
        accountId: Value(statement.accountId),
        statementCycle: Value(statement.statementCycle),
        statementPeriodStart: Value(statement.statementPeriodStart),
        statementPeriodEnd: Value(statement.statementPeriodEnd),
        outstandingAmount: Value(statement.outstandingAmount),
        isSettled: Value(statement.isSettled),
        createdAt: Value(statement.createdAt),
        updatedAt: Value(statement.updatedAt),
      );
      await _database
          .into(_database.creditCardStatements)
          .insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to save credit card statement', e),
      );
    }
  }

  @override
  Future<Result<void, Failure>> generateStatementIfNeeded(
    String accountId,
    String profileId,
    DateTime targetDate,
  ) async {
    try {
      final accountRes = await getAccount(accountId, profileId);
      if (accountRes.isFailure) return FailureResult(accountRes.failureOrNull!);
      final account = accountRes.successOrNull!;

      if (account.type != AccountType.creditCard) {
        return const Success(null);
      }

      final billDay = account.billGenerationDay;
      if (billDay == null || billDay < 1 || billDay > 31) {
        return const Success(null);
      }

      final startYear = account.createdAt.year;
      final startMonth = account.createdAt.month;
      final endYear = targetDate.year;
      final endMonth = targetDate.month;

      await _database.transaction(() async {
        int currentYear = startYear;
        int currentMonth = startMonth;

        while (currentYear < endYear ||
            (currentYear == endYear && currentMonth <= endMonth)) {
          final lastDayOfMonth = DateTime(currentYear, currentMonth + 1, 0).day;
          final actualBillDay = billDay > lastDayOfMonth
              ? lastDayOfMonth
              : billDay;
          final billDate = DateTime(
            currentYear,
            currentMonth,
            actualBillDay,
            23,
            59,
            59,
            999,
          );

          if (billDate.isAfter(targetDate)) {
            break;
          }

          final cycle =
              '$currentYear-${currentMonth.toString().padLeft(2, '0')}';

          final existing =
              await (_database.select(_database.creditCardStatements)..where(
                    (t) =>
                        t.accountId.equals(accountId) &
                        t.profileId.equals(profileId) &
                        t.statementCycle.equals(cycle),
                  ))
                  .getSingleOrNull();

          if (existing == null) {
            DateTime periodStart;
            if (currentMonth == startMonth && currentYear == startYear) {
              periodStart = account.createdAt;
            } else {
              final prevYear = currentMonth == 1
                  ? currentYear - 1
                  : currentYear;
              final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
              final prevLastDay = DateTime(prevYear, prevMonth + 1, 0).day;
              final prevActualBillDay = billDay > prevLastDay
                  ? prevLastDay
                  : billDay;
              periodStart = DateTime(
                prevYear,
                prevMonth,
                prevActualBillDay,
                23,
                59,
                59,
                999,
              ).add(const Duration(milliseconds: 1));
            }

            final txQuery =
                _database.select(_database.transactions).join([
                  leftOuterJoin(
                    _database.transferAllocations,
                    _database.transferAllocations.transactionId.equalsExp(
                      _database.transactions.id,
                    ),
                  ),
                ])..where(
                  _database.transactions.profileId.equals(profileId) &
                      _database.transactions.status.equals(
                        TransactionStatus.active.name.toUpperCase(),
                      ) &
                      _database.transactions.date.isSmallerThanValue(billDate) &
                      (_database.transactions.paymentModeId.equals(accountId) |
                          (_database.transferAllocations.accountId.equals(
                                accountId,
                              ) &
                              _database.transferAllocations.endpointType.equals(
                                EndpointType.account.name.toUpperCase(),
                              ))),
                );

            final txResults = await txQuery.get();

            final allocationsMap = <String, List<TransferAllocation>>{};
            for (final row in txResults) {
              final ta = row.readTableOrNull(_database.transferAllocations);
              if (ta == null) continue;

              final domainTa = TransferAllocation.create(
                id: ta.id,
                transactionId: ta.transactionId,
                role: AllocationRole.values.byName(ta.role.toLowerCase()),
                endpointType: EndpointType.values.byName(ta.endpointType.toLowerCase()),
                accountId: ta.accountId,
                goalId: ta.goalId,
                amount: ta.amount,
                currency: ta.currency,
              ).successOrNull!;

              allocationsMap.putIfAbsent(ta.transactionId, () => []).add(domainTa);
            }

            final transactionMap = <String, Transaction>{};
            for (final row in txResults) {
              final tx = row.readTable(_database.transactions);
              if (transactionMap.containsKey(tx.id)) continue;

              final caQuery = _database.select(_database.categoryAllocations)
                ..where((t) => t.transactionId.equals(tx.id));
              final caResults = await caQuery.get();
              final categoryAllocations = caResults
                  .map(
                    (ca) => CategoryAllocation.create(
                      id: ca.id,
                      transactionId: ca.transactionId,
                      categoryId: ca.categoryId,
                      amount: ca.amount,
                      currency: ca.currency,
                    ).successOrNull!,
                  )
                  .toList();

              final transferAllocations = allocationsMap[tx.id] ?? const [];

              final txn = Transaction.create(
                id: tx.id,
                profileId: tx.profileId,
                type: TransactionType.values.byName(tx.type.toLowerCase()),
                subtype: tx.subtype,
                date: tx.date,
                currency: tx.currency,
                totalAmount: categoryAllocations.fold(
                  0,
                  (sum, ca) => sum + ca.amount,
                ),
                paymentModeId: tx.paymentModeId,
                status: TransactionStatus.active,
                createdAt: tx.createdAt,
                updatedAt: tx.updatedAt,
                categoryAllocations: categoryAllocations,
                transferAllocations: transferAllocations,
              ).successOrNull!;
              transactionMap[tx.id] = txn;
            }

            final transactionsList = transactionMap.values.toList();
            final outstandingAmount =
                FinancialEngine.calculateCreditCardOutstanding(
                  account,
                  transactionsList,
                );

            final statementCompanion = CreditCardStatementsCompanion(
              id: Value('${accountId}_stmt_$cycle'),
              profileId: Value(profileId),
              accountId: Value(accountId),
              statementCycle: Value(cycle),
              statementPeriodStart: Value(periodStart),
              statementPeriodEnd: Value(billDate),
              outstandingAmount: Value(outstandingAmount),
              isSettled: Value(false),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            );
            await _database
                .into(_database.creditCardStatements)
                .insert(statementCompanion);
          }

          if (currentMonth == 12) {
            currentMonth = 1;
            currentYear++;
          } else {
            currentMonth++;
          }
        }
      });

      return const Success(null);
    } catch (e, stack) {
      return FailureResult(DatabaseFailure('Failed to generate statement: $e\n$stack', e));
    }
  }

  @override
  Future<Result<PaymentMode, Failure>> getPaymentMode(
    String modeId,
    String profileId,
  ) async {
    try {
      final query = _database.select(_database.paymentModes)
        ..where((t) => t.id.equals(modeId) & t.profileId.equals(profileId));
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(
          DatabaseFailure(
            'PaymentMode not found with ID: $modeId for profile: $profileId',
          ),
        );
      }
      return Success(_pmToDomain(result));
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch payment mode', e));
    }
  }

  @override
  Future<Result<List<PaymentMode>, Failure>> getPaymentModes(
    String profileId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _database.select(_database.paymentModes)
        ..where((t) => t.profileId.equals(profileId));

      if (!includeArchived) {
        query.where((t) => t.status.equals(PaymentModeStatus.active.name));
      }

      final results = await query.get();
      final modes = results.map(_pmToDomain).toList();
      return Success(modes);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch payment modes', e));
    }
  }

  @override
  Future<Result<void, Failure>> savePaymentMode(PaymentMode mode) async {
    try {
      final typesString = mode.applicableAccountTypes
          .map((e) => e.name)
          .join(',');
      final companion = PaymentModesCompanion(
        id: Value(mode.id),
        profileId: Value(mode.profileId),
        name: Value(mode.name),
        applicableAccountTypes: Value(typesString),
        isDefault: Value(mode.isDefault),
        isSystem: Value(mode.isSystem),
        status: Value(mode.status.name),
        createdAt: Value(mode.createdAt),
        updatedAt: Value(mode.updatedAt),
        archivedAt: Value(mode.archivedAt),
      );
      await _database
          .into(_database.paymentModes)
          .insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save payment mode', e));
    }
  }

  @override
  Future<Result<void, Failure>> archivePaymentMode(
    String modeId,
    String profileId,
  ) async {
    try {
      final now = DateTime.now();
      final query = _database.update(_database.paymentModes)
        ..where((t) => t.id.equals(modeId) & t.profileId.equals(profileId));

      await query.write(
        PaymentModesCompanion(
          status: Value(PaymentModeStatus.archived.name),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to archive payment mode', e),
      );
    }
  }
}
