import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/retention_copy.dart';

class MemoryService {
  MemoryService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<CompanionMemory>> getMemories() async {
    try {
      final json = await _apiClient.getJson('/api/memory');
      final rawMemories = json['memories'];
      if (rawMemories is List) {
        return rawMemories
            .whereType<Map<String, dynamic>>()
            .map(CompanionMemory.fromJson)
            .toList();
      }
      return const [];
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return const [];
    }
  }
}
