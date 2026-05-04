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
const voiceSpeedLabel = 'Ses hızı';
const voiceSpeedOptions = ['Yavaş', 'Normal', 'Hızlı'];
const voiceThinkingLabel = 'Enis düşünüyor...';
const companionListeningStatusLabel = 'Seni dinliyorum...';
const companionThinkingStatusLabel = 'Biraz düşünüyorum...';
const companionSpeakingStatusLabel = 'Konuşuyorum...';
const companionIdleStatusLabel = 'Buradayım.';
const companionComfortingStatusLabel = 'Yanındayım.';
const companionErrorStatusLabel = 'Biraz zorlandım, tekrar deneyelim mi?';
const voiceThinkingDelayMinMs = 300;
const voiceThinkingDelayMaxMs = 600;
const voiceSentencePause = Duration(milliseconds: 200);
const voiceSilenceAutoSendDelay = Duration(milliseconds: 500);
const avatarResponseStateHold = Duration(milliseconds: 1800);

enum AvatarState {
  idle,
  listening,
  thinking,
  speaking,
  comforting,
  error,
}

enum CompanionMessageSignal { neutral, sadTired, anxious, crisis }

CompanionMessageSignal companionSignalForText(String? text) {
  final normalized = (text ?? '').toLowerCase();
  if (normalized.trim().isEmpty) return CompanionMessageSignal.neutral;
  if (_containsAny(normalized, const [
    'kendime zarar',
    'intihar',
    'ölmek istiyorum',
    'yasamak istemiyorum',
    'yaşamak istemiyorum',
    'suicide',
    'self-harm',
    'hurt myself',
  ])) {
    return CompanionMessageSignal.crisis;
  }
  if (_containsAny(normalized, const [
    'kötü',
    'kotu',
    'üzgün',
    'uzgun',
    'mutsuz',
    'yalnız',
    'yalniz',
    'yorgun',
    'yoruldum',
    'tükendim',
    'tukendim',
    'bitkin',
    'ağır',
    'agir',
    'sıkışık',
    'sikisik',
    'sıkıştı',
    'sikisti',
    'moralim bozuk',
    'içim sıkıştı',
    'icim sikisti',
    'ağlamak',
    'aglamak',
  ])) {
    return CompanionMessageSignal.sadTired;
  }
  if (_containsAny(normalized, const [
    'kaygı',
    'kaygi',
    'kaygılı',
    'kaygili',
    'endişe',
    'endise',
    'gergin',
    'panik',
    'huzursuz',
    'stres',
    'stresli',
    'korku',
    'korkuyorum',
  ])) {
    return CompanionMessageSignal.anxious;
  }
  return CompanionMessageSignal.neutral;
}

bool _containsAny(String text, List<String> needles) {
  return needles.any(text.contains);
}

bool shouldUseComfortingAvatarState(String? text) {
  final signal = companionSignalForText(text);
  return signal == CompanionMessageSignal.crisis ||
      signal == CompanionMessageSignal.sadTired ||
      signal == CompanionMessageSignal.anxious;
}

AvatarState resolveAvatarState({
  required bool listening,
  required bool waiting,
  required bool speaking,
  ChatMessage? latestMessage,
  String? latestUserText,
}) {
  if (listening) return AvatarState.listening;
  if (speaking) return AvatarState.speaking;
  if (latestMessage?.isFallback == true) return AvatarState.error;
  if (latestMessage?.responseSource == 'safety' ||
      latestMessage?.tone == 'safety' ||
      latestMessage?.tone == 'safety-focused') {
    return AvatarState.comforting;
  }

  final signal = companionSignalForText(latestUserText);
  if (signal == CompanionMessageSignal.crisis) {
    return AvatarState.comforting;
  }
  if (waiting) return AvatarState.thinking;
  if (signal == CompanionMessageSignal.sadTired) {
    return AvatarState.comforting;
  }
  if (signal == CompanionMessageSignal.anxious) {
    return AvatarState.listening;
  }
  return AvatarState.idle;
}

Duration companionSpeakingWaveDuration(int textLength) {
  final milliseconds = (textLength * 35).clamp(900, 3500).toInt();
  return Duration(milliseconds: milliseconds);
}

String getAvatarAsset(
  PremiumAvatarCharacter character,
  AvatarState state,
) {
  // The first portrait pack ships one realistic idle image per character.
  // State-specific motion is layered in Flutter until separate assets arrive.
  return switch (state) {
    AvatarState.listening ||
    AvatarState.thinking ||
    AvatarState.speaking ||
    AvatarState.comforting ||
    AvatarState.error =>
      character.assetIdle,
    AvatarState.idle => character.assetIdle,
  };
}

