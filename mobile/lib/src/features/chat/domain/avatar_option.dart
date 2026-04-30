import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';

class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

const avatarOptions = [
  AvatarOption(
    id: 'structured',
    label: 'Structured',
    description: 'Calm, organized, and clear.',
    icon: Icons.format_list_bulleted_rounded,
    color: EnisColors.primaryBlue,
  ),
  AvatarOption(
    id: 'friend',
    label: 'Friend',
    description: 'Casual, warm, and simple.',
    icon: Icons.mode_comment_outlined,
    color: EnisColors.lavender,
  ),
  AvatarOption(
    id: 'guide',
    label: 'Guide',
    description: 'Slow, peaceful, and grounding.',
    icon: Icons.spa_outlined,
    color: EnisColors.softPurple,
  ),
];

AvatarOption avatarById(String id) {
  return avatarOptions.firstWhere(
    (avatar) => avatar.id == id,
    orElse: () => avatarOptions.first,
  );
}
