import 'package:drift/drift.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/database.dart';
import '../../domain/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _database;

  TransactionRepositoryImpl(this._database);

  CategoryAllocation _caToDomain(CategoryAllocationData data) {
    return CategoryAllocation.create(
      id: data.id,
      transactionId: data.transactionId,
      categoryId: data.categoryId,
      amount: data.amount,
      currency: data.currency,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database CategoryAllocation: ${failure.message}',
      ),
    );
  }

  TransferAllocation _taToDomain(TransferAllocationData data) {
    return TransferAllocation.create(
      id: data.id,
      transactionId: data.transactionId,
      role: AllocationRole.values.byName(data.role.toLowerCase()),
      endpointType: EndpointType.values.byName(data.endpointType.toLowerCase()),
      accountId: data.accountId,
      goalId: data.goalId,
      amount: data.amount,
      currency: data.currency,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database TransferAllocation: ${failure.message}',
      ),
    );
  }

  Future<Transaction> _assembleTransaction(TransactionData tx) async {
    // 1. Fetch category allocations
    final caQuery = _database.select(_database.categoryAllocations)
      ..where((t) => t.transactionId.equals(tx.id));
    final caResults = await caQuery.get();
    final categoryAllocations = caResults.map(_caToDomain).toList();

    // 2. Fetch transfer allocations
    final taQuery = _database.select(_database.transferAllocations)
      ..where((t) => t.transactionId.equals(tx.id));
    final taResults = await taQuery.get();
    final transferAllocations = taResults.map(_taToDomain).toList();

    // 3. Compute totalAmount
    int totalAmount = 0;
    if (tx.subtype == 'balanceAdjustment') {
      totalAmount = transferAllocations.isEmpty
          ? 0
          : transferAllocations.first.amount;
    } else if (tx.type.toLowerCase() == TransactionType.transfer.name) {
      totalAmount = transferAllocations
          .where((ta) => ta.role == AllocationRole.source)
          .map((ta) => ta.amount)
          .fold(0, (sum, amt) => sum + amt);
    } else {
      totalAmount = categoryAllocations
          .map((ca) => ca.amount)
          .fold(0, (sum, amt) => sum + amt);
    }

    return Transaction.create(
      id: tx.id,
      profileId: tx.profileId,
      type: TransactionType.values.byName(tx.type.toLowerCase()),
      subtype: tx.subtype,
      date: tx.date,
      currency: tx.currency,
      totalAmount: totalAmount > 0
          ? totalAmount
          : 1, // Validation requires total > 0.
      note: tx.note,
      tagId: tx.tagId,
      paymentModeId: tx.paymentModeId,
      recurringRuleId: tx.recurringRuleId,
      recurringOccurrenceId: tx.recurringOccurrenceId,
      status: TransactionStatus.values.byName(tx.status.toLowerCase()),
      createdAt: tx.createdAt,
      updatedAt: tx.updatedAt,
      archivedAt: tx.archivedAt,
      categoryAllocations: categoryAllocations,
      transferAllocations: transferAllocations,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to assemble transaction ${tx.id}: ${failure.message}',
      ),
    );
  }

  @override
  Future<Result<Transaction, Failure>> getTransaction(
    String transactionId,
    String profileId,
  ) async {
    try {
      final query = _database.select(_database.transactions)
        ..where(
          (t) => t.id.equals(transactionId) & t.profileId.equals(profileId),
        );
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(
          DatabaseFailure(
            'Transaction not found with ID: $transactionId for profile: $profileId',
          ),
        );
      }

      final transaction = await _assembleTransaction(result);
      return Success(transaction);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch transaction', e));
    }
  }

  @override
  Future<Result<List<Transaction>, Failure>> getTransactions(
    String profileId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _database.select(_database.transactions)
        ..where((t) => t.profileId.equals(profileId));

      if (!includeArchived) {
        query.where(
          (t) => t.status.equals(TransactionStatus.active.name.toUpperCase()),
        );
      }

      // Sort by date descending
      query.orderBy([(t) => OrderingTerm.desc(t.date)]);

      final results = await query.get();
      final transactions = <Transaction>[];
      for (final tx in results) {
        transactions.add(await _assembleTransaction(tx));
      }
      return Success(transactions);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch transactions', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveTransaction(Transaction transaction) async {
    try {
      await _database.transaction(() async {
        // 0. Goal Balance Invariant Check
        if (transaction.status == TransactionStatus.active) {
          for (final ta in transaction.transferAllocations) {
            if (ta.endpointType == EndpointType.goal &&
                ta.role == AllocationRole.source) {
              final goalId = ta.goalId!;

              // Fetch target Goal's category link
              final goalData = await (_database.select(
                _database.goals,
              )..where((t) => t.id.equals(goalId))).getSingleOrNull();
              if (goalData == null) continue;

              final categoryId = goalData.categoryId;

              // 1. Sum up all category allocations to this category (contributions)
              final caQuery =
                  _database.select(_database.categoryAllocations).join([
                    innerJoin(
                      _database.transactions,
                      _database.transactions.id.equalsExp(
                        _database.categoryAllocations.transactionId,
                      ),
                    ),
                  ])..where(
                    _database.categoryAllocations.categoryId.equals(
                          categoryId,
                        ) &
                        _database.transactions.status.equals(
                          TransactionStatus.active.name.toUpperCase(),
                        ) &
                        _database.transactions.id.equals(transaction.id).not(),
                  );

              final caResults = await caQuery.get();
              int totalContributions = 0;
              for (final row in caResults) {
                final alloc = row.readTable(_database.categoryAllocations);
                totalContributions += alloc.amount;
              }

              // 2. Sum up all transfer allocations from/to this goal (withdrawals/internal transfers)
              final goalQuery =
                  _database.select(_database.transferAllocations).join([
                    innerJoin(
                      _database.transactions,
                      _database.transactions.id.equalsExp(
                        _database.transferAllocations.transactionId,
                      ),
                    ),
                  ])..where(
                    _database.transferAllocations.goalId.equals(goalId) &
                        _database.transactions.status.equals(
                          TransactionStatus.active.name.toUpperCase(),
                        ) &
                        _database.transactions.id.equals(transaction.id).not(),
                  );

              final results = await goalQuery.get();
              int totalWithdrawals = 0;
              for (final row in results) {
                final alloc = row.readTable(_database.transferAllocations);
                if (alloc.role == AllocationRole.source.name.toUpperCase()) {
                  totalWithdrawals += alloc.amount;
                } else if (alloc.role ==
                    AllocationRole.destination.name.toUpperCase()) {
                  totalWithdrawals -= alloc.amount;
                }
              }

              final currentBalance = totalContributions - totalWithdrawals;

              if (currentBalance - ta.amount < 0) {
                throw Exception(
                  'Goal withdrawal of ${ta.amount} exceeds available goal balance of $currentBalance.',
                );
              }
            }
          }
        }

        // 1. Insert/Update the root transaction record
        final companion = TransactionsCompanion(
          id: Value(transaction.id),
          profileId: Value(transaction.profileId),
          type: Value(transaction.type.name.toUpperCase()),
          subtype: Value(transaction.subtype),
          date: Value(transaction.date),
          currency: Value(transaction.currency),
          note: Value(transaction.note),
          tagId: Value(transaction.tagId),
          paymentModeId: Value(transaction.paymentModeId),
          recurringRuleId: Value(transaction.recurringRuleId),
          recurringOccurrenceId: Value(transaction.recurringOccurrenceId),
          status: Value(transaction.status.name.toUpperCase()),
          createdAt: Value(transaction.createdAt),
          updatedAt: Value(transaction.updatedAt),
          archivedAt: Value(transaction.archivedAt),
        );
        await _database
            .into(_database.transactions)
            .insertOnConflictUpdate(companion);

        // 2. Clear old category allocations
        final clearCa = _database.delete(_database.categoryAllocations)
          ..where((t) => t.transactionId.equals(transaction.id));
        await clearCa.go();

        // 3. Clear old transfer allocations
        final clearTa = _database.delete(_database.transferAllocations)
          ..where((t) => t.transactionId.equals(transaction.id));
        await clearTa.go();

        // 4. Insert new category allocations
        for (final ca in transaction.categoryAllocations) {
          final caCompanion = CategoryAllocationsCompanion(
            id: Value(ca.id),
            transactionId: Value(transaction.id),
            categoryId: Value(ca.categoryId),
            amount: Value(ca.amount),
            currency: Value(ca.currency),
          );
          await _database
              .into(_database.categoryAllocations)
              .insert(caCompanion);
        }

        // 5. Insert new transfer allocations
        for (final ta in transaction.transferAllocations) {
          final taCompanion = TransferAllocationsCompanion(
            id: Value(ta.id),
            transactionId: Value(transaction.id),
            role: Value(ta.role.name.toUpperCase()),
            endpointType: Value(ta.endpointType.name.toUpperCase()),
            accountId: Value(ta.accountId),
            goalId: Value(ta.goalId),
            amount: Value(ta.amount),
            currency: Value(ta.currency),
          );
          await _database
              .into(_database.transferAllocations)
              .insert(taCompanion);
        }
      });

      return const Success(null);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      return FailureResult(DatabaseFailure(msg, e));
    }
  }

  @override
  Future<Result<void, Failure>> deleteTransaction(
    String transactionId,
    String profileId,
  ) async {
    try {
      // Due to cascade deletes in the database tables schema, deleting the root transaction
      // automatically deletes category allocations and transfer allocations.
      final query = _database.delete(_database.transactions)
        ..where(
          (t) => t.id.equals(transactionId) & t.profileId.equals(profileId),
        );
      await query.go();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to delete transaction: $transactionId', e),
      );
    }
  }
}
