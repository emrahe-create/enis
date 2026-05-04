import 'package:flutter/material.dart';

import '../../../core/widgets/gradient_button.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../explore/presentation/explore_screen.dart';
import '../../journal/presentation/journal_screen.dart';
import '../../profile/domain/subscription_snapshot.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.profile,
    required this.subscription,
    required this.messages,
    required this.sending,
    required this.showDailyCheckIn,
    required this.onDailyCheckInSelected,
    required this.onSendMessage,
    required this.onOpenPremium,
    required this.onOpenLegal,
    required this.onOpenAvatarSetup,
    required this.onExportData,
    required this.onDeleteAccount,
    required this.onLogout,
    this.returningGreeting,
    this.dailyPresenceMessage,
    this.emotionalHook,
    this.continuityLine,
    this.nightReflectionPrompt,
    this.onEmotionalHookSelected,
    this.onNightReflectionSelected,
  });

  final UserProfile profile;
  final SubscriptionSnapshot subscription;
  final List<ChatMessage> messages;
  final bool sending;
  final bool showDailyCheckIn;
  final ValueChanged<String> onDailyCheckInSelected;
  final ValueChanged<String> onSendMessage;
  final VoidCallback onOpenPremium;
  final VoidCallback onOpenLegal;
  final VoidCallback onOpenAvatarSetup;
  final Future<Map<String, dynamic>> Function() onExportData;
  final Future<void> Function() onDeleteAccount;
  final Future<void> Function() onLogout;
  final String? returningGreeting;
  final String? dailyPresenceMessage;
  final String? emotionalHook;
  final String? continuityLine;
  final String? nightReflectionPrompt;
  final VoidCallback? onEmotionalHookSelected;
  final VoidCallback? onNightReflectionSelected;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ChatScreen(
        profile: widget.profile,
        subscription: widget.subscription,
        messages: widget.messages,
        sending: widget.sending,
        showDailyCheckIn: widget.showDailyCheckIn,
        returningGreeting: widget.returningGreeting,
        dailyPresenceMessage: widget.dailyPresenceMessage,
        emotionalHook: widget.emotionalHook,
        continuityLine: widget.continuityLine,
        nightReflectionPrompt: widget.nightReflectionPrompt,
        onDailyCheckInSelected: widget.onDailyCheckInSelected,
        onEmotionalHookSelected: widget.onEmotionalHookSelected,
        onNightReflectionSelected: widget.onNightReflectionSelected,
        onSendMessage: widget.onSendMessage,
        onOpenPremium: widget.onOpenPremium,
      ),
      ExploreScreen(onOpenPremium: widget.onOpenPremium),
      const JournalScreen(),
      ProfileScreen(
        profile: widget.profile,
        subscription: widget.subscription,
        onOpenPremium: widget.onOpenPremium,
        onOpenLegal: widget.onOpenLegal,
        onOpenAvatarSetup: widget.onOpenAvatarSetup,
        onExportData: widget.onExportData,
        onDeleteAccount: widget.onDeleteAccount,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Sohbet',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            selectedIcon: Icon(Icons.article_rounded),
            label: 'Günlük',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: _index == 0 && !widget.subscription.premium
          ? SizedBox(
              width: 148,
              child: GradientButton(
                label: 'Premium',
                icon: Icons.workspace_premium_rounded,
                onPressed: widget.onOpenPremium,
              ),
            )
          : null,
    );
  }
}
