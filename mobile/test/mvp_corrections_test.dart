import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('token storage uses a web-safe fallback and reads immediately',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = TokenStorage(preferences: SharedPreferences.getInstance());

    await storage.saveToken('jwt-for-web');

    expect(await storage.readToken(), 'jwt-for-web');
  });

  test('chat request uses production endpoint and bearer token', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = TokenStorage(preferences: SharedPreferences.getInstance());
    await storage.saveToken('prod-token');

    late http.Request captured;
    final apiClient = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'response':
                'Kaygı biraz göğsüne oturmuş gibi… buradayım. Bugün bunu en çok ne tetikledi?',
            'tone': 'sakin',
            'suggestion': '',
            'memoryUsed': false,
            'avatarNameUsed': false,
            'responseSource': 'openai',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final chat = ChatService(apiClient: apiClient);

    await chat.sendMessage(
      text: 'Bugün kaygılıyım',
      avatar: 'warm',
      premium: false,
      avatarCharacterId: 'mira',
    );

    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'https://api.enisapp.com/api/chat/message',
    );
    expect(captured.headers['Authorization'], 'Bearer prod-token');
    expect(captured.headers['Content-Type'], 'application/json');
    expect(jsonDecode(captured.body)['avatarCharacterId'], 'mira');
  });

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
    final eren = avatarCharacterById('eren');
    final arda = avatarCharacterById('arda');
    final kerem = avatarCharacterById('kerem');
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
    expect(mira.shortDescription, 'Kıvırcık saçlı, sıcak bakışlı.');
    expect(mira.visualDescription, 'kıvırcık saçlı, sıcak bakışlı');
    expect(mira.companionLabel, 'Samimi eşlikçi');
    expect(voiceOptionLabel(mira.voiceStyle), 'Sakin');
    expect(mira.premiumOnly, true);
    expect(mira.assetIdle, 'assets/avatars/mira/idle.png');
    expect(mira.assetListening, 'assets/avatars/mira/listening.png');
    expect(mira.assetThinking, 'assets/avatars/mira/thinking.png');
    expect(mira.assetSpeaking, 'assets/avatars/mira/speaking.png');
    expect(mira.assetComforting, 'assets/avatars/mira/comforting.png');
    expect(premiumAvatarCharacters.map((character) => character.id), [
      'mira',
      'eren',
      'lina',
      'deniz',
      'arda',
      'ada',
      'kerem',
    ]);
    expect(eren.shortDescription, contains('arkadaş gibi'));
    expect(eren.visualDescription, contains('erkek'));
    expect(arda.personalityStyle, 'sakin, ayakları yere basan, güven veren');
    expect(arda.voiceStyle, 'sakin');
    expect(kerem.voiceStyle, 'enerjik');
    expect(profile.avatarCharacterId, 'mira');
    expect(profile.toPatchJson()['avatarCharacterName'], 'Mira');
    expect(catalogText.contains('terapist'), false);
    expect(catalogText.contains('doktor'), false);
    expect(catalogText.contains('psikolog'), false);
    expect(catalogText.contains('uzman'), false);
    expect(catalogText.contains('agresif'), false);
    expect(catalogText.contains('baskın'), false);
  });

  test('avatar character assets are defined for all presence states', () {
    for (final character in premiumAvatarCharacters) {
      expect(character.premiumOnly, true);
      expect(character.assetIdle, 'assets/avatars/${character.id}/idle.png');
      expect(
        character.assetListening,
        'assets/avatars/${character.id}/listening.png',
      );
      expect(
        character.assetThinking,
        'assets/avatars/${character.id}/thinking.png',
      );
      expect(
        character.assetSpeaking,
        'assets/avatars/${character.id}/speaking.png',
      );
      expect(
        character.assetComforting,
        'assets/avatars/${character.id}/comforting.png',
      );
      expect(
        getAvatarAsset(character, AvatarState.idle),
        character.assetIdle,
      );
      expect(
        getAvatarAsset(character, AvatarState.listening),
        character.assetIdle,
      );
      expect(
        getAvatarAsset(character, AvatarState.thinking),
        character.assetIdle,
      );
      expect(
        getAvatarAsset(character, AvatarState.speaking),
        character.assetIdle,
      );
      expect(
        getAvatarAsset(character, AvatarState.comforting),
        character.assetIdle,
      );
      expect(
        getAvatarAsset(character, AvatarState.error),
        character.assetIdle,
      );
    }
  });

  test('premium avatar idle portraits are lightweight when available', () {
    for (final character in premiumAvatarCharacters) {
      final directFile = File(character.assetIdle);
      final workspaceFile = File('mobile/${character.assetIdle}');
      final assetFile = directFile.existsSync() ? directFile : workspaceFile;

      if (assetFile.existsSync()) {
        expect(assetFile.lengthSync(), lessThan(200 * 1024));
      }
    }
  });

  test('chat fallback does not expose static English responses', () {
    expect(
      chatFallbackUnavailableMessage,
      'Şu anda bağlantıda zorlandım. Birazdan tekrar deneyelim mi?',
    );
    expect(chatFallbackUnavailableMessage.contains('It seems'), false);
    expect(chatFallbackUnavailableMessage.contains('This sounds'), false);

    final response = ChatResponse.fromJson({
      'response': chatFallbackUnavailableMessage,
      'tone': 'temporary-unavailable',
      'suggestion': 'Bağlantı düzelince aynı mesajı tekrar deneyebilirsin.',
      'memoryUsed': false,
      'avatarNameUsed': false,
      'responseSource': 'fallback',
    });
    expect(response.responseSource, 'fallback');
  });

  test('voice conversation copy is Turkish-first', () {
    expect(voiceListeningLabel, 'Seni dinliyorum...');
    expect(companionListeningStatusLabel, 'Seni dinliyorum...');
    expect(companionThinkingStatusLabel, 'Biraz düşünüyorum...');
    expect(companionSpeakingStatusLabel, 'Konuşuyorum...');
    expect(companionIdleStatusLabel, 'Buradayım.');
    expect(companionComfortingStatusLabel, 'Yanındayım.');
    expect(
      companionErrorStatusLabel,
      'Biraz zorlandım, tekrar deneyelim mi?',
    );
    expect(microphonePermissionRequiredLabel, 'Mikrofon izni gerekiyor');
    expect(voiceResponseLabel, 'Sesli yanıt');
    expect(replayVoiceLabel, 'Tekrar dinle');
    expect(stopVoiceLabel, 'Durdur');
    expect(voiceThinkingLabel, 'Enis düşünüyor...');
    expect(voiceStyleOptions, containsAll(['Sakin', 'Samimi', 'Enerjik']));
    expect(voiceSpeedLabel, 'Ses hızı');
    expect(voiceSpeedOptions, ['Yavaş', 'Normal', 'Hızlı']);
    expect(voiceBaseRateForStyle('Sakin'), 0.50);
    expect(voiceBaseRateForStyle('Samimi'), 0.56);
    expect(voiceBaseRateForStyle('Enerjik'), 0.62);
    expect(voicePitchForStyle('Sakin'), 0.96);
    expect(voicePitchForStyle('Samimi'), 1.0);
    expect(voicePitchForStyle('Enerjik'), 1.05);
    expect(voiceRateFor(style: 'Sakin', speed: 'Normal'), 0.50);
    expect(voiceThinkingDelayMinMs, 300);
    expect(voiceThinkingDelayMaxMs, 600);
    expect(voiceSilenceAutoSendDelay.inMilliseconds, 500);
    expect(avatarResponseStateHold.inMilliseconds, greaterThanOrEqualTo(800));
  });

  test('avatar state machine reacts to chat and voice states', () {
    expect(
      resolveAvatarState(
        listening: true,
        waiting: false,
        speaking: false,
      ),
      AvatarState.listening,
    );
    expect(
      resolveAvatarState(
        listening: false,
        waiting: true,
        speaking: false,
      ),
      AvatarState.thinking,
    );
    expect(
      resolveAvatarState(
        listening: false,
        waiting: false,
        speaking: true,
      ),
      AvatarState.speaking,
    );
    expect(
      resolveAvatarState(
        listening: false,
        waiting: false,
        speaking: false,
        latestUserText: 'Bugün normal geçti',
      ),
      AvatarState.idle,
    );
    expect(
      resolveAvatarState(
        listening: false,
        waiting: true,
        speaking: false,
        latestUserText: 'Kendime zarar vermek istiyorum',
      ),
      AvatarState.comforting,
    );
    expect(
      resolveAvatarState(
        listening: false,
        waiting: false,
        speaking: false,
        latestUserText: 'Çok yorgunum ve moralim bozuk',
      ),
      AvatarState.comforting,
    );
    expect(
      resolveAvatarState(
        listening: false,
        waiting: false,
        speaking: false,
        latestUserText: 'Bugün çok kaygılıyım',
      ),
      AvatarState.listening,
    );
    expect(
      resolveAvatarState(
        listening: false,
        waiting: false,
        speaking: false,
        latestMessage: const ChatMessage(
          text: chatFallbackUnavailableMessage,
          author: MessageAuthor.enis,
          responseSource: 'fallback',
        ),
      ),
      AvatarState.error,
    );
    for (final text in [
      'Bugün çok kötü hissediyorum',
      'Çok üzgünüm',
      'Yalnız kaldım',
      'İçim sıkışık',
      'Ağlamak istiyorum',
      'Yoruldum',
      'Kaygılıyım',
    ]) {
      expect(shouldUseComfortingAvatarState(text), true);
    }
    expect(companionSpeakingWaveDuration(20).inMilliseconds, 900);
    expect(companionSpeakingWaveDuration(120).inMilliseconds, 3500);
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
    expect(find.text('Karakterini seç'), findsOneWidget);
    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('Eren'), findsOneWidget);
    expect(find.text('Arda'), findsOneWidget);
    expect(find.text('Kerem'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Ses: Sakin'), findsWidgets);

    await tester.tap(find.text('Lina'));
    await tester.pumpAndSettle();
    final selectButton = find.widgetWithText(GradientButton, 'Karakteri seç');
    await tester.scrollUntilVisible(
      selectButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(selectButton);
    await tester.pump();

    expect(savedCharacter?.id, 'lina');
    expect(
        savedCharacter?.personalityStyle, 'canlı, destekleyici, baskıcı değil');

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

    expect(find.byType(CompanionAvatarView), findsOneWidget);
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
    await tester.drag(find.byType(ListView).first, const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(fallbackReturningGreeting), findsOneWidget);
    expect(find.text(dailyPresenceText), findsOneWidget);
    expect(find.text('Bugün seni en çok ne yordu?'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 300));
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
    expect(find.text(voiceSpeedLabel), findsOneWidget);
    for (final style in voiceStyleOptions) {
      expect(find.text(style), findsOneWidget);
    }
    for (final speed in voiceSpeedOptions) {
      expect(find.text(speed), findsOneWidget);
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
    expect(find.byType(CompanionAvatarView), findsOneWidget);
    expect(find.text(companionIdleStatusLabel), findsOneWidget);
    expect(find.text('Mira'), findsWidgets);
  });

  testWidgets('fallback chat response is shown as a clean connection state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            profile: const UserProfile(email: 'demo@enis.app'),
            subscription: SubscriptionSnapshot.free(),
            messages: const [
              ChatMessage(
                text: chatFallbackUnavailableMessage,
                author: MessageAuthor.enis,
                tone: 'temporary-unavailable',
                responseSource: 'fallback',
              ),
            ],
            sending: false,
            onSendMessage: (_) {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.text('Geçici bağlantı yanıtı'), findsNothing);
    expect(find.text(chatFallbackUnavailableMessage), findsOneWidget);
    expect(find.text(companionErrorStatusLabel), findsOneWidget);
    expect(find.byTooltip(replayVoiceLabel), findsNothing);
  });

  testWidgets('avatar shows thinking state while chat request is pending',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            profile: const UserProfile(email: 'demo@enis.app'),
            subscription: SubscriptionSnapshot.free(),
            messages: const [
              ChatMessage(
                  text: 'Bugün biraz karışığım', author: MessageAuthor.user),
            ],
            sending: true,
            onSendMessage: (_) {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.text(companionThinkingStatusLabel), findsOneWidget);
  });

  testWidgets('safety response uses comforting avatar state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            profile: const UserProfile(email: 'demo@enis.app'),
            subscription: SubscriptionSnapshot.free(),
            messages: const [
              ChatMessage(
                text: 'Bunu tek başına taşımak zorunda değilsin.',
                author: MessageAuthor.enis,
                tone: 'safety-focused',
                responseSource: 'safety',
              ),
            ],
            sending: false,
            onSendMessage: (_) {},
            onOpenPremium: () {},
          ),
        ),
      ),
    );

    expect(find.text(companionComfortingStatusLabel), findsOneWidget);
  });

  testWidgets('emotional response arrival holds comforting state',
      (tester) async {
    Widget buildChat({
      required bool sending,
      required List<ChatMessage> messages,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            profile: const UserProfile(email: 'demo@enis.app'),
            subscription: SubscriptionSnapshot.free(),
            messages: messages,
            sending: sending,
            onSendMessage: (_) {},
            onOpenPremium: () {},
          ),
        ),
      );
    }

    const userMessage = ChatMessage(
      text: 'Bugün çok kötü ve yalnız hissediyorum',
      author: MessageAuthor.user,
    );

    await tester.pumpWidget(
      buildChat(
        sending: true,
        messages: const [userMessage],
      ),
    );
    expect(find.text(companionThinkingStatusLabel), findsOneWidget);

    await tester.pumpWidget(
      buildChat(
        sending: false,
        messages: const [
          userMessage,
          ChatMessage(
            text: 'Bunun içinde yalnız kalmış gibi hissediyorsun.',
            author: MessageAuthor.enis,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text(companionComfortingStatusLabel), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(companionComfortingStatusLabel), findsOneWidget);
  });
}
