const dailyCheckInTitle = 'Bugün nasılsın?';
const dailyCheckInOptions = [
  'Hafifim',
  'Karışığım',
  'Yoruldum',
  'Kaygılıyım',
  'Anlatmak istiyorum',
];
const nightReflectionText =
    'Bugünü kapatmadan önce içinden geçen bir şey var mı?';
const fallbackReturningGreeting =
    'Bir süredir konuşamadık… bugün nasıl gidiyor?';
const dailyPresenceText = 'Buradayım. İstersen devam edebiliriz.';
const silenceNudgeText =
    'İstersen burada kalabiliriz… ya da biraz daha anlatabilirsin.';
const silenceNudgeDelay = Duration(seconds: 45);
const morningNotificationCopy = 'Güne nasıl başladığını merak ettim.';
const eveningNotificationCopy = 'Bugünü burada bırakmak ister misin?';
const returningNotificationCopy =
    'Buradayım. Kaldığımız yerden devam edebiliriz.';
const pushNotificationPreviewEnabled = false;
const microEmotionalHooks = [
  'Bugün seni en çok ne yordu?',
  'İçinde kalan bir şey var mı?',
  'Bugün biraz daha hafif mi yoksa benzer mi?',
];

class CompanionMemory {
  const CompanionMemory({
    required this.key,
    required this.value,
    this.importance = 1,
    this.updatedAt,
    this.lastUsedAt,
  });

  final String key;
  final String value;
  final int importance;
  final DateTime? updatedAt;
  final DateTime? lastUsedAt;

  factory CompanionMemory.fromJson(Map<String, dynamic> json) {
    return CompanionMemory(
      key: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      importance: int.tryParse(json['importance']?.toString() ?? '') ?? 1,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      lastUsedAt: DateTime.tryParse(json['last_used_at']?.toString() ?? '') ??
          DateTime.tryParse(json['lastUsedAt']?.toString() ?? ''),
    );
  }
}

String buildDailyCheckInChatContext(String mood) {
  return 'Bugünkü kısa check-in: $mood. Buna göre yumuşak ve kısa bir yerden cevap ver.';
}

bool shouldShowReturningGreeting(DateTime? lastOpenedAt, DateTime now) {
  if (lastOpenedAt == null) return false;
  return now.difference(lastOpenedAt).inHours >= 24;
}

bool isSameLocalDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

bool shouldShowDailyPresence({
  required DateTime? lastOpenedAt,
  required DateTime? lastInteractionAt,
  required DateTime now,
  required bool returning,
}) {
  if (returning) return false;
  final reference = lastInteractionAt ?? lastOpenedAt;
  if (reference == null) return false;
  return isSameLocalDay(reference, now);
}

String microEmotionalHook({required DateTime now, int seed = 0}) {
  final index = (now.year + now.month + now.day + seed).abs() %
      microEmotionalHooks.length;
  return microEmotionalHooks[index];
}

String? nightReflectionPrompt(DateTime now) {
  return now.hour >= 20 ? nightReflectionText : null;
}

String? buildContinuityLine(int? days) {
  final count = days ?? 0;
  if (count < 2) return null;
  return '$count gündür kendine küçük bir alan açıyorsun.';
}

CompanionMemory? latestCompanionMemory(List<CompanionMemory> memories) {
  final usable = memories
      .where((memory) => memory.key.isNotEmpty && memory.value.isNotEmpty)
      .toList();
  if (usable.isEmpty) return null;

  usable.sort((a, b) {
    if (b.importance != a.importance) return b.importance - a.importance;
    final aTime =
        a.lastUsedAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime =
        b.lastUsedAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
  return usable.first;
}

String memoryGreetingLabel(String key) {
  return switch (key) {
    'work_stress' => 'iş tarafı',
    'relationship' => 'ilişki tarafı',
    'sleep' => 'uyku düzenin',
    'family' => 'aile tarafı',
    'loneliness' => 'yalnızlık hissi',
    'worry' => 'kaygı tarafı',
    _ => 'konuştuğumuz konu',
  };
}

String? buildReturningGreeting({
  required DateTime? lastInteractionAt,
  required DateTime now,
  required bool premium,
  required List<CompanionMemory> memories,
}) {
  if (!shouldShowReturningGreeting(lastInteractionAt, now)) return null;
  final memory = premium ? latestCompanionMemory(memories) : null;
  if (memory == null) return fallbackReturningGreeting;
  return 'Bir süredir yoktun… son konuşmamızda ${memoryGreetingLabel(memory.key)} seni yormuştu. Bugün nasıl hissediyorsun?';
}

bool shouldShowSilenceNudge({
  required int userMessageCount,
  required int assistantMessageCount,
  required bool alreadyShown,
}) {
  if (alreadyShown) return false;
  return userMessageCount >= 2 && assistantMessageCount >= 2;
}

bool containsGuiltLanguage(String text) {
  final normalized = text.toLowerCase();
  return [
    'kaçırdın',
    'kaybettin',
    'bozdun',
    'geri kaldın',
    'streak lost',
    'neredesin',
    'neden yazmadın',
    'niye yazmadın',
  ].any(normalized.contains);
}
