import 'package:flutter/material.dart';

import '../brand/enis_brand.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: EnisColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EnisColors.deepNavy.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: EnisColors.deepNavy.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
