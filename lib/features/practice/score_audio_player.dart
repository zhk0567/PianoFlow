import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import 'practice_constants.dart';
import 'practice_loop_logic.dart';
import 'silent_warm_wav.dart';

part 'score_audio_synth.dart';

/// One metronome click (shared by audio + visual indicator).
@immutable
class MetronomeTick {
  const MetronomeTick({
    required this.beatIndex,
    required this.accent,
    required this.period,
  });

  final int beatIndex;
  final bool accent;
  final Duration period;

  /// 1-based beat in bar (default 4/4).
  int beatInBar({int beatsPerBar = 4}) =>
      (beatIndex % beatsPerBar) + 1;
}

/// Acoustic Grand Piano samples + low-latency one-shot playback.
///
/// Piano tones are MusyngKite Acoustic Grand one-shots (assets/audio/piano),
/// copied into a temp cache with [PracticeConstants.sampleGain] soft-clip so
/// 100% slider is ~10× louder than the quiet source peaks (AudioPlayer max
/// volume remains 1.0). Metronome clicks stay synth-generated.
///
/// Players are bound lazily (plus optional [prefetchMidis]) so we do not open
/// 88 [AudioPlayer]s at once — on Windows that floods `audioplayers` platform-
/// thread ERROR spam from the plugin.
///
/// Stereo: samples are mono; [AudioPlayer.setBalance] pans by score hand
/// (LH left / RH right) and MIDI pitch (bass left → treble right) on Windows.
class ScoreAudioPlayer {
  ScoreAudioPlayer();

  static const _sampleRate = 22050;
  static final Map<int, String> _noteFiles = {};
  static final Map<int, String> _clickFiles = {};
  static Directory? _cacheDir;
  /// PCM-zero buffer used only for WASAPI / MediaPlayer device open.
  static String? _silentWarmFile;
  /// Bump when bundled samples, [PracticeConstants.sampleCacheGain], or sustain
  /// shaping constants change.
  static const _cacheVersion = 'v7-stereo-sustain';

  final Map<int, AudioPlayer> _notePlayers = {};
  final Map<int, AudioPlayer> _clickPlayers = {};
  final Map<int, Future<AudioPlayer?>> _noteBindInflight = {};
  /// Bumped per MIDI so overlapping [_retrigger] calls drop stale resumes.
  final Map<int, int> _noteRetriggerGen = {};
  bool _ready = false;
  Future<void>? _readyFuture;

  Timer? _clock;
  Timer? _metro;
  DateTime? _startedAt;
  double _pausedAtBeats = 0;
  double _speed = 1.0;
  double _masterVolume = PracticeConstants.volumeDefault;
  bool _playing = false;

  /// Practice page drives its own clock; use this so metronome can tick without score autoplay.
  bool _transportPlaying = false;
  bool _metronome = false;
  double _metroBpm = 100;
  /// When false (wait-mode freeze), stop clicks even if transport is "playing".
  bool _metroAdvancing = true;
  SongScore? _score;
  Hand _hand = Hand.both;
  final Set<String> _fired = {};
  int _metroBeat = 0;

  /// Bumped on [pause]/[stop] so in-flight [_retrigger] cannot resume after silence.
  int _voiceEpoch = 0;

  final _position = StreamController<double>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _metroTicks = StreamController<MetronomeTick>.broadcast();

  Stream<double> get positionBeatsStream => _position.stream;
  Stream<bool> get playingStream => _playingCtrl.stream;
  Stream<MetronomeTick> get metronomeTickStream => _metroTicks.stream;
  bool get isPlaying => _playing;
  bool get metronomeEnabled => _metronome;
  int get metronomeBeatIndex => _metroBeat;
  double get positionBeats => _computePosition();
  SongScore? get score => _score;
  double get durationBeats => _score?.durationBeats ?? 0;
  bool get isReady => _ready;

