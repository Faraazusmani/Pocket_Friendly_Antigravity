import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../goal.dart';

abstract class GoalRepository {
  Future<Result<Goal, Failure>> getGoal(String goalId, String profileId);

  Future<Result<List<Goal>, Failure>> getGoals(
    String profileId, {
    bool includeArchived = false,
  });

  Future<Result<void, Failure>> saveGoal(Goal goal);

  Future<Result<void, Failure>> archiveGoal(String goalId, String profileId);
}
