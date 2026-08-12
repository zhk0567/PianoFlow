import 'package:flutter/foundation.dart';

import '../../shared/models/song.dart';
import 'practice_constants.dart';
import 'practice_judge_logic.dart';
import 'practice_wait_logic.dart';
import 'practice_weak_loop.dart';

export 'practice_judge_logic.dart' show HitGrade, HitGradeX;

/// 练习页模式：[wait] 跟弹；[exam] 考试（禁 scrub，由练习页「考试模式」开关开启）；[autoPlay] 自动示范。
/// UI 顶层分段为「自动 | 练习」；考试不是并列分段。
enum PracticeMode { wait, exam, autoPlay }

extension PracticeModeX on PracticeMode {
  bool get isPractice => this == PracticeMode.wait || this == PracticeMode.exam;
  bool get isExam => this == PracticeMode.exam;
  bool get isAutoPlay => this == PracticeMode.autoPlay;
  bool get allowsSeek => this != PracticeMode.exam;
  bool get allowsLoop => this != PracticeMode.exam;

  String get labelZh => switch (this) {
        PracticeMode.wait => '练习',
        PracticeMode.exam => '考试',
        PracticeMode.autoPlay => '自动',
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
    this.guideAudio = false,
    this.metronome = false,
    this.visualFxEnabled = false,
    this.examRecordAudio = false,
    this.showGhost = false,
  });

  final double speed;
  final double volume;
  final Hand hand;
  final PracticeMode mode;
  final bool loopEnabled;
  final double loopStart;
  final double loopEnd;
  final bool guideAudio;
  final bool metronome;

  /// 装饰层（残影 / 极轻条高光），非教学必需；默认关。
  final bool visualFxEnabled;
  final bool examRecordAudio;
  final bool showGhost;

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
    bool? visualFxEnabled,
    bool? examRecordAudio,
    bool? showGhost,
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
      visualFxEnabled: visualFxEnabled ?? this.visualFxEnabled,
      examRecordAudio: examRecordAudio ?? this.examRecordAudio,
      showGhost: showGhost ?? this.showGhost,
    );
  }
}

@immutable
class GhostHit {
  const GhostHit({
    required this.beat,
    required this.midi,
    required this.grade,
  });

  final double beat;
  final int midi;
  final HitGrade grade;

  Map<String, dynamic> toJson() => {
        'beat': beat,
        'midi': midi,
        'grade': grade.name,
      };

