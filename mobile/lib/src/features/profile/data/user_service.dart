import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../profile/domain/user_profile.dart';

class UserService {
  UserService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<UserProfile> getMe({required UserProfile fallback}) async {
    try {
      final json = await _apiClient.getJson('/api/users/me');
      final rawUser = json['user'];
      if (rawUser is Map<String, dynamic>) return UserProfile.fromJson(rawUser);
      if (AppConfig.allowMockFallback) return fallback;
      throw const ApiException('Profil bilgilerine ulaşılamıyor');
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return fallback;
    }
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      final json = await _apiClient.patchJson('/api/users/me',
          body: profile.toPatchJson());
      final rawUser = json['user'];
      if (rawUser is Map<String, dynamic>) return UserProfile.fromJson(rawUser);
      if (AppConfig.allowMockFallback) return profile;
      throw const ApiException('Profil güncellenemedi');
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return profile;
    }
  }

  Future<Map<String, dynamic>> exportMyData() async {
    try {
      return _apiClient.getJson('/api/users/me/export');
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return {
        'exportedAt': DateTime.now().toIso8601String(),
        'data': {
          'source': 'mock',
          'message': 'API kullanılamıyor; yerel örnek veri gösterildi.'
        },
      };
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _apiClient.deleteJson('/api/users/me');
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
    }
  }
}
