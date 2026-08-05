import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import 'exam_pcm_recorder.dart';
import 'guide_retrigger_gate.dart';
import 'note_window_index.dart';
import 'pitch_service.dart';
import 'practice_clock.dart';
import 'practice_constants.dart';
import 'practice_ghost_store.dart';
import 'practice_judge_logic.dart';
import 'practice_loop_logic.dart';
import 'practice_models.dart';
import 'practice_stats_store.dart';
import 'practice_wait_logic.dart';
import 'score_audio_player.dart';

export 'practice_models.dart';

class PracticeController extends Notifier<PracticeSnapshot> {
  PracticeController(this._score);

  final SongScore _score;

  /// Live playhead — drives waterfall / staff / seek slider without Riverpod.
  final PracticeClock clock = PracticeClock();

  Timer? _ticker;
  StreamSubscription<int>? _pitchSub;
  StreamSubscription<PitchFrame>? _pitchFrameSub;
  DateTime? _lastTick;
  DateTime? _sessionStarted;
  Set<int> _satisfied = {};
  Set<String> _audioFired = {};
  Set<int> _pitchPressed = {};
  final GuideRetriggerGate _guideGate = GuideRetriggerGate(
    quietFramesNeeded: PracticeConstants.guideQuietFramesNeeded,
  );
  final NoteOnsetCursor _guideCursor = NoteOnsetCursor();

  /// Chord onset beat we already soft-cued guide for (avoid re-fire while frozen).
  double? _guideCuedChordStart;

  /// MIDI → suppress mic echo until this time (speaker guide → mic feedback).
  final Map<int, DateTime> _echoSuppressUntil = {};

  /// Throttle mic → UI pressedMidi updates (~20 Hz).
  DateTime? _lastPressedUiPush;
  bool _playPreparing = false;
  bool _statsFlushed = false;
  bool _allowExamSeek = false;
  Timer? _endHangTimer;
  final ExamPcmRecorder _examRecorder = ExamPcmRecorder();
  String? _lastExamRecordingPath;

  /// Hands-dialogue tracking.
  DateTime? _lastGradedAt;
  Hand? _lastGradedHand;
  int? _lastGradedMidi;

  ScoreAudioPlayer get _audio => ref.read(scoreAudioProvider);
  PitchService get _pitch => ref.read(pitchServiceProvider);

  double get _pos => clock.positionBeats;

  List<ScoreNote> get _notes => state.filteredNotes;

  @override
  PracticeSnapshot build() {
    final pitch = ref.read(pitchServiceProvider);
    final audio = ref.read(scoreAudioProvider);
    final stats = ref.read(practiceStatsProvider.notifier);
    unawaited(_bootstrapAudioAndPitch(pitch));
    _pitchSub =
        pitch.noteOnStream.listen((midi) => _onNoteOn(midi, playSound: false));
    _pitchFrameSub = pitch.frameStream.listen(_onPitchFrame);
    ref.onDispose(() {
      _ticker?.cancel();
      _endHangTimer?.cancel();
      _pitchSub?.cancel();
      _pitchFrameSub?.cancel();
      _pitch.pcmTee = null;
      unawaited(_examRecorder.stop());
      audio.setTransportPlaying(false);
      unawaited(pitch.stop());
      unawaited(_flushStatsTo(stats));
      clock.dispose();
    });

    final end = _score.durationBeats.clamp(1.0, double.infinity);
    final settings = PracticeSettings(loopEnd: end > 4 ? 4 : end);
    final park = PracticeConstants.playbackStartParkBeats;
    clock.setTransport(positionBeats: park, beatsPerSec: 0);
    // Defer prefetch until after this build returns — reading [state] here
    // throws "uninitialized provider" (Riverpod circular/self-read).
    final warmHand = settings.hand;
    scheduleMicrotask(() {
      unawaited(_prefetchAround(park, aheadBeats: 10, hand: warmHand));
      unawaited(_loadGhost());
    });
    return PracticeSnapshot(
      score: _score,
      settings: settings,
      positionBeats: park,
      waitingFor: _expectedAt(_score, park, settings),
    );
  }

