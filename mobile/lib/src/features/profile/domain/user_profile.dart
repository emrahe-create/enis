class UserProfile {
  const UserProfile({
    required this.email,
    this.id,
    this.fullName,
    this.avatarName,
    this.preferredAvatar = 'structured',
  });

  final String? id;
  final String email;
  final String? fullName;
  final String? avatarName;
  final String preferredAvatar;

  String get displayName => fullName?.trim().isNotEmpty == true ? fullName!.trim() : email;

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarName,
    String? preferredAvatar,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarName: avatarName ?? this.avatarName,
      preferredAvatar: preferredAvatar ?? this.preferredAvatar,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString(),
      email: json['email']?.toString() ?? 'demo@enis.app',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString(),
      avatarName: json['avatarName']?.toString() ?? json['avatar_name']?.toString(),
      preferredAvatar: json['preferredAvatar']?.toString() ??
          json['preferred_avatar']?.toString() ??
          'structured',
    );
  }

  Map<String, dynamic> toPatchJson() {
    return {
      'fullName': fullName,
      'avatarName': avatarName,
      'preferredAvatar': preferredAvatar,
    }..removeWhere((_, value) => value == null);
  }
}
