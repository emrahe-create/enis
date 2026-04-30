import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../../profile/domain/subscription_snapshot.dart';
import '../data/premium_service.dart';

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
  bool _distanceSales = false;
  bool _refundPolicy = false;
  bool _loadingTrial = false;
  bool _loadingCheckout = false;

  Future<void> _startTrial() async {
    setState(() => _loadingTrial = true);
    try {
      final snapshot = await widget.service.startTrial();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium trial started.')));
      Navigator.of(context).pop(snapshot);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loadingTrial = false);
    }
  }

  Future<void> _continuePremium() async {
    if (!_distanceSales || !_refundPolicy) {
      _showMessage('Distance sales and refund policy consents are required before checkout.');
      return;
    }

    setState(() => _loadingCheckout = true);
    try {
      final url = await widget.service.createCheckoutSession(
        consents: {
          ConsentKeys.distanceSales: _distanceSales,
          ConsentKeys.cancellationRefundPolicy: _refundPolicy,
        },
      );
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        _showMessage('Checkout session created.');
        return;
      }

      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!opened) {
        _showMessage('Checkout could not be opened. Please try again.');
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } on FormatException {
      _showMessage('Checkout URL is invalid.');
    } finally {
      if (mounted) setState(() => _loadingCheckout = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenScaffold(
        title: '15 gün Premium ücretsiz',
        subtitle: 'Daha kişisel, daha derin ve daha akılda kalan bir deneyim.',
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ListView(
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: EnisColors.primaryBlue, size: 34),
                  const SizedBox(height: 14),
                  Text(
                    widget.current.premium ? 'Premium active' : 'Premium deneyimi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  const _Benefit(text: 'Daha derin sohbet'),
                  const _Benefit(text: 'Hafıza destekli yanıtlar'),
                  const _Benefit(text: 'Premium avatar deneyimi'),
                  const _Benefit(text: 'Sınırsız sohbet'),
                  const _Benefit(text: 'Mini wellness araçları'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: _loadingTrial ? 'Başlatılıyor...' : '15 Gün Ücretsiz Başlat',
              icon: Icons.auto_awesome_rounded,
              enabled: !_loadingTrial,
              onPressed: _startTrial,
            ),
            const SizedBox(height: 18),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _distanceSales,
                    onChanged: (value) => setState(() => _distanceSales = value ?? false),
                    title: const Text('Distance sales agreement'),
                    activeColor: EnisColors.primaryBlue,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  Divider(height: 1, color: EnisColors.deepNavy.withOpacity(0.08)),
                  CheckboxListTile(
                    value: _refundPolicy,
                    onChanged: (value) => setState(() => _refundPolicy = value ?? false),
                    title: const Text('Cancellation/refund policy'),
                    activeColor: EnisColors.primaryBlue,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: _loadingCheckout ? 'Preparing...' : 'Premium’a Devam Et',
              icon: Icons.payment_rounded,
              enabled: !_loadingCheckout,
              onPressed: _continuePremium,
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
          const Icon(Icons.check_circle_rounded, color: EnisColors.lavender, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
