import 'package:drift/drift.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/database.dart';
import '../../domain/goal.dart';
import '../../domain/repositories/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final AppDatabase _database;

  GoalRepositoryImpl(this._database);

  Goal _toDomain(GoalData data) {
    return Goal.create(
      id: data.id,
      profileId: data.profileId,
      categoryId: data.categoryId,
      goalType: GoalType.values.byName(data.goalType),
      name: data.name,
      icon: data.icon,
      targetAmount: data.targetAmount,
      currency: data.currency,
      targetDate: data.targetDate,
      description: data.description,
      status: GoalStatus.values.byName(data.status),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      archivedAt: data.archivedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database Goal to Domain: ${failure.message}',
      ),
    );
  }

  @override
  Future<Result<Goal, Failure>> getGoal(String goalId, String profileId) async {
    try {
      final query = _database.select(_database.goals)
        ..where((t) => t.id.equals(goalId) & t.profileId.equals(profileId));
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(
          DatabaseFailure(
            'Goal not found with ID: $goalId for profile: $profileId',
          ),
        );
      }
      return Success(_toDomain(result));
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch goal', e));
    }
  }

  @override
  Future<Result<List<Goal>, Failure>> getGoals(
    String profileId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _database.select(_database.goals)
        ..where((t) => t.profileId.equals(profileId));

      if (!includeArchived) {
        query.where((t) => t.status.equals(GoalStatus.active.name));
      }

      final results = await query.get();
      final goals = results.map(_toDomain).toList();
      return Success(goals);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch goals', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveGoal(Goal goal) async {
    try {
      final companion = GoalsCompanion(
        id: Value(goal.id),
        profileId: Value(goal.profileId),
        categoryId: Value(goal.categoryId),
        goalType: Value(goal.goalType.name),
        name: Value(goal.name),
        icon: Value(goal.icon),
        targetAmount: Value(goal.targetAmount),
        currency: Value(goal.currency),
        targetDate: Value(goal.targetDate),
        description: Value(goal.description),
        status: Value(goal.status.name),
        createdAt: Value(goal.createdAt),
        updatedAt: Value(goal.updatedAt),
        archivedAt: Value(goal.archivedAt),
      );
      await _database.into(_database.goals).insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save goal', e));
    }
  }

  @override
  Future<Result<void, Failure>> archiveGoal(
    String goalId,
    String profileId,
  ) async {
    try {
      final now = DateTime.now();
      final query = _database.update(_database.goals)
        ..where((t) => t.id.equals(goalId) & t.profileId.equals(profileId));

      await query.write(
        GoalsCompanion(
          status: Value(GoalStatus.archived.name),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to archive goal', e));
    }
  }
}
