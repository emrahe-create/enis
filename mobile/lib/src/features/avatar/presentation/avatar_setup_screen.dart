import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../../chat/domain/avatar_option.dart';
import '../../profile/domain/user_profile.dart';

class AvatarSetupScreen extends StatefulWidget {
  const AvatarSetupScreen({
    super.key,
    required this.profile,
    required this.onSaved,
  });

  final UserProfile profile;
  final Future<void> Function({required String avatar, required String? avatarName}) onSaved;

  @override
  State<AvatarSetupScreen> createState() => _AvatarSetupScreenState();
}

class _AvatarSetupScreenState extends State<AvatarSetupScreen> {
  late String _selectedAvatar = widget.profile.preferredAvatar;
  late final TextEditingController _avatarNameController = TextEditingController(text: widget.profile.avatarName);
  bool _saving = false;

  @override
  void dispose() {
    _avatarNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSaved(
      avatar: _selectedAvatar,
      avatarName: _avatarNameController.text,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenScaffold(
        title: 'Avatar',
        subtitle: 'Choose how Enis responds in chat.',
        child: ListView(
          children: [
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
              label: _saving ? 'Saving...' : 'Save / Kaydet',
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
              color: avatar.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(avatar.icon, color: avatar.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(avatar.label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(avatar.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? EnisColors.primaryBlue : EnisColors.deepNavy.withOpacity(0.28),
          ),
        ],
      ),
    );
  }
}
