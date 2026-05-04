import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../../avatar/domain/avatar_character.dart';
import '../../checkin/domain/retention_copy.dart';
import '../../profile/domain/subscription_snapshot.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/avatar_option.dart';
import '../domain/chat_models.dart';

const voiceListeningLabel = 'Seni dinliyorum...';
const microphonePermissionRequiredLabel = 'Mikrofon izni gerekiyor';
const microphonePermissionDeniedMessage =
    'Mikrofon izni olmadan sesli sohbet kullanılamaz.';
const speechRecognitionFailedMessage =
    'Seni net duyamadım, tekrar deneyebilir misin?';
const ttsFailedMessage = 'Sesli yanıt şu anda çalışmadı.';
const voiceResponseLabel = 'Sesli yanıt';
const replayVoiceLabel = 'Tekrar dinle';
const stopVoiceLabel = 'Durdur';
const autoReadVoiceLabel = 'Enis cevapları sesli okusun';
const automaticVoiceResponseLabel = 'Otomatik sesli yanıt';
const voiceStyleOptions = ['Sakin', 'Samimi', 'Enerjik'];
const voiceThinkingLabel = 'Enis düşünüyor...';
const voiceThinkingDelayMinMs = 300;
const voiceThinkingDelayMaxMs = 600;
const voiceSentencePause = Duration(milliseconds: 200);
const voiceSilenceAutoSendDelay = Duration(milliseconds: 500);

List<String> voiceResponseSegments(String text, {int maxLength = 140}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return const [];

  final sentences = <String>[];
  final buffer = StringBuffer();

  for (var index = 0; index < normalized.length; index += 1) {
    final char = normalized[index];
    buffer.write(char);

    final nextIsBoundary =
        index == normalized.length - 1 || normalized[index + 1] == ' ';
    if ('.!?…'.contains(char) && nextIsBoundary) {
      final sentence = buffer.toString().trim();
      if (sentence.isNotEmpty) sentences.add(sentence);
      buffer.clear();
    }
  }

  final remaining = buffer.toString().trim();
  if (remaining.isNotEmpty) sentences.add(remaining);

  return sentences
      .expand((sentence) => _softBreakVoiceSentence(sentence, maxLength))
      .toList(growable: false);
}

List<String> _softBreakVoiceSentence(String sentence, int maxLength) {
  var rest = sentence.trim();
  final parts = <String>[];

  while (rest.length > maxLength) {
    final breakAt = _findNaturalVoiceBreak(rest, maxLength);
    if (breakAt <= 0) break;

    final part = rest.substring(0, breakAt).trim();
    if (part.isNotEmpty) parts.add(part);
    rest = rest.substring(breakAt).trim();
  }

  if (rest.isNotEmpty) parts.add(rest);
  return parts;
}

