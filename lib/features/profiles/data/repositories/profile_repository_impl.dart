import 'package:drift/drift.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/database.dart';
import '../../domain/profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final AppDatabase _database;

  ProfileRepositoryImpl(this._database);

  Profile _toDomain(ProfileData data) {
    return Profile.create(
      id: data.id,
      name: data.name,
      defaultCurrency: data.defaultCurrency,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database Profile to Domain: ${failure.message}',
      ),
    );
  }

  @override
  Future<Result<Profile, Failure>> getProfile(String id) async {
    try {
      final query = _database.select(_database.profiles)
        ..where((t) => t.id.equals(id));
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(DatabaseFailure('Profile not found with ID: $id'));
      }
      return Success(_toDomain(result));
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch profile', e));
    }
  }

  @override
  Future<Result<List<Profile>, Failure>> getProfiles() async {
    try {
      final results = await _database.select(_database.profiles).get();
      final profiles = results.map(_toDomain).toList();
      return Success(profiles);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch profiles', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveProfile(Profile profile) async {
    try {
      final companion = ProfilesCompanion(
        id: Value(profile.id),
        name: Value(profile.name),
        defaultCurrency: Value(profile.defaultCurrency),
        createdAt: Value(profile.createdAt),
        updatedAt: Value(profile.updatedAt),
      );
      await _database
          .into(_database.profiles)
          .insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save profile', e));
    }
  }

  @override
  Future<Result<void, Failure>> deleteProfile(String id) async {
    try {
      final query = _database.delete(_database.profiles)
        ..where((t) => t.id.equals(id));
      await query.go();
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to delete profile', e));
    }
  }
}