  Future<void> _loadGhost() async {
    final hits = await PracticeGhostStore.load(_score.id);
    try {
      state = state.copyWith(ghostHits: hits);
    } catch (_) {
      // Provider disposed.
    }
  }

  String? get lastExamRecordingPath => _lastExamRecordingPath;

  void _onPitchFrame(PitchFrame f) {
    if (state.settings.mode.isAutoPlay) return;
    _pitchPressed = {
      for (final m in f.midis)
        if (!_isEchoSuppressed(m)) m,
    };
    _syncPressedMidi(throttle: true);
    if (!state.isPlaying || !state.settings.mode.isPractice) return;
    if (state.endHangActive) return;
    if (state.waitingFor.isEmpty) return;

    final stillSuppressed = {
      for (final m in _guideGate.awaitingGap)
        if (_isEchoSuppressed(m)) m,
    };
    final hits = _guideGate.acceptHits(
      heard: _pitchPressed,
      waitingFor: state.waitingFor,
      stillSuppressed: stillSuppressed,
    );
    for (final m in hits) {
      _registerWaitHit(m);
    }
  }

  Future<void> _bootstrapAudioAndPitch(PitchService pitch) async {
    try {
      await _audio.ensureReady();
      _audio.setMasterVolume(state.settings.volume);
    } catch (e) {
      pianoFlowLog('Practice', '示范音初始化失败：$e');
      state = state.copyWith(
        statusHint: '示范音初始化失败（详情见控制台 [PianoFlow/Practice]）',
      );
    }
    if (!state.settings.mode.isAutoPlay) {
      await _startPitch(pitch);
    }
  }

  Future<void> _startPitch(PitchService pitch) async {
    if (state.settings.mode.isAutoPlay) return;
    await pitch.start();
    if (state.settings.mode.isAutoPlay) {
      await pitch.stop();
      return;
    }
    final err = pitch.lastError;
    if (err != null && err.isNotEmpty) {
      pianoFlowLog('Practice', '麦克风：$err');
      state = state.copyWith(statusHint: err);
    }
  }

  Future<void> _stopPitch(PitchService pitch) async {
    _pitchPressed = {};
    _echoSuppressUntil.clear();
    _guideGate.clear();
    if (state.pressedMidi.isNotEmpty) {
      state = state.copyWith(pressedMidi: const {});
    }
    await pitch.stop();
  }

  void _syncPressedMidi({bool throttle = false}) {
    final merged = {..._pitchPressed};
    final changed = merged.length != state.pressedMidi.length ||
        !merged.containsAll(state.pressedMidi) ||
        !state.pressedMidi.containsAll(merged);
    if (!changed) return;
    if (throttle) {
      final now = DateTime.now();
      final last = _lastPressedUiPush;
      if (last != null && now.difference(last).inMilliseconds < 50) {
        return;
      }
      _lastPressedUiPush = now;
    }
    state = state.copyWith(pressedMidi: merged);
  }

  void _markSelfPlayed(int midi, {Duration? duration}) {
    final until =
        DateTime.now().add(duration ?? PracticeConstants.echoSuppress);
    void arm(int m) {
      if (m < PracticeConstants.midiMin || m > PracticeConstants.midiMax) {
        return;
      }
      final prev = _echoSuppressUntil[m];
      if (prev == null || prev.isBefore(until)) {
        _echoSuppressUntil[m] = until;
      }
    }

    arm(midi);
    arm(midi - 1);
    arm(midi + 1);
    for (final interval in const [12, 19, 24, 28, 31, 36]) {
      arm(midi + interval);
      arm(midi - interval);
    }
  }

  bool _isEchoSuppressed(int midi) {
    final until = _echoSuppressUntil[midi];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _echoSuppressUntil.remove(midi);
    return false;
  }

