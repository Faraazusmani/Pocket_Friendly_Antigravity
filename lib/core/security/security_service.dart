import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../errors/failures.dart';
import '../result/result.dart';

abstract class SecurityService {
  /// Retrieves the existing database encryption key, or generates and stores a new one.
  Future<Result<List<int>, SecurityFailure>> getDatabaseKey();

  /// Clears the secure key (used for complete system resets/wipes).
  Future<Result<void, SecurityFailure>> clearDatabaseKey();
}

class SecurityServiceImpl implements SecurityService {
  final FlutterSecureStorage _secureStorage;
  static const String _dbKeyName = 'pocket_friendly_db_key_v1';

  SecurityServiceImpl({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<Result<List<int>, SecurityFailure>> getDatabaseKey() async {
    try {
      final existingKeyBase64 = await _secureStorage.read(key: _dbKeyName);
      if (existingKeyBase64 != null) {
        final keyBytes = base64.decode(existingKeyBase64);
        return Success(keyBytes);
      }

      // Generate a new 256-bit cryptographically secure random key
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      final newKeyBase64 = base64.encode(keyBytes);

      await _secureStorage.write(key: _dbKeyName, value: newKeyBase64);
      return Success(keyBytes);
    } catch (e) {
      return FailureResult(
        SecurityFailure('Failed to manage secure database key', e),
      );
    }
  }

  @override
  Future<Result<void, SecurityFailure>> clearDatabaseKey() async {
    try {
      await _secureStorage.delete(key: _dbKeyName);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        SecurityFailure('Failed to clear secure database key', e),
      );
    }
  }
}