  Future<void> ensureReady() {
    if (_ready) return Future.value();
    return _readyFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      _cacheDir = await getTemporaryDirectory();
      final toneDir =
          Directory('${_cacheDir!.path}/pianoflow_tones_$_cacheVersion');
      if (!await toneDir.exists()) {
        await toneDir.create(recursive: true);
      }

      // Copy bundled Acoustic Grand WAVs to disk once, applying sampleGain
      // (soft-clip) so effective loudness can exceed AudioPlayer's 0–1 volume.
      for (var midi = PracticeConstants.midiMin;
          midi <= PracticeConstants.midiMax;
          midi++) {
        final file = File('${toneDir.path}/n$midi.wav');
        if (!await file.exists()) {
          final data =
              await rootBundle.load('assets/audio/piano/n$midi.wav');
          final raw = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final boosted = _shapePianoWav(
            raw,
            gain: PracticeConstants.sampleCacheGain,
            maxSeconds: PracticeConstants.noteMaxSeconds,
            fadeSeconds: PracticeConstants.noteFadeSeconds,
            decayTau: PracticeConstants.noteDecayTau,
          );
          await file.writeAsBytes(boosted, flush: true);
        }
        _noteFiles[midi] = file.path;
      }
      for (final accent in [true, false]) {
        final file = File('${toneDir.path}/click_${accent ? 'a' : 'b'}.wav');
        if (!await file.exists()) {
          await file.writeAsBytes(_renderClickWav(accent: accent), flush: true);
        }
        _clickFiles[accent ? 1 : 0] = file.path;
      }
      final silentFile = File('${toneDir.path}/silent_warm.wav');
      if (await silentFile.exists()) {
        final existing = await silentFile.readAsBytes();
        if (!SilentWarmWav.isZeroPcm16Mono(existing)) {
          pianoFlowLog(
            'Audio',
            'cached silent_warm.wav not zero-PCM — rewriting',
          );
          await silentFile.delete();
        }
      }
      if (!await silentFile.exists()) {
        final silentBytes = _renderSilentWav();
        // Refuse to cache a warm buffer that could ghost-note on open.
        if (!SilentWarmWav.isZeroPcm16Mono(silentBytes)) {
          pianoFlowLog('Audio', 'silent warm WAV is not zero-PCM — abort init');
          throw StateError('silent warm WAV must be zero-PCM');
        }
        await silentFile.writeAsBytes(silentBytes, flush: true);
      }
      _silentWarmFile = silentFile.path;

      // Only clicks + silent warm at init. Note players bind lazily /
      // via [prefetchMidis] to avoid 88× audioplayers platform-thread spam.
      final clickEntries = _clickFiles.entries.toList();
      await Future.wait([
        for (final e in clickEntries) _bindPlayer(_clickPlayers, e.key, e.value),
      ]);

      // Open the Windows/desktop audio device once so the first audible
      // resume() is not paying cold-start latency (~0.5–1s).
      await _warmPipeline();

      _ready = true;
      pianoFlowLog(
        'Audio',
        'ready (clicks=${_clickPlayers.length}; notes lazy-bind)',
      );
    } catch (e, st) {
      _readyFuture = null;
      pianoFlowLog('Audio', 'ScoreAudioPlayer init failed: $e\n$st');
      rethrow;
    }
  }

  /// Prefetch pitches whose onsets fall in [[fromBeats], [fromBeats]+[lookAheadBeats]].
  Future<void> prefetchMidisNear(
    Iterable<ScoreNote> notes, {
    required double fromBeats,
    double lookAheadBeats = 8,
  }) {
    final lo = fromBeats;
    final hi = fromBeats + lookAheadBeats;
    final midis = <int>{
      for (final n in notes)
        if (n.start >= lo - 0.05 && n.start <= hi) n.midi,
    };
    return prefetchMidis(midis);
  }

  /// Pre-bind players for [midis] (score pitches) before play to avoid first-hit lag.
  Future<void> prefetchMidis(Iterable<int> midis) async {
    await ensureReady();
    final needed = <int>{};
    for (final raw in midis) {
      final m = raw.clamp(
        PracticeConstants.midiMin,
        PracticeConstants.midiMax,
      );
      if (_notePlayers.containsKey(m) || _noteBindInflight.containsKey(m)) {
        continue;
      }
      if (_noteFiles.containsKey(m)) needed.add(m);
    }
    if (needed.isEmpty) return;
    const batchSize = 8;
    final list = needed.toList()..sort();
    for (var i = 0; i < list.length; i += batchSize) {
      final slice = list.skip(i).take(batchSize);
      await Future.wait([for (final m in slice) _ensureNotePlayer(m)]);
    }
    pianoFlowLogVerbose(
      'Audio',
      'prefetchMidis bound=${list.length} totalNotes=${_notePlayers.length}',
    );
  }

  Future<AudioPlayer?> _ensureNotePlayer(int midi) async {
    final hit = _notePlayers[midi];
    if (hit != null) return hit;
    final inflight = _noteBindInflight[midi];
    if (inflight != null) return inflight;
    final path = _noteFiles[midi];
    if (path == null) return null;
    final future = () async {
      await _bindPlayer(_notePlayers, midi, path);
      return _notePlayers[midi];
    }();
    _noteBindInflight[midi] = future;
    try {
      return await future;
    } finally {
      _noteBindInflight.remove(midi);
    }
  }

  /// Open WASAPI / MediaPlayer once so the first audible resume() is not cold.
  ///
  /// Uses a dedicated zero-PCM buffer only. Never resume a real piano/click
  /// sample: on Windows, [AudioPlayer.setVolume] (0) still often leaks a brief
  /// audible hit ("ghost note" on app / practice-page open). Per-note warm via
  /// resume-at-zero was removed for the same reason.
  Future<void> _warmPipeline() async {
    final path = _silentWarmFile;
    if (path == null) return;
    AudioPlayer? warm;
    try {
      warm = AudioPlayer();
      await warm.setPlayerMode(PlayerMode.lowLatency);
      await warm.setReleaseMode(ReleaseMode.stop);
      // Zero PCM stays inaudible even at full fader — avoid volume-0 quirks.
      await warm.setVolume(1);
      await warm.setSource(DeviceFileSource(path));
      await warm.resume();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await warm.stop();
    } catch (e) {
      // Warm failures are non-fatal; still surface so console can diagnose silence.
      pianoFlowLog('Audio', 'device warm skipped or failed: $e');
    } finally {
      try {
        await warm?.dispose();
      } catch (e) {
        pianoFlowLog('Audio', 'warm player dispose failed: $e');
      }
    }
  }

  Future<void> _bindPlayer(
    Map<int, AudioPlayer> map,
    int key,
    String path,
  ) async {
    final p = AudioPlayer();
    await p.setPlayerMode(PlayerMode.lowLatency);
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setVolume(_playerLevel(_masterVolume));
    // Preload so taps never pay setSource / prepare cost.
    await p.setSource(DeviceFileSource(path));
    map[key] = p;
  }

  /// Map linear master (0–[volumeMax]) onto AudioPlayer's 0–1 fader.
  double _playerLevel(double linear) {
    final max = PracticeConstants.volumeMax;
    if (max <= 0) return 0;
    return (linear / max).clamp(0.0, 1.0);
  }

  /// Master gain for piano notes and metronome clicks (0–[volumeMax]).
  void setMasterVolume(double volume) {
    final next = volume.clamp(
      PracticeConstants.volumeMin,
      PracticeConstants.volumeMax,
    );
    // Avoid flooding 88 setVolume calls on every play() — that glitches the
    // first note / click at transport start.
    if ((next - _masterVolume).abs() < 1e-6) return;
    _masterVolume = next;
    final level = _playerLevel(_masterVolume);
    for (final p in [..._notePlayers.values, ..._clickPlayers.values]) {
      unawaited(p.setVolume(level));
    }
  }

  double get masterVolume => _masterVolume;

  Future<void> load(SongScore score, {Hand hand = Hand.both}) async {
    await ensureReady();
    await stop();
    _score = score;
    _hand = hand;
    _pausedAtBeats = PracticeConstants.playbackStartParkBeats;
    _position.add(_pausedAtBeats);
  }

  void setHand(Hand hand) => _hand = hand;

  void setSpeed(double speed) {
    final next = speed.clamp(
      PracticeConstants.speedMin,
      PracticeConstants.speedMaxAudio,
    );
    if ((next - _speed).abs() < 1e-6) return;
    final pos = _computePosition();
    _speed = next;
    if (_playing) {
      _pausedAtBeats = pos;
      _startedAt = DateTime.now();
      _fired.clear();
      _armPastNotes(pos);
    }
    if (_playing || _transportPlaying) {
      _restartMetronome(preserveBeat: true);
    }
  }

  void setMetronome(bool enabled) {
    if (_metronome == enabled) {
      // Still ensure timers match transport, but skip a redundant click restart
      // when play() re-asserts the same metronome flag.
      if (enabled && (_playing || _transportPlaying) && _metro == null) {
        _restartMetronome(preserveBeat: true);
      }
      return;
    }
    _metronome = enabled;
    _restartMetronome(preserveBeat: true);
  }

  /// BPM for metronome when no score is loaded into this player (practice path).
  void setMetronomeBpm(double bpm) {
    final next = bpm.clamp(
      PracticeConstants.metroBpmMin,
      PracticeConstants.metroBpmMax,
    );
    if ((next - _metroBpm).abs() < 1e-6) return;
    _metroBpm = next;
    if (_metronome) _restartMetronome(preserveBeat: true);
  }

  /// Align metro beat index to practice [positionBeats] so visual/audio share phase.
  ///
  /// When the metronome is already running (seek / loop wrap), also restart the
  /// click timer so accents stay locked to the new playhead — not the old phase.
  void alignMetronomeToPosition(double positionBeats) {
    _metroBeat = PracticeLoopLogic.metronomeBeatIndexForPosition(positionBeats);
    if (_metronome &&
        (_playing || _transportPlaying) &&
        _metroAdvancing) {
      _restartMetronome(preserveBeat: true);
    }
  }

  /// Wait-mode freeze: playhead rate 0 → pause metro; resume when advancing.
  void setMetronomeAdvancing(bool advancing) {
    if (_metroAdvancing == advancing) return;
    _metroAdvancing = advancing;
    if (!advancing) {
      _metro?.cancel();
      _metro = null;
    } else {
      _restartMetronome(preserveBeat: true);
    }
  }

  /// When true, metronome may run even if score autoplay [_playing] is false.
  void setTransportPlaying(bool playing) {
    _transportPlaying = playing;
    if (!playing) {
      _metro?.cancel();
      _metro = null;
    } else {
      _restartMetronome(preserveBeat: true);
    }
  }

  Future<void> play() async {
    if (_score == null) return;
    await ensureReady();
    if (_playing) return;
    _playing = true;
    _playingCtrl.add(true);
    _startedAt = DateTime.now();
    // Pre-roll from piece start so beat-0 notes are not immediate.
    if (_pausedAtBeats >= -1e-6 &&
        _pausedAtBeats <= PracticeConstants.playbackLeadInSeekEps) {
      _pausedAtBeats = PracticeConstants.playbackStartParkBeats;
    }
    _fired.clear();
    _armPastNotes(_pausedAtBeats);
    _clock?.cancel();
    // Fire notes at the playhead; Timer.periodic would wait one period.
    // During lead-in this is a no-op until position crosses the first onset.
    _tick();
    _clock = Timer.periodic(PracticeConstants.tickPeriod, (_) => _tick());
    _restartMetronome();
  }

  Future<void> pause() async {
    if (!_playing) return;
    _pausedAtBeats = _computePosition();
    _playing = false;
    _playingCtrl.add(false);
    _clock?.cancel();
    _clock = null;
    _metro?.cancel();
    _metro = null;
    _voiceEpoch++;
    await _stopAllPlayers();
  }

  Future<void> stop() async {
    _clock?.cancel();
    _clock = null;
    _metro?.cancel();
    _metro = null;
    _playing = false;
    _transportPlaying = false;
    _playingCtrl.add(false);
    _pausedAtBeats = PracticeConstants.playbackStartParkBeats;
    _startedAt = null;
    _fired.clear();
    _metroBeat = 0;
    _voiceEpoch++;
    _position.add(_pausedAtBeats);
    await _stopAllPlayers();
  }

  Future<void> seek(double beats) async {
    final max = durationBeats;
    var target = beats.clamp(0.0, max);
    // Seek-to-start gets pre-roll; mid-piece seeks do not.
    if (target >= -1e-6 &&
        target <= PracticeConstants.playbackLeadInSeekEps) {
      target = PracticeConstants.playbackStartParkBeats;
    }
    _pausedAtBeats = target;
    _startedAt = DateTime.now();
    _fired.clear();
    _armPastNotes(_pausedAtBeats);
    _position.add(_pausedAtBeats);
    if (!_playing) {
      await _stopAllPlayers();
    } else {
      _restartMetronome();
    }
  }

  /// Fire-and-forget one-shot. Prefer this for UI key presses (no await chain).
  ///
  /// [volume] is a relative level 0–1, multiplied by [masterVolume].
  /// [hand] drives LH→left / RH→right balance; omit for pitch-only pan.
  void playOneShot(int midi, {double volume = 1.0, Hand? hand}) {
    final linear = (volume * _masterVolume).clamp(
      0.0,
      PracticeConstants.volumeMax,
    );
    final level = _playerLevel(linear);
    final balance = PracticeConstants.stereoBalanceFor(midi: midi, hand: hand);
    if (!_ready) {
      unawaited(
        ensureReady().then((_) => _triggerNote(midi, level, balance)),
      );
      return;
    }
    _triggerNote(midi, level, balance);
  }

  /// Silence one-shot voices (e.g. soft guide cue when echo-suppress ends).
  /// Same MIDI pool as [playOneShot] — next press retriggers normally.
  void stopOneShots(Iterable<int> midis) {
    for (final raw in midis) {
      final midi = raw.clamp(
        PracticeConstants.midiMin,
        PracticeConstants.midiMax,
      );
      final player = _notePlayers[midi];
      if (player == null) continue;
      unawaited(() async {
        try {
          await player.stop();
        } catch (e) {
          pianoFlowLog('Audio', 'stopOneShot midi=$midi failed: $e');
        }
      }());
    }
  }

  void _triggerNote(int midi, double volume, double balance) {
    final m = midi.clamp(
      PracticeConstants.midiMin,
      PracticeConstants.midiMax,
    );
    final player = _notePlayers[m];
    if (player != null) {
      unawaited(_retrigger(player, volume, midi: m, balance: balance));
      return;
    }
    unawaited(() async {
      final p = await _ensureNotePlayer(m);
      if (p == null) return;
      await _retrigger(p, volume, midi: m, balance: balance);
    }());
  }

  void _triggerClick({required bool accent}) {
    if (!_metronome || !(_playing || _transportPlaying)) return;
    final player = _clickPlayers[accent ? 1 : 0];
    if (player == null) return;
    final rel = accent ? 0.7 : 0.45;
    final linear = (rel * _masterVolume).clamp(
      0.0,
      PracticeConstants.volumeMax,
    );
    // Metronome stays centered so it does not pull the stereo image.
    // Key -1: click pool (not a piano MIDI).
    unawaited(
      _retrigger(player, _playerLevel(linear), midi: -1, balance: 0),
    );
  }

  /// Replay a preloaded source without calling [AudioPlayer.setSource].
  ///
  /// Windows `audioplayers`: awaiting [setBalance]/[setVolume] on a burst of
  /// first-chord notes stalls the method channel while the practice Timer
  /// keeps advancing → hit line moves, audio feels "stuck". Attack path only
  /// awaits seek+resume; pan/level are best-effort and non-blocking.
  Future<void> _retrigger(
    AudioPlayer player,
    double volume, {
    required int midi,
    double balance = 0,
  }) async {
    final epoch = _voiceEpoch;
    final gen = (_noteRetriggerGen[midi] ?? 0) + 1;
    _noteRetriggerGen[midi] = gen;
    bool stale() => epoch != _voiceEpoch || _noteRetriggerGen[midi] != gen;
    try {
      if ((player.balance - balance).abs() > 0.02) {
        unawaited(player.setBalance(balance));
      }
      if ((player.volume - volume).abs() > 0.02) {
        unawaited(player.setVolume(volume));
      }
      if (stale()) return;
      // seek+resume avoids a full stop() round-trip that often clicks / delays
      // the very first note after transport start.
      try {
        await player.seek(Duration.zero);
      } catch (e) {
        pianoFlowLog('Audio', 'tone seek failed, fallback stop: $e');
        await player.stop();
        if (stale()) return;
      }
      if (stale()) return;
      await player.resume();
      // pause/stop may have raced past resume — silence again.
      if (stale()) {
        try {
          await player.stop();
        } catch (e) {
          pianoFlowLog('Audio', 'tone stop after cancel failed: $e');
        }
      }
    } catch (e) {
      pianoFlowLog('Audio', 'tone play failed: $e');
    }
  }

  void _restartMetronome({bool preserveBeat = false}) {
    final wasRunning = _metro != null;
    _metro?.cancel();
    _metro = null;
    final active = (_playing || _transportPlaying) && _metroAdvancing;
    if (!_metronome || !active) return;
    final bpm = (_score?.bpm ?? _metroBpm) * _speed;
    final periodMs = (60000 / bpm).round().clamp(120, 2000);
    final period = Duration(milliseconds: periodMs);
    if (!preserveBeat) {
      _metroBeat = 0;
    }
    // Dart Timer.periodic delays the first callback by [period] (e.g. ~1s at
    // 60 BPM). Fire immediately when starting or when resetting to beat 0.
    if (!wasRunning || !preserveBeat) {
      _emitMetronomeTick(period);
    }
    _metro = Timer.periodic(period, (_) => _emitMetronomeTick(period));
  }

  void _emitMetronomeTick(Duration period) {
    if (!_metronome || !(_playing || _transportPlaying) || !_metroAdvancing) {
      return;
    }
    final accent = _metroBeat % 4 == 0;
    final tick = MetronomeTick(
      beatIndex: _metroBeat,
      accent: accent,
      period: period,
    );
    _metroBeat++;
    _triggerClick(accent: accent);
    if (!_metroTicks.isClosed) {
      _metroTicks.add(tick);
    }
  }

  void _armPastNotes(double pos) {
    final notes = _score?.notesForHand(_hand) ?? const <ScoreNote>[];
    for (final n in notes) {
      if (n.start < pos - 0.01) {
        _fired.add(_key(n));
      }
    }
  }

  void _tick() {
    if (!_playing || _score == null) return;
    final pos = _computePosition();
    _position.add(pos);

    final notes = _score!.notesForHand(_hand);
    for (final n in notes) {
      final key = _key(n);
      if (_fired.contains(key)) continue;
      if (n.start <= pos) {
        _fired.add(key);
        playOneShot(n.midi, hand: n.hand);
      }
    }

    if (pos >= durationBeats) {
      unawaited(stop());
    }
  }

  double _computePosition() {
    if (!_playing || _startedAt == null) return _pausedAtBeats;
    final bpm = (_score?.bpm ?? 100) * _speed;
    final elapsed = DateTime.now().difference(_startedAt!).inMicroseconds / 1e6;
    return _pausedAtBeats + elapsed * (bpm / 60.0);
  }

  String _key(ScoreNote n) => '${n.midi}_${n.start}_${n.hand.name}';

  Future<void> _stopAllPlayers() async {
    final players = [..._notePlayers.values, ..._clickPlayers.values];
    var fail = 0;
    Object? lastErr;
    await Future.wait([
      for (final p in players)
        Future(() async {
          try {
            await p.stop();
          } catch (e) {
            fail++;
            lastErr = e;
          }
        }),
    ]);
    if (fail > 0) {
      pianoFlowLog('Audio', 'stopAllPlayers: $fail failed (last: $lastErr)');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _position.close();
    await _playingCtrl.close();
    await _metroTicks.close();
    var disposeFail = 0;
    Object? lastDisposeErr;
    for (final p in [..._notePlayers.values, ..._clickPlayers.values]) {
      try {
        await p.dispose();
      } catch (e) {
        disposeFail++;
        lastDisposeErr = e;
      }
    }
    if (disposeFail > 0) {
      pianoFlowLog(
        'Audio',
        'player dispose: $disposeFail failed (last: $lastDisposeErr)',
      );
    }
    _notePlayers.clear();
    _clickPlayers.clear();
    _ready = false;
    _readyFuture = null;
  }
}

final scoreAudioProvider = Provider<ScoreAudioPlayer>((ref) {
  final player = ScoreAudioPlayer();
  // Warm device + clicks only; note players bind per-score / on demand.
  unawaited(player.ensureReady());
  ref.onDispose(player.dispose);
  return player;
});
