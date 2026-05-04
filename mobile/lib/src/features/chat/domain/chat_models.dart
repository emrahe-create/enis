enum MessageAuthor { user, enis }

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.author,
    this.suggestion,
    this.premiumUpsell,
    this.tone,
    this.memoryUsed = false,
    this.avatarNameUsed = false,
    this.responseSource = 'openai',
  });

  final String text;
  final MessageAuthor author;
  final String? suggestion;
  final String? premiumUpsell;
  final String? tone;
  final bool memoryUsed;
  final bool avatarNameUsed;
  final String responseSource;

  bool get fromUser => author == MessageAuthor.user;
  bool get isFallback => responseSource == 'fallback';
}

class ChatResponse {
  const ChatResponse({
    required this.response,
    required this.tone,
    required this.suggestion,
    required this.memoryUsed,
    required this.avatarNameUsed,
    this.responseSource = 'openai',
    this.premiumUpsell,
    this.sessionId,
  });

  final String response;
  final String tone;
  final String suggestion;
  final bool memoryUsed;
  final bool avatarNameUsed;
  final String responseSource;
  final String? premiumUpsell;
  final String? sessionId;

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final response = json['response'];
    final chat = json['chat'];
    final data = response is Map<String, dynamic> ? response : json;

    return ChatResponse(
      response: data['response']?.toString() ??
          'Bunu duydum. Biraz daha anlatmak ister misin?',
      tone: data['tone']?.toString() ?? 'supportive',
      suggestion: data['suggestion']?.toString() ?? '',
      memoryUsed: data['memoryUsed'] == true,
      premiumUpsell: data['premiumUpsell']?.toString(),
      avatarNameUsed: data['avatarNameUsed'] == true,
      responseSource: data['responseSource']?.toString() ?? 'openai',
      sessionId: data['sessionId']?.toString() ??
          (chat is Map<String, dynamic> ? chat['sessionId']?.toString() : null),
    );
  }
}
