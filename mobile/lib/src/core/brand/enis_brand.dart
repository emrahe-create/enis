import 'package:flutter/material.dart';

class EnisColors {
  const EnisColors._();

  static const primaryBlue = Color(0xFF5D8CFF);
  static const softBlue = Color(0xFF7CB7FF);
  static const lavender = Color(0xFFA78BFA);
  static const softPurple = Color(0xFFC084FC);
  static const deepNavy = Color(0xFF21184A);
  static const background = Color(0xFFF8F7FF);
  static const white = Color(0xFFFFFFFF);
}

class EnisBrand {
  const EnisBrand._();

  static const appName = 'enis';
  static const ownerCompany = 'EQ Bilişim';
  static const taglineEn = 'Say what’s on your mind.';
  static const taglineTr = 'İçinden geçenleri söyle.';
  static const appIconAsset = 'assets/brand/app_icon.png';
  static const logoAsset = 'assets/brand/logo_enis.png';

  static const onboarding = [
    BilingualCopy(en: taglineEn, tr: taglineTr),
    BilingualCopy(en: 'There’s no pressure here.', tr: 'Burada bir zorunluluk yok.'),
    BilingualCopy(en: 'You can start anytime.', tr: 'Ne zaman istersen başlayabilirsin.'),
  ];

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      EnisColors.softBlue,
      EnisColors.primaryBlue,
      EnisColors.softPurple,
    ],
  );
}

class BilingualCopy {
  const BilingualCopy({required this.en, required this.tr});

  final String en;
  final String tr;
}

class ConsentKeys {
  const ConsentKeys._();

  static const kvkkClarificationSeen = 'kvkk_clarification_seen';
  static const privacyPolicy = 'privacy_policy';
  static const termsOfUse = 'terms_of_use';
  static const wellnessDisclaimer = 'wellness_disclaimer';
  static const marketingPermission = 'marketing_permission';
  static const distanceSales = 'distance_sales';
  static const cancellationRefundPolicy = 'cancellation_refund_policy';
}