int _findNaturalVoiceBreak(String text, int maxLength) {
  final preferredBreaks = [', ', '; ', ': ', ' ama ', ' çünkü ', ' ve '];
  final minimumBreak = min(48, maxLength ~/ 2);
  var best = -1;

  for (final separator in preferredBreaks) {
    final index = text.lastIndexOf(separator, maxLength);
    if (index > minimumBreak && index > best) {
      best = index + separator.trimRight().length;
    }
  }

  if (best > 0) return best;

  final space = text.lastIndexOf(' ', maxLength);
  return space > minimumBreak ? space : -1;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.profile,
    required this.subscription,
    required this.messages,
    required this.sending,
    required this.onSendMessage,
    required this.onOpenPremium,
    this.showDailyCheckIn = false,
    this.returningGreeting,
    this.dailyPresenceMessage,
    this.emotionalHook,
    this.continuityLine,
    this.nightReflectionPrompt,
    this.onDailyCheckInSelected,
    this.onEmotionalHookSelected,
    this.onNightReflectionSelected,
  });

  final UserProfile profile;
  final SubscriptionSnapshot subscription;
  final List<ChatMessage> messages;
  final bool sending;
  final ValueChanged<String> onSendMessage;
  final VoidCallback onOpenPremium;
  final bool showDailyCheckIn;
  final String? returningGreeting;
  final String? dailyPresenceMessage;
  final String? emotionalHook;
  final String? continuityLine;
  final String? nightReflectionPrompt;
  final ValueChanged<String>? onDailyCheckInSelected;
  final VoidCallback? onEmotionalHookSelected;
  final VoidCallback? onNightReflectionSelected;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = speech.SpeechToText();
  final _tts = FlutterTts();
  final _voiceRandom = Random();
  bool _listening = false;
  bool _speechReady = false;
  bool _autoSendVoice = false;
  bool _autoSendDispatched = false;
  bool _autoReadResponses = false;
  bool _ttsTouched = false;
  bool _voiceSequenceActive = false;
  late String _voiceStyle;
  String _liveTranscript = '';
  String? _speakingText;
  String? _thinkingText;
  int _lastAutoReadMessageCount = 0;
  int _voiceRunId = 0;
  Timer? _silenceAutoSendTimer;

  @override
  void initState() {
    super.initState();
    _voiceStyle = voiceOptionLabel(widget.profile.avatarVoiceStyle);
    _lastAutoReadMessageCount = widget.messages.length;
    _tts.setCompletionHandler(_clearSpeakingState);
    _tts.setCancelHandler(_clearSpeakingState);
    _tts.setErrorHandler((_) {
      _clearSpeakingState();
      _showVoiceMessage(ttsFailedMessage);
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.avatarVoiceStyle != widget.profile.avatarVoiceStyle) {
      _voiceStyle = voiceOptionLabel(widget.profile.avatarVoiceStyle);
    }
    if (oldWidget.messages.length != widget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      _maybeReadLatestResponse();
    }
  }

  @override
  void dispose() {
    _voiceRunId += 1;
    _silenceAutoSendTimer?.cancel();
    if (_speechReady) unawaited(_speech.stop());
    if (_ttsTouched) unawaited(_tts.stop());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    _silenceAutoSendTimer?.cancel();
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    if (_liveTranscript.isNotEmpty) {
      setState(() => _liveTranscript = '');
    }
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

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }
    await _startListening(autoSend: true);
  }

  Future<void> _startListening({bool autoSend = false}) async {
    if (widget.sending) return;

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _showVoiceMessage(microphonePermissionDeniedMessage);
      return;
    }

    try {
      final available = _speechReady ||
          await _speech.initialize(
            onError: (_) {
              if (!mounted) return;
              setState(() => _listening = false);
              _showVoiceMessage(speechRecognitionFailedMessage);
            },
            onStatus: _handleSpeechStatus,
          );

      if (!available) {
        _showVoiceMessage(speechRecognitionFailedMessage);
        return;
      }

      _speechReady = true;
      _silenceAutoSendTimer?.cancel();
      setState(() {
        _listening = true;
        _autoSendVoice = autoSend;
        _autoSendDispatched = false;
        _liveTranscript = '';
      });

      await _speech.listen(
        localeId: 'tr_TR',
        listenOptions: speech.SpeechListenOptions(
          partialResults: true,
          listenMode: speech.ListenMode.dictation,
        ),
        onResult: _handleSpeechResult,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _listening = false);
      _showVoiceMessage(speechRecognitionFailedMessage);
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final recognized = result.recognizedWords.trim();
    if (recognized.isEmpty) return;

    _controller
      ..text = recognized
      ..selection = TextSelection.collapsed(offset: recognized.length);
    setState(() => _liveTranscript = recognized);

    if (_autoSendVoice && result.finalResult) {
      _scheduleVoiceAutoSend();
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;
    final stopped = status == 'done' || status == 'notListening';
    if (!stopped) return;

    setState(() => _listening = false);
    if (_autoSendVoice) {
      _scheduleVoiceAutoSend();
    }
  }

  void _scheduleVoiceAutoSend() {
    if (_autoSendDispatched) return;
    _silenceAutoSendTimer?.cancel();
    _silenceAutoSendTimer = Timer(voiceSilenceAutoSendDelay, _sendVoiceResult);
  }

  void _sendVoiceResult() {
    if (_autoSendDispatched) return;
    _autoSendDispatched = true;
    _silenceAutoSendTimer?.cancel();

    final text = _liveTranscript.trim();
    if (text.isEmpty) {
      _showVoiceMessage(speechRecognitionFailedMessage);
      return;
    }
    if (_listening) {
      setState(() => _listening = false);
      if (_speechReady) unawaited(_speech.stop());
    }
    _controller
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _send();
  }

  Future<void> _speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    if (_listening) return;

    try {
      if (_speakingText == cleanText || _thinkingText == cleanText) {
        await _stopVoice();
        return;
      }

      final runId = _voiceRunId + 1;
      _voiceRunId = runId;
      _voiceSequenceActive = false;

      await _configureTts();
      await _tts.stop();
      if (!mounted || runId != _voiceRunId) return;

      setState(() {
        _thinkingText = cleanText;
        _speakingText = cleanText;
      });

      await Future<void>.delayed(_voiceThinkingDelay());
      if (!mounted || runId != _voiceRunId) return;

      setState(() => _thinkingText = null);

      final segments = voiceResponseSegments(cleanText);
      _voiceSequenceActive = true;
      for (var index = 0; index < segments.length; index += 1) {
        if (!mounted || runId != _voiceRunId) return;

        final result = await _tts.speak(segments[index]);
        if (!mounted || runId != _voiceRunId) return;
        if (result == 0 || result == false) {
          throw StateError('TTS speak failed');
        }

        if (index < segments.length - 1) {
          await Future<void>.delayed(voiceSentencePause);
        }
      }

      _voiceSequenceActive = false;
      if (mounted && runId == _voiceRunId) {
        setState(() => _speakingText = null);
      }
    } catch (_) {
      _voiceSequenceActive = false;
      if (!mounted) return;
      setState(() {
        _thinkingText = null;
        _speakingText = null;
      });
      _showVoiceMessage(ttsFailedMessage);
    }
  }

  Future<void> _stopVoice() async {
    _voiceRunId += 1;
    _voiceSequenceActive = false;
    if (mounted) {
      setState(() {
        _thinkingText = null;
        _speakingText = null;
      });
    }
    await _tts.stop();
  }

  Future<void> _configureTts() async {
    _ttsTouched = true;
    final style = widget.subscription.premium ? _voiceStyle : 'Sakin';
    final rate = switch (style) {
      'Samimi' => 0.46,
      'Enerjik' => 0.52,
      _ => 0.40,
    };
    final pitch = switch (style) {
      'Enerjik' => 1.05,
      _ => 1.0,
    };

    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.awaitSpeakCompletion(true);
  }

  Duration _voiceThinkingDelay() {
    final extra = _voiceRandom
        .nextInt(voiceThinkingDelayMaxMs - voiceThinkingDelayMinMs + 1);
    return Duration(milliseconds: voiceThinkingDelayMinMs + extra);
  }

  void _maybeReadLatestResponse() {
    if (!_autoReadResponses || !widget.subscription.premium) return;
    if (_listening) return;
    if (widget.messages.length <= _lastAutoReadMessageCount) return;

    final latest = widget.messages.last;
    _lastAutoReadMessageCount = widget.messages.length;
    if (latest.fromUser) return;
    if (latest.tone == 'thinking') return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speak(latest.text));
    });
  }

  void _clearSpeakingState() {
    if (!mounted) return;
    if (_voiceSequenceActive) return;
    setState(() {
      _thinkingText = null;
      _speakingText = null;
    });
  }

  void _showVoiceMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final avatar = avatarById(widget.profile.preferredAvatar);
    final character = widget.subscription.premium
        ? selectedAvatarCharacter(widget.profile.avatarCharacterId)
        : null;
    final promptCards = <Widget>[
      if (widget.returningGreeting?.isNotEmpty == true ||
          widget.continuityLine?.isNotEmpty == true)
        _RetentionGreetingCard(
          greeting: widget.returningGreeting,
          continuityLine: widget.continuityLine,
          voiceEnabled: widget.subscription.premium,
          onSpeak: widget.subscription.premium
              ? (text) => unawaited(_speak(text))
              : null,
        ),
      if (widget.dailyPresenceMessage?.isNotEmpty == true)
        _PresenceCard(
          message: widget.dailyPresenceMessage!,
          hook: widget.emotionalHook,
          onHookTap: widget.onEmotionalHookSelected,
        ),
      if (widget.showDailyCheckIn)
        _DailyCheckInCard(onSelected: widget.onDailyCheckInSelected),
      if (widget.nightReflectionPrompt?.isNotEmpty == true)
        _NightReflectionCard(
          text: widget.nightReflectionPrompt!,
          onTap: widget.onNightReflectionSelected,
        ),
    ];

    return ScreenScaffold(
      title: character == null ? 'Enis' : 'Enis • ${character.name}',
      subtitle: character == null
          ? 'Konuşmak için güvenli alan'
          : character.companionLabel,
      trailing: IconButton.filledTonal(
        onPressed: widget.onOpenPremium,
        icon: const Icon(Icons.workspace_premium_rounded),
        tooltip: 'Premium',
      ),
      child: Column(
        children: [
          _ChatHeader(
            avatar: avatar,
            subscription: widget.subscription,
            character: character,
          ),
          if (widget.subscription.premium) ...[
            const SizedBox(height: 10),
            _VoiceSettingsCard(
              autoRead: _autoReadResponses,
              voiceStyle: _voiceStyle,
              onAutoReadChanged: (value) {
                setState(() {
                  _autoReadResponses = value;
                  _lastAutoReadMessageCount = widget.messages.length;
                });
              },
              onVoiceStyleChanged: (value) =>
                  setState(() => _voiceStyle = value),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 10),
              itemCount: promptCards.length +
                  widget.messages.length +
                  (widget.sending ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index < promptCards.length) {
                  return promptCards[index];
                }

                final messageIndex = index - promptCards.length;
                if (messageIndex >= widget.messages.length) {
                  return const _TypingBubble();
                }
                final message = widget.messages[messageIndex];
                return _MessageBubble(
                  message: message,
                  onOpenPremium: widget.onOpenPremium,
                  onSpeak: (text) => unawaited(_speak(text)),
                  speakingText: _speakingText,
                  thinkingText: _thinkingText,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _Composer(
            controller: _controller,
            sending: widget.sending,
            listening: _listening,
            liveTranscript: _liveTranscript,
            onSend: _send,
            onMicPressed: _toggleListening,
            onMicLongPress: () => _startListening(autoSend: true),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.avatar,
    required this.subscription,
    required this.character,
  });

  final AvatarOption avatar;
  final SubscriptionSnapshot subscription;
  final PremiumAvatarCharacter? character;

  @override
  Widget build(BuildContext context) {
    final title = character?.name ?? avatar.label;
    final subtitle = character == null
        ? subscription.label
        : '${character!.personalityStyle} • ses: ${character!.voiceStyle}';
    final color = character?.color ?? avatar.color;

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(character?.icon ?? avatar.icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: EnisColors.deepNavy.withValues(alpha: 0.58),
                      ),
                ),
              ],
            ),
          ),
          if (subscription.trialDaysRemaining != null)
            Text(
              '${subscription.trialDaysRemaining} gün',
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

class _VoiceSettingsCard extends StatelessWidget {
  const _VoiceSettingsCard({
    required this.autoRead,
    required this.voiceStyle,
    required this.onAutoReadChanged,
    required this.onVoiceStyleChanged,
  });

  final bool autoRead;
  final String voiceStyle;
  final ValueChanged<bool> onAutoReadChanged;
  final ValueChanged<String> onVoiceStyleChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: autoRead,
            onChanged: onAutoReadChanged,
            secondary: const Icon(Icons.volume_up_rounded,
                color: EnisColors.primaryBlue),
            title: Text(
              autoReadVoiceLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(automaticVoiceResponseLabel,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: voiceStyleOptions.map((style) {
              final selected = style == voiceStyle;
              return ChoiceChip(
                label: Text(style),
                selected: selected,
                onSelected: (_) => onVoiceStyleChanged(style),
                selectedColor: EnisColors.primaryBlue.withValues(alpha: 0.14),
                labelStyle: TextStyle(
                  color: selected
                      ? EnisColors.primaryBlue
                      : EnisColors.deepNavy.withValues(alpha: 0.7),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RetentionGreetingCard extends StatelessWidget {
  const _RetentionGreetingCard({
    required this.greeting,
    required this.continuityLine,
    required this.voiceEnabled,
    required this.onSpeak,
  });

  final String? greeting;
  final String? continuityLine;
  final bool voiceEnabled;
  final ValueChanged<String>? onSpeak;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: EnisColors.lavender, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (greeting?.isNotEmpty == true)
                  Text(
                    greeting!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                if (continuityLine?.isNotEmpty == true) ...[
                  if (greeting?.isNotEmpty == true) const SizedBox(height: 6),
                  Text(
                    continuityLine!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: EnisColors.deepNavy.withValues(alpha: 0.62),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (voiceEnabled && greeting?.isNotEmpty == true)
            IconButton(
              tooltip: voiceResponseLabel,
              icon: const Icon(Icons.volume_up_rounded),
              color: EnisColors.primaryBlue,
              onPressed: () {
                final text = [
                  if (greeting?.isNotEmpty == true) greeting!,
                  if (continuityLine?.isNotEmpty == true) continuityLine!,
                ].join(' ');
                onSpeak?.call(text);
              },
            ),
        ],
      ),
    );
  }
}

class _PresenceCard extends StatelessWidget {
  const _PresenceCard({
    required this.message,
    required this.hook,
    required this.onHookTap,
  });

  final String message;
  final String? hook;
  final VoidCallback? onHookTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_border_rounded,
              color: EnisColors.primaryBlue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (hook?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  ActionChip(
                    label: Text(hook!),
                    avatar:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    onPressed: onHookTap,
                    side: BorderSide(
                      color: EnisColors.primaryBlue.withValues(alpha: 0.14),
                    ),
                    backgroundColor:
                        EnisColors.primaryBlue.withValues(alpha: 0.06),
                    labelStyle: const TextStyle(
                      color: EnisColors.deepNavy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCheckInCard extends StatelessWidget {
  const _DailyCheckInCard({required this.onSelected});

  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dailyCheckInTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dailyCheckInOptions.map((option) {
              return ActionChip(
                label: Text(option),
                avatar: const Icon(Icons.circle_rounded, size: 10),
                onPressed:
                    onSelected == null ? null : () => onSelected!(option),
                side: BorderSide(
                  color: EnisColors.primaryBlue.withValues(alpha: 0.14),
                ),
                backgroundColor: EnisColors.primaryBlue.withValues(alpha: 0.06),
                labelStyle: const TextStyle(
                  color: EnisColors.deepNavy,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NightReflectionCard extends StatelessWidget {
  const _NightReflectionCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.nights_stay_rounded,
              color: EnisColors.softPurple, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onOpenPremium,
    required this.onSpeak,
    required this.speakingText,
    required this.thinkingText,
  });

  final ChatMessage message;
  final VoidCallback onOpenPremium;
  final ValueChanged<String> onSpeak;
  final String? speakingText;
  final String? thinkingText;

  @override
  Widget build(BuildContext context) {
    final align =
        message.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor =
        message.fromUser ? EnisColors.primaryBlue : EnisColors.white;
    final textColor = message.fromUser ? EnisColors.white : EnisColors.deepNavy;
    final isSpeaking = speakingText == message.text;
    final isThinking = thinkingText == message.text;

    return Column(
      crossAxisAlignment: align,
      children: [
        ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
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
                  color: EnisColors.deepNavy.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: message.fromUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: textColor),
                  ),
                  if (!message.fromUser) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isThinking) ...[
                            Text(
                              voiceThinkingLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: EnisColors.primaryBlue
                                        .withValues(alpha: 0.82),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Semantics(
                            label: voiceResponseLabel,
                            button: true,
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => onSpeak(message.text),
                              icon: Icon(
                                isThinking
                                    ? Icons.more_horiz_rounded
                                    : isSpeaking
                                        ? Icons.stop_circle_outlined
                                        : Icons.volume_up_outlined,
                                size: 20,
                              ),
                              color: EnisColors.primaryBlue,
                              tooltip: isThinking
                                  ? voiceThinkingLabel
                                  : isSpeaking
                                      ? stopVoiceLabel
                                      : replayVoiceLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded,
                color: EnisColors.lavender, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child:
                    Text(text, style: Theme.of(context).textTheme.bodyMedium)),
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
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: EnisColors.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sohbetini daha derin hale getirmek ister misin?\nPremium ile devam edebilirsin.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: EnisColors.primaryBlue),
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
    required this.listening,
    required this.liveTranscript,
    required this.onSend,
    required this.onMicPressed,
    required this.onMicLongPress,
  });

  final TextEditingController controller;
  final bool sending;
  final bool listening;
  final String liveTranscript;
  final VoidCallback onSend;
  final VoidCallback onMicPressed;
  final VoidCallback onMicLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (listening) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: EnisColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: EnisColors.primaryBlue.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: EnisColors.primaryBlue.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _ListeningWave(),
                    const SizedBox(width: 10),
                    Text(
                      voiceListeningLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: EnisColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                if (liveTranscript.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    liveTranscript,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: EnisColors.deepNavy.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Bir şey yaz…'),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPress: sending ? null : onMicLongPress,
              child: IconButton.filledTonal(
                onPressed: sending ? null : onMicPressed,
                icon: Icon(
                    listening ? Icons.stop_rounded : Icons.mic_none_rounded),
                tooltip: listening
                    ? stopVoiceLabel
                    : microphonePermissionRequiredLabel,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.arrow_upward_rounded),
              tooltip: 'Gönder',
            ),
          ],
        ),
      ],
    );
  }
}

class _ListeningWave extends StatefulWidget {
  const _ListeningWave();

  @override
  State<_ListeningWave> createState() => _ListeningWaveState();
}

class _ListeningWaveState extends State<_ListeningWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 32,
          height: 22,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(5, (index) {
              final wave = sin((_controller.value + index * 0.16) * pi * 2);
              final height = 7 + ((wave + 1) / 2) * 13;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: EnisColors.primaryBlue.withValues(
                    alpha: 0.42 + ((wave + 1) / 2) * 0.42,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
