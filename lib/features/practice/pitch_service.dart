import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../shared/piano_flow_log.dart';
import 'basic_pitch.dart';
import 'pitch_yin.dart';
import 'swift_f0.dart';

enum PitchEngineKind { basicPitch, swiftf0, yin }

/// noteOn edge with capture time (end of PCM hop that produced the lock).
class PitchNoteOn {
  const PitchNoteOn({required this.midi, required this.captureAt});

  final int midi;
  final DateTime captureAt;
}

class PitchFrame {
  const PitchFrame({
    required this.rms,
    required this.peak,
    required this.rmsDb,
    required this.aboveGate,
    required this.engine,
    this.hz,
    this.midi,
    this.midis = const {},
    this.label,
    this.clarity,
    this.confirmed = false,
    this.captureAt,
  });

  final double rms;
  final double peak;
  final double rmsDb;
  final bool aboveGate;
  final PitchEngineKind engine;
  final double? hz;

  /// Primary / first confirmed MIDI (compat).
  final int? midi;

  /// All currently locked MIDI notes (polyphonic).
  final Set<int> midis;
  final String? label;
  final double? clarity;
  final bool confirmed;

  /// End of the PCM hop that produced this frame (for capture-time grading).
  final DateTime? captureAt;
}

/// Microphone → Basic Pitch (poly) / SwiftF0 / YIN → stable MIDI set.
class PitchService {
  PitchService();

  static const sampleRate = 44100;
  /// 0.25s hop window for gate / YIN / SwiftF0 (snappy noteOn).
  /// Was ~0.32s; shortened for 跟弹体感 (docs/前沿Idea-本地实时一条龙.md).
  static const _window = 11025;
  /// ~30ms hop (was ~40ms / 1764) — snappier noteOn / frame ticks.
  static const _hop = 1323;
  /// Basic Pitch model rate / length — maintain a rolling ring at this rate
  /// so each hop only resamples ~30ms, not the full ~2s window.
  static const _bpRate = BasicPitchEstimator.sampleRate; // 22050
  static const _bpContextSamples = BasicPitchEstimator.audioNSamples; // 43844

  static const rmsGate = 0.005;
  /// 1 frame lock: with ~30ms hops, keep lock immediate.
  static const _lockFrames = 1;
  /// 1 miss frame unlock (~30ms). Was 2 (~80ms@40ms hop) — same-pitch rehits
  /// while BP stays locked never got a second noteOn edge.
  static const _releaseFrames = 1;

  final _recorder = AudioRecorder();
  final _yin = YinPitch(sampleRate: sampleRate, threshold: 0.15);
  final _noteController = StreamController<PitchNoteOn>.broadcast();
  final _frameController = StreamController<PitchFrame>.broadcast();

  StreamSubscription<Uint8List>? _sub;
  final BytesBuilder _pending = BytesBuilder(copy: false);

  BasicPitchEstimator? _basic;
  SwiftF0Estimator? _swift;
  PitchEngineKind _engine = PitchEngineKind.yin;
  bool _inferBusy = false;
  /// When infer is busy, keep only the newest PCM window (drop stale hops).
  ({Uint8List pcm, DateTime captureAt})? _latestWhileBusy;

  final Map<int, int> _hitCount = {};
  final Map<int, int> _missCount = {};
  Set<int> _locked = {};
  final Set<int> _emitted = {};

  /// Optional PCM16 tee (exam recording).
  void Function(Uint8List pcm)? pcmTee;
  DateTime? _lastHeard;
  Timer? _clearTimer;
  bool _running = false;
  String? lastError;
  int _chunkCount = 0;
  int _droppedStale = 0;

  /// Ring of recent PCM @22.05kHz for Basic Pitch (true audio, incremental).
  final Float64List _bpRing = Float64List(_bpContextSamples);
  int _bpWrite = 0;
  int _bpFilled = 0;
  /// First window seeds the ring; later hops append only new [_hop] samples.
  bool _bpPrimed = false;

