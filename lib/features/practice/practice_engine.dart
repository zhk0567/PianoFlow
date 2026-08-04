import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import 'guide_retrigger_gate.dart';
import 'pitch_service.dart';
import 'practice_constants.dart';
import 'practice_loop_logic.dart';
import 'practice_models.dart';
import 'practice_stats_store.dart';
import 'practice_wait_logic.dart';
import 'score_audio_player.dart';

export 'practice_models.dart';

class PracticeController extends Notifier<PracticeSnapshot> {
  PracticeController(this._score);

  final SongScore _score;

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

  /// Chord onset beat we already soft-cued guide for (avoid re-fire while frozen).
  double? _guideCuedChordStart;

  /// MIDI → suppress mic echo until this time (speaker guide → mic feedback).
  final Map<int, DateTime> _echoSuppressUntil = {};

  ScoreAudioPlayer get _audio => ref.read(scoreAudioProvider);
  PitchService get _pitch => ref.read(pitchServiceProvider);

  @override
  PracticeSnapshot build() {
    final pitch = ref.read(pitchServiceProvider);
    unawaited(_bootstrapAudioAndPitch(pitch));
    _pitchSub =
        pitch.noteOnStream.listen((midi) => _onNoteOn(midi, playSound: false));
    _pitchFrameSub = pitch.frameStream.listen(_onPitchFrame);
    ref.onDispose(() {
      _ticker?.cancel();
      _pitchSub?.cancel();
      _pitchFrameSub?.cancel();
      _audio.setTransportPlaying(false);
      unawaited(pitch.stop());
      unawaited(_flushStats());
    });

    final end = _score.durationBeats.clamp(1.0, double.infinity);
    final settings = PracticeSettings(loopEnd: end > 4 ? 4 : end);
    // Park in pre-roll so the first play() does not snap falling notes / staff.
    final park = PracticeConstants.playbackStartParkBeats;
    return PracticeSnapshot(
      score: _score,
      settings: settings,
      positionBeats: park,
      waitingFor: _expectedAt(_score, park, settings),
    );
  }

  void _onPitchFrame(PitchFrame f) {
    // 自动播放关掉 mic；若仍有迟到帧，也不更新按下高亮。
    if (state.settings.mode.isAutoPlay) return;
    _pitchPressed = {
      for (final m in f.midis)
        if (!_isEchoSuppressed(m)) m,
    };
    _syncPressedMidi();
    if (!state.isPlaying || state.settings.mode != PracticeMode.wait) return;
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

  void _syncPressedMidi() {
    final merged = {..._pitchPressed};
    if (merged.length != state.pressedMidi.length ||
        !merged.containsAll(state.pressedMidi) ||
        !state.pressedMidi.containsAll(merged)) {
      state = state.copyWith(pressedMidi: merged);
    }
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
    // Detune / neighbor bins the estimator often locks onto.
    arm(midi - 1);
    arm(midi + 1);
    // Common piano partials heard through the mic after a loud speaker hit.
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
    // 自动播放始终开启示范音。
    if (next.mode.isAutoPlay) {
      next = next.copyWith(guideAudio: true);
    }
    final wasAuto = state.settings.mode.isAutoPlay;
    final nowAuto = next.mode.isAutoPlay;
    final speedChanged =
        (next.speed - state.settings.speed).abs() > 1e-6;
    final metroJustEnabled = next.metronome && !state.settings.metronome;
    _satisfied = {};
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
      _audio.alignMetronomeToPosition(state.positionBeats);
    }
    final waiting = nowAuto
        ? <int>{}
        : _expectedAt(_score, state.positionBeats, next);
    if (nowAuto) {
      _pitchPressed = {};
      _echoSuppressUntil.clear();
      _guideGate.clear();
    }
    state = state.copyWith(
      settings: next,
      waitingFor: waiting,
      activeMidi:
          _activeAt(_score.notesForHand(next.hand), state.positionBeats),
      pressedMidi: nowAuto ? const {} : state.pressedMidi,
    );
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
    _sessionStarted ??= DateTime.now();
    _lastTick = DateTime.now();
    // From piece start: run a pre-roll so the first note is not immediate.
    // Idle already parks at −lead; keep the same beats so UI does not jump.
    final startPos = _withStartLeadIn(state.positionBeats);
    final auto = state.settings.mode.isAutoPlay;
    state = state.copyWith(
      isPlaying: true,
      positionBeats: startPos,
      clearStatusHint: true,
      waitingFor: auto
          ? const {}
          : _expectedAt(_score, startPos, state.settings),
      activeMidi: _activeAt(state.filteredNotes, startPos),
    );
    _audio.setMetronomeBpm(_score.bpm.toDouble());
    _audio.setSpeed(state.settings.speed);
    _audio.setMasterVolume(state.settings.volume);
    _audio.alignMetronomeToPosition(startPos);
    _audio.setTransportPlaying(true);
    _audio.setMetronome(state.settings.metronome);
    _ticker?.cancel();
    if (auto) {
      // Auto-play: fire notes at the playhead immediately (periodic tick waits
      // one period otherwise → ~1s silence at 60 BPM). During lead-in this is
      // a no-op until position crosses the first onset.
      _playGuideAt(startPos);
    } else {
      // Practice wait: play only starts listening — do not oneshot the chord
      // under the cursor. Arm so a later guide fire after advance won't dump
      // past notes.
      _armGuideThrough(startPos);
    }
    _ticker = Timer.periodic(PracticeConstants.tickPeriod, (_) => _tick());
  }

