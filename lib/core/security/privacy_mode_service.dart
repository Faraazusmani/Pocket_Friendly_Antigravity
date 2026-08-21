import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class PrivacyModeService {
  bool get isEnabled;
  Future<void> setEnabled(bool enabled);
  Future<void> init();
}

class PrivacyModeServiceImpl implements PrivacyModeService {
  final FlutterSecureStorage _secureStorage;
  static const String _key = 'pocket_friendly_privacy_mode_v1';
  bool _inMemoryValue = false;

  PrivacyModeServiceImpl({required FlutterSecureStorage secureStorage})
      : _secureStorage = secureStorage;

  @override
  Future<void> init() async {
    try {
      final stored = await _secureStorage.read(key: _key);
      _inMemoryValue = stored == 'true';
    } catch (_) {
      _inMemoryValue = false;
    }
  }

  @override
  bool get isEnabled => _inMemoryValue;

  @override
  Future<void> setEnabled(bool enabled) async {
    _inMemoryValue = enabled;
    try {
      await _secureStorage.write(key: _key, value: enabled.toString());
    } catch (_) {
      // Fail-soft: keep in memory
    }
  }
}
