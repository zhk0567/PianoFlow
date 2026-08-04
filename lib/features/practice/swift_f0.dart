import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../shared/piano_flow_log.dart';
import 'pitch_yin.dart';

/// Linear resample mono float samples [fromSr] → [toSr].
Float32List resampleLinear(List<double> input, int fromSr, int toSr) {
  if (input.isEmpty) return Float32List(0);
  if (fromSr == toSr) {
    return Float32List.fromList(input.map((e) => e.toDouble()).toList());
  }
  final outLen = math.max(1, (input.length * toSr / fromSr).floor());
  final out = Float32List(outLen);
  final ratio = fromSr / toSr;
  for (var i = 0; i < outLen; i++) {
    final src = i * ratio;
    final i0 = src.floor();
    final i1 = math.min(i0 + 1, input.length - 1);
    final frac = src - i0;
    out[i] = input[i0] * (1 - frac) + input[i1] * frac;
  }
  return out;
}

/// SwiftF0 ONNX wrapper (model embeds STFT; input is raw 16 kHz mono PCM).
class SwiftF0Estimator {
  SwiftF0Estimator._(this._session, {this.confidenceThreshold = 0.88});

  static const assetPath = 'assets/models/swiftf0.onnx';
  static const sampleRate = 16000;
  static const hopLength = 256;
  static const minAudioLength = 256;
  static const modelFmin = 46.875;
  static const modelFmax = 2093.75;

  final OrtSession _session;
  final double confidenceThreshold;
  bool _closed = false;

  /// Load bundled ONNX from Flutter assets.
  static Future<SwiftF0Estimator> create({
    double confidenceThreshold = 0.88,
  }) async {
    pianoFlowLog('Pitch', 'loading SwiftF0 ONNX ($assetPath)…');
    final ort = OnnxRuntime();
    final session = await ort.createSessionFromAsset(assetPath);
    return SwiftF0Estimator._(
      session,
      confidenceThreshold: confidenceThreshold,
    );
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    try {
      await _session.close();
    } catch (e) {
      pianoFlowLog('Pitch', 'SwiftF0 session close failed: $e');
    }
  }

  /// Run on 16 kHz mono floats in [-1, 1]. Returns last strong voiced frame.
  Future<PitchEstimate?> estimate16k(Float32List audio16k) async {
    if (_closed || audio16k.isEmpty) return null;

    var audio = audio16k;
    if (audio.length < minAudioLength) {
      final padded = Float32List(minAudioLength);
      padded.setRange(0, audio.length, audio);
      audio = padded;
    }

    OrtValue? input;
    Map<String, OrtValue>? outputs;
    try {
      input = await OrtValue.fromList(audio, [1, audio.length]);
      outputs = await _session.run({'input_audio': input});

      final pitchVal = outputs['pitch_hz'];
      final confVal = outputs['confidence'];
      if (pitchVal == null || confVal == null) {
        pianoFlowLog(
          'Pitch',
          'SwiftF0 outputs missing '
          '(pitch_hz=${pitchVal != null}, confidence=${confVal != null})',
        );
        return null;
      }

      final pitchList = await pitchVal.asList();
      final confList = await confVal.asList();
      // Nested [batch][frames] or flat [frames]
      final pitches = _flattenNums(pitchList);
      final confs = _flattenNums(confList);
      if (pitches.isEmpty || confs.isEmpty) return null;

      final n = math.min(pitches.length, confs.length);
      // Prefer recent voiced frames (tail).
      final start = math.max(0, n - 8);
      double? bestHz;
      double bestConf = 0;
      for (var i = start; i < n; i++) {
        final hz = pitches[i];
        final c = confs[i];
        if (c < confidenceThreshold) continue;
        if (hz < modelFmin || hz > modelFmax) continue;
        if (c >= bestConf) {
          bestConf = c;
          bestHz = hz;
        }
      }
      if (bestHz == null) return null;
      return PitchEstimate(hz: bestHz, clarity: bestConf);
    } catch (e, st) {
      pianoFlowLog('Pitch', 'SwiftF0 infer failed: $e\n$st');
      return null;
    } finally {
      await input?.dispose();
      if (outputs != null) {
        for (final v in outputs.values) {
          await v.dispose();
        }
      }
    }
  }

  /// Convenience: 44.1 kHz window → resample → estimate.
  Future<PitchEstimate?> estimateFrom44100(Float64List samples441) async {
    final r = resampleLinear(samples441, 44100, sampleRate);
    return estimate16k(r);
  }

  static List<double> _flattenNums(dynamic list) {
    final out = <double>[];
    void walk(dynamic x) {
      if (x is num) {
        out.add(x.toDouble());
      } else if (x is List) {
        for (final e in x) {
          walk(e);
        }
      }
    }

    walk(list);
    return out;
  }
}

/// True when the bundled model asset is present (does not load ORT).
Future<bool> swiftF0AssetExists() async {
  try {
    await rootBundle.load(SwiftF0Estimator.assetPath);
    return true;
  } catch (e) {
    pianoFlowLog(
      'Pitch',
      'SwiftF0 asset missing (${SwiftF0Estimator.assetPath}): $e',
    );
    return false;
  }
}