  void updateSettings(PracticeSettings settings) {
    var loopEnd = settings.loopEnd;
    final maxBeat = _score.durationBeats;
    if (loopEnd > maxBeat) loopEnd = maxBeat;
    if (loopEnd <= settings.loopStart) {
      loopEnd = (settings.loopStart + 2).clamp(0, maxBeat).toDouble();
    }
    var next = settings.copyWith(loopEnd: loopEnd);
    if (next.mode.isExam) {
      next = next.copyWith(loopEnabled: false, guideAudio: false);
    }
    if (next.mode.isAutoPlay) {
      next = next.copyWith(guideAudio: true);
    } else if (state.settings.mode.isAutoPlay && next.mode.isPractice) {
      next = next.copyWith(guideAudio: false);
    }
    final wasAuto = state.settings.mode.isAutoPlay;
    final nowAuto = next.mode.isAutoPlay;
    final speedChanged = (next.speed - state.settings.speed).abs() > 1e-6;
    final metroJustEnabled = next.metronome && !state.settings.metronome;
    _satisfied = {};
    _guideCursor.reset();
    _audio.setMetronomeBpm(_score.bpm.toDouble());
    _audio.setMetronome(next.metronome);
    _audio.setSpeed(next.speed);
    _audio.setMasterVolume(next.volume);
    _audio.setHand(next.hand);
    if (PracticeLoopLogic.shouldRealignMetronome(
      isPlaying: state.isPlaying,
      metronomeEnabled: next.metronome,
      speedChanged: speedChanged,
      metronomeJustEnabled: metroJustEnabled,
    )) {
      _audio.alignMetronomeToPosition(_pos);
    }
    final waiting =
        nowAuto ? <int>{} : _expectedAt(_score, _pos, next);
    if (nowAuto) {
      _pitchPressed = {};
      _echoSuppressUntil.clear();
      _guideGate.clear();
    }
    state = state.copyWith(
      settings: next,
      positionBeats: _pos,
      waitingFor: waiting,
      activeMidi: _activeAt(_score.notesForHand(next.hand), _pos),
      pressedMidi: nowAuto ? const {} : state.pressedMidi,
    );
    _syncClockRate();
    final pitch = ref.read(pitchServiceProvider);
    if (nowAuto && !wasAuto) {
      unawaited(_stopPitch(pitch));
    } else if (!nowAuto && wasAuto) {
      unawaited(_startPitch(pitch));
    }
  }

  void togglePlay() => state.isPlaying ? pause() : play();

  void play() {
    if (state.isPlaying || _playPreparing) return;
    unawaited(_playPrepared());
  }

  Future<void> _playPrepared() async {
    if (state.isPlaying || _playPreparing) return;
    _playPreparing = true;
    try {
      if (!_audio.isReady) {
        try {
          await _audio.ensureReady();
        } catch (e) {
          pianoFlowLog('Practice', '示范音初始化失败：$e');
          state = state.copyWith(
            statusHint: '示范音初始化失败（详情见控制台 [PianoFlow/Practice]）',
          );
          return;
        }
      }
      if (state.isPlaying) return;
      final startPos = _withStartLeadIn(_pos);
      // Bind first sounding notes BEFORE the transport clock starts so the
      // opening chord does not create AudioPlayers on the audible frame.
      state = state.copyWith(statusHint: '正在预热音色…');
      try {
        await _audio.prefetchMidis(
          _midisInWindow(
            startPos,
            aheadBeats: 8,
            hand: state.settings.hand,
          ),
        ).timeout(const Duration(milliseconds: 900));
      } on TimeoutException {
        pianoFlowLog('Practice', 'opening tone prefetch timed out — continue');
      } catch (e) {
        pianoFlowLog('Practice', 'opening tone prefetch failed: $e');
      }
      if (state.isPlaying) return;
      _startTransport();
      unawaited(_prefetchAround(startPos, aheadBeats: 32));
    } finally {
      _playPreparing = false;
    }
  }

  Future<void> _prefetchAround(
    double pos, {
    required double aheadBeats,
    Hand? hand,
  }) {
    return _audio.prefetchMidis(
      _midisInWindow(pos, aheadBeats: aheadBeats, hand: hand),
    );
  }

