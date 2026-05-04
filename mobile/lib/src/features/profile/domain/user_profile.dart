class UserProfile {
  const UserProfile({
    required this.email,
    this.id,
    this.fullName,
    this.avatarName,
    this.preferredAvatar = 'structured',
    this.avatarCharacterId,
    this.avatarCharacterName,
    this.avatarVoiceStyle,
    this.avatarVisualStyle,
    this.avatarPersonalityStyle,
  });

  final String? id;
  final String email;
  final String? fullName;
  final String? avatarName;
  final String preferredAvatar;
  final String? avatarCharacterId;
  final String? avatarCharacterName;
  final String? avatarVoiceStyle;
  final String? avatarVisualStyle;
  final String? avatarPersonalityStyle;

  String get displayName =>
      fullName?.trim().isNotEmpty == true ? fullName!.trim() : email;

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarName,
    String? preferredAvatar,
    String? avatarCharacterId,
    String? avatarCharacterName,
    String? avatarVoiceStyle,
    String? avatarVisualStyle,
    String? avatarPersonalityStyle,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarName: avatarName ?? this.avatarName,
      preferredAvatar: preferredAvatar ?? this.preferredAvatar,
      avatarCharacterId: avatarCharacterId ?? this.avatarCharacterId,
      avatarCharacterName: avatarCharacterName ?? this.avatarCharacterName,
      avatarVoiceStyle: avatarVoiceStyle ?? this.avatarVoiceStyle,
      avatarVisualStyle: avatarVisualStyle ?? this.avatarVisualStyle,
      avatarPersonalityStyle:
          avatarPersonalityStyle ?? this.avatarPersonalityStyle,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString(),
      email: json['email']?.toString() ?? 'demo@enis.app',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString(),
      avatarName:
          json['avatarName']?.toString() ?? json['avatar_name']?.toString(),
      preferredAvatar: json['preferredAvatar']?.toString() ??
          json['preferred_avatar']?.toString() ??
          'structured',
      avatarCharacterId: json['avatarCharacterId']?.toString() ??
          json['avatar_character_id']?.toString(),
      avatarCharacterName: json['avatarCharacterName']?.toString() ??
          json['avatar_character_name']?.toString(),
      avatarVoiceStyle: json['avatarVoiceStyle']?.toString() ??
          json['avatar_voice_style']?.toString(),
      avatarVisualStyle: json['avatarVisualStyle']?.toString() ??
          json['avatar_visual_style']?.toString(),
      avatarPersonalityStyle: json['avatarPersonalityStyle']?.toString() ??
          json['avatar_personality_style']?.toString(),
    );
  }

  Map<String, dynamic> toPatchJson() {
    return {
      'fullName': fullName,
      'avatarName': avatarName,
      'preferredAvatar': preferredAvatar,
      'avatarCharacterId': avatarCharacterId,
      'avatarCharacterName': avatarCharacterName,
      'avatarVoiceStyle': avatarVoiceStyle,
      'avatarVisualStyle': avatarVisualStyle,
      'avatarPersonalityStyle': avatarPersonalityStyle,
    }..removeWhere((_, value) => value == null);
  }
}
