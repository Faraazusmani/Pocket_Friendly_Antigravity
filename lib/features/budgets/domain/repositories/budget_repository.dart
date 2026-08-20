import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../budget.dart';
import '../unallocated_budget_pool.dart';

abstract class BudgetRepository {
  Future<Result<List<Budget>, Failure>> getCategoryBudgets(
    String profileId,
    int month,
    int year,
  );

  Future<Result<void, Failure>> saveCategoryBudget(Budget budget);

  Future<Result<UnallocatedBudgetPool, Failure>> getUnallocatedBudgetPool({
    required String profileId,
    required int month,
    required int year,
    required String currency,
  });

  Future<Result<void, Failure>> saveUnallocatedBudgetPool(
    UnallocatedBudgetPool pool,
  );

  Future<Result<void, Failure>> carryForward({
    required String profileId,
    required int sourceMonth,
    required int sourceYear,
    required int targetMonth,
    required int targetYear,
    required String currency,
  });
}
