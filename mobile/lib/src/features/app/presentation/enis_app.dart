import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';
import '../../avatar/presentation/avatar_setup_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _subscription = subscription;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(_apiErrorMessage(error));
    }
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
        _showMessage('API unavailable, mock session started.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_apiErrorMessage(error));
    }
  }

  Future<void> _saveAvatarSetup({required String avatar, required String? avatarName}) async {
    final cleanName = avatarName?.trim();
    final nextProfile = UserProfile(
      id: _profile.id,
      email: _profile.email,
      fullName: _profile.fullName,
      preferredAvatar: avatar,
      avatarName: cleanName == null || cleanName.isEmpty ? null : cleanName,
    );
    final updated = await widget.services.user.updateProfile(nextProfile);
    if (!mounted) return;
    setState(() {
      _profile = updated;
      _stage = AppStage.main;
    });
  }

  Future<void> _sendChatMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(ChatMessage(text: trimmed, author: MessageAuthor.user));
    });

    try {
      final sessionId = _sessionId ?? await widget.services.chat.startSession();
      final response = await widget.services.chat.sendMessage(
        text: trimmed,
        avatar: _profile.preferredAvatar,
        premium: _subscription.premium,
        sessionId: sessionId,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = response.sessionId ?? sessionId;
        _messages.add(
          ChatMessage(
            text: response.response,
            author: MessageAuthor.enis,
            suggestion: response.suggestion.isEmpty ? null : response.suggestion,
            premiumUpsell: response.premiumUpsell,
            tone: response.tone,
            memoryUsed: response.memoryUsed,
            avatarNameUsed: response.avatarNameUsed,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
      MaterialPageRoute(builder: (_) => LegalScreen(service: widget.services.legal)),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      await widget.services.user.deleteAccount();
      await widget.services.auth.logout();
      if (!mounted) return;
      setState(() {
        _profile = const UserProfile(email: 'demo@enis.app');
        _subscription = SubscriptionSnapshot.free();
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
    if (!mounted) return;
    setState(() => _stage = AppStage.onboarding);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          onSaved: _saveAvatarSetup,
        );
      case AppStage.main:
        return MainShell(
          profile: _profile,
          subscription: _subscription,
          messages: _messages,
          sending: _sending,
          onSendMessage: _sendChatMessage,
          onOpenPremium: _openPremium,
          onOpenLegal: _openLegal,
          onOpenAvatarSetup: () => setState(() => _stage = AppStage.avatarSetup),
          onExportData: widget.services.user.exportMyData,
          onDeleteAccount: _deleteAccount,
          onLogout: _logout,
        );
    }
  }
}
