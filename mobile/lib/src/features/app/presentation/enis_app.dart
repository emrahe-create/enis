import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';
import '../../avatar/domain/avatar_character.dart';
import '../../avatar/presentation/avatar_setup_screen.dart';
import '../../checkin/data/checkin_service.dart';
import '../../checkin/domain/retention_copy.dart';
import '../../chat/data/chat_service.dart';
import '../../chat/domain/chat_models.dart';
import '../../legal/presentation/legal_screen.dart';
import '../../premium/presentation/premium_screen.dart';
import '../../profile/domain/subscription_snapshot.dart';
import '../../profile/domain/user_profile.dart';
import 'app_services.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'splash_screen.dart';

enum AppStage { splash, onboarding, register, login, avatarSetup, main }

const chatSlowThinkingMessage = 'Biraz düşünüyorum…';
const chatSlowThinkingDelay = Duration(seconds: 6);

class EnisApp extends StatelessWidget {
  const EnisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'enis',
      theme: AppTheme.light(),
      home: EnisRoot(services: AppServices.create()),
    );
  }
}

class EnisRoot extends StatefulWidget {
  const EnisRoot({super.key, required this.services});

  final AppServices services;

  @override
  State<EnisRoot> createState() => _EnisRootState();
}

class _EnisRootState extends State<EnisRoot> {
  AppStage _stage = AppStage.splash;
  UserProfile _profile = const UserProfile(email: 'demo@enis.app');
  SubscriptionSnapshot _subscription = SubscriptionSnapshot.free();
  final List<ChatMessage> _messages = [
    const ChatMessage(
      text: 'Merhaba. İçinden geçenleri sakin bir yerden yazabilirsin.',
      author: MessageAuthor.enis,
      suggestion: 'Başlamak için tek bir cümle yeterli.',
    ),
  ];
  String? _sessionId;
  bool _sending = false;
  DailyCheckInState _dailyCheckInState = DailyCheckInState.empty();
  String? _returningGreeting;
  String? _dailyPresenceMessage;
  String? _emotionalHook;
  String? _continuityLine;
  String? _nightReflectionPrompt;
  Timer? _silenceNudgeTimer;
  Timer? _slowThinkingTimer;
  bool _silenceNudgeShown = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    if (kDebugMode) {
      debugPrint('API_BASE_URL=${widget.services.apiClient.baseUrl}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_checkApiHealth());
      });
    }
  }

  @override
  void dispose() {
    _silenceNudgeTimer?.cancel();
    _slowThinkingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApiHealth() async {
    try {
      await widget.services.apiClient.getJson('/health');
    } catch (error) {
      if (!mounted) return;
      _showMessage('API bağlantı uyarısı: ${_apiErrorMessage(error)}');
    }
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final token = await widget.services.tokenStorage.readToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() => _stage = AppStage.onboarding);
      return;
    }

    setState(() => _stage = AppStage.main);
    unawaited(_refreshSessionData());
  }

  Future<void> _refreshSessionData() async {
    try {
      final fallback = _profile;
      final profile = await widget.services.user.getMe(fallback: fallback);
      final subscription = await widget.services.premium.getSubscription();
      final retention = await _loadRetentionData(subscription);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _subscription = subscription;
        _dailyCheckInState = retention.checkInState;
        _returningGreeting = retention.returningGreeting;
        _dailyPresenceMessage = retention.dailyPresenceMessage;
        _emotionalHook = retention.emotionalHook;
        _continuityLine = retention.continuityLine;
        _nightReflectionPrompt = retention.nightReflectionPrompt;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(_apiErrorMessage(error));
    }
  }

  Future<_RetentionSnapshot> _loadRetentionData(
      SubscriptionSnapshot subscription) async {
    final now = DateTime.now();
    final previousOpenedAt =
        await widget.services.retentionStorage.readLastOpenedAt();
    final lastInteractionAt =
        await widget.services.retentionStorage.readLastInteractionAt();
    final checkInState = await widget.services.checkIns.getToday();
    final memories = subscription.premium
        ? await widget.services.memory.getMemories()
        : <CompanionMemory>[];
    final greeting = buildReturningGreeting(
      lastInteractionAt: lastInteractionAt ?? previousOpenedAt,
      now: now,
      premium: subscription.premium,
      memories: memories,
    );
    final presence = shouldShowDailyPresence(
      lastOpenedAt: previousOpenedAt,
      lastInteractionAt: lastInteractionAt,
      now: now,
      returning: greeting != null,
    )
        ? dailyPresenceText
        : null;
    final hook = presence == null
        ? null
        : microEmotionalHook(
            now: now,
            seed: (lastInteractionAt ?? previousOpenedAt)
                    ?.millisecondsSinceEpoch ??
                0,
          );
    await widget.services.retentionStorage.saveLastOpenedAt(now);

    return _RetentionSnapshot(
      checkInState: checkInState,
      returningGreeting: greeting,
      dailyPresenceMessage: presence,
      emotionalHook: hook,
      continuityLine: checkInState.continuityLine,
      nightReflectionPrompt: nightReflectionPrompt(now),
    );
  }

  Future<void> _handleAuth(AuthResult result) async {
    try {
      final subscription = await widget.services.premium.getSubscription();
      if (!mounted) return;
      setState(() {
        _profile = result.user;
        _subscription = subscription;
        _stage = AppStage.avatarSetup;
      });
      if (result.usedMock) {
        _showMessage('API kullanılamıyor, örnek oturum başlatıldı.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_apiErrorMessage(error));
    }
  }

  Future<void> _saveAvatarSetup(
      {required String avatar,
      required String? avatarName,
      required PremiumAvatarCharacter? avatarCharacter}) async {
    final cleanName = avatarName?.trim();
    final nextProfile = UserProfile(
      id: _profile.id,
      email: _profile.email,
      fullName: _profile.fullName,
      preferredAvatar: avatar,
      avatarName: cleanName == null || cleanName.isEmpty ? null : cleanName,
      avatarCharacterId: avatarCharacter?.id,
      avatarCharacterName: avatarCharacter?.name,
      avatarVoiceStyle: avatarCharacter?.voiceStyle,
      avatarVisualStyle: avatarCharacter?.visualStyle,
      avatarPersonalityStyle: avatarCharacter?.personalityStyle,
    );
    final updated = await widget.services.user.updateProfile(nextProfile);
    if (!mounted) return;
    setState(() {
      _profile = updated;
      _stage = AppStage.main;
    });
    unawaited(_refreshRetentionAfterMain());
  }

  Future<void> _refreshRetentionAfterMain() async {
    try {
      final retention = await _loadRetentionData(_subscription);
      if (!mounted) return;
      setState(() {
        _dailyCheckInState = retention.checkInState;
        _returningGreeting = retention.returningGreeting;
        _dailyPresenceMessage = retention.dailyPresenceMessage;
        _emotionalHook = retention.emotionalHook;
        _continuityLine = retention.continuityLine;
        _nightReflectionPrompt = retention.nightReflectionPrompt;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(_apiErrorMessage(error));
    }
  }

  Future<void> _handleDailyCheckIn(String mood) async {
    _silenceNudgeTimer?.cancel();
    setState(() {
      _dailyCheckInState = DailyCheckInState(
        checkedInToday: true,
        showCard: false,
        checkIn: DailyCheckIn(mood: mood, createdAt: DateTime.now()),
        continuityLine: _continuityLine,
      );
    });

    try {
      final result = await widget.services.checkIns.save(mood: mood);
      if (!mounted) return;
      setState(() {
        _dailyCheckInState = result;
        _continuityLine = result.continuityLine ?? _continuityLine;
      });
      await _sendChatMessage(result.chatContext);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_apiErrorMessage(error));
      await _sendChatMessage(buildDailyCheckInChatContext(mood));
    }
  }

  void _handleNightReflection() {
    final prompt = _nightReflectionPrompt;
    if (prompt == null || prompt.isEmpty) return;
    setState(() => _nightReflectionPrompt = null);
    unawaited(_sendChatMessage(prompt));
  }

  void _handleEmotionalHook() {
    final hook = _emotionalHook;
    if (hook == null || hook.isEmpty) return;
    setState(() {
      _dailyPresenceMessage = null;
      _emotionalHook = null;
    });
    unawaited(_sendChatMessage(hook));
  }

  Future<void> _sendChatMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    final token = await widget.services.tokenStorage.readToken();
    if (kDebugMode) {
      debugPrint(
        'CHAT_API_URL ${widget.services.apiClient.baseUrl}/api/chat/message',
      );
      debugPrint('CHAT_TOKEN_EXISTS ${token?.isNotEmpty == true}');
    }
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _stage = AppStage.login);
      _showMessage('Oturumunu yenilemen gerekiyor.');
      return;
    }

    _silenceNudgeTimer?.cancel();
    _slowThinkingTimer?.cancel();
    unawaited(
      widget.services.retentionStorage.saveLastInteractionAt(DateTime.now()),
    );
    setState(() {
      _sending = true;
      _dailyPresenceMessage = null;
      _emotionalHook = null;
      _messages.add(ChatMessage(text: trimmed, author: MessageAuthor.user));
    });
    _slowThinkingTimer = Timer(chatSlowThinkingDelay, () {
      if (!mounted || !_sending) return;
      final alreadyShown = _messages.any(
        (message) =>
            message.author == MessageAuthor.enis &&
            message.tone == 'thinking' &&
            message.text == chatSlowThinkingMessage,
      );
      if (alreadyShown) return;
      setState(() {
        _messages.add(
          const ChatMessage(
            text: chatSlowThinkingMessage,
            author: MessageAuthor.enis,
            tone: 'thinking',
          ),
        );
      });
    });

    try {
      final response = await widget.services.chat.sendMessage(
        text: trimmed,
        avatar: _profile.preferredAvatar,
        premium: _subscription.premium,
        sessionId: _sessionId,
        avatarCharacterId: _profile.avatarCharacterId,
      );
      if (!mounted) return;
      final usedFallback = response.responseSource == 'fallback';
      setState(() {
        _messages.removeWhere(
          (message) =>
              message.author == MessageAuthor.enis &&
              message.tone == 'thinking' &&
              message.text == chatSlowThinkingMessage,
        );
        _sessionId = response.sessionId ?? _sessionId;
        if (usedFallback) {
          _replaceConnectionFallbackMessage();
        } else {
          _messages.add(
            ChatMessage(
              text: response.response,
              author: MessageAuthor.enis,
              suggestion:
                  response.suggestion.isEmpty ? null : response.suggestion,
              premiumUpsell: response.premiumUpsell,
              tone: response.tone,
              memoryUsed: response.memoryUsed,
              avatarNameUsed: response.avatarNameUsed,
              responseSource: response.responseSource,
            ),
          );
        }
      });
      if (!usedFallback) _scheduleSilenceNudge();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        await widget.services.auth.logout();
        await widget.services.retentionStorage.clear();
        if (!mounted) return;
        setState(() {
          _sending = false;
          _messages.removeWhere(
            (message) =>
                message.author == MessageAuthor.enis &&
                message.tone == 'thinking' &&
                message.text == chatSlowThinkingMessage,
          );
          _stage = AppStage.login;
        });
        _showMessage('Oturumunu yenilemen gerekiyor.');
        return;
      }
      setState(() {
        _messages.removeWhere(
          (message) =>
              message.author == MessageAuthor.enis &&
              message.tone == 'thinking' &&
              message.text == chatSlowThinkingMessage,
        );
        _replaceConnectionFallbackMessage();
      });
    } finally {
      _slowThinkingTimer?.cancel();
      if (mounted) setState(() => _sending = false);
    }
  }

  void _replaceConnectionFallbackMessage() {
    _messages.removeWhere(
      (message) => !message.fromUser && message.isFallback,
    );
    _messages.add(
      const ChatMessage(
        text: chatConnectionUnavailableMessage,
        author: MessageAuthor.enis,
        tone: 'connection-error',
        responseSource: 'fallback',
      ),
    );
  }

  void _scheduleSilenceNudge() {
    final userMessageCount = _messages
        .where((message) => message.author == MessageAuthor.user)
        .length;
    final assistantMessageCount = _messages
        .where((message) => message.author == MessageAuthor.enis)
        .length;

    if (!shouldShowSilenceNudge(
      userMessageCount: userMessageCount,
      assistantMessageCount: assistantMessageCount,
      alreadyShown: _silenceNudgeShown,
    )) {
      return;
    }

    _silenceNudgeTimer?.cancel();
    _silenceNudgeTimer = Timer(silenceNudgeDelay, () {
      if (!mounted || _sending || _silenceNudgeShown) return;
      setState(() {
        _silenceNudgeShown = true;
        _messages.add(
          const ChatMessage(
            text: silenceNudgeText,
            author: MessageAuthor.enis,
            tone: 'sakin',
          ),
        );
      });
    });
  }

  Future<void> _openPremium() async {
    final result = await Navigator.of(context).push<SubscriptionSnapshot>(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          current: _subscription,
          service: widget.services.premium,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _subscription = result);
  }

  Future<void> _openLegal() {
    return Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => LegalScreen(service: widget.services.legal)),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      await widget.services.user.deleteAccount();
      await widget.services.auth.logout();
      await widget.services.retentionStorage.clear();
      if (!mounted) return;
      setState(() {
        _profile = const UserProfile(email: 'demo@enis.app');
        _subscription = SubscriptionSnapshot.free();
        _dailyCheckInState = DailyCheckInState.empty();
        _returningGreeting = null;
        _dailyPresenceMessage = null;
        _emotionalHook = null;
        _continuityLine = null;
        _nightReflectionPrompt = null;
        _silenceNudgeShown = false;
        _messages
          ..clear()
          ..add(
            const ChatMessage(
              text: 'Merhaba. İçinden geçenleri sakin bir yerden yazabilirsin.',
              author: MessageAuthor.enis,
              suggestion: 'Başlamak için tek bir cümle yeterli.',
            ),
          );
        _stage = AppStage.onboarding;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(_apiErrorMessage(error));
    }
  }

  Future<void> _logout() async {
    await widget.services.auth.logout();
    await widget.services.retentionStorage.clear();
    if (!mounted) return;
    setState(() => _stage = AppStage.onboarding);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _apiErrorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case AppStage.splash:
        return const SplashScreen();
      case AppStage.onboarding:
        return OnboardingScreen(
          onStart: () => setState(() => _stage = AppStage.register),
          onWelcomeBack: () => setState(() => _stage = AppStage.login),
        );
      case AppStage.register:
        return RegisterScreen(
          authService: widget.services.auth,
          legalService: widget.services.legal,
          onRegistered: _handleAuth,
          onLoginRequested: () => setState(() => _stage = AppStage.login),
        );
      case AppStage.login:
        return LoginScreen(
          authService: widget.services.auth,
          onLoggedIn: _handleAuth,
          onRegisterRequested: () => setState(() => _stage = AppStage.register),
        );
      case AppStage.avatarSetup:
        return AvatarSetupScreen(
          profile: _profile,
          subscription: _subscription,
          onSaved: _saveAvatarSetup,
        );
      case AppStage.main:
        return MainShell(
          profile: _profile,
          subscription: _subscription,
          messages: _messages,
          sending: _sending,
          showDailyCheckIn: _dailyCheckInState.showCard,
          returningGreeting: _returningGreeting,
          dailyPresenceMessage: _dailyPresenceMessage,
          emotionalHook: _emotionalHook,
          continuityLine: _continuityLine,
          nightReflectionPrompt: _nightReflectionPrompt,
          onDailyCheckInSelected: _handleDailyCheckIn,
          onEmotionalHookSelected: _handleEmotionalHook,
          onNightReflectionSelected: _handleNightReflection,
          onSendMessage: _sendChatMessage,
          onOpenPremium: _openPremium,
          onOpenLegal: _openLegal,
          onOpenAvatarSetup: () =>
              setState(() => _stage = AppStage.avatarSetup),
          onExportData: widget.services.user.exportMyData,
          onDeleteAccount: _deleteAccount,
          onLogout: _logout,
        );
    }
  }
}

class _RetentionSnapshot {
  const _RetentionSnapshot({
    required this.checkInState,
    this.returningGreeting,
    this.dailyPresenceMessage,
    this.emotionalHook,
    this.continuityLine,
    this.nightReflectionPrompt,
  });

  final DailyCheckInState checkInState;
  final String? returningGreeting;
  final String? dailyPresenceMessage;
  final String? emotionalHook;
  final String? continuityLine;
  final String? nightReflectionPrompt;
}
