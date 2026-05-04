import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/enis_icon.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/soft_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onStart,
    required this.onWelcomeBack,
  });

  final VoidCallback onStart;
  final VoidCallback onWelcomeBack;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const EnisIcon(size: 48),
                    const SizedBox(width: 10),
                    Text(
                      EnisBrand.appName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: EnisBrand.onboarding.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final slide = EnisBrand.onboarding[index];
                    return Center(
                      child: SoftCard(
                        padding: const EdgeInsets.all(26),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                gradient: EnisBrand.gradient,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 26),
                            Text(
                              slide.tr,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              slide.en,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: EnisColors.primaryBlue,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  EnisBrand.onboarding.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _index == index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _index == index
                          ? EnisColors.primaryBlue
                          : EnisColors.deepNavy.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              GradientButton(
                label: 'Başla',
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onStart,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onWelcomeBack,
                child: const Text('Geri dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
