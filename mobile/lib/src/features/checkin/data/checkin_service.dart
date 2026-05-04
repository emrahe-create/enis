import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/retention_copy.dart';

class DailyCheckIn {
  const DailyCheckIn({
    required this.mood,
    this.note,
    this.createdAt,
  });

  final String mood;
  final String? note;
  final DateTime? createdAt;

  factory DailyCheckIn.fromJson(Map<String, dynamic> json) {
    return DailyCheckIn(
      mood: json['mood']?.toString() ?? '',
      note: json['note']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class DailyCheckInState {
  const DailyCheckInState({
    required this.checkedInToday,
    required this.showCard,
    this.checkIn,
    this.continuityLine,
  });

  final bool checkedInToday;
  final bool showCard;
  final DailyCheckIn? checkIn;
  final String? continuityLine;

  factory DailyCheckInState.empty() {
    return const DailyCheckInState(checkedInToday: false, showCard: true);
  }

  factory DailyCheckInState.fromJson(Map<String, dynamic> json) {
    final rawCheckIn = json['checkIn'];
    return DailyCheckInState(
      checkedInToday: json['checkedInToday'] == true,
      showCard: json['showCard'] != false && json['checkedInToday'] != true,
      checkIn: rawCheckIn is Map<String, dynamic>
          ? DailyCheckIn.fromJson(rawCheckIn)
          : null,
      continuityLine: json['continuityLine']?.toString(),
    );
  }
}

class DailyCheckInResult extends DailyCheckInState {
  const DailyCheckInResult({
    required super.checkedInToday,
    required super.showCard,
    required this.chatContext,
    super.checkIn,
    super.continuityLine,
  });

  final String chatContext;

  factory DailyCheckInResult.fromJson(
    Map<String, dynamic> json, {
    required String fallbackMood,
  }) {
    final state = DailyCheckInState.fromJson(json);
    return DailyCheckInResult(
      checkedInToday: state.checkedInToday,
      showCard: state.showCard,
      checkIn: state.checkIn,
      continuityLine: state.continuityLine,
      chatContext: json['chatContext']?.toString() ??
          buildDailyCheckInChatContext(fallbackMood),
    );
  }
}

class CheckInService {
  CheckInService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DailyCheckInState> getToday() async {
    try {
      final json = await _apiClient.getJson('/api/checkins/today');
      return DailyCheckInState.fromJson(json);
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return DailyCheckInState.empty();
    }
  }

  Future<DailyCheckInResult> save({required String mood, String? note}) async {
    try {
      final json = await _apiClient.postJson('/api/checkins', body: {
        'mood': mood,
        if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
      });
      return DailyCheckInResult.fromJson(json, fallbackMood: mood);
    } on ApiException catch (error) {
      if (!error.isNetworkFailure || !AppConfig.allowMockFallback) rethrow;
      return DailyCheckInResult(
        checkedInToday: true,
        showCard: false,
        checkIn: DailyCheckIn(mood: mood, note: note),
        chatContext: buildDailyCheckInChatContext(mood),
      );
    }
  }
}