  Stream<PitchNoteOn> get noteOnStream => _noteController.stream;
  Stream<PitchFrame> get frameStream => _frameController.stream;
  bool get isRunning => _running;
  PitchEngineKind get engine => _engine;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_running) return;
    lastError = null;
    _chunkCount = 0;
    _hitCount.clear();
    _missCount.clear();
    _locked = {};
    _emitted.clear();
    _inferBusy = false;
    _latestWhileBusy = null;
    _droppedStale = 0;
    _bpWrite = 0;
    _bpFilled = 0;
    _bpPrimed = false;

    await _initEngine();

    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        lastError = '没有麦克风权限，请在系统设置中允许 PianoFlow 使用麦克风。';
        pianoFlowLog('Pitch', lastError!);
        return;
      }

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      _running = true;
      _sub = stream.listen(
        _onPcm,
        onError: (Object e) {
          pianoFlowLog('Pitch', 'stream error: $e');
          lastError = '麦克风异常（详情见控制台 [PianoFlow/Pitch]）';
        },
        onDone: () {
          pianoFlowLogVerbose('Pitch', 'stream done');
          _running = false;
        },
      );
    } catch (e) {
      pianoFlowLog('Pitch', 'start failed: $e');
      lastError = '麦克风启动失败（详情见控制台 [PianoFlow/Pitch]）';
      _running = false;
    }
  }

  Future<void> _initEngine() async {
    await _basic?.dispose();
    await _swift?.dispose();
    _basic = null;
    _swift = null;
    _engine = PitchEngineKind.yin;

    try {
      if (await basicPitchAssetExists()) {
        _basic = await BasicPitchEstimator.create();
        _engine = PitchEngineKind.basicPitch;
        pianoFlowLog('Pitch', 'engine: Basic Pitch (polyphonic)');
        return;
      }
      pianoFlowLog('Pitch', 'Basic Pitch skipped (asset absent)');
    } catch (e, st) {
      pianoFlowLog('Pitch', 'Basic Pitch init failed: $e\n$st');
      _basic = null;
    }

    try {
      if (await swiftF0AssetExists()) {
        _swift = await SwiftF0Estimator.create();
        _engine = PitchEngineKind.swiftf0;
        pianoFlowLog('Pitch', 'engine: SwiftF0 (monophonic fallback)');
        return;
      }
      pianoFlowLog('Pitch', 'SwiftF0 skipped (asset absent)');
    } catch (e, st) {
      pianoFlowLog('Pitch', 'SwiftF0 init failed: $e\n$st');
      _swift = null;
    }

    pianoFlowLog('Pitch', 'engine: YIN fallback');
    _engine = PitchEngineKind.yin;
  }

  Future<void> stop() async {
    _clearTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    _pending.clear();
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      pianoFlowLog('Pitch', 'recorder stop on shutdown: $e');
    }
    _running = false;
    _hitCount.clear();
    _missCount.clear();
    _locked = {};
    _emitted.clear();
    _inferBusy = false;
    _latestWhileBusy = null;
    _bpWrite = 0;
    _bpFilled = 0;
    _bpPrimed = false;
  }

  void _appendBp22k(Float32List samples22050) {
    for (var i = 0; i < samples22050.length; i++) {
      _bpRing[_bpWrite] = samples22050[i];
      _bpWrite++;
      if (_bpWrite >= _bpContextSamples) _bpWrite = 0;
      if (_bpFilled < _bpContextSamples) _bpFilled++;
    }
  }

  /// Feed BP ring: first window full; thereafter only the newly advanced hop.
  void _feedBpFrom44100Window(Float64List window441) {
    if (window441.isEmpty) return;
    if (!_bpPrimed) {
      _appendBp22k(resampleLinear(window441, sampleRate, _bpRate));
      _bpPrimed = true;
      return;
    }
    final hopStart = math.max(0, window441.length - _hop);
    final hop = Float64List.sublistView(window441, hopStart);
    _appendBp22k(resampleLinear(hop, sampleRate, _bpRate));
  }

  /// Chronological view of the rolling BP context @22.05kHz (oldest → newest).
  Float32List _bpContextLinear22k() {
    if (_bpFilled <= 0) return Float32List(0);
    if (_bpFilled < _bpContextSamples) {
      final out = Float32List(_bpFilled);
      for (var i = 0; i < _bpFilled; i++) {
        out[i] = _bpRing[i];
      }
      return out;
    }
    final out = Float32List(_bpContextSamples);
    final head = _bpContextSamples - _bpWrite;
    for (var i = 0; i < head; i++) {
      out[i] = _bpRing[_bpWrite + i];
    }
    for (var i = 0; i < _bpWrite; i++) {
      out[head + i] = _bpRing[i];
    }
    return out;
  }

  /// Allow [midis] to re-fire on [noteOnStream] after guide echo / suppress.
  void clearEmitted([Iterable<int>? midis]) {
    if (midis == null) {
      _emitted.clear();
      return;
    }
    _emitted.removeAll(midis);
  }

  /// Whether [midi] already produced a noteOn edge while still locked.
  bool isEmitted(int midi) => _emitted.contains(midi);

  /// After [clearEmitted]: if still locked, fire noteOn immediately (held tones
  /// after guide suppress — do not wait for the next hop / key re-strike).
  void reedgeIfLocked([Iterable<int>? midis]) {
    final targets = midis == null
        ? _locked
        : midis.where(_locked.contains).toSet();
    final now = DateTime.now();
    for (final m in targets) {
      if (_emitted.add(m)) {
        _noteController.add(PitchNoteOn(midi: m, captureAt: now));
        pianoFlowLogVerbose(
          'Pitch',
          'reedge ${YinPitch.midiLabel(m)}',
        );
      }
    }
  }

  void dispose() {
    unawaited(() async {
      await stop();
      await _basic?.dispose();
      await _swift?.dispose();
      _basic = null;
      _swift = null;
      await _recorder.dispose();
      await _noteController.close();
      await _frameController.close();
    }());
  }

  void _onPcm(Uint8List data) {
    if (data.isEmpty) return;
    pcmTee?.call(data);
    _pending.add(data);
    final windowBytes = _window * 2;
    final hopBytes = _hop * 2;
    while (_pending.length >= windowBytes) {
      final all = _pending.takeBytes();
      final chunk = Uint8List.sublistView(all, 0, windowBytes);
      if (all.length > hopBytes) {
        _pending.add(Uint8List.sublistView(all, hopBytes));
      }
      // Feed BP @22.05k ring incrementally (even hops dropped while infer busy).
      if (_engine == PitchEngineKind.basicPitch) {
        _feedBpFrom44100Window(pcm16ToFloat(chunk));
      }
      unawaited(_analyze(chunk, DateTime.now()));
    }
  }

  Future<void> _analyze(Uint8List pcm16, DateTime captureAt) async {
    if (_inferBusy) {
      if (_latestWhileBusy != null) _droppedStale++;
      _latestWhileBusy = (pcm: pcm16, captureAt: captureAt);
      return;
    }
    _inferBusy = true;
    _chunkCount++;
    try {
      await _analyzeBody(pcm16, captureAt);
    } finally {
      _inferBusy = false;
      final next = _latestWhileBusy;
      _latestWhileBusy = null;
      if (next != null) {
        unawaited(_analyze(next.pcm, next.captureAt));
      }
    }
  }

  Future<void> _analyzeBody(Uint8List pcm16, DateTime captureAt) async {
    try {
      final samples = pcm16ToFloat(pcm16);
      final level = measureLevel(samples);
      final above = level.rms >= rmsGate;

      var raw = <int>{};
      double? hz;
      double? clarity;

      if (above) {
        if (_engine == PitchEngineKind.basicPitch && _basic != null) {
          // Incremental 22.05kHz rolling context — no full-window resample.
          raw = await _basic!.estimateActiveMidi(_bpContextLinear22k());
        } else if (_engine == PitchEngineKind.swiftf0 && _swift != null) {
          final est = await _swift!.estimateFrom44100(samples);
          if (est != null) {
            hz = est.hz;
            clarity = est.clarity;
            final m = YinPitch.hzToMidi(est.hz, maxCents: 40);
            if (m != null) raw = {m};
          }
        } else {
          final est = _yin.estimate(samples);
          if (est != null) {
            hz = est.hz;
            clarity = est.clarity;
            final m = YinPitch.hzToMidi(est.hz, maxCents: 40);
            if (m != null) raw = {m};
          }
        }
      }

      final locked = _updateLock(raw, above);

      final label = locked.isEmpty
          ? null
          : (locked.toList()..sort())
              .map(YinPitch.midiLabel)
              .join(' ');

      _frameController.add(
        PitchFrame(
          rms: level.rms,
          peak: level.peak,
          rmsDb: amplitudeToDb(level.rms),
          aboveGate: above,
          engine: _engine,
          hz: hz,
          midi: locked.isEmpty ? null : locked.first,
          midis: locked,
          label: label,
          clarity: clarity,
          confirmed: locked.isNotEmpty,
          captureAt: captureAt,
        ),
      );

      if (locked.isEmpty) {
        // Unlock must free noteOn edges immediately — delaying _emitted clear
        // by ~280ms left cue bleed blocking the first post-cue attack.
        _emitted.clear();
        _scheduleClear();
        return;
      }

      _lastHeard = DateTime.now();
      _clearTimer?.cancel();

      for (final m in locked) {
        if (_emitted.add(m)) {
          _noteController.add(PitchNoteOn(midi: m, captureAt: captureAt));
          pianoFlowLogVerbose(
            'Pitch',
            '+${YinPitch.midiLabel(m)} '
            'engine=${_engine.name} '
            'set=${locked.map(YinPitch.midiLabel).join(",")} '
            'chunks=$_chunkCount'
            '${_droppedStale > 0 ? " staleDrop=$_droppedStale" : ""}',
          );
        }
      }
      _emitted.removeWhere((m) => !locked.contains(m));
    } catch (e, st) {
      pianoFlowLog('Pitch', 'analyze failed: $e\n$st');
    }
  }

  Set<int> _updateLock(Set<int> raw, bool above) {
    if (!above) {
      _hitCount.clear();
      for (final m in _locked.toList()) {
        _missCount[m] = (_missCount[m] ?? 0) + 1;
        if ((_missCount[m] ?? 0) >= _releaseFrames) {
          _locked.remove(m);
          _missCount.remove(m);
        }
      }
      return {..._locked};
    }

    for (final m in raw) {
      _hitCount[m] = (_hitCount[m] ?? 0) + 1;
      _missCount.remove(m);
      if ((_hitCount[m] ?? 0) >= _lockFrames) {
        _locked.add(m);
      }
    }

    for (final m in _locked.toList()) {
      if (raw.contains(m)) continue;
      _missCount[m] = (_missCount[m] ?? 0) + 1;
      _hitCount.remove(m);
      if ((_missCount[m] ?? 0) >= _releaseFrames) {
        _locked.remove(m);
        _missCount.remove(m);
      }
    }

    // Drop candidates that never locked
    _hitCount.removeWhere((m, _) => !raw.contains(m) && !_locked.contains(m));

    return {..._locked};
  }

  void _scheduleClear() {
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(milliseconds: 280), () {
      final last = _lastHeard;
      if (last == null ||
          DateTime.now().difference(last) >=
              const Duration(milliseconds: 250)) {
        _emitted.clear();
        _locked = {};
        _hitCount.clear();
        _missCount.clear();
      }
    });
  }
}

final pitchServiceProvider = Provider<PitchService>((ref) {
  final service = PitchService();
  ref.onDispose(service.dispose);
  return service;
});
