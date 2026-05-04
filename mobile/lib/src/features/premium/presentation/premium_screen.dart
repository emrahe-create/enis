import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../../profile/domain/subscription_snapshot.dart';
import '../data/premium_service.dart';

const mobilePremiumCheckoutEnabled = false;
const mobileSubscriptionUnavailableMessage =
    'Mobil abonelikler çok yakında App Store ve Google Play üzerinden aktif olacak.';
const freePackageFeatures = [
  'Günlük sınırlı sohbet',
  'Temel Enis yanıtları',
  'Basit iyi oluş önerileri',
];
const premiumPackageFeatures = [
  'Sınırsız sohbet',
  'Hafıza destekli yanıtlar',
  'Premium avatar karakterleri',
  'Duygu analizi ve raporlama',
  'Mini nefes, meditasyon ve düşünce günlüğü araçları',
  'Uzman eşleştirme sistemine öncelikli erişim',
];

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({
    super.key,
    required this.current,
    required this.service,
  });

  final SubscriptionSnapshot current;
  final PremiumService service;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loadingTrial = false;

  Future<void> _startTrial() async {
    setState(() => _loadingTrial = true);
    try {
      final snapshot = await widget.service.startTrial();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium deneme başladı.')));
      Navigator.of(context).pop(snapshot);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loadingTrial = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenScaffold(
        title: '15 Gün Premium Ücretsiz',
        subtitle: 'Daha kişisel, daha derin ve daha akılda kalan bir deneyim.',
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ListView(
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: EnisColors.primaryBlue, size: 34),
                  const SizedBox(height: 14),
                  Text(
                    widget.current.premium
                        ? 'Premium aktif'
                        : 'Premium deneyimi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  const _Benefit(text: 'Sınırsız sohbet'),
                  const _Benefit(text: 'Daha derin ve kişisel yanıtlar'),
                  const _Benefit(text: 'Hafıza destekli konuşma devamlılığı'),
                  const _Benefit(text: 'Premium avatar karakterleri'),
                  const _Benefit(
                      text: 'Duygu takibi ve zaman içindeki değişim'),
                  const _Benefit(
                      text:
                          'Mini nefes, meditasyon ve düşünce günlüğü araçları'),
                  const _Benefit(
                      text: 'Uzman eşleştirme sistemine öncelikli erişim'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _PackageCard(
              title: 'Ücretsiz',
              features: freePackageFeatures,
            ),
            const SizedBox(height: 12),
            const _PackageCard(
              title: 'Premium',
              highlighted: true,
              features: premiumPackageFeatures,
            ),
            const SizedBox(height: 18),
            GradientButton(
              label:
                  _loadingTrial ? 'Başlatılıyor...' : '15 Gün Ücretsiz Başlat',
              icon: Icons.auto_awesome_rounded,
              enabled: !_loadingTrial,
              onPressed: _startTrial,
            ),
            const SizedBox(height: 18),
            const SoftCard(
              child: Text(mobileSubscriptionUnavailableMessage),
            ),
            const SizedBox(height: 14),
            const GradientButton(
              label: 'Mobil abonelik çok yakında',
              icon: Icons.lock_clock_rounded,
              enabled: mobilePremiumCheckoutEnabled,
              onPressed: null,
            ),
            const SizedBox(height: 14),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yasal satın alma metinleri',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Mesafeli satış sözleşmesi ve iptal/iade politikası mobil abonelikler aktif olduğunda satın alma öncesinde gösterilecek.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: EnisColors.lavender, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.title,
    required this.features,
    this.highlighted = false,
  });

  final String title;
  final List<String> features;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                highlighted
                    ? Icons.workspace_premium_rounded
                    : Icons.favorite_border_rounded,
                color:
                    highlighted ? EnisColors.primaryBlue : EnisColors.lavender,
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => _Benefit(text: feature)),
        ],
      ),
    );
  }
}
