import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import 'pitch_service.dart';
import 'practice_constants.dart';
import 'practice_models.dart';
import 'practice_stats_store.dart';
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

  /// MIDI → suppress mic echo until this time (speaker guide → mic feedback).
  final Map<int, DateTime> _echoSuppressUntil = {};

  ScoreAudioPlayer get _audio => ref.read(scoreAudioProvider);

  @override
  PracticeSnapshot build() {
    final pitch = ref.read(pitchServiceProvider);
    unawaited(_bootstrapAudioAndPitch(pitch));
    _pitchSub =
        pitch.noteOnStream.listen((midi) => _onNoteOn(midi, playSound: false));
    _pitchFrameSub = pitch.frameStream.listen((f) {
      // 自动播放关掉 mic；若仍有迟到帧，也不更新按下高亮。
      if (state.settings.mode.isAutoPlay) return;
      _pitchPressed = {
        for (final m in f.midis)
          if (!_isEchoSuppressed(m)) m,
      };
      _syncPressedMidi();
    });
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

  Future<void> _bootstrapAudioAndPitch(PitchService pitch) async {
    try {
      await _audio.ensureReady();
      _audio.setMasterVolume(state.settings.volume);
      // Device warm is silent zero-PCM inside ensureReady. Do NOT resume real
      // piano samples here — Windows volume-0 still leaks ("ghost notes" on open).
    } catch (e) {
      state = state.copyWith(statusHint: '示范音初始化失败：$e');
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
      state = state.copyWith(statusHint: err);
    }
  }

  Future<void> _stopPitch(PitchService pitch) async {
    _pitchPressed = {};
    _echoSuppressUntil.clear();
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

  void _markSelfPlayed(int midi) {
    final until = DateTime.now().add(PracticeConstants.echoSuppress);
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
    _satisfied = {};
    _audio.setMetronomeBpm(_score.bpm.toDouble());
    _audio.setMetronome(next.metronome);
    _audio.setSpeed(next.speed);
    _audio.setMasterVolume(next.volume);
    _audio.setHand(next.hand);
    final waiting = nowAuto
        ? <int>{}
        : _expectedAt(_score, state.positionBeats, next);
    if (nowAuto) {
      _pitchPressed = {};
      _echoSuppressUntil.clear();
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
      state = state.copyWith(statusHint: '示范音初始化失败：$e');
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

  /// True when [pos] is at/near beat 0 (not mid-piece, not already in pre-roll).
  bool _isAtPieceStart(double pos) {
    return pos >= -1e-6 && pos <= PracticeConstants.playbackLeadInSeekEps;
  }

  /// Apply negative pre-roll when starting/seeking at the piece beginning.
  double _withStartLeadIn(double pos) {
    // Already in pre-roll — keep current beats (do not snap back to −lead).
    if (pos < -1e-6) return pos;
    if (!_isAtPieceStart(pos)) return pos;
    return PracticeConstants.playbackStartParkBeats;
  }

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

    if (playSound) {
      // Prefer score-hand pan when this key is an expected/active note.
      _audio.playOneShot(midi, hand: state.highlightByHand[midi]);
      _markSelfPlayed(midi);
    }
    _syncPressedMidi();
    if (!state.pressedMidi.contains(midi)) {
      state = state.copyWith(pressedMidi: {...state.pressedMidi, midi});
    }
    // 跟弹练习才计命中。
    if (!state.isPlaying || state.settings.mode != PracticeMode.wait) return;

    if (state.waitingFor.contains(midi)) {
      _satisfied = {..._satisfied, midi};
      final remaining = {...state.waitingFor}..removeAll(_satisfied);
      state = state.copyWith(
        waitingFor: remaining,
        sessionHits: state.sessionHits + 1,
      );
      if (remaining.isEmpty) {
        _advancePastCurrentChord();
      }
    } else if (state.waitingFor.isNotEmpty) {
      state = state.copyWith(sessionMisses: state.sessionMisses + 1);
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

    // 跟弹：等正确音才前进。
    if (state.settings.mode == PracticeMode.wait) {
      final expected =
          _expectedAt(_score, state.positionBeats, state.settings);
      if (expected.isNotEmpty && !_satisfied.containsAll(expected)) {
        state = state.copyWith(
          waitingFor: expected.difference(_satisfied),
          activeMidi: expected,
        );
        return;
      }
      if (expected.isEmpty) {
        _advance(beatDelta);
        // Guide only as the playhead crosses onsets (not on play()).
        _playGuideAt(state.positionBeats);
      }
      return;
    }

    // 自动播放：按 BPM 时间轴前进，必播示范音。
    _advance(beatDelta);
    _playGuideAt(state.positionBeats);
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
    final volume =
        auto ? 1.0 : PracticeConstants.guideVolumeWithMic;
    for (final n in state.filteredNotes) {
      final key = '${n.midi}_${n.start}_${n.hand.name}';
      if (_audioFired.contains(key)) continue;
      if (n.start <= pos) {
        _audioFired.add(key);
        _markSelfPlayed(n.midi);
        _audio.playOneShot(n.midi, volume: volume, hand: n.hand);
      }
    }
  }

  void _advancePastCurrentChord() {
    final notes = _score.notesForHand(state.settings.hand);
    final pos = state.positionBeats;
    final atPos = notes.where((n) => (n.start - pos).abs() < 0.05).toList();
    double nextPos;
    if (atPos.isNotEmpty) {
      final start = atPos.first.start;
      final after = notes.where((n) => n.start > start + 0.001).toList();
      nextPos = after.isEmpty ? start + 0.25 : after.first.start;
    } else {
      final after = notes.where((n) => n.start > pos + 0.001).toList();
      nextPos = after.isEmpty ? pos + 0.25 : after.first.start;
    }
    _satisfied = {};
    // Arm the completed chord so guide plays only the newly reached onset.
    _armGuideThrough(pos);
    _applyPosition(nextPos);
    _playGuideAt(nextPos);
  }

  void _advance(double beatDelta) {
    var next = state.positionBeats + beatDelta;
    final settings = state.settings;
    if (settings.loopEnabled) {
      if (next >= settings.loopEnd) {
        next = _withStartLeadIn(settings.loopStart);
        _satisfied = {};
        _audioFired = {};
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
    final expected = _expectedAt(_score, next, state.settings);
    state = state.copyWith(
      positionBeats: next,
      waitingFor: expected.difference(_satisfied),
      activeMidi: expected,
    );
  }

  Set<int> _expectedAt(
    SongScore score,
    double pos,
    PracticeSettings settings,
  ) {
    if (settings.mode.isAutoPlay) return {};
    final notes = score.notesForHand(settings.hand);
    if (notes.isEmpty) return {};
    ScoreNote? target;
    for (final n in notes) {
      if (n.start + 0.001 >= pos - 0.001) {
        target = n;
        break;
      }
    }
    if (target == null) return {};
    // Pre-roll / gaps: free-advance until the playhead reaches the onset.
    // Do not require playing during pure lead-in before beat 0.
    if (target.start > pos + 0.02) return {};
    final start = target.start;
    return notes
        .where((n) => (n.start - start).abs() < 0.02)
        .map((n) => n.midi)
        .toSet();
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