double voiceBaseRateForStyle(String style) {
  return switch (style) {
    'Samimi' => 0.56,
    'Enerjik' => 0.62,
    _ => 0.50,
  };
}

double voicePitchForStyle(String style) {
  return switch (style) {
    'Samimi' => 1.0,
    'Enerjik' => 1.05,
    _ => 0.96,
  };
}

double voiceRateFor({required String style, required String speed}) {
  final multiplier = switch (speed) {
    'Yavaş' => 0.92,
    'Hızlı' => 1.08,
    _ => 1.0,
  };
  return (voiceBaseRateForStyle(style) * multiplier)
      .clamp(0.46, 0.72)
      .toDouble();
}

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
  String _voiceSpeed = 'Normal';
  String _liveTranscript = '';
  String? _speakingText;
  String? _thinkingText;
  String? _lastAutoReadSignature;
  int _voiceRunId = 0;
  int _avatarStateRunId = 0;
  AvatarState _avatarState = AvatarState.idle;
  Timer? _silenceAutoSendTimer;
  Timer? _avatarIdleTimer;

  @override
  void initState() {
    super.initState();
    _voiceStyle = voiceOptionLabel(widget.profile.avatarVoiceStyle);
    _avatarState = _initialAvatarState();
    _lastAutoReadSignature = widget.messages.isEmpty
        ? null
        : _messageSignature(widget.messages.last);
    _tts.setCompletionHandler(_clearSpeakingState);
    _tts.setCancelHandler(_clearSpeakingState);
    _tts.setErrorHandler((_) {
      _clearSpeakingState();
      _setAvatarState(
        AvatarState.error,
        idleAfter: const Duration(milliseconds: 1800),
      );
      _showVoiceMessage(ttsFailedMessage);
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.avatarVoiceStyle != widget.profile.avatarVoiceStyle) {
      _voiceStyle = voiceOptionLabel(widget.profile.avatarVoiceStyle);
    }
    if (!oldWidget.sending && widget.sending) {
      _setAvatarState(AvatarState.thinking);
    }
    final oldLatest =
        oldWidget.messages.isEmpty ? null : oldWidget.messages.last;
    final latest = widget.messages.isEmpty ? null : widget.messages.last;
    final latestChanged =
        _messageSignature(oldLatest) != _messageSignature(latest);
    if (oldWidget.messages.length != widget.messages.length || latestChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      if (latest != null && !latest.fromUser && latest.tone != 'thinking') {
        final nextState = _stateForReceivedMessage(latest);
        _setAvatarState(
          nextState,
          idleAfter:
              nextState == AvatarState.error ? null : avatarResponseStateHold,
        );
      }
      _maybeReadLatestResponse();
    }
    if (oldWidget.sending && !widget.sending) {
      final endedWithoutAssistant =
          latest == null || latest.fromUser || latest.tone == 'thinking';
      if (endedWithoutAssistant) {
        _setAvatarState(
          AvatarState.error,
          idleAfter: const Duration(milliseconds: 2200),
        );
      }
    }
  }

  @override
  void dispose() {
    _voiceRunId += 1;
    _avatarStateRunId += 1;
    _silenceAutoSendTimer?.cancel();
    _avatarIdleTimer?.cancel();
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
    _setAvatarState(AvatarState.thinking);
    widget.onSendMessage(text);
  }

  void _setAvatarState(AvatarState state, {Duration? idleAfter}) {
    _avatarIdleTimer?.cancel();
    _avatarStateRunId += 1;
    final runId = _avatarStateRunId;

    if (mounted && _avatarState != state) {
      setState(() => _avatarState = state);
    }

    if (idleAfter != null) {
      _avatarIdleTimer = Timer(idleAfter, () {
        if (!mounted || runId != _avatarStateRunId) return;
        if (_avatarState == AvatarState.speaking ||
            _avatarState == AvatarState.comforting ||
            _avatarState == AvatarState.thinking ||
            _avatarState == AvatarState.listening) {
          setState(() => _avatarState = AvatarState.idle);
        }
      });
    }
  }

  AvatarState _stateForReceivedMessage(ChatMessage message) {
    if (message.isFallback) return AvatarState.error;
    if (message.responseSource == 'safety' ||
        message.tone == 'safety' ||
        message.tone == 'safety-focused') {
      return AvatarState.comforting;
    }

    if (shouldUseComfortingAvatarState(_latestUserText())) {
      return AvatarState.comforting;
    }

    return AvatarState.speaking;
  }

  AvatarState _initialAvatarState() {
    if (widget.sending) return AvatarState.thinking;
    if (widget.messages.isEmpty) return AvatarState.idle;

    final latest = widget.messages.last;
    if (latest.isFallback) return AvatarState.error;
    if (latest.responseSource == 'safety' ||
        latest.tone == 'safety' ||
        latest.tone == 'safety-focused') {
      return AvatarState.comforting;
    }
    return AvatarState.idle;
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
      _setAvatarState(
        AvatarState.thinking,
        idleAfter: const Duration(milliseconds: 900),
      );
      return;
    }
    await _startListening(autoSend: true);
  }

  Future<void> _startListening({bool autoSend = false}) async {
    if (widget.sending) return;

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _setAvatarState(
        AvatarState.error,
        idleAfter: const Duration(milliseconds: 1800),
      );
      _showVoiceMessage(microphonePermissionDeniedMessage);
      return;
    }

    try {
      final available = _speechReady ||
          await _speech.initialize(
            onError: (_) {
              if (!mounted) return;
              setState(() => _listening = false);
              _setAvatarState(
                AvatarState.error,
                idleAfter: const Duration(milliseconds: 1800),
              );
              _showVoiceMessage(speechRecognitionFailedMessage);
            },
            onStatus: _handleSpeechStatus,
          );

      if (!available) {
        _setAvatarState(
          AvatarState.error,
          idleAfter: const Duration(milliseconds: 1800),
        );
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
      _setAvatarState(AvatarState.listening);

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
      _setAvatarState(
        AvatarState.error,
        idleAfter: const Duration(milliseconds: 1800),
      );
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
    _setAvatarState(
      AvatarState.thinking,
      idleAfter: _autoSendVoice ? null : const Duration(milliseconds: 900),
    );
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
      _setAvatarState(
        AvatarState.error,
        idleAfter: const Duration(milliseconds: 1800),
      );
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
    _setAvatarState(AvatarState.thinking);
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
      _setAvatarState(AvatarState.thinking);

      await Future<void>.delayed(_voiceThinkingDelay());
      if (!mounted || runId != _voiceRunId) return;

      setState(() => _thinkingText = null);
      _setAvatarState(AvatarState.speaking);

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
        _setAvatarState(AvatarState.idle);
      }
    } catch (_) {
      _voiceSequenceActive = false;
      if (!mounted) return;
      setState(() {
        _thinkingText = null;
        _speakingText = null;
      });
      _setAvatarState(
        AvatarState.error,
        idleAfter: const Duration(milliseconds: 1800),
      );
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
      _setAvatarState(AvatarState.idle);
    }
    await _tts.stop();
  }

  Future<void> _configureTts() async {
    _ttsTouched = true;
    final style = widget.subscription.premium ? _voiceStyle : 'Sakin';
    final rate = voiceRateFor(style: style, speed: _voiceSpeed);
    final pitch = voicePitchForStyle(style);

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
    if (widget.messages.isEmpty) return;

    final latest = widget.messages.last;
    final signature = _messageSignature(latest);
    if (signature == _lastAutoReadSignature) return;
    _lastAutoReadSignature = signature;
    if (latest.fromUser) return;
    if (latest.tone == 'thinking') return;
    if (latest.isFallback) return;

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
    _setAvatarState(AvatarState.idle);
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
      if (widget.subscription.premium)
        _VoiceSettingsCard(
          autoRead: _autoReadResponses,
          voiceStyle: _voiceStyle,
          voiceSpeed: _voiceSpeed,
          onAutoReadChanged: (value) {
            setState(() {
              _autoReadResponses = value;
              _lastAutoReadSignature = widget.messages.isEmpty
                  ? null
                  : _messageSignature(widget.messages.last);
            });
          },
          onVoiceStyleChanged: (value) => setState(() => _voiceStyle = value),
          onVoiceSpeedChanged: (value) => setState(() => _voiceSpeed = value),
        ),
      if (widget.showDailyCheckIn)
        _DailyCheckInCard(onSelected: widget.onDailyCheckInSelected),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactViewport = constraints.maxHeight < 640;
          return Column(
            children: [
              Flexible(
                flex: compactViewport ? 30 : 35,
                fit: FlexFit.tight,
                child: _CompanionAvatarCard(
                  avatar: avatar,
                  subscription: widget.subscription,
                  character: character,
                  avatarState: _avatarState,
                  speakingTextLength: _speakingText?.length ?? 0,
                ),
              ),
              SizedBox(height: compactViewport ? 6 : 8),
              Expanded(
                flex: compactViewport ? 52 : 45,
                child: ListView.separated(
                  controller: _scrollController,
                  cacheExtent: 900,
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
              SizedBox(height: compactViewport ? 6 : 10),
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
          );
        },
      ),
    );
  }

  String? _latestUserText() {
    for (final message in widget.messages.reversed) {
      if (message.fromUser) return message.text;
    }
    return null;
  }

  String? _messageSignature(ChatMessage? message) {
    if (message == null) return null;
    return [
      message.author.name,
      message.text,
      message.tone ?? '',
      message.responseSource,
    ].join('|');
  }
}

