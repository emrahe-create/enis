import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../../profile/domain/subscription_snapshot.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/avatar_option.dart';
import '../domain/chat_models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.profile,
    required this.subscription,
    required this.messages,
    required this.sending,
    required this.onSendMessage,
    required this.onOpenPremium,
  });

  final UserProfile profile;
  final SubscriptionSnapshot subscription;
  final List<ChatMessage> messages;
  final bool sending;
  final ValueChanged<String> onSendMessage;
  final VoidCallback onOpenPremium;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length != widget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSendMessage(text);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = avatarById(widget.profile.preferredAvatar);

    return ScreenScaffold(
      title: 'Enis',
      subtitle: 'Safe space to talk',
      trailing: IconButton.filledTonal(
        onPressed: widget.onOpenPremium,
        icon: const Icon(Icons.workspace_premium_rounded),
        tooltip: 'Premium',
      ),
      child: Column(
        children: [
          _ChatHeader(avatar: avatar, subscription: widget.subscription),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 10),
              itemCount: widget.messages.length + (widget.sending ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index >= widget.messages.length) {
                  return const _TypingBubble();
                }
                final message = widget.messages[index];
                return _MessageBubble(
                  message: message,
                  onOpenPremium: widget.onOpenPremium,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _Composer(controller: _controller, sending: widget.sending, onSend: _send),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.avatar, required this.subscription});

  final AvatarOption avatar;
  final SubscriptionSnapshot subscription;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatar.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(avatar.icon, color: avatar.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(avatar.label, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  subscription.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: EnisColors.deepNavy.withOpacity(0.58),
                      ),
                ),
              ],
            ),
          ),
          if (subscription.trialDaysRemaining != null)
            Text(
              '${subscription.trialDaysRemaining} days',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: EnisColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onOpenPremium});

  final ChatMessage message;
  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    final align = message.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.fromUser ? EnisColors.primaryBlue : EnisColors.white;
    final textColor = message.fromUser ? EnisColors.white : EnisColors.deepNavy;

    return Column(
      crossAxisAlignment: align,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(message.fromUser ? 20 : 6),
                bottomRight: Radius.circular(message.fromUser ? 6 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: EnisColors.deepNavy.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: textColor),
              ),
            ),
          ),
        ),
        if (!message.fromUser && message.suggestion?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          _SuggestionCard(text: message.suggestion!),
        ],
        if (!message.fromUser && message.premiumUpsell?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          _UpgradeCard(onTap: onOpenPremium),
        ],
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: EnisColors.lavender, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: EnisColors.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sohbetini daha derin hale getirmek ister misin?\nPremium ile devam edebilirsin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: EnisColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            '...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: EnisColors.primaryBlue),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(hintText: 'Bir şey yaz… / Say something…'),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: sending ? null : onSend,
          icon: const Icon(Icons.arrow_upward_rounded),
          tooltip: 'Send',
        ),
      ],
    );
  }
}