  Set<int> _midisInWindow(
    double pos, {
    required double aheadBeats,
    Hand? hand,
  }) {
    final from = pos - 0.25;
    final to = pos + aheadBeats;
    final out = <int>{};
    final notes = _score.notesForHand(hand ?? state.settings.hand);
    for (final n in notes) {
      if (n.start < from) continue;
      if (n.start > to) break; // notes sorted by start
      out.add(n.midi);
    }
    return out;
  }

  void _startTransport() {
    _sessionStarted ??= DateTime.now();
    _lastTick = DateTime.now();
    final startPos = _withStartLeadIn(_pos);
    final auto = state.settings.mode.isAutoPlay;
    final waiting = auto
        ? const <int>{}
        : _expectedAt(_score, startPos, state.settings);
    final active = _activeAt(_notes, startPos);
    state = state.copyWith(
      isPlaying: true,
      positionBeats: startPos,
      clearStatusHint: true,
      waitingFor: waiting,
      activeMidi: active,
      endHangActive: false,
      settlementReady: false,
    );
    _pushClock(startPos, playing: true);
    // Spread metro/audio side-effects off the same sync stack as the first
    // Riverpod+clock notify (reduces play-button hitch).
    scheduleMicrotask(() {
      if (!state.isPlaying) return;
      _audio.setMetronomeBpm(_score.bpm.toDouble());
      _audio.setSpeed(state.settings.speed);
      _audio.setMasterVolume(state.settings.volume);
      _audio.alignMetronomeToPosition(startPos);
      _audio.setTransportPlaying(true);
      _audio.setMetronome(state.settings.metronome);
    });
    _ticker?.cancel();
    if (auto) {
      _playGuideAt(startPos);
    } else {
      _armGuideThrough(startPos);
    }
    unawaited(_maybeStartExamRecording());
    _ticker = Timer.periodic(PracticeConstants.tickPeriod, (_) => _tick());
  }

  Future<void> _maybeStartExamRecording() async {
    if (!state.settings.mode.isExam || !state.settings.examRecordAudio) {
      return;
    }
    _pitch.pcmTee = _examRecorder.addPcm16;
    await _examRecorder.start(songId: _score.id);
  }

  Future<void> _stopExamRecording() async {
    _pitch.pcmTee = null;
    final path = await _examRecorder.stop();
    if (path != null) _lastExamRecordingPath = path;
  }

