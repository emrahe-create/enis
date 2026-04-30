import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat_models.dart';

class ChatService {
  ChatService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<String> startSession() async {
    try {
      final json = await _apiClient.postJson('/api/chat/sessions', body: {'title': 'Enis chat'});
      final session = json['session'];
      if (session is Map<String, dynamic>) {
        final id = session['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
      if (AppConfig.allowMockFallback) return 'mock-session';
      throw const ApiException('Chat session unavailable');
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
  }) async {
    try {
      final json = await _apiClient.postJson(
        '/api/chat/message',
        body: {
          'text': text,
          'avatar': avatar,
          if (sessionId != null) 'sessionId': sessionId,
        },
      );
      return ChatResponse.fromJson(json);
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return _fallbackResponse(text: text, avatar: avatar, premium: premium);
    }
  }

  ChatResponse _fallbackResponse({
    required String text,
    required String avatar,
    required bool premium,
  }) {
    final lower = text.toLowerCase();
    final turkish = RegExp(r'[çğıöşüİı]').hasMatch(text) ||
        RegExp(r'\b(ben|bir|çok|bugün|içimde|hissediyorum|zor|kaygı|uyku)\b').hasMatch(lower);
    final crisis = RegExp(r'\b(kendime zarar|intihar|ölmek istiyorum|suicide|self-harm|hurt myself)\b').hasMatch(lower);

    if (crisis) {
      return ChatResponse(
        response: turkish
            ? 'Bu çok ciddi gelebilir. Şu anda yalnız kalmamaya çalışıp acil destek hattına, 112’ye veya güvendiğin bir kişiye ulaşman önemli.'
            : 'This sounds urgent. It may help to contact emergency services, a local crisis line, or someone you trust right now.',
        tone: 'safety',
        suggestion: turkish ? 'Yakınındaki birinden destek istemeyi düşünebilirsin.' : 'Consider reaching out to immediate outside support.',
        memoryUsed: false,
        avatarNameUsed: false,
        premiumUpsell: null,
      );
    }

    final structured = avatar == 'structured';
    final guide = avatar == 'guide';
    final response = turkish
        ? guide
            ? 'Bu biraz yavaşlamaya ihtiyaç duyuyor gibi. Şu an bedeninde en çok nerede hissediyorsun?'
            : structured
                ? 'Bu yoğun görünüyor. İstersen önce en ağır gelen parçayı ayıralım: ne daha çok öne çıkıyor?'
                : 'Bunu söylemen iyi oldu. Bu anın en zor tarafı ne gibi geliyor?'
        : guide
            ? 'It seems like this wants a slower pace. Where do you feel it most in your body right now?'
            : structured
                ? 'That sounds like a lot to hold. What part feels most important to name first?'
                : 'I’m glad you said it. What feels like the hardest part of this moment?';

    return ChatResponse(
      response: response,
      tone: guide ? 'peaceful' : structured ? 'calm' : 'warm',
      suggestion: turkish ? 'İstersen bir nefeslik ara verip tek bir duyguyu adlandır.' : 'You might pause for one breath and name one feeling.',
      memoryUsed: premium,
      avatarNameUsed: false,
      premiumUpsell: premium
          ? null
          : 'Sohbetini daha derin hale getirmek ister misin?\nPremium ile devam edebilirsin.',
    );
  }
}
