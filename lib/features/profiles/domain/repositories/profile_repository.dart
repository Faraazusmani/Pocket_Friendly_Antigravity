import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../profile.dart';

abstract class ProfileRepository {
  Future<Result<Profile, Failure>> getProfile(String id);

  Future<Result<List<Profile>, Failure>> getProfiles();

  Future<Result<void, Failure>> saveProfile(Profile profile);

  Future<Result<void, Failure>> deleteProfile(String id);
}
