import 'package:drift/drift.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/database.dart';
import '../../domain/budget.dart';
import '../../domain/unallocated_budget_pool.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/services/budget_calculations.dart';
import '../../../transactions/domain/transaction.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final AppDatabase _database;

  BudgetRepositoryImpl(this._database);

  Budget _toDomain(BudgetData data) {
    return Budget.create(
      id: data.id,
      profileId: data.profileId,
      categoryId: data.categoryId,
      month: data.month,
      year: data.year,
      baseAmount: data.baseAmount,
      carryForwardAmount: data.carryForwardAmount,
      currency: data.currency,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    ).fold(
      (success) => success,
      (failure) =>
          throw Exception('Failed to map database Budget: ${failure.message}'),
    );
  }

  UnallocatedBudgetPool _poolToDomain(UnallocatedBudgetPoolData data) {
    return UnallocatedBudgetPool.create(
      id: data.id,
      profileId: data.profileId,
      month: data.month,
      year: data.year,
      amount: data.amount,
      currency: data.currency,
      carriedForwardAmount: data.carriedForwardAmount,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database UnallocatedBudgetPool: ${failure.message}',
      ),
    );
  }

  @override
  Future<Result<List<Budget>, Failure>> getCategoryBudgets(
    String profileId,
    int month,
    int year,
  ) async {
    try {
      final query = _database.select(_database.budgets)
        ..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.month.equals(month) &
              t.year.equals(year),
        );
      final results = await query.get();
      return Success(results.map(_toDomain).toList());
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to fetch category budgets', e),
      );
    }
  }

  @override
  Future<Result<void, Failure>> saveCategoryBudget(Budget budget) async {
    try {
      final companion = BudgetsCompanion(
        id: Value(budget.id),
        profileId: Value(budget.profileId),
        categoryId: Value(budget.categoryId),
        month: Value(budget.month),
        year: Value(budget.year),
        baseAmount: Value(budget.baseAmount),
        carryForwardAmount: Value(budget.carryForwardAmount),
        currency: Value(budget.currency),
        createdAt: Value(budget.createdAt),
        updatedAt: Value(budget.updatedAt),
      );
      await _database.into(_database.budgets).insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to save category budget', e),
      );
    }
  }

  @override
  Future<Result<UnallocatedBudgetPool, Failure>> getUnallocatedBudgetPool({
    required String profileId,
    required int month,
    required int year,
    required String currency,
  }) async {
    try {
      final uppercaseCurrency = currency.toUpperCase();
      final query = _database.select(_database.unallocatedBudgetPools)
        ..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.month.equals(month) &
              t.year.equals(year) &
              t.currency.equals(uppercaseCurrency),
        );
      final result = await query.getSingleOrNull();

      if (result == null) {
        // Return an empty pool representation (does not auto-persist until edited)
        final tempPool = UnallocatedBudgetPool.create(
          id: '${profileId}_pool_${year}_${month}_$uppercaseCurrency',
          profileId: profileId,
          month: month,
          year: year,
          amount: 0,
          currency: uppercaseCurrency,
        ).successOrNull!;
        return Success(tempPool);
      }

      return Success(_poolToDomain(result));
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to fetch unallocated budget pool', e),
      );
    }
  }

  @override
  Future<Result<void, Failure>> saveUnallocatedBudgetPool(
    UnallocatedBudgetPool pool,
  ) async {
    try {
      final companion = UnallocatedBudgetPoolsCompanion(
        id: Value(pool.id),
        profileId: Value(pool.profileId),
        month: Value(pool.month),
        year: Value(pool.year),
        amount: Value(pool.amount),
        currency: Value(pool.currency),
        carriedForwardAmount: Value(pool.carriedForwardAmount),
      );
      await _database
          .into(_database.unallocatedBudgetPools)
          .insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to save unallocated budget pool', e),
      );
    }
  }

  @override
  Future<Result<void, Failure>> carryForward({
    required String profileId,
    required int sourceMonth,
    required int sourceYear,
    required int targetMonth,
    required int targetYear,
    required String currency,
  }) async {
    try {
      final uppercaseCurrency = currency.toUpperCase();
      final sourceStart = DateTime(sourceYear, sourceMonth, 1);
      final sourceEnd = DateTime(
        sourceYear,
        sourceMonth + 1,
        1,
      ).subtract(const Duration(milliseconds: 1));

      await _database.transaction(() async {
        // 1. Fetch source month category budgets
        final budgetQuery = _database.select(_database.budgets)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.month.equals(sourceMonth) &
                t.year.equals(sourceYear) &
                t.currency.equals(uppercaseCurrency),
          );
        final budgetResults = await budgetQuery.get();
        final budgets = budgetResults.map(_toDomain).toList();

        if (budgets.isEmpty) return; // Nothing to carry forward

        // 2. Fetch source month transactions and allocations
        final txQuery = _database.select(_database.transactions)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.currency.equals(uppercaseCurrency) &
                t.date.isBetweenValues(sourceStart, sourceEnd) &
                t.status.equals(TransactionStatus.active.name.toUpperCase()),
          );
        final txResults = await txQuery.get();

        final transactionsList = <Transaction>[];
        for (final tx in txResults) {
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

          final taQuery = _database.select(_database.transferAllocations)
            ..where((t) => t.transactionId.equals(tx.id));
          final taResults = await taQuery.get();
          final transferAllocations = taResults
              .map(
                (ta) => TransferAllocation.create(
                  id: ta.id,
                  transactionId: ta.transactionId,
                  role: AllocationRole.values.byName(ta.role.toLowerCase()),
                  endpointType: EndpointType.values.byName(
                    ta.endpointType.toLowerCase(),
                  ),
                  accountId: ta.accountId,
                  goalId: ta.goalId,
                  amount: ta.amount,
                  currency: ta.currency,
                ).successOrNull!,
              )
              .toList();

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
          transactionsList.add(txn);
        }

        // 3. Compute unused budget total
        final totalUnused = BudgetCalculations.calculateTotalUnusedBudget(
          categoryBudgets: budgets,
          transactions: transactionsList,
        );

        if (totalUnused <= 0) return; // No surplus to carry forward

        // 4. Fetch or create target month's unallocated pool
        final poolQuery = _database.select(_database.unallocatedBudgetPools)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.month.equals(targetMonth) &
                t.year.equals(targetYear) &
                t.currency.equals(uppercaseCurrency),
          );
        final poolResult = await poolQuery.getSingleOrNull();

        int targetAmount = totalUnused;
        String poolId =
            '${profileId}_pool_${targetYear}_${targetMonth}_$uppercaseCurrency';

        if (poolResult != null) {
          targetAmount =
              poolResult.amount - poolResult.carriedForwardAmount + totalUnused;
          poolId = poolResult.id;
        }

        // 5. Update/Save target pool
        final companion = UnallocatedBudgetPoolsCompanion(
          id: Value(poolId),
          profileId: Value(profileId),
          month: Value(targetMonth),
          year: Value(targetYear),
          amount: Value(targetAmount),
          currency: Value(uppercaseCurrency),
          carriedForwardAmount: Value(totalUnused),
        );
        await _database
            .into(_database.unallocatedBudgetPools)
            .insertOnConflictUpdate(companion);
      });

      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Carry-forward failed', e));
    }
  }
}
