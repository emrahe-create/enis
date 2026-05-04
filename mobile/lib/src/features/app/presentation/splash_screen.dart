import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/enis_icon.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: EnisColors.background),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EnisIcon(size: 112),
                  const SizedBox(height: 22),
                  Text(
                    EnisBrand.appName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontSize: 44),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    EnisBrand.taglineTr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    EnisBrand.taglineEn,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: EnisColors.primaryBlue,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
