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
    this.relativeThresh = 0.60,
  });

  static const assetPath = 'assets/models/basic_pitch.onnx';
  static const sampleRate = 22050;
  static const audioNSamples = 43844;
  static const midiOffset = 21; // bin 0 = A0
  static const nBins = 88;
  static const minMidi = 21;
  static const maxMidi = 108;

  /// Bass register ceiling (C3). Mic + BP often lock the 2nd partial here.
  static const bassMidiCeiling = 48;

  /// Absolute score to accept a weak bass fundamental under a strong octave.
  static const bassFundFloor = 0.18;

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
    double relativeThresh = 0.60,
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
  ///
  /// [priorMidis]: optional score-conditioned boost around expected waits.
  Future<Set<int>> estimateActiveMidi(
    Float32List audio22050, {
    Set<int>? priorMidis,
  }) async {
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
      // 6→4 with 0.25s capture window (跟弹体感).
      final scores = _tailMeanScores(frames, tail: 4);
      return selectNotes(
        scores,
        frameThresh: frameThresh,
        relativeThresh: relativeThresh,
        priorMidis: priorMidis,
      );
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

  /// Absolute + relative gate, bass octave recovery, then drop partial ghosts.
  ///
  /// [priorMidis]: waiting neighborhood — boost those bins before gating
  /// (score-conditioned decoding for follow mode).
  ///
  /// Exposed for unit tests (same path as live ONNX post-process).
  static Set<int> selectNotes(
    List<double> scores, {
    double frameThresh = 0.42,
    double relativeThresh = 0.60,
    Set<int>? priorMidis,
    double priorBoost = 1.35,
  }) {
    final work = List<double>.from(scores);
    if (priorMidis != null && priorMidis.isNotEmpty && priorBoost > 1.0) {
      for (final m in priorMidis) {
        final b = m - midiOffset;
        if (b < 0 || b >= work.length) continue;
        work[b] = (work[b] * priorBoost).clamp(0.0, 1.0);
      }
    }
    var peak = 0.0;
    for (final s in work) {
      if (s > peak) peak = s;
    }
    if (peak < frameThresh * 0.85) return {};

    final floor = math.max(frameThresh, peak * relativeThresh);
    // Bass fundamentals are often weaker than H2 on laptop mics — lower floor
    // so C2–C3 bins can enter the candidate list alongside a strong octave.
    // Below C2: no discount — ambient rumble otherwise locks G#1 etc.
    final bassFloor = math.max(frameThresh * 0.55, peak * relativeThresh * 0.65);
    const bassFloorMinMidi = 36; // C2
    final candidates = <({int midi, double score})>[];
    final n = math.min(nBins, work.length);
    for (var b = 0; b < n; b++) {
      final s = work[b];
      final midi = midiOffset + b;
      if (midi < minMidi || midi > maxMidi) continue;
      final binFloor =
          (midi >= bassFloorMinMidi && midi <= bassMidiCeiling)
              ? bassFloor
              : floor;
      if (s < binFloor) continue;
      candidates.add((midi: midi, score: s));
    }
    if (candidates.isEmpty) return {};

    // Strongest first — fundamentals usually outrank their partials.
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final kept = <({int midi, double score})>[];
    for (final c in candidates) {
      if (_isPartialGhost(c, kept)) continue;
      if (_isNeighborBleed(c, kept)) continue;
      kept.add(c);
      if (kept.length >= 6) break;
    }

    // Prefer lower of near-equal octave pairs when the upper looks like a
    // weak partial (below absolute frameThresh). Keep both when both clear
    // the gate — e.g. Moonlight LH C#2+C#3.
    final midis = kept.map((e) => e.midi).toSet();
    for (final m in midis.toList()..sort()) {
      if (midis.contains(m + 12)) {
        final low = kept.firstWhere((e) => e.midi == m);
        final high = kept.firstWhere((e) => e.midi == m + 12);
        if (high.score < frameThresh && high.score <= low.score * 1.25) {
          midis.remove(m + 12);
        }
      }
    }

    return _recoverBassFundamentals(
      work,
      midis,
      frameThresh: frameThresh,
    );
  }

  /// Piano bass via mic: H2 often outranks H1, so BP emits C#3 for C#2.
  /// Only fold detections **above** [bassMidiCeiling] (C3..C4] down one octave
  /// when a weak fundamental score exists — never fold a true bass note lower.
  static Set<int> _recoverBassFundamentals(
    List<double> scores,
    Set<int> selected, {
    required double frameThresh,
  }) {
    if (selected.isEmpty) return selected;
    final out = <int>{};
    var folded = false;

    for (final m in selected) {
      final low = m - 12;
      // Selected must sit in (C3, C4]; recovered pitch must be ≤C3.
      if (m <= bassMidiCeiling ||
          m > bassMidiCeiling + 12 ||
          low < minMidi ||
          low > bassMidiCeiling) {
        out.add(m);
        continue;
      }
      final ls = _scoreAt(scores, low);
      final hs = _scoreAt(scores, m);
      if (ls < bassFundFloor || hs > ls * 2.8) {
        out.add(m);
        continue;
      }

      out.add(low);
      folded = true;
      // Keep the upper note only when both look independently strong
      // (e.g. Moonlight LH C#2+C#3 octave).
      final bothReal = hs >= frameThresh &&
          ls >= frameThresh * 0.85 &&
          hs >= ls * 0.8;
      if (bothReal) {
        out.add(m);
      }
    }

    if (folded) {
      final sortedIn = selected.toList()..sort();
      final sortedOut = out.toList()..sort();
      pianoFlowLog(
        'Pitch',
        'bass octave recover in=$sortedIn → out=$sortedOut',
      );
    }
    return out;
  }

  static double _scoreAt(List<double> scores, int midi) {
    final b = midi - midiOffset;
    if (b < 0 || b >= scores.length) return 0;
    return scores[b];
  }

  /// True if [c] looks like a harmonic/partial ghost of an already-kept note.
  ///
  /// Covers both directions:
  /// - upper partial of a stronger lower peak (classic H2/H3 bleed);
  /// - weaker mid/treble **subharmonic** under a stronger upper peak
  ///   (e.g. A5 kept → drop weak A4/A3). Bass funds (≤C3) are not killed
  ///   here — [_recoverBassFundamentals] owns that register.
  static bool _isPartialGhost(
    ({int midi, double score}) c,
    List<({int midi, double score})> kept,
  ) {
    for (final k in kept) {
      final interval = (c.midi - k.midi).abs();
      if (interval == 0) continue;
      if (!_partialIntervals.contains(interval)) continue;

      if (c.midi > k.midi) {
        // c is above kept k — upper partial / harmonic.
        // Bass true-octave pairs (both strong) — e.g. Moonlight C#2+C#3.
        if (interval == 12 &&
            k.midi <= bassMidiCeiling &&
            c.score >= 0.42 &&
            k.score >= 0.42 * 0.85) {
          continue;
        }
        // Drop upper partial unless clearly stronger than the lower note.
        // Bass: H2 often beats H1 — slightly tighter margin.
        final margin = k.midi <= bassMidiCeiling ? 1.15 : 1.35;
        if (c.score < k.score * margin) return true;
        continue;
      }

      // c is below kept k — subharmonic / missing-fund ghost under treble.
      // Never drop ≤C3 here (bass floor + octave recover handle it).
      if (c.midi <= bassMidiCeiling) continue;
      // True mid/treble octave chord: keep lower when nearly as strong.
      if (c.score >= k.score * 0.90) continue;
      return true;
    }
    return false;
  }

  /// Mic spectral smear often lights ±1 of a strong peak (邻键假 onset).
  /// True minor-second chords keep both when scores are close (≥0.88×).
  static bool _isNeighborBleed(
    ({int midi, double score}) c,
    List<({int midi, double score})> kept,
  ) {
    for (final k in kept) {
      if ((c.midi - k.midi).abs() != 1) continue;
      if (c.score < k.score * 0.88) return true;
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
