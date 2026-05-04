import 'package:flutter/foundation.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../profile/domain/user_profile.dart';

class AuthResult {
  const AuthResult(
      {required this.user, required this.token, this.usedMock = false});

  final UserProfile user;
  final String token;
  final bool usedMock;
}

class AuthService {
  AuthService(
      {required ApiClient apiClient, required TokenStorage tokenStorage})
      : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthResult> register({
    required String email,
    required String password,
    String? fullName,
    String? avatarName,
    required Map<String, bool> consents,
  }) async {
    try {
      final json = await _apiClient.postJson(
        '/api/auth/register',
        body: {
          'email': email,
          'password': password,
          if (fullName?.trim().isNotEmpty == true) 'fullName': fullName!.trim(),
          if (avatarName?.trim().isNotEmpty == true)
            'avatarName': avatarName!.trim(),
          'consents': consents,
          'marketingConsent': consents['marketing_permission'] == true,
        },
      );
      return _storeAuth(json);
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return _mockAuth(
        email: email,
        fullName: fullName,
        avatarName: avatarName,
      );
    }
  }

  Future<void> resendVerificationEmail({required String email}) async {
    try {
      await _apiClient.postJson(
        '/api/auth/resend-verification',
        body: {'email': email},
      );
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
    }
  }

  Future<AuthResult> login(
      {required String email, required String password}) async {
    try {
      final json = await _apiClient.postJson(
        '/api/auth/login',
        body: {'email': email, 'password': password},
      );
      return _storeAuth(json);
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return _mockAuth(email: email);
    }
  }

  Future<void> logout() {
    return _tokenStorage.clear();
  }

  Future<AuthResult> _storeAuth(
    Map<String, dynamic> json, {
    bool persistToken = true,
  }) async {
    final token = json['token']?.toString() ?? '';
    final rawUser = json['user'];
    final user = rawUser is Map<String, dynamic>
        ? UserProfile.fromJson(rawUser)
        : const UserProfile(email: 'demo@enis.app');
    if (persistToken && token.isNotEmpty) {
      await _tokenStorage.saveToken(token);
    }
    if (kDebugMode) {
      final savedToken = token.isEmpty ? null : await _tokenStorage.readToken();
      debugPrint(
        'AUTH_TOKEN_SAVED tokenExists=${savedToken?.isNotEmpty == true}',
      );
    }
    return AuthResult(user: user, token: token);
  }

  Future<AuthResult> _mockAuth({
    required String email,
    String? fullName,
    String? avatarName,
    bool persistToken = true,
  }) async {
    const token = 'mock-jwt-token';
    if (persistToken) await _tokenStorage.saveToken(token);
    return AuthResult(
      usedMock: true,
      token: token,
      user: UserProfile(
        id: 'mock-user',
        email: email,
        fullName: fullName?.trim().isEmpty == true ? null : fullName,
        avatarName: avatarName?.trim().isEmpty == true ? null : avatarName,
      ),
    );
  }
}