  factory GhostHit.fromJson(Map<String, dynamic> json) {
    final g = json['grade'] as String? ?? 'good';
    return GhostHit(
      beat: (json['beat'] as num?)?.toDouble() ?? 0,
      midi: json['midi'] as int? ?? 60,
      grade: HitGrade.values.firstWhere(
        (e) => e.name == g,
        orElse: () => HitGrade.good,
      ),
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
    this.missBeats = const [],
    this.perfectCount = 0,
    this.goodCount = 0,
    this.combo = 0,
    this.maxCombo = 0,
    this.lastGrade,
    this.lastHitMidi,
    this.lastHitHand,
    this.feedbackNonce = 0,
    this.settlementReady = false,
    this.endHangActive = false,
    this.statusHint,
    this.ghostHits = const [],
    this.sessionHitLog = const [],
    this.handsDialogueNonce = 0,
    this.handsDialogueLeftMidi,
    this.handsDialogueRightMidi,
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
  /// Beat positions where a frozen-line miss was counted (for 再练弱项).
  final List<double> missBeats;
  final int perfectCount;
  final int goodCount;
  final int combo;
  final int maxCombo;
  final HitGrade? lastGrade;
  final int? lastHitMidi;
  final Hand? lastHitHand;
  final int feedbackNonce;
  final bool settlementReady;
  final bool endHangActive;
  final String? statusHint;
  final List<GhostHit> ghostHits;
  final List<GhostHit> sessionHitLog;
  final int handsDialogueNonce;
  final int? handsDialogueLeftMidi;
  final int? handsDialogueRightMidi;

  double get durationBeats => score.durationBeats;
  List<ScoreNote> get filteredNotes => score.notesForHand(settings.hand);

  bool get hasSessionActivity => sessionHits > 0 || sessionMisses > 0;

  /// Suggested loop around the densest miss cluster; null if none.
  ({double start, double end})? get suggestedWeakLoop =>
      PracticeWeakLoopLogic.suggest(
        missBeats: missBeats,
        durationBeats: durationBeats,
      );

  bool get isLeadInRitual =>
      isPlaying && !endHangActive && positionBeats < -0.02;

  double get nominalBeatsPerSec => score.bpm * settings.speed / 60.0;

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

  double get staffBeatsPerSec {
    if (!isPlaying || endHangActive) return 0;
    if (settings.mode.isAutoPlay) return nominalBeatsPerSec;
    if (isWaitFrozenAtOnset) return 0;
    return nominalBeatsPerSec;
  }

  Map<int, Hand> highlightByHandAt(double atBeats) {
    final Set<int> midis;
    if (settings.mode.isAutoPlay) {
      midis = {
        for (final n in filteredNotes)
          if (atBeats >= n.start && atBeats < n.end) n.midi,
      };
    } else {
      midis = {...activeMidi, ...waitingFor};
    }
    if (midis.isEmpty) return const {};

    final map = <int, Hand>{};
    for (final midi in midis) {
      ScoreNote? best;
      for (final n in filteredNotes) {
        if (n.midi != midi) continue;
        if (settings.mode.isAutoPlay || activeMidi.contains(midi)) {
          if (atBeats >= n.start && atBeats < n.end) {
            best = n;
            break;
          }
        }
        if (waitingFor.contains(midi)) {
          if (best == null ||
              (n.start - atBeats).abs() < (best.start - atBeats).abs()) {
            best = n;
          }
        }
      }
      map[midi] = best?.hand ?? Hand.right;
    }
    return map;
  }

  Map<int, Hand> get highlightByHand => highlightByHandAt(positionBeats);

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
    List<double>? missBeats,
    int? perfectCount,
    int? goodCount,
    int? combo,
    int? maxCombo,
    HitGrade? lastGrade,
    bool clearLastGrade = false,
    int? lastHitMidi,
    bool clearLastHitMidi = false,
    Hand? lastHitHand,
    bool clearLastHitHand = false,
    int? feedbackNonce,
    bool? settlementReady,
    bool? endHangActive,
    String? statusHint,
    bool clearStatusHint = false,
    List<GhostHit>? ghostHits,
    List<GhostHit>? sessionHitLog,
    int? handsDialogueNonce,
    int? handsDialogueLeftMidi,
    int? handsDialogueRightMidi,
    bool clearHandsDialogue = false,
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
      missBeats: missBeats ?? this.missBeats,
      perfectCount: perfectCount ?? this.perfectCount,
      goodCount: goodCount ?? this.goodCount,
      combo: combo ?? this.combo,
      maxCombo: maxCombo ?? this.maxCombo,
      lastGrade: clearLastGrade ? null : (lastGrade ?? this.lastGrade),
      lastHitMidi:
          clearLastHitMidi ? null : (lastHitMidi ?? this.lastHitMidi),
      lastHitHand:
          clearLastHitHand ? null : (lastHitHand ?? this.lastHitHand),
      feedbackNonce: feedbackNonce ?? this.feedbackNonce,
      settlementReady: settlementReady ?? this.settlementReady,
      endHangActive: endHangActive ?? this.endHangActive,
      statusHint: clearStatusHint ? null : (statusHint ?? this.statusHint),
      ghostHits: ghostHits ?? this.ghostHits,
      sessionHitLog: sessionHitLog ?? this.sessionHitLog,
      handsDialogueNonce: handsDialogueNonce ?? this.handsDialogueNonce,
      handsDialogueLeftMidi: clearHandsDialogue
          ? null
          : (handsDialogueLeftMidi ?? this.handsDialogueLeftMidi),
      handsDialogueRightMidi: clearHandsDialogue
          ? null
          : (handsDialogueRightMidi ?? this.handsDialogueRightMidi),
    );
  }
}
