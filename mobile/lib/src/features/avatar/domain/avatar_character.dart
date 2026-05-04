import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';

class PremiumAvatarCharacter {
  const PremiumAvatarCharacter({
    required this.id,
    required this.name,
    required this.visualStyle,
    required this.personalityStyle,
    required this.voiceStyle,
    required this.description,
    required this.icon,
    required this.color,
    required this.toneAvatarId,
  });

  final String id;
  final String name;
  final String visualStyle;
  final String personalityStyle;
  final String voiceStyle;
  final String description;
  final IconData icon;
  final Color color;
  final String toneAvatarId;

  String get voiceLabel {
    if (voiceStyle.isEmpty) return '';
    return '${voiceStyle[0].toUpperCase()}${voiceStyle.substring(1)}';
  }

  String get companionLabel {
    return switch (id) {
      'lina' => 'Enerjik eşlikçi',
      'deniz' => 'Sakin eşlikçi',
      'ada' => 'Düzenli eşlikçi',
      'eren' => 'Doğal eşlikçi',
      _ => 'Samimi eşlikçi',
    };
  }
}

const premiumAvatarCharacters = [
  PremiumAvatarCharacter(
    id: 'mira',
    name: 'Mira',
    visualStyle: 'kıvırcık saçlı, sıcak bakışlı',
    personalityStyle: 'samimi, yumuşak, destekleyici',
    voiceStyle: 'sakin',
    description: 'Kıvırcık saçlı, sıcak bakışlı. Samimi ve yumuşak.',
    icon: Icons.face_3_rounded,
    color: EnisColors.primaryBlue,
    toneAvatarId: 'friend',
  ),
  PremiumAvatarCharacter(
    id: 'lina',
    name: 'Lina',
    visualStyle: 'sarışın, enerjik',
    personalityStyle: 'daha canlı, motive edici',
    voiceStyle: 'enerjik',
    description: 'Sarışın, enerjik. Daha canlı ve motive edici.',
    icon: Icons.face_4_rounded,
    color: EnisColors.softBlue,
    toneAvatarId: 'friend',
  ),
  PremiumAvatarCharacter(
    id: 'deniz',
    name: 'Deniz',
    visualStyle: 'mavi gözlü, sakin',
    personalityStyle: 'dengeli, açık, güven veren',
    voiceStyle: 'sakin',
    description: 'Mavi gözlü, sakin. Dengeli ve güven veren.',
    icon: Icons.face_5_rounded,
    color: EnisColors.lavender,
    toneAvatarId: 'guide',
  ),
  PremiumAvatarCharacter(
    id: 'ada',
    name: 'Ada',
    visualStyle: 'profesyonel ve sade',
    personalityStyle: 'düzenli, net, düşünceli',
    voiceStyle: 'sakin',
    description: 'Profesyonel ve sade. Düzenli, net ve düşünceli.',
    icon: Icons.auto_awesome_rounded,
    color: EnisColors.deepNavy,
    toneAvatarId: 'structured',
  ),
  PremiumAvatarCharacter(
    id: 'eren',
    name: 'Eren',
    visualStyle: 'sade, nötr',
    personalityStyle: 'arkadaş gibi, doğal',
    voiceStyle: 'samimi',
    description: 'Sade, nötr. Arkadaş gibi doğal bir ton.',
    icon: Icons.chat_bubble_rounded,
    color: EnisColors.softPurple,
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
