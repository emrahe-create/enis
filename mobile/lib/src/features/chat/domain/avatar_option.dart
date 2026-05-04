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
    label: 'Düzenli',
    description: 'Sakin, planlı ve net.',
    icon: Icons.format_list_bulleted_rounded,
    color: EnisColors.primaryBlue,
  ),
  AvatarOption(
    id: 'friend',
    label: 'Samimi',
    description: 'Sıcak, gündelik ve sade.',
    icon: Icons.mode_comment_outlined,
    color: EnisColors.lavender,
  ),
  AvatarOption(
    id: 'guide',
    label: 'Rehber',
    description: 'Yavaş, dingin ve toparlayıcı.',
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
