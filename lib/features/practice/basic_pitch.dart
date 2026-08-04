import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../shared/piano_flow_log.dart';
import 'swift_f0.dart' show resampleLinear;

/// Spotify Basic Pitch (ONNX) — polyphonic notes with harmonic suppression.
class BasicPitchEstimator {
  BasicPitchEstimator._(
    this._session, {
    this.frameThresh = 0.42,
    this.relativeThresh = 0.62,
  });

  static const assetPath = 'assets/models/basic_pitch.onnx';
  static const sampleRate = 22050;
  static const audioNSamples = 43844;
  static const midiOffset = 21; // bin 0 = A0
  static const nBins = 88;
  static const minMidi = 21;
  static const maxMidi = 108;

  static const _inputName = 'serving_default_input_2:0';
  static const _noteOut = 'StatefulPartitionedCall:1';

  /// Piano partial intervals (semitones) that often fake extra keys via mic.
  static const _partialIntervals = {12, 19, 24, 28, 31, 36};

  final OrtSession _session;
  final double frameThresh;
  /// Keep only peaks at least this fraction of the strongest peak.
  final double relativeThresh;
  bool _closed = false;

  static Future<BasicPitchEstimator> create({
    double frameThresh = 0.42,
    double relativeThresh = 0.62,
  }) async {
    pianoFlowLog('Pitch', 'loading Basic Pitch ONNX ($assetPath)…');
    final ort = OnnxRuntime();
    final session = await ort.createSessionFromAsset(assetPath);
    return BasicPitchEstimator._(
      session,
      frameThresh: frameThresh,
      relativeThresh: relativeThresh,
    );
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    try {
      await _session.close();
    } catch (e) {
      pianoFlowLog('Pitch', 'BasicPitch session close failed: $e');
    }
  }

  /// Active MIDI notes in [minMidi, maxMidi] from 22.05 kHz mono audio.
  /// Short buffers are **right-aligned** (recent audio at the end) and
  /// zero-padded on the left so we don't wait for a full 2s of real audio.
  Future<Set<int>> estimateActiveMidi(Float32List audio22050) async {
    if (_closed || audio22050.isEmpty) return {};

    final window = Float32List(audioNSamples);
    if (audio22050.length >= audioNSamples) {
      window.setRange(
        0,
        audioNSamples,
        audio22050,
        audio22050.length - audioNSamples,
      );
    } else {
      // Causal pad: silence | recent audio
      window.setRange(
        audioNSamples - audio22050.length,
        audioNSamples,
        audio22050,
      );
    }

    OrtValue? input;
    Map<String, OrtValue>? outputs;
    try {
      input = await OrtValue.fromList(window, [1, audioNSamples, 1]);
      outputs = await _session.run({_inputName: input});
      final noteVal = outputs[_noteOut];
      if (noteVal == null) {
        pianoFlowLog('Pitch', 'BasicPitch output "$_noteOut" missing');
        return {};
      }

      final raw = await noteVal.asList();
      final frames = _asFrameBins(raw);
      if (frames.isEmpty) return {};

      // Short tail — emphasize newest frames (less lag from left-pad silence).
      final scores = _tailMeanScores(frames, tail: 6);
      return _selectNotes(scores);
    } catch (e, st) {
      pianoFlowLog('Pitch', 'BasicPitch infer failed: $e\n$st');
      return {};
    } finally {
      await input?.dispose();
      if (outputs != null) {
        for (final v in outputs.values) {
          await v.dispose();
        }
      }
    }
  }

  Future<Set<int>> estimateFrom44100(Float64List samples441) async {
    final r = resampleLinear(samples441, 44100, sampleRate);
    return estimateActiveMidi(r);
  }

  List<double> _tailMeanScores(List<List<double>> frames, {required int tail}) {
    final n = math.min(tail, frames.length);
    final start = frames.length - n;
    final scores = List<double>.filled(nBins, 0);
    for (var t = start; t < frames.length; t++) {
      final row = frames[t];
      for (var b = 0; b < nBins && b < row.length; b++) {
        scores[b] += row[b];
      }
    }
    for (var b = 0; b < nBins; b++) {
      scores[b] /= n;
    }
    return scores;
  }

  /// Absolute + relative gate, then drop octave / partial ghosts.
  Set<int> _selectNotes(List<double> scores) {
    var peak = 0.0;
    for (final s in scores) {
      if (s > peak) peak = s;
    }
    if (peak < frameThresh) return {};

    final floor = math.max(frameThresh, peak * relativeThresh);
    final candidates = <({int midi, double score})>[];
    for (var b = 0; b < nBins; b++) {
      final s = scores[b];
      if (s < floor) continue;
      final midi = midiOffset + b;
      if (midi < minMidi || midi > maxMidi) continue;
      candidates.add((midi: midi, score: s));
    }
    if (candidates.isEmpty) return {};

    // Strongest first — fundamentals usually outrank their partials.
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final kept = <({int midi, double score})>[];
    for (final c in candidates) {
      if (_isPartialGhost(c, kept)) continue;
      kept.add(c);
      if (kept.length >= 6) break;
    }

    // Prefer lower of near-equal octave pairs if both somehow survived.
    final midis = kept.map((e) => e.midi).toSet();
    for (final m in midis.toList()..sort()) {
      if (midis.contains(m + 12)) {
        final low = kept.firstWhere((e) => e.midi == m);
        final high = kept.firstWhere((e) => e.midi == m + 12);
        if (high.score <= low.score * 1.25) {
          midis.remove(m + 12);
        }
      }
    }
    return midis;
  }

  /// True if [c] looks like a harmonic/partial of an already-kept stronger note.
  static bool _isPartialGhost(
    ({int midi, double score}) c,
    List<({int midi, double score})> kept,
  ) {
    for (final k in kept) {
      final interval = c.midi - k.midi;
      if (interval <= 0) continue;
      if (!_partialIntervals.contains(interval)) continue;
      // Drop upper partial unless it is clearly stronger than the lower note.
      if (c.score < k.score * 1.35) return true;
    }
    return false;
  }

  static List<List<double>> _asFrameBins(dynamic raw) {
    List<dynamic> root = raw is List ? raw : const [];
    if (root.isEmpty) return const [];

    if (root.first is List &&
        (root.first as List).isNotEmpty &&
        (root.first as List).first is List) {
      root = root.first as List;
    }

    final out = <List<double>>[];
    for (final row in root) {
      if (row is! List) continue;
      out.add(row.map((e) => (e as num).toDouble()).toList());
    }
    return out;
  }
}

Future<bool> basicPitchAssetExists() async {
  try {
    await rootBundle.load(BasicPitchEstimator.assetPath);
    return true;
  } catch (e) {
    pianoFlowLog(
      'Pitch',
      'Basic Pitch asset missing (${BasicPitchEstimator.assetPath}): $e',
    );
    return false;
  }
}
