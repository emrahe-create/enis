import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../profile/domain/subscription_snapshot.dart';

class PremiumService {
  PremiumService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<SubscriptionSnapshot> getSubscription() async {
    try {
      final json = await _apiClient.getJson('/api/subscriptions/me');
      return SubscriptionSnapshot.fromJson(json);
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return SubscriptionSnapshot.free();
    }
  }

  Future<SubscriptionSnapshot> startTrial() async {
    try {
      final json = await _apiClient.postJson('/api/subscriptions/trial');
      return SubscriptionSnapshot.fromJson(json);
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return SubscriptionSnapshot.trial();
    }
  }
}
