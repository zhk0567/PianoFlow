import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import 'exam_pcm_recorder.dart';
import 'guide_retrigger_gate.dart';
import 'pitch_service.dart';
import 'practice_clock.dart';
import 'practice_constants.dart';
import 'practice_ghost_store.dart';
import 'practice_guide_hit_policy.dart';
import 'practice_hit_latency.dart';
import 'practice_judge_logic.dart';
import 'practice_loop_logic.dart';
import 'practice_models.dart';
import 'practice_pitch_match.dart';
import 'practice_pos_history.dart';
import 'practice_stats_store.dart';
import 'practice_wait_logic.dart';
import 'score_audio_player.dart';

export 'practice_models.dart';

class PracticeController extends Notifier<PracticeSnapshot> {
  PracticeController(this._score);

  final SongScore _score;

  /// ~60 Hz playhead for waterfall / staff / seek — not via Riverpod.
  final PracticeClock clock = PracticeClock();

  Timer? _ticker;
  StreamSubscription<PitchNoteOn>? _pitchSub;
  StreamSubscription<PitchFrame>? _pitchFrameSub;
  DateTime? _lastTick;
  DateTime? _sessionStarted;
  Set<int> _satisfied = {};
  Set<String> _audioFired = {};
  Set<int> _pitchPressed = {};
  final GuideRetriggerGate _guideGate = GuideRetriggerGate(
    quietFramesNeeded: PracticeConstants.guideQuietFramesNeeded,
  );

  /// Authoritative playhead (Riverpod [state.positionBeats] may lag between
  /// discrete notifies — UI animation must read [clock]).
  double _pos = 0;

  /// Chord onset beat we already soft-cued guide for (avoid re-fire while frozen).
  double? _guideCuedChordStart;

  /// MIDI → suppress mic echo until this time (speaker guide → mic feedback).
  final Map<int, DateTime> _echoSuppressUntil = {};

  /// Chord midis soft-cued; stopped on suppress end or early advance.
  Set<int> _guideCuedMidis = {};

  /// When the playhead last froze waiting for a chord (hit-latency probe).
  DateTime? _freezeSince;
  bool _lastMetroAdvancing = true;
  final PracticePosHistory _posHistory = PracticePosHistory();

  bool _allowExamSeek = false;
  bool _statsFlushed = false;
  Timer? _endHangTimer;
  Timer? _rewindTimer;
  Timer? _deferredClearEmitted;
  final ExamPcmRecorder _examRecorder = ExamPcmRecorder();
  String? _lastExamRecordingPath;
  DateTime? _lastGradedAt;
  Hand? _lastGradedHand;
  int? _lastGradedMidi;

  ScoreAudioPlayer get _audio => ref.read(scoreAudioProvider);
  PitchService get _pitch => ref.read(pitchServiceProvider);

  String? get lastExamRecordingPath => _lastExamRecordingPath;

