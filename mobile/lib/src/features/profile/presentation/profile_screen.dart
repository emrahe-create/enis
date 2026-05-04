import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../../avatar/domain/avatar_character.dart';
import '../../chat/domain/avatar_option.dart';
import '../domain/subscription_snapshot.dart';
import '../domain/user_profile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.subscription,
    required this.onOpenPremium,
    required this.onOpenLegal,
    required this.onOpenAvatarSetup,
    required this.onExportData,
    required this.onDeleteAccount,
    required this.onLogout,
  });

  final UserProfile profile;
  final SubscriptionSnapshot subscription;
  final VoidCallback onOpenPremium;
  final VoidCallback onOpenLegal;
  final VoidCallback onOpenAvatarSetup;
  final Future<Map<String, dynamic>> Function() onExportData;
  final Future<void> Function() onDeleteAccount;
  final Future<void> Function() onLogout;

  Future<void> _export(BuildContext context) async {
    late Map<String, dynamic> data;
    try {
      data = await onExportData();
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, _apiErrorMessage(error));
      return;
    }
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Text(
            const JsonEncoder.withIndent('  ').convert(data),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabımı sil'),
        content: const Text(
            'Bu işlem API kullanılabiliyorsa Enis hesabını kalıcı olarak siler.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) await onDeleteAccount();
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _apiErrorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = avatarById(profile.preferredAvatar);
    final character = subscription.premium
        ? selectedAvatarCharacter(profile.avatarCharacterId)
        : null;
    return ScreenScaffold(
      title: 'Profil',
      subtitle: EnisBrand.ownerCompany,
      child: ListView(
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Ad Soyad', value: profile.fullName ?? '-'),
                _InfoRow(label: 'E-posta', value: profile.email),
                _InfoRow(
                    label: 'Karakterinin adı',
                    value: profile.avatarName ?? '-'),
                _InfoRow(label: 'Seçili avatar', value: avatar.label),
                if (character != null)
                  _InfoRow(label: 'Avatar karakteri', value: character.name),
                if (character != null)
                  _InfoRow(label: 'Ses tarzı', value: character.voiceLabel),
                _InfoRow(label: 'Abonelik durumu', value: subscription.label),
                _InfoRow(
                  label: 'Kalan deneme günü',
                  value: subscription.trialDaysRemaining?.toString() ?? '-',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ActionTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Avatar ayarları',
            onTap: onOpenAvatarSetup,
          ),
          _ActionTile(
            icon: Icons.workspace_premium_rounded,
            title: 'Premium',
            onTap: onOpenPremium,
          ),
          _ActionTile(
            icon: Icons.download_rounded,
            title: 'Verilerimi indir',
            onTap: () => _export(context),
          ),
          _ActionTile(
            icon: Icons.menu_book_rounded,
            title: 'Yasal metinler',
            onTap: onOpenLegal,
          ),
          _ActionTile(
            icon: Icons.logout_rounded,
            title: 'Çıkış yap',
            onTap: onLogout,
          ),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Hesabımı sil',
            destructive: true,
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: EnisColors.deepNavy.withValues(alpha: 0.58),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.redAccent : EnisColors.deepNavy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: color),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
