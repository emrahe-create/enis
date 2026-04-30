import 'package:flutter/material.dart';

import '../brand/enis_brand.dart';

class EnisIcon extends StatelessWidget {
  const EnisIcon({super.key, this.size = 88, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final assetPath = showWordmark ? EnisBrand.logoAsset : EnisBrand.appIconAsset;

    return Image.asset(
      assetPath,
      width: size,
      height: showWordmark ? null : size,
      fit: BoxFit.contain,
      semanticLabel: showWordmark ? 'enis logo' : 'enis icon',
    );
  }
}
