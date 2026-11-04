import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import 'cue_bleed_guard.dart';
import 'exam_pcm_recorder.dart';
import 'guide_retrigger_gate.dart';
import 'pitch_service.dart';
import 'practice_attack_latch.dart';
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

  /// One physical lock/ring must not clear the next time-position (同音连推进).
  final PracticeAttackLatch _attackLatch = PracticeAttackLatch(
    releaseFrames: PracticeConstants.guideQuietFramesNeeded,
  );

  /// Soft-cue speaker bleed filter (does not retune echoSuppressGuide).
  final CueBleedGuard _cueBleed = CueBleedGuard();

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
  /// Autoplay / gap guide, one turn after the transport tick so note
  /// platform calls are not posted in the same turn as Verovio / the ticker.
  Timer? _guideTurn;
  final ExamPcmRecorder _examRecorder = ExamPcmRecorder();
  String? _lastExamRecordingPath;
  DateTime? _lastGradedAt;
  Hand? _lastGradedHand;
  int? _lastGradedMidi;
  DateTime? _lastLatchBlockLog;
  DateTime? _lastSoftMatchLog;

  /// Unconditioned mic locks (pre score-neighborhood filter) — for latch quiet
  /// / carryover so BP linger outside the current wait still counts as sounding.
  Set<int> _lastRawHeard = {};

  /// Pitches to fold into the next wait's carryover (set on hit / advance).
  Set<int> _pendingCarryover = {};

  /// True while [play] is awaiting tone bind / silent device warm.
  bool _playArming = false;

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
      _guideTurn?.cancel();
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
    // Idle：麦常开以减首击延迟，但环境噪声 + BP 单帧误锁不得点亮琴键。
    if (!state.isPlaying) {
      if (_pitchPressed.isNotEmpty || state.pressedMidi.isNotEmpty) {
        _pitchPressed = {};
        _syncPressedMidi();
      }
      _attackLatch.clear();
      _pendingCarryover = {};
      return;
    }
    final rawHeard = {
      for (final m in f.midis)
        if (!_isEchoSuppressed(m)) m,
    };
    _lastRawHeard = rawHeard;
    _pitchPressed = rawHeard;
    // Score-conditioned: drop estimator junk outside waiting neighborhood.
    if (state.waitingFor.isNotEmpty) {
      _pitchPressed = PracticePitchMatch.conditionHeard(
        heard: _pitchPressed,
        waitingFor: state.waitingFor,
      );
    }
    _syncPressedMidi();
    // Quiet / carryover decay must see raw locks (not only wait-neighborhood).
    _attackLatch.onHeard(rawHeard);
    // Onset re-strike: allow same pitch again without full mic quiet (连击).
    if (f.onset && _pitchPressed.isNotEmpty) {
      final before = _attackLatch.spent.length;
      _attackLatch.releaseOnOnset(_pitchPressed);
      if (_attackLatch.spent.length < before) {
        PracticeHitLatency.noteOnsetRelease();
        pianoFlowLogVerbose(
          'Practice',
          'onset-release flux=${f.onsetFlux.toStringAsFixed(3)} '
          'heard=${_pitchPressed.join(",")}',
        );
      }
    }
    if (!state.settings.mode.isPractice) return;
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
      if (_attackLatch.blocks(m)) {
        _logLatchBlock('frame', m);
        continue;
      }
      if (_attackLatch.blocksCarryover(m)) {
        _logLatchBlock('frame-carry', m);
        continue;
      }
      // Frame path is guide re-strike only; still require onset so sustain
      // hold after gap cannot auto-walk the score.
      if (!f.onset) {
        _logLatchBlock('frame-no-onset', m);
        continue;
      }
      if (_cueBleed.isBleed(
        midi: m,
        hasOnset: f.onset,
        heardAll: _pitchPressed,
      )) {
        PracticeHitLatency.noteCueBleed();
        continue;
      }
      _registerWaitHit(
        m,
        captureAt: f.captureAt,
        heardMidi: m,
        path: 'frame',
      );
    }
  }

  void _logLatchBlock(String path, int midi, [int? matched]) {
    PracticeHitLatency.noteLatchBlock();
    final now = DateTime.now();
    final last = _lastLatchBlockLog;
    if (last != null && now.difference(last).inMilliseconds < 400) return;
    _lastLatchBlockLog = now;
    final extra = matched == null ? '' : ' matched=$matched';
    pianoFlowLog(
      'Practice',
      'latch-block $path midi=$midi$extra（需新击键）',
    );
  }

  void _logSoftMatch(int heard, int matched) {
    PracticeHitLatency.noteSoftMatch();
    final now = DateTime.now();
    final last = _lastSoftMatchLog;
    if (last != null && now.difference(last).inMilliseconds < 500) return;
    _lastSoftMatchLog = now;
    final kind = (heard - matched).abs() == 12
        ? 'octave'
        : (heard - matched).abs() == 1
            ? '±1'
            : 'soft';
    pianoFlowLog(
      'Practice',
      'match-$kind heard=$heard → waiting=$matched',
    );
  }

  Future<void> _bootstrapAudioAndPitch(PitchService pitch) async {
    try {
      await _audio.ensureReady();
      // Silent zero-PCM only — keeps WASAPI awake without ghost notes on open.
      await _audio.ensureDeviceWarm();
      // Open window first so autoplay beat-0 is not still binding.
      await _audio.prefetchMidisNear(
        _score.notes,
        fromBeats: _pos,
        lookAheadBeats: 8,
      );
      unawaited(_audio.prefetchMidis(_score.notes.map((n) => n.midi)));
      _audio.setMasterVolume(state.settings.volume);
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
    _attackLatch.clear();
    _pendingCarryover = {};
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
    _attackLatch.clear();
    _pendingCarryover = {};
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
      _attackLatch.clear();
      _pendingCarryover = {};
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
    if (state.isPlaying || _playArming) return;
    // Always arm async: even when [isReady], seek/idle can leave nearby
    // midis unbound and WASAPI cold — sync _startTransport then hitchs.
    unawaited(_armAndStartTransport());
  }

  Future<void> _armAndStartTransport() async {
    if (state.isPlaying || _playArming) return;
    _playArming = true;
    final sw = Stopwatch()..start();
    final startPos = _withStartLeadIn(_pos);
    try {
      await _audio.ensureReady();
      // Zero-PCM only (no audible sample). Cheap no-op if warmed recently.
      await _audio.ensureDeviceWarm();
      try {
        await _audio
            .prefetchMidisNear(
              _score.notes,
              fromBeats: startPos,
              lookAheadBeats: 8,
            )
            .timeout(const Duration(milliseconds: 500));
      } on TimeoutException {
        pianoFlowLog('Practice', 'play-arm prefetch timed out — continue');
      }
      unawaited(_audio.prefetchMidis(_score.notes.map((n) => n.midi)));
      if (sw.elapsedMilliseconds >= 40) {
        pianoFlowLog(
          'Practice',
          'play-arm ${sw.elapsedMilliseconds}ms '
          '(warm+prefetch before transport)',
        );
      }
    } catch (e) {
      pianoFlowLog('Practice', '示范音初始化失败：$e');
      state = state.copyWith(
        statusHint: '示范音初始化失败（详情见控制台 [PianoFlow/Practice]）',
      );
      return;
    } finally {
      _playArming = false;
    }
    if (state.isPlaying) return;
    _startTransport(startPos: startPos);
  }

  void _startTransport({double? startPos}) {
    _cancelEndRitual();
    _sessionStarted ??= DateTime.now();
    // Fresh lab metrics each transport start (跟弹可测).
    if (state.settings.mode.isPractice) {
      PracticeHitLatency.reset();
    }
    _lastTick = DateTime.now();
    // From piece start: run a pre-roll so the first note is not immediate.
    // Idle already parks at −lead; keep the same beats so UI does not jump.
    final pos = startPos ?? _withStartLeadIn(_pos);
    _pos = pos;
    final auto = state.settings.mode.isAutoPlay;
    state = state.copyWith(
      isPlaying: true,
      positionBeats: pos,
      clearStatusHint: true,
      waitingFor: auto
          ? const {}
          : _expectedAt(_score, pos, state.settings),
      activeMidi: _activeAt(state.filteredNotes, pos),
      endHangActive: false,
      settlementReady: false,
    );
    // Clock/UI first; defer audible side-effects off this sync stack so
    // Riverpod rebuild + Verovio rate push are not fighting metro/guide
    // method-channel traffic on the same turn (Windows play-start hitch).
    _syncClock();
    _ticker?.cancel();
    unawaited(_maybeStartExamRecording());
    _ticker = Timer.periodic(PracticeConstants.tickPeriod, (_) => _tick());
    Timer.run(() {
      if (!state.isPlaying) return;
      _audio.setMetronomeBpm(_score.bpm.toDouble());
      _audio.setSpeed(state.settings.speed);
      _audio.setMasterVolume(state.settings.volume);
      _audio.alignMetronomeToPosition(pos);
      _audio.setMetronome(state.settings.metronome);
      _audio.setTransportPlaying(true);
      if (auto) {
        _playGuideAt(pos);
      } else {
        _armGuideThrough(pos);
      }
    });
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
    // Cut queued and in-flight one-shots before the scaffold rebuild.
    _audio.setTransportPlaying(false);
    unawaited(_stopExamRecording());
    _pitchPressed = {};
    _attackLatch.clear();
    _pendingCarryover = {};
    _pitch.clearScorePriorMidis();
    state = state.copyWith(
      isPlaying: false,
      positionBeats: _pos,
      pressedMidi: const {},
      endHangActive: false,
      clearStatusHint: true,
    );
    _syncClock();
  }

  void seek(double beats) {
    if (state.settings.mode.isExam && !_allowExamSeek) {
      pianoFlowLog('Practice', 'exam mode: seek blocked');
      return;
    }
    // User scrub (slider / staff) or programmatic seek while playing: pause
    // transport. Do not auto-resume on finger-up — user must press play again.
    if (state.isPlaying) {
      pause();
    }
    _cancelEndRitual();
    final clamped = beats.clamp(0.0, _score.durationBeats);
    // Restart / seek-to-start get pre-roll; mid-piece seeks do not.
    final target = _withStartLeadIn(clamped);
    _satisfied = {};
    _audioFired = {};
    _guideCuedChordStart = null;
    _resetGuideRetrigger();
    _attackLatch.clear();
    _pendingCarryover = {};
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
    _guideTurn?.cancel();
    _guideTurn = null;
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
    _attackLatch.clear();
    _pendingCarryover = {};
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
    // 纯自动播放、或跟弹/考试里还没有命中与失误：不记账。
    if (!state.hasSessionActivity) return;
    _statsFlushed = true;
    await ref.read(practiceStatsProvider.notifier).recordSession(
          songId: _score.id,
          hits: state.sessionHits,
          misses: state.sessionMisses,
          perfects: state.perfectCount,
          goods: state.goodCount,
          maxCombo: state.maxCombo,
          isExam: state.settings.mode.isExam,
        );
    pianoFlowLog(
      'Practice',
      'stats flushed hits=${state.sessionHits}',
    );
    if (state.settings.mode.isPractice) {
      // Stuck at freeze with unpaid chord → count as leak heuristic.
      if (_freezeSince != null &&
          state.waitingFor.isNotEmpty &&
          DateTime.now().difference(_freezeSince!).inSeconds >= 5) {
        PracticeHitLatency.noteLeak();
      }
      pianoFlowLog('Practice', PracticeHitLatency.snapshotLine());
    }
  }

  void _onNoteOn(PitchNoteOn edge, {bool playSound = true}) {
    final midi = edge.midi;
    // 自动播放：mic 应已停；迟到事件也不更新高亮/命中。
    if (state.settings.mode.isAutoPlay) return;
    // 未开运输：忽略麦 noteOn（避免静音环境幽灵闪键）；开播放后再跟弹。
    if (!state.isPlaying) return;
    // Mic echo of our own speaker (guide/demo) — ignore delayed second hit.
    if (_isEchoSuppressed(midi)) return;

    // Soft-cue bleed (onset-less cue neighborhood) — adaptive soft tail.
    if (_cueBleed.isBleed(
      midi: midi,
      hasOnset: edge.attackOnset,
      heardAll: {midi, ..._pitchPressed},
    )) {
      PracticeHitLatency.noteCueBleed();
      pianoFlowLogVerbose(
        'Practice',
        'cue-bleed block noteOn midi=$midi onset=${edge.attackOnset}',
      );
      return;
    }

    // User re-strike with onset: cut cue ring early so bleed dies faster.
    if (edge.attackOnset && _guideCuedMidis.isNotEmpty) {
      _stopGuideCueAudio(_guideCuedMidis);
    }

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
      // Same lock/ring already spent on the previous time-position — need a
      // real release then re-attack (同音连推进 / ±1 double noteOn).
      if (_attackLatch.blocks(midi) || _attackLatch.blocks(matched)) {
        _logLatchBlock('noteOn', midi, matched);
        return;
      }
      // Phrase carryover: BP window / sustain still sounding when the next
      // wait armed — must not auto-advance (弹了前几个、后面自己过).
      if (_attackLatch.blocksCarryover(midi) ||
          _attackLatch.blocksCarryover(matched)) {
        _logLatchBlock('noteOn-carry', midi, matched);
        return;
      }
      // Lock-flicker re-edges often arrive without attack flux. Require onset
      // for noteOn wait hits (sticky onset in PitchService covers soft presses).
      if (!edge.attackOnset) {
        _logLatchBlock('noteOn-no-onset', midi, matched);
        return;
      }
      // Suppress already ended: a fresh noteOn edge is a user re-attack.
      // Do not require quiet-gap first — holding the key would reset the
      // streak forever and force release-then-repress (sticky).
      // Continuous guide bleed is usually consumed as noteOn during suppress
      // (_emitted) and will not re-edge after suppress ends.
      _guideGate.disarm([matched]);
      _registerWaitHit(
        matched,
        captureAt: edge.captureAt,
        heardMidi: midi,
        path: 'noteOn',
      );
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
      // Monophonic: ±1 estimator bias forgivable; chords: exact/octave only.
      final nearExpected = PracticePitchMatch.isForgivableWrongPitch(
        heard: midi,
        waitingFor: state.waitingFor,
      );
      if (!nearExpected) {
        PracticeHitLatency.noteMiss();
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

  void _registerWaitHit(
    int midi, {
    DateTime? captureAt,
    int? heardMidi,
    String path = 'noteOn',
  }) {
    if (!state.waitingFor.contains(midi)) return;
    if (_satisfied.contains(midi)) return;
    if (_attackLatch.blocks(midi) ||
        (heardMidi != null && _attackLatch.blocks(heardMidi))) {
      return;
    }
    if (heardMidi != null && heardMidi != midi) {
      _logSoftMatch(heardMidi, midi);
    }

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
        guideOn: state.settings.guideAudio,
        path: path,
      );
      pianoFlowLogVerbose(
        'Practice',
        'hit-capture-ms=$ms grade=${grade.name} midi=$midi '
        'path=$path guide=${state.settings.guideAudio} '
        'gradePos=${gradePos.toStringAsFixed(3)}',
      );
    } else {
      // Still count hit bucket when capture stamp missing.
      PracticeHitLatency.record(
        0,
        guideOn: state.settings.guideAudio,
        path: path,
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
    _attackLatch.markConsumed(midi, heardMidi: heardMidi ?? midi);
    // Seed next-wait carryover immediately (don't wait for the next frame).
    _pendingCarryover = {
      ..._pendingCarryover,
      ..._lastRawHeard,
      midi,
      if (heardMidi != null) heardMidi,
    };
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
        _scheduleGuide(_pos);
      }
      return;
    }

    // 自动播放：按 BPM 时间轴前进，必播示范音。
    // Large dt (UI hitch) would mark+fire many onsets at once and stall
    // Windows audioplayers while the hit line keeps moving — skip the gap.
    // Sounding is one event later so this tick can return to pointer events
    // before any note seek/resume is posted.
    if (dtSec > 0.085) {
      final skipTo = _pos + beatDelta;
      _armGuideBefore(skipTo);
      _advance(beatDelta);
      _scheduleGuide(_pos);
      pianoFlowLog(
        'Practice',
        'autoplay catch-up skip dt=${dtSec.toStringAsFixed(3)}s '
        '→ arm before ${_pos.toStringAsFixed(2)}',
      );
      return;
    }
    _advance(beatDelta);
    _scheduleGuide(_pos);
  }

  /// Post guide attacks on a later event-loop turn.
  ///
  /// The transport tick also pushes Verovio. Doing both, plus every due
  /// note's audioplayers call, in that same turn is what makes pause / back
  /// miss their gesture when the score is dense.
  void _scheduleGuide(double pos) {
    _guideTurn?.cancel();
    _guideTurn = null;
    if (!state.isPlaying || state.endHangActive) return;
    _guideTurn = Timer(Duration.zero, () {
      _guideTurn = null;
      if (!state.isPlaying || state.endHangActive) return;
      _playGuideAt(pos);
    });
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
      _audio.playScoreNote(
        n.midi,
        durationBeats: n.duration,
        bpm: _score.bpm * state.settings.speed,
        volume: volume,
        hand: n.hand,
      );
    }
    if (cued.isNotEmpty) {
      _guideGate.arm(cued);
      _cueBleed.arm(cued);
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

  /// After soft-guide suppress: re-allow noteOn for tones already emitted
  /// before the cue. The tone itself stops when its written duration ends
  /// ([ScoreAudioPlayer.playScoreNote]), not on this fixed window.
  void _scheduleClearEmittedAfterGuideSuppress(Set<int> cued) {
    final already = PracticeGuideHitPolicy.midisToReedgeAfterSuppress(
      cued: cued,
      isEmitted: _pitch.isEmitted,
    );
    _deferredClearEmitted?.cancel();
    _deferredClearEmitted = Timer(PracticeConstants.echoSuppressGuide, () {
      _deferredClearEmitted = null;
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
    _cueBleed.clear();
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
    if (!state.isPlaying) return;
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
        _audio.playScoreNote(
          n.midi,
          durationBeats: n.duration,
          bpm: _score.bpm * state.settings.speed,
          volume: volume,
          hand: n.hand,
        );
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
    // Arm linger before position/waiting update so the next early window
    // cannot eat BP-window leftovers from this strike.
    _pendingCarryover = {..._pendingCarryover, ..._lastRawHeard};
    _attackLatch.armCarryover(_pendingCarryover);
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
    // 平时练习不弹结算；仅考试模式段末展示结算页。
    final wantSettlement =
        state.settings.mode.isExam && state.hasSessionActivity;

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
    _attackLatch.clear();
    _pendingCarryover = {};
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
    // 平时练习：静默落库，不弹结算 sheet。
    if (!settlement && state.hasSessionActivity) {
      unawaited(_flushStats());
    }
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
    // New owed pitches: arm currently sounding locks as carryover so BP
    // linger / sustain cannot auto-hit the next onset without a new strike.
    if (waitingChanged && waitingFor.isNotEmpty) {
      _attackLatch.armCarryover({..._lastRawHeard, ..._pendingCarryover});
      _pendingCarryover = {};
    }
    // Score-conditioned BP: boost bins around currently owed pitches.
    _pitch.setScorePriorMidis(PracticePitchMatch.priorBins(waitingFor));
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
