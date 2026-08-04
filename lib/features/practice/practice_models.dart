import 'package:flutter/foundation.dart';

import '../../shared/models/song.dart';
import 'practice_constants.dart';
import 'practice_wait_logic.dart';

/// 练习页模式：[wait] 跟弹练习；[autoPlay] 自动示范，不跟弹等待。
enum PracticeMode { wait, autoPlay }

extension PracticeModeX on PracticeMode {
  bool get isPractice => this == PracticeMode.wait;
  bool get isAutoPlay => this == PracticeMode.autoPlay;

  String get labelZh => switch (this) {
        PracticeMode.wait => '练习',
        PracticeMode.autoPlay => '自动播放',
      };
}

@immutable
class PracticeSettings {
  const PracticeSettings({
    this.speed = 1.0,
    this.volume = PracticeConstants.volumeDefault,
    this.hand = Hand.both,
    this.mode = PracticeMode.wait,
    this.loopEnabled = false,
    this.loopStart = 0.0,
    this.loopEnd = 4.0,
    this.guideAudio = true,
    this.metronome = false,
  });

  final double speed;
  /// Master output level 0–1 (piano + metronome).
  final double volume;
  final Hand hand;
  final PracticeMode mode;
  final bool loopEnabled;
  final double loopStart;
  final double loopEnd;
  final bool guideAudio;
  final bool metronome;

  PracticeSettings copyWith({
    double? speed,
    double? volume,
    Hand? hand,
    PracticeMode? mode,
    bool? loopEnabled,
    double? loopStart,
    double? loopEnd,
    bool? guideAudio,
    bool? metronome,
  }) {
    return PracticeSettings(
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      hand: hand ?? this.hand,
      mode: mode ?? this.mode,
      loopEnabled: loopEnabled ?? this.loopEnabled,
      loopStart: loopStart ?? this.loopStart,
      loopEnd: loopEnd ?? this.loopEnd,
      guideAudio: guideAudio ?? this.guideAudio,
      metronome: metronome ?? this.metronome,
    );
  }
}

@immutable
class PracticeSnapshot {
  const PracticeSnapshot({
    required this.score,
    required this.settings,
    this.positionBeats = 0,
    this.isPlaying = false,
    this.activeMidi = const {},
    this.waitingFor = const {},
    this.pressedMidi = const {},
    this.sessionHits = 0,
    this.sessionMisses = 0,
    this.statusHint,
  });

  final SongScore score;
  final PracticeSettings settings;
  final double positionBeats;
  final bool isPlaying;
  final Set<int> activeMidi;
  final Set<int> waitingFor;
  final Set<int> pressedMidi;
  final int sessionHits;
  final int sessionMisses;

  /// Mic / audio init issues surfaced once for the practice page banner.
  final String? statusHint;

  double get durationBeats => score.durationBeats;
  List<ScoreNote> get filteredNotes => score.notesForHand(settings.hand);

  /// Nominal transport rate (quarter-notes / sec) from BPM × speed.
  double get nominalBeatsPerSec => score.bpm * settings.speed / 60.0;

  /// True when wait-mode is holding at a chord onset (waterfall frozen).
  bool get isWaitFrozenAtOnset {
    if (!settings.mode.isPractice) return false;
    if (waitingFor.isEmpty) return false;
    final chordStart = PracticeWaitLogic.chordStartForExpected(
      notes: filteredNotes,
      expected: waitingFor,
      pos: positionBeats,
    );
    if (chordStart == null) return false;
    return PracticeWaitLogic.shouldFreezeAt(
      pos: positionBeats,
      chordStart: chordStart,
    );
  }

  /// Ease rate between Dart [positionBeats] ticks (not a second clock).
  /// Auto-play: nominal while playing. Wait-mode: same, but **0** at onset freeze
  /// so staff cannot ease ahead of the hit line.
  double get staffBeatsPerSec {
    if (!isPlaying) return 0;
    if (settings.mode.isAutoPlay) return nominalBeatsPerSec;
    if (isWaitFrozenAtOnset) return 0;
    return nominalBeatsPerSec;
  }

  /// Active + waiting MIDI keys mapped to their score hand (for keyboard colors).
  Map<int, Hand> get highlightByHand {
    final midis = {...activeMidi, ...waitingFor};
    if (midis.isEmpty) return const {};

    final map = <int, Hand>{};
    for (final midi in midis) {
      ScoreNote? best;
      for (final n in filteredNotes) {
        if (n.midi != midi) continue;
        if (activeMidi.contains(midi) &&
            positionBeats >= n.start &&
            positionBeats < n.end) {
          best = n;
          break;
        }
        if (waitingFor.contains(midi)) {
          if (best == null ||
              (n.start - positionBeats).abs() <
                  (best.start - positionBeats).abs()) {
            best = n;
          }
        }
      }
      map[midi] = best?.hand ?? Hand.right;
    }
    return map;
  }

  PracticeSnapshot copyWith({
    SongScore? score,
    PracticeSettings? settings,
    double? positionBeats,
    bool? isPlaying,
    Set<int>? activeMidi,
    Set<int>? waitingFor,
    Set<int>? pressedMidi,
    int? sessionHits,
    int? sessionMisses,
    String? statusHint,
    bool clearStatusHint = false,
  }) {
    return PracticeSnapshot(
      score: score ?? this.score,
      settings: settings ?? this.settings,
      positionBeats: positionBeats ?? this.positionBeats,
      isPlaying: isPlaying ?? this.isPlaying,
      activeMidi: activeMidi ?? this.activeMidi,
      waitingFor: waitingFor ?? this.waitingFor,
      pressedMidi: pressedMidi ?? this.pressedMidi,
      sessionHits: sessionHits ?? this.sessionHits,
      sessionMisses: sessionMisses ?? this.sessionMisses,
      statusHint: clearStatusHint ? null : (statusHint ?? this.statusHint),
    );
  }
}
