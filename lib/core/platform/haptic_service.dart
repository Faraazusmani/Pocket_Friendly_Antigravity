import 'package:flutter/services.dart';
import '../errors/failures.dart';
import '../result/result.dart';

abstract class HapticService {
  /// Triggers a light physical tap.
  Future<Result<void, PlatformFailure>> lightImpact();

  /// Triggers a medium physical tap.
  Future<Result<void, PlatformFailure>> mediumImpact();

  /// Triggers a heavy physical tap.
  Future<Result<void, PlatformFailure>> heavyImpact();

  /// Triggers a subtle click feedback.
  Future<Result<void, PlatformFailure>> selectionClick();

  /// Triggers a general device vibration.
  Future<Result<void, PlatformFailure>> vibrate();
}

class HapticServiceImpl implements HapticService {
  const HapticServiceImpl();

  @override
  Future<Result<void, PlatformFailure>> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to trigger light haptic impact', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to trigger medium haptic impact', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to trigger heavy haptic impact', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to trigger haptic selection click', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> vibrate() async {
    try {
      await HapticFeedback.vibrate();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to trigger general vibration', e),
      );
    }
  }
}
