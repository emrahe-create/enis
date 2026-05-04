import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../domain/avatar_character.dart';
import '../../chat/domain/avatar_option.dart';
import '../../profile/domain/subscription_snapshot.dart';
import '../../profile/domain/user_profile.dart';

class AvatarSetupScreen extends StatefulWidget {
  const AvatarSetupScreen({
    super.key,
    required this.profile,
    required this.subscription,
    required this.onSaved,
  });

  final UserProfile profile;
  final SubscriptionSnapshot subscription;
  final Future<void> Function(
      {required String avatar,
      required String? avatarName,
      required PremiumAvatarCharacter? avatarCharacter}) onSaved;

  @override
  State<AvatarSetupScreen> createState() => _AvatarSetupScreenState();
}

class _AvatarSetupScreenState extends State<AvatarSetupScreen> {
  late String _selectedAvatar = widget.profile.preferredAvatar;
  late final TextEditingController _avatarNameController =
      TextEditingController(text: widget.profile.avatarName);
  late String? _selectedCharacterId =
      widget.profile.avatarCharacterId ?? premiumAvatarCharacters.first.id;
  bool _saving = false;

  @override
  void dispose() {
    _avatarNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final character = widget.subscription.premium
        ? avatarCharacterById(_selectedCharacterId)
        : null;
    setState(() => _saving = true);
    await widget.onSaved(
      avatar: character?.toneAvatarId ?? _selectedAvatar,
      avatarName: _avatarNameController.text,
      avatarCharacter: character,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final premium = widget.subscription.premium;
    return Scaffold(
      body: ScreenScaffold(
        title: premium ? 'Avatar karakterini seç' : 'Yanıt tarzını seç',
        subtitle:
            'Enis içinde sana eşlik edecek karakterin tarzını belirleyebilirsin.',
        child: ListView(
          children: [
            if (!premium) ...[
              ...avatarOptions.map(
                (avatar) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AvatarChoice(
                    avatar: avatar,
                    selected: avatar.id == _selectedAvatar,
                    onTap: () => setState(() => _selectedAvatar = avatar.id),
                  ),
                ),
              ),
            ] else ...[
              _PremiumCharacterSection(
                selected: _selectedCharacterId,
                onSelected: (value) =>
                    setState(() => _selectedCharacterId = value),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sana eşlik edecek karaktere bir isim verebilirsin.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _avatarNameController,
                    decoration: const InputDecoration(
                      labelText: 'Karakterinin adı',
                      helperText: 'Bu isim sadece sana özel olacak.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GradientButton(
              label: _saving
                  ? 'Kaydediliyor...'
                  : (premium ? 'Karakteri seç' : 'Kaydet'),
              icon: Icons.check_rounded,
              enabled: !_saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCharacterSection extends StatelessWidget {
  const _PremiumCharacterSection({
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Karakter seçenekleri',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Enis içinde sana eşlik edecek karakterin tarzını belirleyebilirsin.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 520 ? 3 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: columns == 3 ? 0.92 : 0.78,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: premiumAvatarCharacters
                    .map(
                      (character) => _PremiumCharacterCard(
                        character: character,
                        selected: selected == character.id,
                        onTap: () => onSelected(character.id),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Bu seçim yalnızca karakter görünümü, ses ve konuşma tarzını belirler.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: EnisColors.deepNavy.withValues(alpha: 0.58),
                ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCharacterCard extends StatelessWidget {
  const _PremiumCharacterCard({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final PremiumAvatarCharacter character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = character.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? EnisColors.primaryBlue.withValues(alpha: 0.1)
              : EnisColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? EnisColors.primaryBlue
                : EnisColors.deepNavy.withValues(alpha: 0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.86),
                    EnisColors.softPurple.withValues(alpha: 0.78),
                  ],
                ),
              ),
              child: Icon(character.icon, color: EnisColors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              character.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: EnisColors.deepNavy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Text(
                character.description,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ses: ${character.voiceLabel}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: EnisColors.deepNavy.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 5),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? EnisColors.primaryBlue
                  : EnisColors.deepNavy.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final AvatarOption avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: avatar.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(avatar.icon, color: avatar.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(avatar.label,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(avatar.description,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected
                ? EnisColors.primaryBlue
                : EnisColors.deepNavy.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}