  double _withStartLeadIn(double pos) => PracticeLoopLogic.withStartLeadIn(pos);

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    _endHangTimer?.cancel();
    _endHangTimer = null;
    unawaited(_stopExamRecording());
    state = state.copyWith(
      isPlaying: false,
      positionBeats: _pos,
      endHangActive: false,
    );
    _pushClock(_pos, playing: false);
    _audio.setTransportPlaying(false);
  }

  void seek(double beats) {
    if (state.settings.mode.isExam && !_allowExamSeek) {
      pianoFlowLog('Practice', 'exam mode: seek blocked');
      return;
    }
    _endHangTimer?.cancel();
    _endHangTimer = null;
    final clamped = beats.clamp(0.0, _score.durationBeats);
    final target = _withStartLeadIn(clamped);
    _satisfied = {};
    _audioFired = {};
    _guideCuedChordStart = null;
    _guideGate.clear();
    _audio.alignMetronomeToPosition(target);
    if (state.isPlaying && state.settings.metronome) {
      _audio.setTransportPlaying(true);
      _audio.setMetronome(true);
    }
    final auto = state.settings.mode.isAutoPlay;
    final waiting =
        auto ? <int>{} : _expectedAt(_score, target, state.settings);
    state = state.copyWith(
      positionBeats: target,
      waitingFor: waiting,
      activeMidi: _activeAt(_notes, target),
      pressedMidi: auto ? const {} : {..._pitchPressed},
      endHangActive: false,
      settlementReady: false,
    );
    _pushClock(target, playing: state.isPlaying, intentionalSeek: true);
    if (auto) {
      _armGuideBefore(target);
    } else {
      _armGuideThrough(target);
    }
    unawaited(_prefetchAround(target, aheadBeats: 12));
  }

  void restart() {
    _allowExamSeek = true;
    try {
      _audioFired = {};
      seek(state.settings.loopEnabled && state.settings.mode.allowsLoop
          ? state.settings.loopStart
          : 0);
    } finally {
      _allowExamSeek = false;
    }
  }

  /// Clear session grade counters and park at start (「再练一次」).
  void resetSessionAndRestart() {
    _satisfied = {};
    _audioFired = {};
    _guideCuedChordStart = null;
    _guideGate.clear();
    _guideCursor.reset();
    _statsFlushed = false;
    _sessionStarted = null;
    _lastGradedAt = null;
    _lastGradedHand = null;
    _lastGradedMidi = null;
    _lastExamRecordingPath = null;
    state = state.copyWith(
      sessionHits: 0,
      sessionMisses: 0,
      perfectCount: 0,
      goodCount: 0,
      combo: 0,
      maxCombo: 0,
      clearLastGrade: true,
      settlementReady: false,
      endHangActive: false,
      feedbackNonce: state.feedbackNonce + 1,
      sessionHitLog: const [],
      clearHandsDialogue: true,
    );
    _allowExamSeek = true;
    try {
      seek(0);
    } finally {
      _allowExamSeek = false;
    }
  }

  /// Mark settlement UI as consumed (sheet dismissed without leaving).
  void clearSettlementReady() {
    if (!state.settlementReady) return;
    state = state.copyWith(settlementReady: false);
  }

  /// Persist session stats if not already flushed (settlement / leave).
  Future<void> flushStatsIfNeeded() =>
      _flushStatsTo(ref.read(practiceStatsProvider.notifier));

  Future<void> _flushStatsTo(PracticeStatsController stats) async {
    if (_statsFlushed) return;
    if (_sessionStarted == null && !state.hasSessionActivity) return;
    _statsFlushed = true;
    final started = _sessionStarted ?? DateTime.now();
    final seconds =
        DateTime.now().difference(started).inSeconds.clamp(1, 86400);
    await stats.recordSession(
      songId: _score.id,
      seconds: seconds,
      hits: state.sessionHits,
      misses: state.sessionMisses,
      perfects: state.perfectCount,
      goods: state.goodCount,
      maxCombo: state.maxCombo,
      isExam: state.settings.mode.isExam,
    );
  }

  void _onNoteOn(int midi, {bool playSound = true}) {
    if (state.settings.mode.isAutoPlay) return;
    if (_isEchoSuppressed(midi)) return;

    final gateBlocks = _guideGate.blocks(midi);
    if (playSound) {
      _audio.playOneShot(midi, hand: state.highlightByHand[midi]);
      if (!gateBlocks) {
        _markSelfPlayed(midi);
      }
    }
    if (gateBlocks) return;

    _syncPressedMidi();
    if (!state.pressedMidi.contains(midi)) {
      state = state.copyWith(pressedMidi: {...state.pressedMidi, midi});
    }
    if (!state.isPlaying || !state.settings.mode.isPractice) return;
    if (state.endHangActive) return;

    if (state.waitingFor.contains(midi)) {
      _guideGate.disarm([midi]);
      _registerWaitHit(midi);
    } else if (state.waitingFor.isNotEmpty) {
      final chordStart = PracticeWaitLogic.chordStartForExpected(
        notes: _notes,
        expected: state.waitingFor.union(_satisfied),
        pos: _pos,
      );
      if (chordStart != null &&
          PracticeWaitLogic.shouldFreezeAt(
            pos: _pos,
            chordStart: chordStart,
          )) {
        state = state.copyWith(
          sessionMisses: state.sessionMisses + 1,
          combo: 0,
          lastGrade: HitGrade.miss,
          feedbackNonce: state.feedbackNonce + 1,
        );
      }
    }
  }

  void _registerWaitHit(int midi) {
    if (!state.waitingFor.contains(midi)) return;
    if (_satisfied.contains(midi)) return;

    final chordStart = PracticeWaitLogic.chordStartForExpected(
          notes: _notes,
          expected: state.waitingFor.union(_satisfied),
          pos: _pos,
        ) ??
        _pos;
    final grade = PracticeJudgeLogic.gradeFromDelta(_pos - chordStart);
    final nextCombo = state.combo + 1;
    final nextMax = nextCombo > state.maxCombo ? nextCombo : state.maxCombo;
    final perfects =
        state.perfectCount + (grade == HitGrade.perfect ? 1 : 0);
    final goods = state.goodCount + (grade == HitGrade.good ? 1 : 0);

    Hand hitHand = Hand.right;
    for (final n in _notes) {
      if (n.midi == midi && (n.start - chordStart).abs() < 0.05) {
        hitHand = n.hand;
        break;
      }
    }

    final now = DateTime.now();
    var dialogueNonce = state.handsDialogueNonce;
    int? dlgL = state.handsDialogueLeftMidi;
    int? dlgR = state.handsDialogueRightMidi;
    if (_lastGradedAt != null &&
        _lastGradedHand != null &&
        _lastGradedMidi != null &&
        _lastGradedHand != hitHand &&
        now.difference(_lastGradedAt!).inMilliseconds <=
            PracticeConstants.handsDialogueMs) {
      dialogueNonce++;
      if (hitHand == Hand.left) {
        dlgL = midi;
        dlgR = _lastGradedMidi;
      } else {
        dlgR = midi;
        dlgL = _lastGradedMidi;
      }
    }
    _lastGradedAt = now;
    _lastGradedHand = hitHand;
    _lastGradedMidi = midi;

    final ghost = GhostHit(beat: chordStart, midi: midi, grade: grade);
    final log = [...state.sessionHitLog, ghost];

    _satisfied = {..._satisfied, midi};
    final remaining = {...state.waitingFor}..removeAll(_satisfied);
    state = state.copyWith(
      waitingFor: remaining,
      sessionHits: state.sessionHits + 1,
      perfectCount: perfects,
      goodCount: goods,
      combo: nextCombo,
      maxCombo: nextMax,
      lastGrade: grade,
      lastHitMidi: midi,
      lastHitHand: hitHand,
      feedbackNonce: state.feedbackNonce + 1,
      positionBeats: _pos,
      sessionHitLog: log,
      handsDialogueNonce: dialogueNonce,
      handsDialogueLeftMidi: dlgL,
      handsDialogueRightMidi: dlgR,
    );
    if (remaining.isEmpty) {
      _advancePastCurrentChord();
    }
  }

  void _tick() {
    if (!state.isPlaying) return;
    if (state.endHangActive) {
      _pushClock(_pos, playing: true);
      return;
    }
    final now = DateTime.now();
    final last = _lastTick ?? now;
    _lastTick = now;
    final dtSec = now.difference(last).inMicroseconds / 1e6;
    final bpm = _score.bpm * state.settings.speed;
    final beatDelta = dtSec * (bpm / 60.0);

    if (state.settings.mode.isPractice) {
      final notes = _notes;
      final expected =
          PracticeWaitLogic.expectedAt(notes: notes, pos: _pos);
      if (expected.isNotEmpty && !_satisfied.containsAll(expected)) {
        final chordStart = PracticeWaitLogic.chordStartForExpected(
              notes: notes,
              expected: expected,
              pos: _pos,
            ) ??
            _pos;
        final freeze = PracticeWaitLogic.shouldFreezeAt(
          pos: _pos,
          chordStart: chordStart,
        );
        final waiting = expected.difference(_satisfied);
        _publishLogicIfChanged(waitingFor: waiting, activeMidi: expected);
        if (freeze) {
          // Keep clock frozen (rate 0) without Riverpod spam.
          _pushClock(_pos, playing: true);
          _cueGuideIfNeeded(chordStart, expected);
          return;
        }
        _advance(beatDelta);
        return;
      }
      _guideCuedChordStart = null;
      if (expected.isEmpty) {
        _advance(beatDelta);
        _playGuideAt(_pos);
      }
      return;
    }

    _advance(beatDelta);
    _playGuideAt(_pos);
  }

  void _cueGuideIfNeeded(double chordStart, Set<int> expected) {
    if (_guideCuedChordStart != null &&
        (_guideCuedChordStart! - chordStart).abs() < 0.001) {
      return;
    }
    _guideCuedChordStart = chordStart;
    if (!state.settings.guideAudio) return;
    final volume = PracticeConstants.guideVolumeWithMic;
    final cued = <int>{};
    for (final n in _notes) {
      if (!expected.contains(n.midi)) continue;
      if ((n.start - chordStart).abs() >=
          PracticeConstants.waitChordClusterBeats) {
        continue;
      }
      final key = '${n.midi}_${n.start}_${n.hand.name}';
      if (_audioFired.contains(key)) continue;
      _audioFired.add(key);
      cued.add(n.midi);
      _markSelfPlayed(n.midi, duration: PracticeConstants.echoSuppressGuide);
      _audio.playOneShot(n.midi, volume: volume, hand: n.hand);
    }
    if (cued.isNotEmpty) {
      _guideGate.arm(cued);
      _pitch.clearEmitted(cued);
      pianoFlowLog(
        'Practice',
        'guide cue ${cued.map((m) => m).join(",")} + retrigger gate',
      );
    }
  }

  void _armGuideThrough(double pos) {
    for (final n in _notes) {
      if (n.start <= pos) {
        _audioFired.add('${n.midi}_${n.start}_${n.hand.name}');
      }
    }
    _guideCursor.seekThrough(_notes, pos);
  }

  void _armGuideBefore(double pos) {
    for (final n in _notes) {
      if (n.start < pos - 0.01) {
        _audioFired.add('${n.midi}_${n.start}_${n.hand.name}');
      }
    }
    _guideCursor.seekBefore(_notes, pos);
  }

  void _playGuideAt(double pos) {
    final auto = state.settings.mode.isAutoPlay;
    if (!auto && !state.settings.guideAudio) return;
    final volume = auto ? 1.0 : PracticeConstants.guideVolumeWithMic;
    final cued = <int>{};
    for (final n in _guideCursor.takeDue(_notes, pos)) {
      final key = '${n.midi}_${n.start}_${n.hand.name}';
      if (_audioFired.contains(key)) continue;
      _audioFired.add(key);
      _markSelfPlayed(
        n.midi,
        duration: auto ? null : PracticeConstants.echoSuppressGuide,
      );
      if (!auto) {
        cued.add(n.midi);
      }
      _audio.playOneShot(n.midi, volume: volume, hand: n.hand);
    }
    if (cued.isNotEmpty) {
      _pitch.clearEmitted(cued);
    }
  }

  void _advancePastCurrentChord() {
    final notes = _notes;
    final pos = _pos;
    final nextPos = PracticeWaitLogic.nudgePastChord(notes: notes, pos: pos);
    _satisfied = {};
    _guideCuedChordStart = null;
    _guideGate.clear();
    _armGuideThrough(pos);
    _applyPosition(nextPos);
  }

  void _advance(double beatDelta) {
    var next = _pos + beatDelta;
    final settings = state.settings;
    if (settings.loopEnabled && settings.mode.allowsLoop) {
      final wrapped = PracticeLoopLogic.wrapIfPastEnd(
        next: next,
        loopStart: settings.loopStart,
        loopEnd: settings.loopEnd,
      );
      if (wrapped != null) {
        next = wrapped;
        _satisfied = {};
        _audioFired = {};
        _guideCuedChordStart = null;
        _guideGate.clear();
        _guideCursor.reset();
        _audio.alignMetronomeToPosition(next);
        _applyPosition(next);
        _pushClock(next, playing: true, intentionalSeek: true);
        return;
      }
    } else if (next >= _score.durationBeats) {
      next = _score.durationBeats;
      _applyPosition(next);
      if (state.settings.mode.isPractice && state.hasSessionActivity) {
        _beginEndHang();
      } else {
        pause();
      }
      return;
    }
    _applyPosition(next);
  }

  void _beginEndHang() {
    if (state.endHangActive) return;
    _ticker?.cancel();
    _ticker = null;
    final lastActive = state.activeMidi.isNotEmpty
        ? state.activeMidi
        : _activeAt(_notes, _score.durationBeats - 0.01);
    state = state.copyWith(
      isPlaying: true,
      endHangActive: true,
      positionBeats: _score.durationBeats,
      activeMidi: lastActive,
      waitingFor: const {},
    );
    _pushClock(_score.durationBeats, playing: true);
    _audio.setTransportPlaying(false);
    _endHangTimer?.cancel();
    _endHangTimer = Timer(
      const Duration(milliseconds: PracticeConstants.endHangMs),
      _finishEndHang,
    );
  }

  void _finishEndHang() {
    _endHangTimer = null;
    unawaited(_finalizeExamArtifacts());
    state = state.copyWith(
      isPlaying: false,
      endHangActive: false,
      settlementReady: state.settings.mode.isPractice && state.hasSessionActivity,
    );
    _pushClock(_pos, playing: false);
  }

  Future<void> _finalizeExamArtifacts() async {
    await _stopExamRecording();
    if (!state.settings.mode.isExam) return;
    if (state.sessionHitLog.isEmpty) return;
    await PracticeGhostStore.save(_score.id, state.sessionHitLog);
    state = state.copyWith(ghostHits: state.sessionHitLog);
  }

  void _applyPosition(double next) {
    if (state.settings.mode.isAutoPlay) {
      final active = _activeAt(_notes, next);
      _publishLogicIfChanged(
        waitingFor: const {},
        activeMidi: active,
        positionBeats: next,
      );
      _pushClock(next, playing: state.isPlaying);
      return;
    }
    final expected = PracticeWaitLogic.expectedAt(notes: _notes, pos: next);
    final waiting = expected.difference(_satisfied);
    final active = expected.isNotEmpty ? expected : _activeAt(_notes, next);
    _publishLogicIfChanged(
      waitingFor: waiting,
      activeMidi: active,
      positionBeats: next,
    );
    _pushClock(next, playing: state.isPlaying);
  }

  /// Riverpod notify only when waiting/active sets change (or forced pos sync).
  void _publishLogicIfChanged({
    required Set<int> waitingFor,
    required Set<int> activeMidi,
    double? positionBeats,
  }) {
    final pos = positionBeats ?? _pos;
    final waitingSame = _setEq(waitingFor, state.waitingFor);
    final activeSame = _setEq(activeMidi, state.activeMidi);
    if (waitingSame && activeSame) return;
    state = state.copyWith(
      positionBeats: pos,
      waitingFor: waitingFor,
      activeMidi: activeMidi,
    );
  }

  static bool _setEq(Set<int> a, Set<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  void _pushClock(
    double pos, {
    required bool playing,
    bool intentionalSeek = false,
  }) {
    clock.setTransport(
      positionBeats: pos,
      beatsPerSec: _staffRateAt(pos, playing: playing),
      intentionalSeek: intentionalSeek,
    );
  }

  void _syncClockRate() {
    _pushClock(_pos, playing: state.isPlaying);
  }

  double _staffRateAt(double pos, {required bool playing}) {
    if (!playing || state.endHangActive) return 0;
    final nominal = _score.bpm * state.settings.speed / 60.0;
    if (state.settings.mode.isAutoPlay) return nominal;
    if (state.waitingFor.isEmpty) return nominal;
    final chordStart = PracticeWaitLogic.chordStartForExpected(
      notes: _notes,
      expected: state.waitingFor,
      pos: pos,
    );
    if (chordStart != null &&
        PracticeWaitLogic.shouldFreezeAt(pos: pos, chordStart: chordStart)) {
      return 0;
    }
    return nominal;
  }

  Set<int> _expectedAt(
    SongScore score,
    double pos,
    PracticeSettings settings,
  ) {
    if (settings.mode.isAutoPlay) return {};
    return PracticeWaitLogic.expectedAt(
      notes: score.notesForHand(settings.hand),
      pos: pos,
    );
  }

  Set<int> _activeAt(List<ScoreNote> notes, double pos) {
    return NoteWindowIndex.activeMidiAt(notes, pos);
  }
}

final practiceProvider = NotifierProvider.autoDispose
    .family<PracticeController, PracticeSnapshot, SongScore>(
  PracticeController.new,
);
