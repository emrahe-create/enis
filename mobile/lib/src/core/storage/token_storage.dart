import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage({
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences>? preferences,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _preferences = preferences ?? SharedPreferences.getInstance();

  static const _tokenKey = 'enis.jwt';

  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> _preferences;

  Future<String?> readToken() async {
    try {
      final secureToken = await _secureStorage.read(key: _tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) return secureToken;
    } catch (error) {
      _log('TOKEN_STORAGE_SECURE_READ_FAILED $error');
    }

    try {
      return (await _preferences).getString(_tokenKey);
    } catch (error) {
      _log('TOKEN_STORAGE_FALLBACK_READ_FAILED $error');
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    var saved = false;
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      saved = true;
    } catch (error) {
      _log('TOKEN_STORAGE_SECURE_WRITE_FAILED $error');
    }

    try {
      await (await _preferences).setString(_tokenKey, token);
      saved = true;
    } catch (error) {
      _log('TOKEN_STORAGE_FALLBACK_WRITE_FAILED $error');
    }

    if (!saved) {
      throw Exception('JWT token kaydedilemedi');
    }
    _log('TOKEN_STORAGE_SAVE tokenExists=true');
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (error) {
      _log('TOKEN_STORAGE_SECURE_CLEAR_FAILED $error');
    }

    try {
      await (await _preferences).remove(_tokenKey);
    } catch (error) {
      _log('TOKEN_STORAGE_FALLBACK_CLEAR_FAILED $error');
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }
}
