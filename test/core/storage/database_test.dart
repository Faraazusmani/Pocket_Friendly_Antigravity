import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';


void main() {
  group('Database Drift & SQLite In-Memory Tests', () {
    late List<int> testKey;
    late AppDatabase database;

    setUp(() {
      testKey = List<int>.generate(32, (i) => i);
      final dbConnection = openEncryptedConnection(testKey, inMemory: true);
      database = AppDatabase(dbConnection);
    });

    tearDown(() async {
      await database.close();
    });

    test('Can insert and retrieve profile successfully', () async {
      final now = DateTime.now();

      // Insert a profile using companion class
      final profile = ProfilesCompanion.insert(
        id: 'test-profile-id',
        name: 'Lead Architect',
        defaultCurrency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      final insertId = await database.into(database.profiles).insert(profile);
      expect(insertId, 1); // Row ID of first insert is usually 1 in SQLite

      // Query profiles
      final profiles = await database.select(database.profiles).get();
      expect(profiles.length, 1);

      final savedProfile = profiles.first;
      expect(savedProfile.id, 'test-profile-id');
      expect(savedProfile.name, 'Lead Architect');
      expect(savedProfile.defaultCurrency, 'USD');
    });

    test('Database transaction ensures atomicity', () async {
      final now = DateTime.now();

      try {
        await database.transaction(() async {
          // Insert a profile
          await database
              .into(database.profiles)
              .insert(
                ProfilesCompanion.insert(
                  id: 'txn-profile-1',
                  name: 'Txn Name',
                  defaultCurrency: 'EUR',
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          // Force an error to trigger rollback by inserting a profile with the same ID
          await database
              .into(database.profiles)
              .insert(
                ProfilesCompanion.insert(
                  id: 'txn-profile-1', // Duplicate ID triggers UNIQUE constraint failure
                  name: 'Duplicate Txn Name',
                  defaultCurrency: 'EUR',
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        });
      } catch (e) {
        // Expected constraint violation error
      }

      // Verify that NO profiles were saved, confirming rollback
      final profiles = await database.select(database.profiles).get();
      expect(profiles, isEmpty);
    });
  });
}
