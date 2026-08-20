import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_friendly/core/security/security_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('SecurityService Tests', () {
    late MockFlutterSecureStorage mockSecureStorage;
    late SecurityServiceImpl securityService;

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
      securityService = SecurityServiceImpl(secureStorage: mockSecureStorage);
    });

    test('getDatabaseKey returns existing key if stored', () async {
      // Arrange
      const storedKeyBase64 =
          'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8='; // 32-byte key base64
      when(
        () => mockSecureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => storedKeyBase64);

      // Act
      final result = await securityService.getDatabaseKey();

      // Assert
      expect(result.isSuccess, isTrue);
      final keyBytes = result.successOrNull!;
      expect(keyBytes.length, 32);
      expect(keyBytes[0], 0);
      expect(keyBytes[31], 31);
      verify(
        () => mockSecureStorage.read(key: 'pocket_friendly_db_key_v1'),
      ).called(1);
    });

    test(
      'getDatabaseKey generates and writes new key if none exists',
      () async {
        // Arrange
        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);
        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async => {});

        // Act
        final result = await securityService.getDatabaseKey();

        // Assert
        expect(result.isSuccess, isTrue);
        final keyBytes = result.successOrNull!;
        expect(keyBytes.length, 32);

        verify(
          () => mockSecureStorage.read(key: 'pocket_friendly_db_key_v1'),
        ).called(1);
        verify(
          () => mockSecureStorage.write(
            key: 'pocket_friendly_db_key_v1',
            value: any(named: 'value'),
          ),
        ).called(1);
      },
    );

    test('clearDatabaseKey deletes key from secure storage', () async {
      // Arrange
      when(
        () => mockSecureStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async => {});

      // Act
      final result = await securityService.clearDatabaseKey();

      // Assert
      expect(result.isSuccess, isTrue);
      verify(
        () => mockSecureStorage.delete(key: 'pocket_friendly_db_key_v1'),
      ).called(1);
    });
  });
}
