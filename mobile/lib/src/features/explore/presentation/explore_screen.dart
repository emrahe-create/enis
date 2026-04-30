import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, required this.onOpenPremium});

  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Keşfet',
      subtitle: 'Mini wellness tools and upcoming expert matching.',
      child: ListView(
        children: [
          const _ToolCard(
            icon: Icons.air_rounded,
            title: 'Breathing',
            text: 'Take a quiet one-minute breathing pause.',
          ),
          const SizedBox(height: 12),
          const _ToolCard(
            icon: Icons.self_improvement_rounded,
            title: 'Meditation',
            text: 'A short grounding moment for the day.',
          ),
          const SizedBox(height: 12),
          const _ToolCard(
            icon: Icons.edit_note_rounded,
            title: 'CBT journal',
            text: 'Notice a thought, feeling, and gentle next step.',
          ),
          const SizedBox(height: 18),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.people_alt_outlined, color: EnisColors.lavender, size: 30),
                const SizedBox(height: 12),
                Text('Uzman eşleştirme', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Uzman eşleştirme sistemimiz çok yakında aktif olacak. Öncelikli erişim listesine katılarak ilk bilgilendirilenlerden biri olabilirsin.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Premium', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Sohbetini daha derin hale getirmek ister misin?\nPremium ile devam edebilirsin.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: '15 Gün Ücretsiz Başlat',
                  icon: Icons.workspace_premium_rounded,
                  onPressed: onOpenPremium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: EnisBrand.gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: EnisColors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
