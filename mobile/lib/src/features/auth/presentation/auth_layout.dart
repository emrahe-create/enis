import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/enis_icon.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          children: [
            const EnisIcon(size: 58),
            const SizedBox(height: 22),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: EnisColors.deepNavy.withValues(alpha: 0.64),
                  ),
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