  @override
  PracticeSnapshot build() {
    final pitch = ref.read(pitchServiceProvider);
    unawaited(_bootstrapAudioAndPitch(pitch));
    _pitchSub =
        pitch.noteOnStream.listen((e) => _onNoteOn(e, playSound: false));
    _pitchFrameSub = pitch.frameStream.listen(_onPitchFrame);
    ref.onDispose(() {
      _ticker?.cancel();
      _endHangTimer?.cancel();
      _rewindTimer?.cancel();
      _deferredClearEmitted?.cancel();
      _pitchSub?.cancel();
      _pitchFrameSub?.cancel();
      _pitch.pcmTee = null;
      unawaited(_examRecorder.stop());
      _audio.setTransportPlaying(false);
      unawaited(pitch.stop());
      unawaited(_flushStats());
      clock.dispose();
    });

    final end = _score.durationBeats.clamp(1.0, double.infinity);
    final settings = PracticeSettings(loopEnd: end > 4 ? 4 : end);
    // Park before the *first sounding note* (not always absolute −lead).
    final firstOnset = PracticeLoopLogic.firstOnsetBeats(
      _score.notesForHand(settings.hand).map((n) => n.start),
    );
    final park = PracticeLoopLogic.startParkBeats(firstOnset: firstOnset);
    _pos = park;
    clock.setParked(park);
    scheduleMicrotask(() => unawaited(_loadGhost()));
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
    } catch (_) {}
  }

  void _onPitchFrame(PitchFrame f) {
    // 自动播放关掉 mic；若仍有迟到帧，也不更新按下高亮。
    if (state.settings.mode.isAutoPlay) return;
    _pitchPressed = {
      for (final m in f.midis)
        if (!_isEchoSuppressed(m)) m,
    };
    _syncPressedMidi();
    if (!state.isPlaying || !state.settings.mode.isPractice) return;
    if (state.endHangActive) return;
    if (state.waitingFor.isEmpty) return;

    final stillSuppressed = {
      for (final m in _guideGate.awaitingGap)
        if (_isEchoSuppressed(m)) m,
    };
    // Frame path: only post-guide re-strikes (armed + quiet gap).
    // Ordinary attacks / no-guide practice use noteOn edges (_onNoteOn).
    final hits = _guideGate.acceptHits(
      heard: _pitchPressed,
      waitingFor: state.waitingFor,
      stillSuppressed: stillSuppressed,
    );
    for (final m in hits) {
      _registerWaitHit(m, captureAt: f.captureAt);
    }
  }

  Future<void> _bootstrapAudioAndPitch(PitchService pitch) async {
    try {
      await _audio.ensureReady();
      // Open window first so autoplay beat-0 is not still binding.
      await _audio.prefetchMidisNear(
        _score.notes,
        fromBeats: _pos,
        lookAheadBeats: 8,
      );
      unawaited(_audio.prefetchMidis(_score.notes.map((n) => n.midi)));
      _audio.setMasterVolume(state.settings.volume);
      // Device warm is silent zero-PCM inside ensureReady. Do NOT resume real
      // piano samples here — Windows volume-0 still leaks ("ghost notes" on open).
    } catch (e) {
      pianoFlowLog('Practice', '示范音初始化失败：$e');
      state = state.copyWith(
        statusHint: '示范音初始化失败（详情见控制台 [PianoFlow/Practice]）',
      );
    }
    // 仅跟弹练习开 mic；自动播放示范音进麦会误亮。
    if (!state.settings.mode.isAutoPlay) {
      await _startPitch(pitch);
    }
  }

  Future<void> _startPitch(PitchService pitch) async {
    if (state.settings.mode.isAutoPlay) return;
    await pitch.start();
    // start() 异步期间可能已切到自动播放。
    if (state.settings.mode.isAutoPlay) {
      await pitch.stop();
      return;
    }
    final err = pitch.lastError;
    if (err != null && err.isNotEmpty) {
      pianoFlowLog('Practice', '麦克风：$err');
      state = state.copyWith(
        statusHint: err.contains('权限')
            ? '跟弹需要麦克风权限。请在系统设置中允许 PianoFlow 使用麦克风后重试。'
            : err,
      );
    }
  }

  Future<void> _stopPitch(PitchService pitch) async {
    _pitchPressed = {};
    _echoSuppressUntil.clear();
    _resetGuideRetrigger();
    if (state.pressedMidi.isNotEmpty) {
      state = state.copyWith(pressedMidi: const {});
    }
    await pitch.stop();
  }

  void _syncPressedMidi() {
    final merged = {..._pitchPressed};
    if (merged.length != state.pressedMidi.length ||
        !merged.containsAll(state.pressedMidi) ||
        !state.pressedMidi.containsAll(merged)) {
      state = state.copyWith(pressedMidi: merged);
    }
  }

  void _markSelfPlayed(
    int midi, {
    Duration? duration,
    bool partials = true,
  }) {
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
    // Detune / neighbor bins the estimator often locks onto.
    arm(midi - 1);
    arm(midi + 1);
    // Loud speaker hits bleed piano partials into the mic; soft cues do not —
    // fanning partials there blocks re-hitting the same pitch for too long.
    if (partials) {
      for (final interval in const [12, 19, 24, 28, 31, 36]) {
        arm(midi + interval);
        arm(midi - interval);
      }
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
    // Loop UI removed — always keep loop off; end-of-piece rewinds to start.
    var next = settings.copyWith(loopEnd: loopEnd, loopEnabled: false);
    final wasAuto = state.settings.mode.isAutoPlay;
    final handChanged = next.hand != state.settings.hand;
    if (next.mode.isExam) {
      next = next.copyWith(guideAudio: false);
    }
    // 自动播放始终开启示范音。
    if (next.mode.isAutoPlay) {
      next = next.copyWith(guideAudio: true);
    } else if (wasAuto && next.mode.isPractice) {
      next = next.copyWith(guideAudio: false);
    }
    final nowAuto = next.mode.isAutoPlay;
    final speedChanged =
        (next.speed - state.settings.speed).abs() > 1e-6;
    final metroJustEnabled = next.metronome && !state.settings.metronome;
    _satisfied = {};
    if (handChanged) {
      final onset = PracticeLoopLogic.firstOnsetBeats(
        _score.notesForHand(next.hand).map((n) => n.start),
      );
      if (_pos <= PracticeConstants.playbackLeadInSeekEps ||
          (_pos - onset).abs() <= PracticeConstants.playbackLeadInSeekEps ||
          (_pos + 1e-9 >= PracticeLoopLogic.startParkBeats(firstOnset: onset) &&
              _pos < onset - 1e-9)) {
        _pos = PracticeLoopLogic.withStartLeadIn(_pos, firstOnset: onset);
      }
    }
    _audio.setMetronomeBpm(_score.bpm.toDouble());
    _audio.setMetronome(next.metronome);
    _audio.setSpeed(next.speed);
    _audio.setMasterVolume(next.volume);
    _audio.setHand(next.hand);
    // Staff already follows settings.speed via staffBeatsPerSec; metro must
    // re-phase to the playhead or clicks drift after a mid-play speed change.
    if (PracticeLoopLogic.shouldRealignMetronome(
      isPlaying: state.isPlaying,
      metronomeEnabled: next.metronome,
      speedChanged: speedChanged,
      metronomeJustEnabled: metroJustEnabled,
    )) {
      _audio.alignMetronomeToPosition(_pos);
    }
    final waiting = nowAuto
        ? <int>{}
        : _expectedAt(_score, _pos, next);
    if (nowAuto) {
      _pitchPressed = {};
      _echoSuppressUntil.clear();
      _resetGuideRetrigger();
    }
    state = state.copyWith(
      settings: next,
      positionBeats: _pos,
      waitingFor: waiting,
      activeMidi: _activeAt(_score.notesForHand(next.hand), _pos),
      pressedMidi: nowAuto ? const {} : state.pressedMidi,
    );
    _syncClock();
    // 自动播放关 mic；回到跟弹再开。不靠回声抑制挡示范音。
    final pitch = ref.read(pitchServiceProvider);
    if (nowAuto && !wasAuto) {
      unawaited(_stopPitch(pitch));
    } else if (!nowAuto && wasAuto) {
      unawaited(_startPitch(pitch));
    }
  }

  void togglePlay() => state.isPlaying ? pause() : play();

  void play() {
    if (state.isPlaying) return;
    // Avoid starting the transport while tones are still binding — otherwise
    // beat-0 one-shots queue behind ensureReady and feel like ~1s of silence.
    if (!_audio.isReady) {
      unawaited(_playWhenReady());
      return;
    }
    _startTransport();
  }

  Future<void> _playWhenReady() async {
    try {
      await _audio.ensureReady();
      await _audio.prefetchMidisNear(
        _score.notes,
        fromBeats: _pos,
        lookAheadBeats: 8,
      );
      unawaited(_audio.prefetchMidis(_score.notes.map((n) => n.midi)));
    } catch (e) {
      pianoFlowLog('Practice', '示范音初始化失败：$e');
      state = state.copyWith(
        statusHint: '示范音初始化失败（详情见控制台 [PianoFlow/Practice]）',
      );
      return;
    }
    if (state.isPlaying) return;
    _startTransport();
  }

  void _startTransport() {
    _cancelEndRitual();
    _sessionStarted ??= DateTime.now();
    _lastTick = DateTime.now();
    // From piece start: run a pre-roll so the first note is not immediate.
    // Idle already parks at −lead; keep the same beats so UI does not jump.
    final startPos = _withStartLeadIn(_pos);
    _pos = startPos;
    final auto = state.settings.mode.isAutoPlay;
    state = state.copyWith(
      isPlaying: true,
      positionBeats: startPos,
      clearStatusHint: true,
      waitingFor: auto
          ? const {}
          : _expectedAt(_score, startPos, state.settings),
      activeMidi: _activeAt(state.filteredNotes, startPos),
      endHangActive: false,
      settlementReady: false,
    );
    _syncClock();
    _audio.setMetronomeBpm(_score.bpm.toDouble());
    _audio.setSpeed(state.settings.speed);
    _audio.setMasterVolume(state.settings.volume);
    _audio.alignMetronomeToPosition(startPos);
    _audio.setTransportPlaying(true);
    _audio.setMetronome(state.settings.metronome);
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

  /// Apply negative pre-roll when starting/seeking at the piece beginning.
  double _firstOnsetBeats([PracticeSettings? settings]) {
    final hand = (settings ?? state.settings).hand;
    return PracticeLoopLogic.firstOnsetBeats(
      _score.notesForHand(hand).map((n) => n.start),
    );
  }

  double _withStartLeadIn(double pos) => PracticeLoopLogic.withStartLeadIn(
        pos,
        firstOnset: _firstOnsetBeats(),
      );

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    _cancelEndRitual();
    unawaited(_stopExamRecording());
    state = state.copyWith(
      isPlaying: false,
      positionBeats: _pos,
      endHangActive: false,
      clearStatusHint: true,
    );
    _audio.setTransportPlaying(false);
    _syncClock();
  }

  void seek(double beats) {
    if (state.settings.mode.isExam && !_allowExamSeek) {
      pianoFlowLog('Practice', 'exam mode: seek blocked');
      return;
    }
    _cancelEndRitual();
    final clamped = beats.clamp(0.0, _score.durationBeats);
    // Restart / seek-to-start get pre-roll; mid-piece seeks do not.
    final target = _withStartLeadIn(clamped);
    _satisfied = {};
    _audioFired = {};
    _guideCuedChordStart = null;
    _resetGuideRetrigger();
    _audio.alignMetronomeToPosition(target);
    if (state.isPlaying && state.settings.metronome) {
      _audio.setTransportPlaying(true);
      _audio.setMetronome(true);
    }
    final auto = state.settings.mode.isAutoPlay;
    final waiting =
        auto ? <int>{} : _expectedAt(_score, target, state.settings);
    _pos = target;
    state = state.copyWith(
      positionBeats: target,
      waitingFor: waiting,
      activeMidi: auto
          ? _activeAt(state.filteredNotes, target)
          : (waiting.isNotEmpty
              ? waiting
              : _activeAt(state.filteredNotes, target)),
      endHangActive: false,
      settlementReady: false,
      clearStatusHint: true,
    );
    _syncClock(intentionalSeek: true);
    if (state.isPlaying) {
      if (auto) {
        _armGuideBefore(target);
        _playGuideAt(target);
      } else {
        _armGuideThrough(target);
      }
    }
  }

  void _cancelEndRitual() {
    _endHangTimer?.cancel();
    _endHangTimer = null;
    _rewindTimer?.cancel();
    _rewindTimer = null;
  }

  void restart() {
    _audioFired = {};
    _allowExamSeek = true;
    try {
      seek(0);
    } finally {
      _allowExamSeek = false;
    }
  }

  void resetSessionAndRestart() {
    _satisfied = {};
    _audioFired = {};
    _guideCuedChordStart = null;
    _resetGuideRetrigger();
    _statsFlushed = false;
    _sessionStarted = null;
    _lastGradedAt = null;
    _lastGradedHand = null;
    _lastGradedMidi = null;
    _lastExamRecordingPath = null;
    state = state.copyWith(
      sessionHits: 0,
      sessionMisses: 0,
      missBeats: const [],
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
    restart();
  }

  /// Jump to a weak section and restart once（不再启用循环区间）.
  void applyWeakLoopAndRestart({
    required double start,
    required double end,
  }) {
    var lo = start;
    final maxBeat = _score.durationBeats;
    if (lo < 0) lo = 0;
    if (lo > maxBeat) lo = maxBeat;
    updateSettings(
      state.settings.copyWith(
        loopEnabled: false,
        mode: PracticeMode.wait,
      ),
    );
    pianoFlowLog(
      'Practice',
      'weak-section restart at=${lo.toStringAsFixed(2)} (end hint=${end.toStringAsFixed(2)})',
    );
    resetSessionAndRestart();
    _allowExamSeek = true;
    try {
      seek(lo);
    } finally {
      _allowExamSeek = false;
    }
    if (!state.isPlaying) {
      togglePlay();
    }
  }

  void clearSettlementReady() {
    if (!state.settlementReady) return;
    state = state.copyWith(settlementReady: false);
  }

  Future<void> flushStatsIfNeeded() => _flushStats();

  Future<void> _flushStats() async {
    if (_statsFlushed) return;
    if (_sessionStarted == null && !state.hasSessionActivity) return;
    _statsFlushed = true;
    final started = _sessionStarted ?? DateTime.now();
    final seconds =
        DateTime.now().difference(started).inSeconds.clamp(1, 86400);
    await ref.read(practiceStatsProvider.notifier).recordSession(
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

  void _onNoteOn(PitchNoteOn edge, {bool playSound = true}) {
    final midi = edge.midi;
    // 自动播放：mic 应已停；迟到事件也不更新高亮/命中。
    if (state.settings.mode.isAutoPlay) return;
    // Mic echo of our own speaker (guide/demo) — ignore delayed second hit.
    if (_isEchoSuppressed(midi)) return;

    final gateBlocks = _guideGate.blocks(midi);
    if (playSound) {
      // Prefer score-hand pan when this key is an expected/active note.
      _audio.playOneShot(midi, hand: state.highlightByHand[midi]);
      // While waiting for a post-guide quiet gap, still give key feedback but
      // do not extend the speaker→mic suppress window (that would re-bury the gap).
      if (!gateBlocks) {
        _markSelfPlayed(midi);
      }
    }

    _syncPressedMidi();
    if (!state.pressedMidi.contains(midi)) {
      state = state.copyWith(pressedMidi: {...state.pressedMidi, midi});
    }
    // 跟弹 / 考试才计命中。
    if (!state.isPlaying || !state.settings.mode.isPractice) return;
    if (state.endHangActive) return;
    if (state.waitingFor.isEmpty) return;

    final matched = PracticeGuideHitPolicy.resolveNoteOnHit(
      midi: midi,
      waitingFor: state.waitingFor,
      echoSuppressed: false, // already returned above if suppressed
    );
    if (matched != null) {
      // Suppress already ended: a fresh noteOn edge is a user re-attack.
      // Do not require quiet-gap first — holding the key would reset the
      // streak forever and force release-then-repress (sticky).
      // Continuous guide bleed is usually consumed as noteOn during suppress
      // (_emitted) and will not re-edge after suppress ends.
      _guideGate.disarm([matched]);
      _registerWaitHit(matched, captureAt: edge.captureAt);
      return;
    }

    // Wrong pitch while guide bleed still gated — don't miss-spam.
    if (gateBlocks) return;

    // Only count misses once frozen at the hit line — early window is forgiving.
    final chordStart = PracticeWaitLogic.chordStartForExpected(
      notes: state.filteredNotes,
      expected: state.waitingFor.union(_satisfied),
      pos: _pos,
    );
    if (chordStart != null &&
        PracticeWaitLogic.shouldFreezeAt(
          pos: _pos,
          chordStart: chordStart,
        )) {
      // Estimator often lands ±1 of an expected pitch — do not count as miss.
      final nearExpected = state.waitingFor.any(
        (e) => PracticePitchMatch.isNear(e, midi),
      );
      if (!nearExpected) {
        final missAt = chordStart;
        state = state.copyWith(
          sessionMisses: state.sessionMisses + 1,
          missBeats: [...state.missBeats, missAt],
          combo: 0,
          lastGrade: HitGrade.miss,
          feedbackNonce: state.feedbackNonce + 1,
        );
      }
    }
  }

  void _registerWaitHit(int midi, {DateTime? captureAt}) {
    if (!state.waitingFor.contains(midi)) return;
    if (_satisfied.contains(midi)) return;

    final chordStart = PracticeWaitLogic.chordStartForExpected(
          notes: state.filteredNotes,
          expected: state.waitingFor.union(_satisfied),
          pos: _pos,
        ) ??
        _pos;
    final gradePos = captureAt != null
        ? _posHistory.beatsAt(captureAt, fallback: _pos)
        : _pos;
    final grade = PracticeJudgeLogic.gradeFromDelta(gradePos - chordStart);
    final now = DateTime.now();
    if (captureAt != null) {
      final ms = PracticeHitLatency.record(
        now.difference(captureAt).inMilliseconds,
      );
      pianoFlowLogVerbose(
        'Practice',
        'hit-capture-ms=$ms grade=${grade.name} midi=$midi '
        'gradePos=${gradePos.toStringAsFixed(3)}',
      );
    }
    final freezeAt = _freezeSince;
    if (freezeAt != null) {
      pianoFlowLogVerbose(
        'Practice',
        'hit-wait-ms=${now.difference(freezeAt).inMilliseconds} '
        'grade=${grade.name} midi=$midi',
      );
    }
    final nextCombo = state.combo + 1;
    final nextMax = nextCombo > state.maxCombo ? nextCombo : state.maxCombo;
    final perfects =
        state.perfectCount + (grade == HitGrade.perfect ? 1 : 0);
    final goods = state.goodCount + (grade == HitGrade.good ? 1 : 0);

    Hand hitHand = Hand.right;
    for (final n in state.filteredNotes) {
      if (n.midi == midi && (n.start - chordStart).abs() < 0.05) {
        hitHand = n.hand;
        break;
      }
    }

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
      _syncClock();
      return;
    }
    final now = DateTime.now();
    _posHistory.record(now, _pos);
    final last = _lastTick ?? now;
    _lastTick = now;
    final dtSec = now.difference(last).inMicroseconds / 1e6;
    final bpm = _score.bpm * state.settings.speed;
    final beatDelta = dtSec * (bpm / 60.0);

    // 跟弹 / 考试：到达音头才冻结；提前窗内可命中但仍下落；空隙自由前进。
    if (state.settings.mode.isPractice) {
      final notes = state.filteredNotes;
      final expected = PracticeWaitLogic.expectedAt(notes: notes, pos: _pos);
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
        final waiting = PracticeGuideHitPolicy.midisToSoftCue(
          expected: expected,
          satisfied: _satisfied,
        );
        _publishDiscrete(waitingFor: waiting, activeMidi: expected);
        _syncClock();
        if (freeze) {
          _freezeSince ??= DateTime.now();
          // Only soft-cue pitches still owed — early-hit notes must not
          // re-arm suppress / gate (that re-buries the remaining chord).
          if (waiting.isNotEmpty) {
            _cueGuideIfNeeded(chordStart, waiting);
          }
          return;
        }
        _freezeSince = null;
        // Early-hit window: keep waterfall moving toward the hit line.
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

    // 自动播放：按 BPM 时间轴前进，必播示范音。
    // Large dt (UI hitch) would mark+fire many onsets at once and stall
    // Windows audioplayers while the hit line keeps moving — skip the gap.
    if (dtSec > 0.085) {
      final skipTo = _pos + beatDelta;
      _armGuideBefore(skipTo);
      _advance(beatDelta);
      _playGuideAt(_pos);
      pianoFlowLog(
        'Practice',
        'autoplay catch-up skip dt=${dtSec.toStringAsFixed(3)}s '
        '→ arm before ${_pos.toStringAsFixed(2)}',
      );
      return;
    }
    _advance(beatDelta);
    _playGuideAt(_pos);
  }

  /// Soft guide once when the playhead freezes on a chord (Flowkey cue).
  /// [stillWaiting] = expected − satisfied (never re-cue early hits).
  void _cueGuideIfNeeded(double chordStart, Set<int> stillWaiting) {
    if (_guideCuedChordStart != null &&
        (_guideCuedChordStart! - chordStart).abs() < 0.001) {
      return;
    }
    _guideCuedChordStart = chordStart;
    if (!state.settings.guideAudio) return;
    if (stillWaiting.isEmpty) return;
    final volume = PracticeConstants.guideVolumeWithMic;
    final cued = <int>{};
    for (final n in state.filteredNotes) {
      if (!stillWaiting.contains(n.midi)) continue;
      if ((n.start - chordStart).abs() >=
          PracticeConstants.waitChordClusterBeats) {
        continue;
      }
      final key = '${n.midi}_${n.start}_${n.hand.name}';
      if (_audioFired.contains(key)) continue;
      _audioFired.add(key);
      cued.add(n.midi);
      _markSelfPlayed(
        n.midi,
        duration: PracticeConstants.echoSuppressGuide,
        partials: false,
      );
      _audio.playOneShot(n.midi, volume: volume, hand: n.hand);
    }
    if (cued.isNotEmpty) {
      _guideGate.arm(cued);
      _guideCuedMidis = {...cued};
      // Do NOT clearEmitted now — the re-edge would land inside suppress and
      // be discarded; held common tones would never noteOn again.
      _scheduleClearEmittedAfterGuideSuppress(cued);
      pianoFlowLogVerbose(
        'Practice',
        'guide cue ${cued.map((m) => m).join(",")} + retrigger gate',
      );
    }
  }

  /// After soft-guide suppress: stop cue ring (samples ≫ 250ms) and re-allow
  /// noteOn only for tones already emitted before the cue (held / common tones).
  /// Cue bleed that first appears during suppress stays in `_emitted`.
  void _scheduleClearEmittedAfterGuideSuppress(Set<int> cued) {
    final already = PracticeGuideHitPolicy.midisToReedgeAfterSuppress(
      cued: cued,
      isEmitted: _pitch.isEmitted,
    );
    _deferredClearEmitted?.cancel();
    _deferredClearEmitted = Timer(PracticeConstants.echoSuppressGuide, () {
      _deferredClearEmitted = null;
      _stopGuideCueAudio(cued);
      if (already.isNotEmpty) {
        _pitch.clearEmitted(already);
        _pitch.reedgeIfLocked(already);
        pianoFlowLogVerbose(
          'Practice',
          'deferred clearEmitted+reedge ${already.join(",")}',
        );
      }
    });
  }

  void _stopGuideCueAudio([Set<int>? midis]) {
    final targets = midis ?? _guideCuedMidis;
    if (targets.isEmpty) return;
    _audio.stopOneShots(targets);
    if (midis == null || identical(targets, _guideCuedMidis)) {
      _guideCuedMidis = {};
    } else {
      _guideCuedMidis.removeAll(targets);
    }
  }

  void _resetGuideRetrigger() {
    // Cancel timer BEFORE stop — but always stop cue now (race with hit-advance).
    _deferredClearEmitted?.cancel();
    _deferredClearEmitted = null;
    _stopGuideCueAudio();
    _guideGate.clear();
  }

  /// Mark notes at/before [pos] as already handled without sounding them.
  void _armGuideThrough(double pos) {
    for (final n in state.filteredNotes) {
      if (n.start <= pos) {
        _audioFired.add('${n.midi}_${n.start}_${n.hand.name}');
      }
    }
  }

  /// Mark strictly-past notes so the note under the seek head can still fire.
  void _armGuideBefore(double pos) {
    for (final n in state.filteredNotes) {
      if (n.start < pos - 0.01) {
        _audioFired.add('${n.midi}_${n.start}_${n.hand.name}');
      }
    }
  }

  void _playGuideAt(double pos) {
    final auto = state.settings.mode.isAutoPlay;
    if (!auto && !state.settings.guideAudio) return;
    // Practice + mic: keep guide soft so speaker→mic echo stays usable.
    final volume = auto ? 1.0 : PracticeConstants.guideVolumeWithMic;
    final cued = <int>{};
    // One AudioPlayer per MIDI: LH+RH unison must not double-trigger.
    final soundedMidi = <int>{};
    for (final n in state.filteredNotes) {
      final key = '${n.midi}_${n.start}_${n.hand.name}';
      if (_audioFired.contains(key)) continue;
      if (n.start <= pos) {
        _audioFired.add(key);
        _markSelfPlayed(
          n.midi,
          duration: auto ? null : PracticeConstants.echoSuppressGuide,
          partials: auto,
        );
        // Wait-mode retrigger gate is armed only at freeze cue (_cueGuideIfNeeded).
        // Arming here during gap travel can mark gapSeen early and auto-hit later.
        if (!auto) {
          cued.add(n.midi);
        }
        if (soundedMidi.add(n.midi)) {
          _audio.playOneShot(n.midi, volume: volume, hand: n.hand);
        }
      }
    }
    if (cued.isNotEmpty) {
      _guideCuedMidis = {..._guideCuedMidis, ...cued};
      _scheduleClearEmittedAfterGuideSuppress(cued);
    }
  }

  void _advancePastCurrentChord() {
    final notes = _score.notesForHand(state.settings.hand);
    final pos = _pos;
    // Nudge past this onset — do NOT teleport to the next note (Flowkey gaps).
    final nextPos = PracticeWaitLogic.nudgePastChord(notes: notes, pos: pos);
    _satisfied = {};
    _guideCuedChordStart = null;
    _freezeSince = null;
    _resetGuideRetrigger();
    _armGuideThrough(pos);
    _applyPosition(nextPos);
    // Next chord guide fires when freeze arrives (_cueGuideIfNeeded).
  }

  void _advance(double beatDelta) {
    var next = _pos + beatDelta;
    if (next >= _score.durationBeats) {
      next = _score.durationBeats;
      _applyPosition(next);
      _beginEndRewind();
      return;
    }
    _applyPosition(next);
  }

  /// Animate playhead back to the start park after reaching the end.
  void _beginEndRewind() {
    if (_rewindTimer != null) return;
    _ticker?.cancel();
    _ticker = null;
    _cancelEndRitual();

    final from = _pos;
    final to = PracticeLoopLogic.withStartLeadIn(
      0,
      firstOnset: _firstOnsetBeats(state.settings),
    );
    final wantSettlement =
        state.settings.mode.isPractice && state.hasSessionActivity;

    _audio.setTransportPlaying(false);
    state = state.copyWith(
      isPlaying: false,
      endHangActive: true,
      positionBeats: from,
      waitingFor: const {},
      statusHint: '返回开头…',
    );
    _syncClock();

    final started = DateTime.now();
    _rewindTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      final u = (ms / PracticeConstants.endRewindMs).clamp(0.0, 1.0);
      final e = PracticeLoopLogic.easeInOutCubic(u);
      final pos = from + (to - from) * e;
      _pos = pos;
      // Snap staff at the ends; soft-track in the middle for a scrub feel.
      _syncClock(intentionalSeek: u < 0.03 || u > 0.97);
      if (u >= 1.0) {
        t.cancel();
        _rewindTimer = null;
        _finishEndRewind(to, settlement: wantSettlement);
      }
    });
  }

  void _finishEndRewind(double to, {required bool settlement}) {
    _satisfied = {};
    _audioFired = {};
    _guideCuedChordStart = null;
    _freezeSince = null;
    _resetGuideRetrigger();
    _pos = to;
    unawaited(_finalizeExamArtifacts());
    final auto = state.settings.mode.isAutoPlay;
    state = state.copyWith(
      isPlaying: false,
      endHangActive: false,
      positionBeats: to,
      waitingFor: auto
          ? const {}
          : _expectedAt(_score, to, state.settings),
      activeMidi: _activeAt(state.filteredNotes, to),
      settlementReady: settlement,
      clearStatusHint: true,
    );
    _audio.alignMetronomeToPosition(to);
    _syncClock(intentionalSeek: true);
  }

  Future<void> _finalizeExamArtifacts() async {
    await _stopExamRecording();
    if (!state.settings.mode.isExam) return;
    if (state.sessionHitLog.isEmpty) return;
    await PracticeGhostStore.save(_score.id, state.sessionHitLog);
    try {
      state = state.copyWith(ghostHits: state.sessionHitLog);
    } catch (_) {}
  }

  void _applyPosition(double next, {bool intentionalSeek = false}) {
    _pos = next;
    if (state.settings.mode.isAutoPlay) {
      // Auto-play highlight churn must not rebuild the scaffold / WebView.
      _syncClock(intentionalSeek: intentionalSeek);
      return;
    }
    final expected = PracticeWaitLogic.expectedAt(
      notes: state.filteredNotes,
      pos: next,
    );
    final waiting = expected.difference(_satisfied);
    final active = expected.isNotEmpty
        ? expected
        : _activeAt(state.filteredNotes, next);
    _publishDiscrete(
      waitingFor: waiting,
      activeMidi: active,
    );
    _syncClock(intentionalSeek: intentionalSeek);
  }

  /// Notify Riverpod only when discrete UI fields change (not every 16ms).
  void _publishDiscrete({
    required Set<int> waitingFor,
    required Set<int> activeMidi,
  }) {
    final waitingChanged = !_sameMidiSet(waitingFor, state.waitingFor);
    final activeChanged = !_sameMidiSet(activeMidi, state.activeMidi);
    if (!waitingChanged && !activeChanged) {
      return;
    }
    state = state.copyWith(
      positionBeats: _pos,
      waitingFor: waitingFor,
      activeMidi: activeMidi,
    );
  }

  void _syncClock({bool intentionalSeek = false}) {
    final playing = state.isPlaying;
    var rate = 0.0;
    if (playing && !state.endHangActive) {
      final nominal = state.nominalBeatsPerSec;
      if (state.settings.mode.isAutoPlay) {
        rate = nominal;
      } else if (_isWaitFrozenAt(_pos)) {
        rate = 0;
      } else {
        rate = nominal;
      }
    }
    clock.sync(
      positionBeats: _pos,
      beatsPerSec: rate,
      isPlaying: playing,
      intentionalSeek: intentionalSeek,
    );
    _posHistory.record(DateTime.now(), _pos);
    // Metronome follows PracticeClock: freeze (rate 0) must stop clicks.
    final advancing =
        PracticeLoopLogic.metronomeShouldAdvance(transportBeatsPerSec: rate);
    if (advancing != _lastMetroAdvancing) {
      _lastMetroAdvancing = advancing;
      if (advancing) {
        _audio.alignMetronomeToPosition(_pos);
      }
      _audio.setMetronomeAdvancing(advancing);
    }
  }

  bool _isWaitFrozenAt(double pos) {
    if (!state.settings.mode.isPractice) return false;
    if (state.waitingFor.isEmpty) return false;
    final chordStart = PracticeWaitLogic.chordStartForExpected(
      notes: state.filteredNotes,
      expected: state.waitingFor,
      pos: pos,
    );
    if (chordStart == null) return false;
    return PracticeWaitLogic.shouldFreezeAt(pos: pos, chordStart: chordStart);
  }

  static bool _sameMidiSet(Set<int> a, Set<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
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
    return notes
        .where((n) => pos >= n.start && pos < n.end)
        .map((n) => n.midi)
        .toSet();
  }
}

final practiceProvider = NotifierProvider.autoDispose
    .family<PracticeController, PracticeSnapshot, SongScore>(
  PracticeController.new,
);
