import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _tokenKey = 'enis.jwt';

  final FlutterSecureStorage _secureStorage;

  Future<String?> readToken() {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> saveToken(String token) {
    return _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() {
    return _secureStorage.delete(key: _tokenKey);
  }
}
