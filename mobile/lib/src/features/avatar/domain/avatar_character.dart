import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';

class PremiumAvatarCharacter {
  const PremiumAvatarCharacter({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.visualDescription,
    required this.personalityStyle,
    required this.voiceStyle,
    required this.premiumOnly,
    required this.assetIdle,
    required this.assetListening,
    required this.assetThinking,
    required this.assetSpeaking,
    required this.assetComforting,
    required this.icon,
    required this.color,
    required this.toneAvatarId,
  });

  final String id;
  final String name;
  final String shortDescription;
  final String visualDescription;
  final String personalityStyle;
  final String voiceStyle;
  final bool premiumOnly;
  final String assetIdle;
  final String assetListening;
  final String assetThinking;
  final String assetSpeaking;
  final String assetComforting;
  final IconData icon;
  final Color color;
  final String toneAvatarId;

  String get description => shortDescription;
  String get visualStyle => visualDescription;

  String get voiceLabel {
    if (voiceStyle.isEmpty) return '';
    return '${voiceStyle[0].toUpperCase()}${voiceStyle.substring(1)}';
  }

  String get companionLabel {
    return switch (id) {
      'lina' => 'Enerjik eşlikçi',
      'deniz' => 'Sakin eşlikçi',
      'ada' => 'Düzenli eşlikçi',
      'eren' => 'Samimi eşlikçi',
      'arda' => 'Güven veren eşlikçi',
      'kerem' => 'Canlı eşlikçi',
      _ => 'Samimi eşlikçi',
    };
  }
}

