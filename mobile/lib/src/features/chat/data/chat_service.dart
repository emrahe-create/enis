import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat_models.dart';

const chatFallbackUnavailableMessage =
    'Şu anda bağlantıda zorlandım. Birazdan tekrar deneyelim mi?';
const chatConnectionUnavailableMessage = chatFallbackUnavailableMessage;

class ChatService {
  ChatService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<String> startSession() async {
    try {
      final json = await _apiClient
          .postJson('/api/chat/sessions', body: {'title': 'Enis sohbet'});
      final session = json['session'];
      if (session is Map<String, dynamic>) {
        final id = session['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
      if (AppConfig.allowMockFallback) return 'mock-session';
      throw const ApiException('Sohbet oturumu başlatılamadı');
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return 'mock-session';
    }
  }

  Future<ChatResponse> sendMessage({
    required String text,
    required String avatar,
    required bool premium,
    String? sessionId,
    String? avatarCharacterId,
  }) async {
    try {
      _apiClient.logDebug(
        'CHAT_REQUEST_URL ${_apiClient.baseUrl}/api/chat/message',
      );
      final json = await _apiClient.postJson(
        '/api/chat/message',
        body: {
          'text': text,
          'avatar': avatar,
          if (avatarCharacterId?.isNotEmpty == true)
            'avatarCharacterId': avatarCharacterId,
          if (sessionId != null) 'sessionId': sessionId,
        },
      );
      return ChatResponse.fromJson(json);
    } on ApiException catch (error) {
      if (!AppConfig.allowMockFallback) rethrow;
      if (!error.isNetworkFailure) rethrow;
      return _fallbackResponse(text: text, avatar: avatar, premium: premium);
    }
  }

  ChatResponse _fallbackResponse({
    required String text,
    required String avatar,
    required bool premium,
  }) {
    final lower = text.toLowerCase();
    final crisis = RegExp(
            r'\b(kendime zarar|intihar|ölmek istiyorum|suicide|self-harm|hurt myself)\b')
        .hasMatch(lower);

    if (crisis) {
      return const ChatResponse(
        response:
            'Bu çok ciddi gelebilir. Şu anda yalnız kalmamaya çalışıp 112’ye, yakınındaki acil destek kaynaklarına veya güvendiğin bir kişiye ulaşman önemli.',
        tone: 'safety',
        suggestion: 'Yakınındaki birinden destek istemeyi düşünebilirsin.',
        memoryUsed: false,
        avatarNameUsed: false,
        premiumUpsell: null,
        responseSource: 'safety',
      );
    }

    final guide = avatar == 'guide';

    return ChatResponse(
      response: chatConnectionUnavailableMessage,
      tone: guide
          ? 'sakin'
          : avatar == 'structured'
              ? 'düzenli'
              : 'samimi',
      suggestion: 'Bağlantı düzelince aynı mesajı tekrar deneyebilirsin.',
      memoryUsed: false,
      avatarNameUsed: false,
      premiumUpsell: null,
      responseSource: 'fallback',
    );
  }
}
