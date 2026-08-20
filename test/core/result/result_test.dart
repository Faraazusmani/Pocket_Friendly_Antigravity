import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/errors/failures.dart';
import 'package:pocket_friendly/core/result/result.dart';

void main() {
  group('Result / Failure Utility Tests', () {
    test('Success returns correct value on fold', () {
      const result = Success<int, Failure>(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.successOrNull, 42);
      expect(result.failureOrNull, isNull);

      final foldedValue = result.fold((success) => success * 2, (failure) => 0);
      expect(foldedValue, 84);
    });

    test('FailureResult returns correct failure on fold', () {
      const failure = ValidationFailure('Invalid input');
      const result = FailureResult<int, Failure>(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.successOrNull, isNull);
      expect(result.failureOrNull, failure);

      final foldedValue = result.fold((success) => 1, (failure) => 0);
      expect(foldedValue, 0);
    });
  });
}