const premiumAvatarCharacters = [
  PremiumAvatarCharacter(
    id: 'mira',
    name: 'Mira',
    shortDescription: 'Kıvırcık saçlı, sıcak bakışlı.',
    visualDescription: 'kıvırcık saçlı, sıcak bakışlı',
    personalityStyle: 'samimi, yumuşak, destekleyici',
    voiceStyle: 'sakin',
    premiumOnly: true,
    assetIdle: 'assets/avatars/mira/idle.png',
    assetListening: 'assets/avatars/mira/listening.png',
    assetThinking: 'assets/avatars/mira/thinking.png',
    assetSpeaking: 'assets/avatars/mira/speaking.png',
    assetComforting: 'assets/avatars/mira/comforting.png',
    icon: Icons.face_3_rounded,
    color: EnisColors.primaryBlue,
    toneAvatarId: 'friend',
  ),
  PremiumAvatarCharacter(
    id: 'eren',
    name: 'Eren',
    shortDescription: 'Rahat, arkadaş gibi ve yumuşak ifadeli.',
    visualDescription: 'rahat, arkadaş gibi, yumuşak ifadeli erkek',
    personalityStyle: 'samimi, doğal, arkadaş gibi',
    voiceStyle: 'samimi',
    premiumOnly: true,
    assetIdle: 'assets/avatars/eren/idle.png',
    assetListening: 'assets/avatars/eren/listening.png',
    assetThinking: 'assets/avatars/eren/thinking.png',
    assetSpeaking: 'assets/avatars/eren/speaking.png',
    assetComforting: 'assets/avatars/eren/comforting.png',
    icon: Icons.chat_bubble_rounded,
    color: EnisColors.softPurple,
    toneAvatarId: 'friend',
  ),
  PremiumAvatarCharacter(
    id: 'lina',
    name: 'Lina',
    shortDescription: 'Sarışın, canlı ve dengeli.',
    visualDescription: 'sarışın, canlı ve enerjik',
    personalityStyle: 'canlı, destekleyici, baskıcı değil',
    voiceStyle: 'enerjik',
    premiumOnly: true,
    assetIdle: 'assets/avatars/lina/idle.png',
    assetListening: 'assets/avatars/lina/listening.png',
    assetThinking: 'assets/avatars/lina/thinking.png',
    assetSpeaking: 'assets/avatars/lina/speaking.png',
    assetComforting: 'assets/avatars/lina/comforting.png',
    icon: Icons.face_4_rounded,
    color: EnisColors.softBlue,
    toneAvatarId: 'friend',
  ),
  PremiumAvatarCharacter(
    id: 'deniz',
    name: 'Deniz',
    shortDescription: 'Nötr, mavi gözlü ve sakin.',
    visualDescription: 'nötr, mavi gözlü, sakin ve güven veren',
    personalityStyle: 'dengeli, açık, huzurlu',
    voiceStyle: 'sakin',
    premiumOnly: true,
    assetIdle: 'assets/avatars/deniz/idle.png',
    assetListening: 'assets/avatars/deniz/listening.png',
    assetThinking: 'assets/avatars/deniz/thinking.png',
    assetSpeaking: 'assets/avatars/deniz/speaking.png',
    assetComforting: 'assets/avatars/deniz/comforting.png',
    icon: Icons.face_5_rounded,
    color: EnisColors.lavender,
    toneAvatarId: 'guide',
  ),
  PremiumAvatarCharacter(
    id: 'arda',
    name: 'Arda',
    shortDescription: 'Sakin, ayakları yere basan ve güven veren.',
    visualDescription: 'sakin, kendinden emin, güven veren erkek',
    personalityStyle: 'sakin, ayakları yere basan, güven veren',
    voiceStyle: 'sakin',
    premiumOnly: true,
    assetIdle: 'assets/avatars/arda/idle.png',
    assetListening: 'assets/avatars/arda/listening.png',
    assetThinking: 'assets/avatars/arda/thinking.png',
    assetSpeaking: 'assets/avatars/arda/speaking.png',
    assetComforting: 'assets/avatars/arda/comforting.png',
    icon: Icons.person_rounded,
    color: Color(0xFF4F7FD8),
    toneAvatarId: 'structured',
  ),
  PremiumAvatarCharacter(
    id: 'ada',
    name: 'Ada',
    shortDescription: 'Sade, net ve profesyonel.',
    visualDescription: 'sade ve profesyonel',
    personalityStyle: 'düzenli, net, düşünceli',
    voiceStyle: 'sakin',
    premiumOnly: true,
    assetIdle: 'assets/avatars/ada/idle.png',
    assetListening: 'assets/avatars/ada/listening.png',
    assetThinking: 'assets/avatars/ada/thinking.png',
    assetSpeaking: 'assets/avatars/ada/speaking.png',
    assetComforting: 'assets/avatars/ada/comforting.png',
    icon: Icons.auto_awesome_rounded,
    color: EnisColors.deepNavy,
    toneAvatarId: 'structured',
  ),
  PremiumAvatarCharacter(
    id: 'kerem',
    name: 'Kerem',
    shortDescription: 'Canlı, hafif ve destekleyici.',
    visualDescription: 'canlı, hafif tonlu, destekleyici erkek',
    personalityStyle: 'enerjik, hafif, destekleyici',
    voiceStyle: 'enerjik',
    premiumOnly: true,
    assetIdle: 'assets/avatars/kerem/idle.png',
    assetListening: 'assets/avatars/kerem/listening.png',
    assetThinking: 'assets/avatars/kerem/thinking.png',
    assetSpeaking: 'assets/avatars/kerem/speaking.png',
    assetComforting: 'assets/avatars/kerem/comforting.png',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFF6BA6FF),
    toneAvatarId: 'friend',
  ),
];

PremiumAvatarCharacter avatarCharacterById(String? id) {
  return premiumAvatarCharacters.firstWhere(
    (character) => character.id == id,
    orElse: () => premiumAvatarCharacters.first,
  );
}

PremiumAvatarCharacter? selectedAvatarCharacter(String? id) {
  if (id == null || id.trim().isEmpty) return null;
  for (final character in premiumAvatarCharacters) {
    if (character.id == id) return character;
  }
  return null;
}

String voiceOptionLabel(String? voiceStyle) {
  final normalized = voiceStyle?.trim().toLowerCase();
  return switch (normalized) {
    'samimi' => 'Samimi',
    'enerjik' => 'Enerjik',
    _ => 'Sakin',
  };
}
