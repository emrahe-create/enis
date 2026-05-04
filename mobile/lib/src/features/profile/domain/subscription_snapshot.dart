class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.status,
    required this.premium,
    this.trialDaysRemaining,
  });

  final String status;
  final bool premium;
  final int? trialDaysRemaining;

  String get label {
    if (premium && status == 'trialing') return 'Premium deneme';
    if (premium) return 'Premium';
    return 'Ücretsiz';
  }

  factory SubscriptionSnapshot.free() {
    return const SubscriptionSnapshot(
        status: 'free', premium: false, trialDaysRemaining: null);
  }

  factory SubscriptionSnapshot.trial({int daysRemaining = 15}) {
    return SubscriptionSnapshot(
      status: 'trialing',
      premium: true,
      trialDaysRemaining: daysRemaining,
    );
  }

  factory SubscriptionSnapshot.fromJson(Map<String, dynamic> json) {
    final subscription = json['subscription'];
    final trial = json['trial'];
    final entitlements = json['entitlements'];
    final status = subscription is Map<String, dynamic>
        ? subscription['status']?.toString()
        : json['status']?.toString();
    final premium = entitlements is Map<String, dynamic>
        ? entitlements['premium'] == true || entitlements['memory'] == true
        : json['premium'] == true || status == 'active' || status == 'trialing';
    final daysRemaining = trial is Map<String, dynamic>
        ? trial['daysRemaining']
        : json['trialDaysRemaining'];

    return SubscriptionSnapshot(
      status: status ?? (premium ? 'active' : 'free'),
      premium: premium,
      trialDaysRemaining: daysRemaining is int
          ? daysRemaining
          : int.tryParse(daysRemaining?.toString() ?? ''),
    );
  }
}
