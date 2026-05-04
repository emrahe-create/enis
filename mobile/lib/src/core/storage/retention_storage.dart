import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RetentionStorage {
  RetentionStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _lastOpenedAtKey = 'enis.last_opened_at';
  static const _lastInteractionAtKey = 'enis.last_interaction_at';

  final FlutterSecureStorage _secureStorage;

  Future<DateTime?> readLastOpenedAt() async {
    final raw = await _secureStorage.read(key: _lastOpenedAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveLastOpenedAt(DateTime value) {
    return _secureStorage.write(
      key: _lastOpenedAtKey,
      value: value.toIso8601String(),
    );
  }

  Future<DateTime?> readLastInteractionAt() async {
    final raw = await _secureStorage.read(key: _lastInteractionAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveLastInteractionAt(DateTime value) {
    return _secureStorage.write(
      key: _lastInteractionAtKey,
      value: value.toIso8601String(),
    );
  }

  Future<void> clear() {
    return Future.wait([
      _secureStorage.delete(key: _lastOpenedAtKey),
      _secureStorage.delete(key: _lastInteractionAtKey),
    ]).then((_) {});
  }
}
