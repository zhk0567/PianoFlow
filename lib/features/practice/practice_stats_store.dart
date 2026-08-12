import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/piano_flow_log.dart';
import 'practice_constants.dart';

class SongPracticeStats {
  const SongPracticeStats({
    this.sessions = 0,
    this.seconds = 0,
    this.hits = 0,
    this.misses = 0,
    this.perfects = 0,
    this.goods = 0,
    this.maxComboBest = 0,
    this.examSessions = 0,
    this.lastPracticedDay = '',
  });

  final int sessions;
  final int seconds;
  final int hits;
  final int misses;
  final int perfects;
  final int goods;
  final int maxComboBest;
  final int examSessions;
  final String lastPracticedDay;

  bool get lit => sessions > 0;

  SongPracticeStats copyWith({
    int? sessions,
    int? seconds,
    int? hits,
    int? misses,
    int? perfects,
    int? goods,
    int? maxComboBest,
    int? examSessions,
    String? lastPracticedDay,
  }) {
    return SongPracticeStats(
      sessions: sessions ?? this.sessions,
      seconds: seconds ?? this.seconds,
      hits: hits ?? this.hits,
      misses: misses ?? this.misses,
      perfects: perfects ?? this.perfects,
      goods: goods ?? this.goods,
      maxComboBest: maxComboBest ?? this.maxComboBest,
      examSessions: examSessions ?? this.examSessions,
      lastPracticedDay: lastPracticedDay ?? this.lastPracticedDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessions': sessions,
        'seconds': seconds,
        'hits': hits,
        'misses': misses,
        'perfects': perfects,
        'goods': goods,
        'maxComboBest': maxComboBest,
        'examSessions': examSessions,
        'lastPracticedDay': lastPracticedDay,
      };

  factory SongPracticeStats.fromJson(Map<String, dynamic> json) {
    return SongPracticeStats(
      sessions: json['sessions'] as int? ?? 0,
      seconds: json['seconds'] as int? ?? 0,
      hits: json['hits'] as int? ?? 0,
      misses: json['misses'] as int? ?? 0,
      perfects: json['perfects'] as int? ?? 0,
      goods: json['goods'] as int? ?? 0,
      maxComboBest: json['maxComboBest'] as int? ?? 0,
      examSessions: json['examSessions'] as int? ?? 0,
      lastPracticedDay: json['lastPracticedDay'] as String? ?? '',
    );
  }
}

class PracticeStatsState {
  const PracticeStatsState({
    this.bySong = const {},
    this.dailySeconds = const {},
    this.ready = false,
  });

  final Map<String, SongPracticeStats> bySong;
  final Map<String, int> dailySeconds;
  final bool ready;

  int get totalSessions =>
      bySong.values.fold(0, (a, b) => a + b.sessions);

  int get totalSeconds => bySong.values.fold(0, (a, b) => a + b.seconds);

  int todaySeconds([DateTime? now]) {
    final key = dayKey(now ?? DateTime.now());
    return dailySeconds[key] ?? 0;
  }

  double todayProgress01([DateTime? now]) {
    final goal = PracticeConstants.dailyPracticeGoalMinutes * 60;
    if (goal <= 0) return 0;
    return (todaySeconds(now) / goal).clamp(0.0, 1.0);
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  PracticeStatsState copyWith({
    Map<String, SongPracticeStats>? bySong,
    Map<String, int>? dailySeconds,
    bool? ready,
  }) {
    return PracticeStatsState(
      bySong: bySong ?? this.bySong,
      dailySeconds: dailySeconds ?? this.dailySeconds,
      ready: ready ?? this.ready,
    );
  }
}

class PracticeStatsController extends Notifier<PracticeStatsState> {
  static const _key = 'practice_stats_v2';
  static const _legacyKey = 'practice_stats_v1';

  @override
  PracticeStatsState build() {
    Future.microtask(_load);
    return const PracticeStatsState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_key);
      raw ??= prefs.getString(_legacyKey);
      if (raw == null) {
        state = const PracticeStatsState(ready: true);
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final bySong = <String, SongPracticeStats>{};
      var daily = <String, int>{};
      if (map.containsKey('bySong') || map.containsKey('dailySeconds')) {
        final songs = map['bySong'] as Map<String, dynamic>? ?? {};
        for (final e in songs.entries) {
          bySong[e.key] =
              SongPracticeStats.fromJson(e.value as Map<String, dynamic>);
        }
        final d = map['dailySeconds'] as Map<String, dynamic>? ?? {};
        daily = {
          for (final e in d.entries) e.key: (e.value as num).toInt(),
        };
      } else {
        for (final e in map.entries) {
          bySong[e.key] =
              SongPracticeStats.fromJson(e.value as Map<String, dynamic>);
        }
      }
      state = PracticeStatsState(
        bySong: bySong,
        dailySeconds: daily,
        ready: true,
      );
    } catch (e, st) {
      pianoFlowLog('Practice', 'stats load failed: $e\n$st');
      state = const PracticeStatsState(ready: true);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'bySong': {
            for (final e in state.bySong.entries) e.key: e.value.toJson(),
          },
          'dailySeconds': state.dailySeconds,
        }),
      );
    } catch (e, st) {
      pianoFlowLog('Practice', 'stats persist failed: $e\n$st');
    }
  }

  Future<void> recordSession({
    required String songId,
    required int seconds,
    int hits = 0,
    int misses = 0,
    int perfects = 0,
    int goods = 0,
    int maxCombo = 0,
    bool isExam = false,
    DateTime? now,
  }) async {
    final when = now ?? DateTime.now();
    final day = PracticeStatsState.dayKey(when);
    final prev = state.bySong[songId] ?? const SongPracticeStats();
    final next = prev.copyWith(
      sessions: prev.sessions + 1,
      seconds: prev.seconds + seconds,
      hits: prev.hits + hits,
      misses: prev.misses + misses,
      perfects: prev.perfects + perfects,
      goods: prev.goods + goods,
      maxComboBest:
          maxCombo > prev.maxComboBest ? maxCombo : prev.maxComboBest,
      examSessions: prev.examSessions + (isExam ? 1 : 0),
      lastPracticedDay: day,
    );
    final daily = Map<String, int>.from(state.dailySeconds);
    daily[day] = (daily[day] ?? 0) + seconds;
    state = state.copyWith(
      bySong: {...state.bySong, songId: next},
      dailySeconds: daily,
      ready: true,
    );
    await _persist();
  }
}

final practiceStatsProvider =
    NotifierProvider<PracticeStatsController, PracticeStatsState>(
  PracticeStatsController.new,
);