class _CompanionAvatarCard extends StatelessWidget {
  const _CompanionAvatarCard({
    required this.avatar,
    required this.subscription,
    required this.character,
    required this.avatarState,
    required this.speakingTextLength,
  });

  final AvatarOption avatar;
  final SubscriptionSnapshot subscription;
  final PremiumAvatarCharacter? character;
  final AvatarState avatarState;
  final int speakingTextLength;

  @override
  Widget build(BuildContext context) {
    final title = character?.name ?? 'Enis';
    final subtitle =
        character == null ? 'Sade eşlikçi' : character!.personalityStyle;
    final color = character?.color ?? avatar.color;
    final status = switch (avatarState) {
      AvatarState.listening => companionListeningStatusLabel,
      AvatarState.thinking => companionThinkingStatusLabel,
      AvatarState.speaking => companionSpeakingStatusLabel,
      AvatarState.comforting => companionComfortingStatusLabel,
      AvatarState.error => companionErrorStatusLabel,
      AvatarState.idle => companionIdleStatusLabel,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final tiny = height < 170;
        final compact = height < 230;
        final showSubtitle = height >= 280;
        final showTrialBadge = subscription.trialDaysRemaining != null &&
            height >= 150 &&
            constraints.maxWidth >= 240;
        final portraitSize = tiny
            ? (height * 0.34).clamp(48.0, 64.0).toDouble()
            : compact
                ? (height * 0.38).clamp(60.0, 86.0).toDouble()
                : (height * 0.52).clamp(112.0, 178.0).toDouble();
        final padding = compact
            ? const EdgeInsets.fromLTRB(8, 8, 8, 8)
            : const EdgeInsets.fromLTRB(12, 10, 12, 10);
        final contentWidth =
            max(0.0, constraints.maxWidth - padding.horizontal);

        return SoftCard(
          padding: padding,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: CompanionAvatarView(
                            avatar: avatar,
                            character: character,
                            avatarState: avatarState,
                            speakingTextLength: speakingTextLength,
                            size: portraitSize,
                          ),
                        ),
                        if (showTrialBadge)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  EnisColors.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: EnisColors.primaryBlue
                                    .withValues(alpha: 0.14),
                              ),
                            ),
                            child: Text(
                              '${subscription.trialDaysRemaining} gün',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: EnisColors.primaryBlue,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: tiny ? 4 : 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (compact
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.titleLarge)
                          ?.copyWith(
                        color: EnisColors.deepNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (showSubtitle) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  EnisColors.deepNavy.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    SizedBox(height: tiny ? 4 : 6),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 12,
                        vertical: compact ? 6 : 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: color.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CompanionStatusIndicator(
                            avatarState: avatarState,
                            color: color,
                            speakingTextLength: speakingTextLength,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CompanionAvatarView extends StatefulWidget {
  const CompanionAvatarView({
    super.key,
    required this.avatar,
    required this.character,
    required this.avatarState,
    required this.speakingTextLength,
    required this.size,
  });

  final AvatarOption avatar;
  final PremiumAvatarCharacter? character;
  final AvatarState avatarState;
  final int speakingTextLength;
  final double size;

  @override
  State<CompanionAvatarView> createState() => _CompanionAvatarViewState();
}

class _CompanionAvatarViewState extends State<CompanionAvatarView>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _gazeController;
  Timer? _blinkTimer;
  bool _blink = false;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat(reverse: true);
    _gazeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);
    _scheduleBlink();
  }

  @override
  void didUpdateWidget(covariant CompanionAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character?.id != widget.character?.id ||
        oldWidget.avatar.id != widget.avatar.id) {
      _scheduleBlink();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathController.dispose();
    _gazeController.dispose();
    super.dispose();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    final delay = Duration(seconds: 4 + _random.nextInt(4));
    _blinkTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _blink = true);
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _blink = false);
        _scheduleBlink();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.character?.color ?? widget.avatar.color;
    final id = widget.character?.id ??
        switch (widget.avatar.id) {
          'structured' => 'ada',
          'guide' => 'deniz',
          _ => 'eren',
        };
    final size = widget.size;
    final faceColor = switch (id) {
      'lina' => const Color(0xFFFFD8B5),
      'deniz' => const Color(0xFFF1C9A8),
      'ada' => const Color(0xFFEFC8AA),
      'eren' => const Color(0xFFE9C4A7),
      'arda' => const Color(0xFFE4B896),
      'kerem' => const Color(0xFFEBC09D),
      _ => const Color(0xFFF3C7A8),
    };
    final hairColor = switch (id) {
      'mira' => const Color(0xFF442D5E),
      'lina' => const Color(0xFFFFD56B),
      'deniz' => const Color(0xFF6A4C9A),
      'ada' => const Color(0xFF2F2754),
      'eren' => const Color(0xFF695A82),
      'arda' => const Color(0xFF29243D),
      'kerem' => const Color(0xFF5D463D),
      _ => EnisColors.white,
    };
    final eyeColor = id == 'deniz'
        ? EnisColors.primaryBlue
        : EnisColors.deepNavy.withValues(alpha: 0.78);
    final isFree = widget.character == null;
    final glowColor = switch (widget.avatarState) {
      AvatarState.comforting => EnisColors.softPurple,
      AvatarState.error => EnisColors.lavender,
      AvatarState.thinking => EnisColors.lavender,
      AvatarState.listening => EnisColors.primaryBlue,
      AvatarState.speaking => color,
      AvatarState.idle => color,
    };
    final glowAlpha = switch (widget.avatarState) {
      AvatarState.comforting => 0.24,
      AvatarState.error => 0.10,
      AvatarState.listening => 0.22,
      AvatarState.thinking => 0.18,
      AvatarState.speaking => 0.24,
      AvatarState.idle => 0.14,
    };
    final waveDuration = companionSpeakingWaveDuration(
      widget.speakingTextLength,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_breathController, _gazeController]),
      builder: (context, _) {
        final breathing = widget.avatarState == AvatarState.idle ||
            widget.avatarState == AvatarState.comforting;
        final scale = breathing ? 1 + (_breathController.value * 0.03) : 1.0;
        final gazeOffset = Offset(
          sin(_gazeController.value * pi * 2) * size * 0.010,
          cos(_gazeController.value * pi * 2) * size * 0.006,
        );

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (widget.avatarState == AvatarState.thinking ||
                    widget.avatarState == AvatarState.listening ||
                    widget.avatarState == AvatarState.comforting)
                  _PulseRing(
                    color: glowColor,
                    size: size,
                    warm: widget.avatarState == AvatarState.comforting,
                  ),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    gradient: isFree
                        ? EnisBrand.gradient
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              glowColor.withValues(alpha: 0.18),
                              EnisColors.white,
                              EnisColors.lavender.withValues(alpha: 0.20),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(size * 0.36),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: glowAlpha),
                        blurRadius:
                            widget.avatarState == AvatarState.error ? 22 : 36,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: EnisColors.deepNavy.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey(
                        '${isFree ? widget.avatar.id : widget.character!.id}-${widget.avatarState.name}',
                      ),
                      child: isFree
                          ? _CharacterPlaceholderPortrait(
                              id: id,
                              hairColor: hairColor,
                              faceColor: faceColor,
                              eyeColor: eyeColor,
                              avatarState: widget.avatarState,
                              size: size,
                              blink: _blink,
                              gazeOffset: gazeOffset,
                              waveDuration: waveDuration,
                            )
                          : _CharacterAssetOrPlaceholder(
                              character: widget.character!,
                              assetPath: getAvatarAsset(
                                widget.character!,
                                widget.avatarState,
                              ),
                              id: id,
                              hairColor: hairColor,
                              faceColor: faceColor,
                              eyeColor: eyeColor,
                              avatarState: widget.avatarState,
                              size: size,
                              blink: _blink,
                              gazeOffset: gazeOffset,
                              waveDuration: waveDuration,
                            ),
                    ),
                  ),
                ),
                if (widget.avatarState == AvatarState.listening)
                  Positioned(
                    bottom: 8,
                    child: _MiniWave(
                      color: EnisColors.white,
                      background: color,
                    ),
                  ),
                if (widget.avatarState == AvatarState.thinking)
                  Positioned(
                    bottom: 10,
                    child: _ThinkingDots(color: color),
                  ),
                if (widget.avatarState == AvatarState.speaking)
                  Positioned(
                    bottom: 8,
                    child: _MiniWave(
                      color: color,
                      background: EnisColors.white,
                      duration: waveDuration,
                    ),
                  ),
                if (widget.avatarState == AvatarState.error)
                  Positioned(
                    bottom: 10,
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: EnisColors.deepNavy.withValues(alpha: 0.34),
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CharacterAssetOrPlaceholder extends StatelessWidget {
  const _CharacterAssetOrPlaceholder({
    required this.character,
    required this.assetPath,
    required this.id,
    required this.hairColor,
    required this.faceColor,
    required this.eyeColor,
    required this.avatarState,
    required this.size,
    required this.blink,
    required this.gazeOffset,
    required this.waveDuration,
  });

  final PremiumAvatarCharacter character;
  final String assetPath;
  final String id;
  final Color hairColor;
  final Color faceColor;
  final Color eyeColor;
  final AvatarState avatarState;
  final double size;
  final bool blink;
  final Offset gazeOffset;
  final Duration waveDuration;

  @override
  Widget build(BuildContext context) {
    final usePortraitAsset =
        !const {'deniz', 'eren', 'arda', 'kerem'}.contains(id);
    return Padding(
      padding: EdgeInsets.all(size * 0.10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CharacterPlaceholderPortrait(
              id: id,
              hairColor: hairColor,
              faceColor: faceColor,
              eyeColor: eyeColor,
              avatarState: avatarState,
              size: size,
              blink: blink,
              gazeOffset: gazeOffset,
              waveDuration: waveDuration,
            ),
            if (usePortraitAsset)
              Image.asset(
                assetPath,
                fit: BoxFit.cover,
                semanticLabel: character.name,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CharacterPlaceholderPortrait extends StatelessWidget {
  const _CharacterPlaceholderPortrait({
    required this.id,
    required this.hairColor,
    required this.faceColor,
    required this.eyeColor,
    required this.avatarState,
    required this.size,
    required this.blink,
    required this.gazeOffset,
    required this.waveDuration,
  });

  final String id;
  final Color hairColor;
  final Color faceColor;
  final Color eyeColor;
  final AvatarState avatarState;
  final double size;
  final bool blink;
  final Offset gazeOffset;
  final Duration waveDuration;

  @override
  Widget build(BuildContext context) {
    final faceWidth = switch (id) {
      'arda' => size * 0.49,
      'kerem' || 'eren' => size * 0.47,
      'deniz' => size * 0.46,
      _ => size * 0.44,
    };
    final faceHeight = switch (id) {
      'arda' => size * 0.48,
      'kerem' => size * 0.49,
      _ => size * 0.50,
    };
    final faceRadius = switch (id) {
      'arda' => size * 0.17,
      'kerem' || 'eren' => size * 0.19,
      _ => size * 0.22,
    };
    final eyeInset = switch (id) {
      'arda' => size * 0.135,
      'kerem' => size * 0.13,
      _ => size * 0.12,
    };

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          top: size * 0.14,
          child: _CharacterHair(
            id: id,
            color: hairColor,
            size: size,
          ),
        ),
        Positioned(
          top: size * 0.21,
          child: Container(
            width: faceWidth,
            height: faceHeight,
            decoration: BoxDecoration(
              color: faceColor,
              borderRadius: BorderRadius.circular(faceRadius),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: size *
                      (avatarState == AvatarState.comforting ? 0.19 : 0.18),
                  left: eyeInset,
                  child: _Eye(
                    color: eyeColor,
                    size: size,
                    closed: blink,
                    gazeOffset: gazeOffset,
                  ),
                ),
                Positioned(
                  top: size *
                      (avatarState == AvatarState.comforting ? 0.19 : 0.18),
                  right: eyeInset,
                  child: _Eye(
                    color: eyeColor,
                    size: size,
                    closed: blink,
                    gazeOffset: gazeOffset,
                  ),
                ),
                Positioned(
                  bottom: size * 0.13,
                  child: _Mouth(
                    color: EnisColors.deepNavy.withValues(
                      alpha:
                          avatarState == AvatarState.comforting ? 0.34 : 0.42,
                    ),
                    avatarState: avatarState,
                    size: size,
                    waveDuration: waveDuration,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CharacterHair extends StatelessWidget {
  const _CharacterHair({
    required this.id,
    required this.color,
    required this.size,
  });

  final String id;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final width = size * 0.54;
    final height = size * 0.28;
    if (id == 'mira') {
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: List.generate(7, (index) {
            final offset = (index - 3) * size * 0.065;
            return Positioned(
              left: width / 2 + offset - size * 0.06,
              top: index.isEven ? size * 0.01 : size * 0.04,
              child: Container(
                width: size * 0.13,
                height: size * 0.13,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            );
          }),
        ),
      );
    }

    if (id == 'lina') {
      return SizedBox(
        width: width,
        height: height * 1.25,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: size * 0.02,
              left: size * 0.04,
              child: Container(
                width: width * 0.78,
                height: height * 1.05,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(size * 0.28),
                    topRight: Radius.circular(size * 0.24),
                    bottomLeft: Radius.circular(size * 0.22),
                    bottomRight: Radius.circular(size * 0.10),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: size * 0.02,
              child: Container(
                width: width * 0.42,
                height: height * 0.86,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(size * 0.22),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (id == 'arda') {
      return Container(
        width: width * 0.86,
        height: height * 0.70,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.22),
            topRight: Radius.circular(size * 0.22),
            bottomLeft: Radius.circular(size * 0.08),
            bottomRight: Radius.circular(size * 0.08),
          ),
        ),
      );
    }

    if (id == 'kerem') {
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: List.generate(5, (index) {
            final offset = (index - 2) * size * 0.07;
            return Positioned(
              left: width / 2 + offset - size * 0.055,
              top: index.isEven ? 0 : size * 0.035,
              child: Transform.rotate(
                angle: (index - 2) * 0.10,
                child: Container(
                  width: size * 0.13,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(size * 0.08),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    if (id == 'eren') {
      return SizedBox(
        width: width * 0.92,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: width * 0.86,
              height: height * 0.76,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size * 0.24),
                  topRight: Radius.circular(size * 0.24),
                  bottomLeft: Radius.circular(size * 0.14),
                  bottomRight: Radius.circular(size * 0.14),
                ),
              ),
            ),
            Positioned(
              top: size * 0.03,
              left: size * 0.13,
              child: Container(
                width: size * 0.18,
                height: size * 0.10,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(size * 0.08),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (id == 'ada') {
      return Container(
        width: width * 0.86,
        height: height * 0.84,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.24),
            topRight: Radius.circular(size * 0.20),
            bottomLeft: Radius.circular(size * 0.07),
            bottomRight: Radius.circular(size * 0.12),
          ),
        ),
      );
    }

    if (id == 'deniz') {
      return Container(
        width: width * 0.92,
        height: height * 0.88,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.24),
            topRight: Radius.circular(size * 0.26),
            bottomLeft: Radius.circular(size * 0.16),
            bottomRight: Radius.circular(size * 0.16),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.26),
          topRight: Radius.circular(size * 0.26),
          bottomLeft: Radius.circular(id == 'lina' ? size * 0.24 : size * 0.12),
          bottomRight: Radius.circular(size * 0.12),
        ),
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({
    required this.color,
    required this.size,
    required this.closed,
    required this.gazeOffset,
  });

  final Color color;
  final double size;
  final bool closed;
  final Offset gazeOffset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: gazeOffset,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: size * 0.045,
        height: closed ? size * 0.010 : size * 0.045,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _Mouth extends StatefulWidget {
  const _Mouth({
    required this.color,
    required this.avatarState,
    required this.size,
    required this.waveDuration,
  });

  final Color color;
  final AvatarState avatarState;
  final double size;
  final Duration waveDuration;

  @override
  State<_Mouth> createState() => _MouthState();
}

class _MouthState extends State<_Mouth> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.waveDuration);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _Mouth oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waveDuration != widget.waveDuration) {
      _controller.duration = widget.waveDuration;
    }
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.avatarState == AvatarState.speaking) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
      return;
    }
    if (_controller.isAnimating) _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final speaking = widget.avatarState == AvatarState.speaking;
        final comforting = widget.avatarState == AvatarState.comforting;
        final pulse = speaking ? _controller.value : 0.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: speaking
              ? widget.size * (0.08 + pulse * 0.04)
              : widget.size * (comforting ? 0.18 : 0.16),
          height: speaking
              ? widget.size * (0.06 + pulse * 0.035)
              : widget.size * 0.028,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: speaking ? 0.62 : 0.86),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      },
    );
  }
}

class _CompanionStatusIndicator extends StatelessWidget {
  const _CompanionStatusIndicator({
    required this.avatarState,
    required this.color,
    required this.speakingTextLength,
  });

  final AvatarState avatarState;
  final Color color;
  final int speakingTextLength;

  @override
  Widget build(BuildContext context) {
    if (avatarState == AvatarState.listening) {
      return _MiniWave(
        color: color,
        background: color.withValues(alpha: 0.08),
      );
    }
    if (avatarState == AvatarState.speaking) {
      return _MiniWave(
        color: color,
        background: color.withValues(alpha: 0.08),
        duration: companionSpeakingWaveDuration(speakingTextLength),
      );
    }
    if (avatarState == AvatarState.thinking) {
      return _ThinkingDots(color: color);
    }
    if (avatarState == AvatarState.comforting) {
      return _PulseDot(color: color);
    }
    if (avatarState == AvatarState.error) {
      return Icon(
        Icons.more_horiz_rounded,
        color: EnisColors.deepNavy.withValues(alpha: 0.38),
        size: 18,
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MiniWave extends StatelessWidget {
  const _MiniWave({
    required this.color,
    required this.background,
    this.duration = const Duration(milliseconds: 900),
  });

  final Color color;
  final Color background;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: _ListeningWave(barColor: color, duration: duration),
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({
    required this.color,
    required this.size,
    this.warm = false,
  });

  final Color color;
  final double size;
  final bool warm;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
        final scale = 1 + (_controller.value * (widget.warm ? 0.10 : 0.08));
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.38),
              border: Border.all(
                color: widget.color.withValues(
                  alpha:
                      (widget.warm ? 0.16 : 0.12) + (_controller.value * 0.10),
                ),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots({required this.color});

  final Color color;

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index * 0.18) % 1;
            final lift = sin(phase * pi) * 3;
            return Transform.translate(
              offset: Offset(0, -lift),
              child: Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.36 + lift / 10),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
        return Container(
          width: 8 + (_controller.value * 5),
          height: 8 + (_controller.value * 5),
          decoration: BoxDecoration(
            color: widget.color.withValues(
              alpha: 0.46 + (_controller.value * 0.30),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _VoiceSettingsCard extends StatelessWidget {
  const _VoiceSettingsCard({
    required this.autoRead,
    required this.voiceStyle,
    required this.voiceSpeed,
    required this.onAutoReadChanged,
    required this.onVoiceStyleChanged,
    required this.onVoiceSpeedChanged,
  });

  final bool autoRead;
  final String voiceStyle;
  final String voiceSpeed;
  final ValueChanged<bool> onAutoReadChanged;
  final ValueChanged<String> onVoiceStyleChanged;
  final ValueChanged<String> onVoiceSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up_rounded,
                  color: EnisColors.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      autoReadVoiceLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      automaticVoiceResponseLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: autoRead,
                onChanged: onAutoReadChanged,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: voiceStyleOptions.map((style) {
                final selected = style == voiceStyle;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(style),
                    selected: selected,
                    onSelected: (_) => onVoiceStyleChanged(style),
                    selectedColor:
                        EnisColors.primaryBlue.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      color: selected
                          ? EnisColors.primaryBlue
                          : EnisColors.deepNavy.withValues(alpha: 0.7),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                voiceSpeedLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: EnisColors.deepNavy.withValues(alpha: 0.68),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: voiceSpeedOptions.map((speed) {
                      final selected = speed == voiceSpeed;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(speed),
                          selected: selected,
                          onSelected: (_) => onVoiceSpeedChanged(speed),
                          selectedColor:
                              EnisColors.lavender.withValues(alpha: 0.14),
                          labelStyle: TextStyle(
                            color: selected
                                ? EnisColors.primaryBlue
                                : EnisColors.deepNavy.withValues(alpha: 0.7),
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
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
    final isFallback = message.isFallback;
    final bubbleColor = message.fromUser
        ? EnisColors.primaryBlue
        : isFallback
            ? EnisColors.background
            : EnisColors.white;
    final textColor = message.fromUser
        ? EnisColors.white
        : isFallback
            ? EnisColors.deepNavy.withValues(alpha: 0.72)
            : EnisColors.deepNavy;
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
              border: isFallback
                  ? Border.all(
                      color: EnisColors.lavender.withValues(alpha: 0.24),
                    )
                  : null,
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
                    if (!isFallback)
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
        if (!message.fromUser &&
            !isFallback &&
            message.suggestion?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          _SuggestionCard(text: message.suggestion!),
        ],
        if (!message.fromUser &&
            !isFallback &&
            message.premiumUpsell?.isNotEmpty == true) ...[
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
  const _ListeningWave({
    this.barColor = EnisColors.primaryBlue,
    this.duration = const Duration(milliseconds: 900),
  });

  final Color barColor;
  final Duration duration;

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
      duration: widget.duration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _ListeningWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (!_controller.isAnimating) _controller.repeat();
    }
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
                  color: widget.barColor.withValues(
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