  /// Apply negative pre-roll when starting/seeking at the piece beginning.
  double _withStartLeadIn(double pos) => PracticeLoopLogic.withStartLeadIn(pos);

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(isPlaying: false);
    _audio.setTransportPlaying(false);
  }

  void seek(double beats) {
    final clamped = beats.clamp(0.0, _score.durationBeats);
    // Restart / seek-to-start get pre-roll; mid-piece seeks do not.
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
      activeMidi: _activeAt(state.filteredNotes, target),
      pressedMidi: auto ? const {} : {..._pitchPressed},
    );
    // Prevent the next _playGuideAt from dumping every note from beat 0.
    if (auto) {
      _armGuideBefore(target);
    } else {
      _armGuideThrough(target);
    }
  }

  void restart() {
    _audioFired = {};
    seek(state.settings.loopEnabled ? state.settings.loopStart : 0);
  }

  Future<void> _flushStats() async {
    if (_sessionStarted == null) return;
    final seconds =
        DateTime.now().difference(_sessionStarted!).inSeconds.clamp(1, 86400);
    await ref.read(practiceStatsProvider.notifier).recordSession(
          songId: _score.id,
          seconds: seconds,
          hits: state.sessionHits,
          misses: state.sessionMisses,
        );
  }

  void _onNoteOn(int midi, {bool playSound = true}) {
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
    // Guide just played this pitch — need quiet gap then re-strike to count.
    if (gateBlocks) return;

    _syncPressedMidi();
    if (!state.pressedMidi.contains(midi)) {
      state = state.copyWith(pressedMidi: {...state.pressedMidi, midi});
    }
    // 跟弹练习才计命中。
    if (!state.isPlaying || state.settings.mode != PracticeMode.wait) return;

    if (state.waitingFor.contains(midi)) {
      _guideGate.disarm([midi]);
      _registerWaitHit(midi);
    } else if (state.waitingFor.isNotEmpty) {
      // Only count misses once frozen at the hit line — early window is forgiving.
      final chordStart = PracticeWaitLogic.chordStartForExpected(
        notes: state.filteredNotes,
        expected: state.waitingFor.union(_satisfied),
        pos: state.positionBeats,
      );
      if (chordStart != null &&
          PracticeWaitLogic.shouldFreezeAt(
            pos: state.positionBeats,
            chordStart: chordStart,
          )) {
        state = state.copyWith(sessionMisses: state.sessionMisses + 1);
      }
    }
  }

  void _registerWaitHit(int midi) {
    if (!state.waitingFor.contains(midi)) return;
    if (_satisfied.contains(midi)) return;
    _satisfied = {..._satisfied, midi};
    final remaining = {...state.waitingFor}..removeAll(_satisfied);
    state = state.copyWith(
      waitingFor: remaining,
      sessionHits: state.sessionHits + 1,
    );
    if (remaining.isEmpty) {
      _advancePastCurrentChord();
    }
  }

  void _tick() {
    if (!state.isPlaying) return;
    final now = DateTime.now();
    final last = _lastTick ?? now;
    _lastTick = now;
    final dtSec = now.difference(last).inMicroseconds / 1e6;
    final bpm = _score.bpm * state.settings.speed;
    final beatDelta = dtSec * (bpm / 60.0);

    // 跟弹：到达音头才冻结；提前窗内可命中但仍下落；空隙自由前进。
    if (state.settings.mode == PracticeMode.wait) {
      final notes = state.filteredNotes;
      final expected =
          PracticeWaitLogic.expectedAt(notes: notes, pos: state.positionBeats);
      if (expected.isNotEmpty && !_satisfied.containsAll(expected)) {
        final chordStart = PracticeWaitLogic.chordStartForExpected(
              notes: notes,
              expected: expected,
              pos: state.positionBeats,
            ) ??
            state.positionBeats;
        final freeze = PracticeWaitLogic.shouldFreezeAt(
          pos: state.positionBeats,
          chordStart: chordStart,
        );
        state = state.copyWith(
          waitingFor: expected.difference(_satisfied),
          activeMidi: expected,
        );
        if (freeze) {
          _cueGuideIfNeeded(chordStart, expected);
          return;
        }
        // Early-hit window: keep waterfall moving toward the hit line.
        _advance(beatDelta);
        return;
      }
      _guideCuedChordStart = null;
      if (expected.isEmpty) {
        _advance(beatDelta);
        _playGuideAt(state.positionBeats);
      }
      return;
    }

    // 自动播放：按 BPM 时间轴前进，必播示范音。
    _advance(beatDelta);
    _playGuideAt(state.positionBeats);
  }

  /// Soft guide once when the playhead freezes on a chord (Flowkey cue).
  void _cueGuideIfNeeded(double chordStart, Set<int> expected) {
    if (_guideCuedChordStart != null &&
        (_guideCuedChordStart! - chordStart).abs() < 0.001) {
      return;
    }
    _guideCuedChordStart = chordStart;
    if (!state.settings.guideAudio) return;
    final volume = PracticeConstants.guideVolumeWithMic;
    final cued = <int>{};
    for (final n in state.filteredNotes) {
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
      // Let the same MIDI re-fire noteOn after echo dies / user re-strikes.
      _pitch.clearEmitted(cued);
      pianoFlowLog(
        'Practice',
        'guide cue ${cued.map((m) => m).join(",")} + retrigger gate',
      );
    }
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
    for (final n in state.filteredNotes) {
      final key = '${n.midi}_${n.start}_${n.hand.name}';
      if (_audioFired.contains(key)) continue;
      if (n.start <= pos) {
        _audioFired.add(key);
        _markSelfPlayed(
          n.midi,
          duration: auto ? null : PracticeConstants.echoSuppressGuide,
        );
        // Wait-mode retrigger gate is armed only at freeze cue (_cueGuideIfNeeded).
        // Arming here during gap travel can mark gapSeen early and auto-hit later.
        if (!auto) {
          cued.add(n.midi);
        }
        _audio.playOneShot(n.midi, volume: volume, hand: n.hand);
      }
    }
    if (cued.isNotEmpty) {
      _pitch.clearEmitted(cued);
    }
  }

  void _advancePastCurrentChord() {
    final notes = _score.notesForHand(state.settings.hand);
    final pos = state.positionBeats;
    // Nudge past this onset — do NOT teleport to the next note (Flowkey gaps).
    final nextPos = PracticeWaitLogic.nudgePastChord(notes: notes, pos: pos);
    _satisfied = {};
    _guideCuedChordStart = null;
    _guideGate.clear();
    _armGuideThrough(pos);
    _applyPosition(nextPos);
    // Next chord guide fires when freeze arrives (_cueGuideIfNeeded).
  }

  void _advance(double beatDelta) {
    var next = state.positionBeats + beatDelta;
    final settings = state.settings;
    if (settings.loopEnabled) {
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
        // Match seek(): re-phase metro beat index (and click timer) to wrap.
        _audio.alignMetronomeToPosition(next);
      }
    } else if (next >= _score.durationBeats) {
      next = _score.durationBeats;
      pause();
      _applyPosition(next);
      return;
    }
    _applyPosition(next);
  }

  void _applyPosition(double next) {
    if (state.settings.mode.isAutoPlay) {
      state = state.copyWith(
        positionBeats: next,
        waitingFor: const {},
        activeMidi: _activeAt(state.filteredNotes, next),
      );
      return;
    }
    final expected = PracticeWaitLogic.expectedAt(
      notes: state.filteredNotes,
      pos: next,
    );
    state = state.copyWith(
      positionBeats: next,
      waitingFor: expected.difference(_satisfied),
      activeMidi: expected.isNotEmpty
          ? expected
          : _activeAt(state.filteredNotes, next),
    );
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
