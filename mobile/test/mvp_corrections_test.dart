import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_wellness_mobile/src/core/network/api_client.dart';
import 'package:ai_wellness_mobile/src/core/storage/token_storage.dart';
import 'package:ai_wellness_mobile/src/core/widgets/gradient_button.dart';
import 'package:ai_wellness_mobile/src/features/app/presentation/enis_app.dart';
import 'package:ai_wellness_mobile/src/features/auth/presentation/register_screen.dart';
import 'package:ai_wellness_mobile/src/features/avatar/domain/avatar_character.dart';
import 'package:ai_wellness_mobile/src/features/avatar/presentation/avatar_setup_screen.dart';
import 'package:ai_wellness_mobile/src/features/checkin/domain/retention_copy.dart';
import 'package:ai_wellness_mobile/src/features/chat/data/chat_service.dart';
import 'package:ai_wellness_mobile/src/features/chat/domain/chat_models.dart';
import 'package:ai_wellness_mobile/src/features/chat/presentation/chat_screen.dart';
import 'package:ai_wellness_mobile/src/features/premium/data/premium_service.dart';
import 'package:ai_wellness_mobile/src/features/premium/presentation/premium_screen.dart';
import 'package:ai_wellness_mobile/src/features/profile/domain/subscription_snapshot.dart';
import 'package:ai_wellness_mobile/src/features/profile/domain/user_profile.dart';

