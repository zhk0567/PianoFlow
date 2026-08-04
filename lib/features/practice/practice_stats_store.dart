import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/piano_flow_log.dart';

class SongPracticeStats {
  const SongPracticeStats({
    this.sessions = 0,
    this.seconds = 0,
    this.hits = 0,
    this.misses = 0,
  });

  final int sessions;
  final int seconds;
  final int hits;
  final int misses;

  SongPracticeStats copyWith({
    int? sessions,
    int? seconds,
    int? hits,
    int? misses,
  }) {
    return SongPracticeStats(
      sessions: sessions ?? this.sessions,
      seconds: seconds ?? this.seconds,
      hits: hits ?? this.hits,
      misses: misses ?? this.misses,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessions': sessions,
        'seconds': seconds,
        'hits': hits,
        'misses': misses,
      };

  factory SongPracticeStats.fromJson(Map<String, dynamic> json) {
    return SongPracticeStats(
      sessions: json['sessions'] as int? ?? 0,
      seconds: json['seconds'] as int? ?? 0,
      hits: json['hits'] as int? ?? 0,
      misses: json['misses'] as int? ?? 0,
    );
  }
}

class PracticeStatsState {
  const PracticeStatsState({
    this.bySong = const {},
    this.ready = false,
  });

  final Map<String, SongPracticeStats> bySong;
  final bool ready;

  int get totalSessions =>
      bySong.values.fold(0, (a, b) => a + b.sessions);

  int get totalSeconds => bySong.values.fold(0, (a, b) => a + b.seconds);

  PracticeStatsState copyWith({
    Map<String, SongPracticeStats>? bySong,
    bool? ready,
  }) {
    return PracticeStatsState(
      bySong: bySong ?? this.bySong,
      ready: ready ?? this.ready,
    );
  }
}

class PracticeStatsController extends Notifier<PracticeStatsState> {
  static const _key = 'practice_stats_v1';

  @override
  PracticeStatsState build() {
    Future.microtask(_load);
    return const PracticeStatsState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) {
        state = const PracticeStatsState(ready: true);
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final bySong = <String, SongPracticeStats>{};
      for (final e in map.entries) {
        bySong[e.key] =
            SongPracticeStats.fromJson(e.value as Map<String, dynamic>);
      }
      state = PracticeStatsState(bySong: bySong, ready: true);
    } catch (e, st) {
      pianoFlowLog('Practice', 'stats load failed: $e\n$st');
      state = const PracticeStatsState(ready: true);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        for (final e in state.bySong.entries) e.key: e.value.toJson(),
      };
      await prefs.setString(_key, jsonEncode(map));
    } catch (e, st) {
      pianoFlowLog('Practice', 'stats persist failed: $e\n$st');
    }
  }

  Future<void> recordSession({
    required String songId,
    required int seconds,
    int hits = 0,
    int misses = 0,
  }) async {
    final prev = state.bySong[songId] ?? const SongPracticeStats();
    final next = prev.copyWith(
      sessions: prev.sessions + 1,
      seconds: prev.seconds + seconds,
      hits: prev.hits + hits,
      misses: prev.misses + misses,
    );
    state = state.copyWith(
      bySong: {...state.bySong, songId: next},
      ready: true,
    );
    await _persist();
  }
}

final practiceStatsProvider =
    NotifierProvider<PracticeStatsController, PracticeStatsState>(
  PracticeStatsController.new,
);