void main() {
  test('password confirmation mismatch blocks register validation', () {
    expect(registerPasswordsMatch('secret123', 'secret123'), true);
    expect(registerPasswordsMatch('secret123', 'other123'), false);
  });

  test('mobile premium checkout is disabled for Turkey launch', () {
    expect(mobilePremiumCheckoutEnabled, false);
    expect(
      mobileSubscriptionUnavailableMessage,
      'Mobil abonelikler çok yakında App Store ve Google Play üzerinden aktif olacak.',
    );
  });

  test('premium package benefits are available for rendering', () {
    expect(
      freePackageFeatures,
      containsAll([
        'Günlük sınırlı sohbet',
        'Temel Enis yanıtları',
        'Basit iyi oluş önerileri',
      ]),
    );
    expect(
      premiumPackageFeatures,
      containsAll([
        'Sınırsız sohbet',
        'Hafıza destekli yanıtlar',
        'Premium avatar karakterleri',
        'Mini nefes, meditasyon ve düşünce günlüğü araçları',
        'Uzman eşleştirme sistemine öncelikli erişim',
      ]),
    );
  });

  test('premium avatar character catalog is safe and persistent', () {
    final mira = avatarCharacterById('mira');
    final catalogText = premiumAvatarCharacters
        .map((character) =>
            '${character.name} ${character.visualStyle} ${character.personalityStyle} ${character.description}')
        .join(' ')
        .toLowerCase();
    final profile = UserProfile.fromJson({
      'email': 'demo@enis.app',
      'preferredAvatar': mira.toneAvatarId,
      'avatarCharacterId': mira.id,
      'avatarCharacterName': mira.name,
      'avatarVoiceStyle': mira.voiceStyle,
      'avatarVisualStyle': mira.visualStyle,
      'avatarPersonalityStyle': mira.personalityStyle,
    });

    expect(mira.name, 'Mira');
    expect(mira.companionLabel, 'Samimi eşlikçi');
    expect(voiceOptionLabel(mira.voiceStyle), 'Sakin');
    expect(profile.avatarCharacterId, 'mira');
    expect(profile.toPatchJson()['avatarCharacterName'], 'Mira');
    expect(catalogText.contains('terapist'), false);
    expect(catalogText.contains('doktor'), false);
    expect(catalogText.contains('psikolog'), false);
    expect(catalogText.contains('uzman'), false);
  });

  test('chat fallback does not expose static English responses', () {
    expect(
      chatFallbackUnavailableMessage,
      'Şu anda yanıt üretirken zorlandım… birazdan tekrar deneyelim mi?',
    );
    expect(chatFallbackUnavailableMessage.contains('It seems'), false);
    expect(chatFallbackUnavailableMessage.contains('This sounds'), false);
  });

  test('voice conversation copy is Turkish-first', () {
    expect(voiceListeningLabel, 'Seni dinliyorum...');
    expect(microphonePermissionRequiredLabel, 'Mikrofon izni gerekiyor');
    expect(voiceResponseLabel, 'Sesli yanıt');
    expect(replayVoiceLabel, 'Tekrar dinle');
    expect(stopVoiceLabel, 'Durdur');
    expect(voiceThinkingLabel, 'Enis düşünüyor...');
    expect(voiceStyleOptions, containsAll(['Sakin', 'Samimi', 'Enerjik']));
    expect(voiceThinkingDelayMinMs, 300);
    expect(voiceThinkingDelayMaxMs, 600);
    expect(voiceSilenceAutoSendDelay.inMilliseconds, 500);
  });

  test('voice responses are split into natural speaking segments', () {
    final segments = voiceResponseSegments(
      'Bugün içinde bir ağırlık var gibi. Böyle günler insanı yavaşlatıyor. '
      'En çok hangi an üstüne geldi?',
    );

    expect(segments, hasLength(3));
    expect(segments.first, 'Bugün içinde bir ağırlık var gibi.');
    expect(voiceSentencePause.inMilliseconds, inInclusiveRange(150, 250));
    expect(chatSlowThinkingMessage, 'Biraz düşünüyorum…');
    expect(chatSlowThinkingDelay.inSeconds, 6);

    final longSegments = voiceResponseSegments(
      'Bugün biraz üst üste gelmiş gibi, bunu tek başına taşımak da yorucu olabilir ama burada biraz durup neyin ağır geldiğini ayırabiliriz.',
      maxLength: 70,
    );
    expect(longSegments.length, greaterThan(1));
  });

  test('retention copy is gentle and Turkish-first', () {
    final greeting = buildReturningGreeting(
      lastInteractionAt: DateTime(2026, 5, 3, 8),
      now: DateTime(2026, 5, 4, 9),
      premium: true,
      memories: const [
        CompanionMemory(
          key: 'work_stress',
          value: 'İşinde yoğunluk ve baskı hissettiğini sık sık söylüyor.',
          importance: 5,
        ),
      ],
    );

    expect(dailyCheckInTitle, 'Bugün nasılsın?');
    expect(greeting,
        'Bir süredir yoktun… son konuşmamızda iş tarafı seni yormuştu. Bugün nasıl hissediyorsun?');
    expect(fallbackReturningGreeting,
        'Bir süredir konuşamadık… bugün nasıl gidiyor?');
    expect(dailyPresenceText, 'Buradayım. İstersen devam edebiliriz.');
    expect(
      shouldShowDailyPresence(
        lastOpenedAt: DateTime(2026, 5, 4, 8),
        lastInteractionAt: null,
        now: DateTime(2026, 5, 4, 13),
        returning: false,
      ),
      true,
    );
    expect(
      shouldShowReturningGreeting(
        DateTime(2026, 5, 3, 18),
        DateTime(2026, 5, 4, 9),
      ),
      false,
    );
    expect(
        microEmotionalHooks,
        containsAll(
            ['Bugün seni en çok ne yordu?', 'İçinde kalan bir şey var mı?']));
    expect(microEmotionalHooks,
        contains('Bugün biraz daha hafif mi yoksa benzer mi?'));
    expect(microEmotionalHooks,
        contains(microEmotionalHook(now: DateTime(2026, 5, 4), seed: 1)));
    expect(
      shouldShowSilenceNudge(
        userMessageCount: 2,
        assistantMessageCount: 2,
        alreadyShown: false,
      ),
      true,
    );
    expect(silenceNudgeText,
        'İstersen burada kalabiliriz… ya da biraz daha anlatabilirsin.');
    expect(pushNotificationPreviewEnabled, false);
    expect(
        buildContinuityLine(3), '3 gündür kendine küçük bir alan açıyorsun.');
    expect(
        nightReflectionPrompt(DateTime(2026, 5, 4, 21)), nightReflectionText);
    expect(
        containsGuiltLanguage(
            '$greeting ${buildContinuityLine(3)} $dailyPresenceText ${microEmotionalHooks.join(" ")}'),
        false);
    expect(morningNotificationCopy, 'Güne nasıl başladığını merak ettim.');
    expect(eveningNotificationCopy, 'Bugünü burada bırakmak ister misin?');
    expect(returningNotificationCopy,
        'Buradayım. Kaldığımız yerden devam edebiliriz.');
  });

  testWidgets('premium screen shows packages and disabled mobile subscription',
      (tester) async {
    final service = PremiumService(
      apiClient: ApiClient(
        tokenStorage: TokenStorage(),
        baseUrl: 'http://localhost:4000',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PremiumScreen(
          current: SubscriptionSnapshot.free(),
          service: service,
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Ücretsiz'), 320);
    expect(find.text('Ücretsiz'), findsOneWidget);
    expect(find.text('Sınırsız sohbet'), findsWidgets);
    await tester.scrollUntilVisible(
        find.text('Mobil abonelik çok yakında'), 520);
    expect(find.text('Mobil abonelik çok yakında'), findsOneWidget);
    expect(find.text(mobileSubscriptionUnavailableMessage), findsOneWidget);
    expect(find.text('Premium’a Devam Et'), findsNothing);
  });

  testWidgets('avatar visual cards render for premium users only',
      (tester) async {
    const profile = UserProfile(email: 'demo@enis.app');
    PremiumAvatarCharacter? savedCharacter;

    await tester.pumpWidget(
      MaterialApp(
        home: AvatarSetupScreen(
          profile: profile,
          subscription: SubscriptionSnapshot.trial(),
          onSaved: (
              {required avatar,
              required avatarName,
              required avatarCharacter}) async {
            savedCharacter = avatarCharacter;
          },
        ),
      ),
    );

    expect(find.text('Avatar karakterini seç'), findsOneWidget);
    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Ses: Sakin'), findsWidgets);

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    final selectButton = find.widgetWithText(GradientButton, 'Karakteri seç');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(selectButton.first);
    await tester.pump();

    expect(savedCharacter?.id, 'ada');
    expect(savedCharacter?.personalityStyle, 'düzenli, net, düşünceli');

    await tester.pumpWidget(
      MaterialApp(
        home: AvatarSetupScreen(
          profile: profile,
          subscription: SubscriptionSnapshot.free(),
          onSaved: (
              {required avatar,
              required avatarName,
              required avatarCharacter}) async {},
        ),
      ),
    );

    expect(find.text('Avatar karakterini seç'), findsNothing);
    expect(find.text('Yanıt tarzını seç'), findsOneWidget);
    expect(find.text('Düzenli'), findsOneWidget);
    expect(find.text('Mira'), findsNothing);
  });

  testWidgets('chat screen shows microphone and speaker controls',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            profile: const UserProfile(email: 'demo@enis.app'),
            subscription: SubscriptionSnapshot.free(),
            messages: const [
              ChatMessage(
                text: 'İçin biraz sıkışmış gibi...',
                author: MessageAuthor.enis,
              ),
            ],
            sending: false,
            onSendMessage: (_) {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip(microphonePermissionRequiredLabel), findsOneWidget);
    expect(find.byTooltip(replayVoiceLabel), findsOneWidget);
    expect(find.text(autoReadVoiceLabel), findsNothing);
  });

  testWidgets('chat screen renders daily retention cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            profile: const UserProfile(email: 'demo@enis.app'),
            subscription: SubscriptionSnapshot.free(),
            messages: const [],
            sending: false,
            showDailyCheckIn: true,
            returningGreeting: fallbackReturningGreeting,
            dailyPresenceMessage: dailyPresenceText,
            emotionalHook: 'Bugün seni en çok ne yordu?',
            continuityLine: '3 gündür kendine küçük bir alan açıyorsun.',
            nightReflectionPrompt: nightReflectionText,
            onDailyCheckInSelected: (_) {},
            onEmotionalHookSelected: () {},
            onNightReflectionSelected: () {},
            onSendMessage: (_) {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.text(dailyCheckInTitle), findsOneWidget);
    expect(find.text('Kaygılıyım'), findsOneWidget);
    expect(find.text(fallbackReturningGreeting), findsOneWidget);
    expect(find.text(dailyPresenceText), findsOneWidget);
    expect(find.text('Bugün seni en çok ne yordu?'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text(nightReflectionText), findsOneWidget);
  });

  testWidgets('premium chat shows automatic voice response controls',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            profile: const UserProfile(email: 'demo@enis.app'),
            subscription: SubscriptionSnapshot.trial(),
            messages: const [
              ChatMessage(
                text: 'Bugün seni biraz yormuş gibi.',
                author: MessageAuthor.enis,
              ),
            ],
            sending: false,
            onSendMessage: (_) {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.text(autoReadVoiceLabel), findsOneWidget);
    expect(find.text(automaticVoiceResponseLabel), findsOneWidget);
    for (final style in voiceStyleOptions) {
      expect(find.text(style), findsOneWidget);
    }
  });

  testWidgets('premium chat header uses selected character continuity',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            profile: const UserProfile(
              email: 'demo@enis.app',
              preferredAvatar: 'friend',
              avatarCharacterId: 'mira',
              avatarCharacterName: 'Mira',
              avatarVoiceStyle: 'sakin',
              avatarVisualStyle: 'kıvırcık saçlı, sıcak bakışlı',
              avatarPersonalityStyle: 'samimi, yumuşak, destekleyici',
            ),
            subscription: SubscriptionSnapshot.trial(),
            messages: const [],
            sending: false,
            onSendMessage: (_) {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.text('Enis • Mira'), findsOneWidget);
    expect(find.text('Samimi eşlikçi'), findsOneWidget);
    expect(find.text('Mira'), findsWidgets);
  });
}
