import 'dart:math' as math;
import 'dart:typed_data';

/// Result of a single YIN estimate.
class PitchEstimate {
  const PitchEstimate({required this.hz, required this.clarity});

  final double hz;

  /// 0..1, higher = cleaner periodic trough (1 - cmndf).
  final double clarity;
}

/// YIN pitch estimator (De Cheveigné & Kawahara), tuned for piano via mic.
class YinPitch {
  YinPitch({
    this.sampleRate = 44100,
    this.threshold = 0.15,
    this.minHz = 27.5, // A0
    this.maxHz = 4200, // ~C8
  });

  final int sampleRate;
  final double threshold;
  final double minHz;
  final double maxHz;

  /// Estimate fundamental frequency from mono PCM float samples in [-1, 1].
  PitchEstimate? estimate(Float64List samples) {
    final n = samples.length;
    if (n < 1024) return null;

    // Prefer steadier latter portion (skip piano attack).
    final start = n >= 3072 ? n ~/ 4 : 0;
    final view = Float64List.sublistView(samples, start);
    final windowed = _hann(view);

    final wn = windowed.length;
    final minTau = (sampleRate / maxHz).floor().clamp(2, wn ~/ 2);
    final maxTau = (sampleRate / minHz).floor().clamp(minTau + 1, wn ~/ 2);

    final diff = Float64List(maxTau + 1);
    for (var tau = minTau; tau <= maxTau; tau++) {
      var sum = 0.0;
      final limit = wn - tau;
      for (var i = 0; i < limit; i++) {
        final d = windowed[i] - windowed[i + tau];
        sum += d * d;
      }
      diff[tau] = sum;
    }

    final cmndf = Float64List(maxTau + 1);
    cmndf[0] = 1;
    var runningSum = 0.0;
    for (var tau = 1; tau <= maxTau; tau++) {
      runningSum += diff[tau];
      cmndf[tau] = runningSum > 0 ? diff[tau] * tau / runningSum : 1.0;
    }

    var tauEstimate = _absoluteThreshold(cmndf, minTau, maxTau, threshold);
    // Soft fallback only for a *very* clear trough (reduces random locks).
    if (tauEstimate < 0) {
      tauEstimate = _bestTrough(cmndf, minTau, maxTau, threshold * 1.35);
    }
    if (tauEstimate < 0) return null;

    // Ambiguous spectrum (two competing troughs) → reject.
    if (_isAmbiguous(cmndf, tauEstimate, minTau, maxTau)) return null;

    tauEstimate = _octaveCorrect(cmndf, tauEstimate, minTau, maxTau);

    final betterTau = _parabolic(cmndf, tauEstimate, minTau, maxTau);
    final hz = sampleRate / betterTau;
    if (hz < minHz || hz > maxHz) return null;

    final trough = cmndf[tauEstimate];
    // Reject weak periodicity (noise / room / multipitch).
    if (trough > 0.28) return null;

    final clarity = (1.0 - trough).clamp(0.0, 1.0);
    if (clarity < 0.72) return null;

    return PitchEstimate(hz: hz, clarity: clarity);
  }

  /// Back-compat helper.
  double? estimateHz(Float64List samples) => estimate(samples)?.hz;

  static int _absoluteThreshold(
    Float64List cmndf,
    int minTau,
    int maxTau,
    double threshold,
  ) {
    for (var tau = minTau; tau <= maxTau; tau++) {
      if (cmndf[tau] < threshold) {
        while (tau + 1 <= maxTau && cmndf[tau + 1] < cmndf[tau]) {
          tau++;
        }
        return tau;
      }
    }
    return -1;
  }

  static int _bestTrough(
    Float64List cmndf,
    int minTau,
    int maxTau,
    double softCap,
  ) {
    var bestTau = -1;
    var bestVal = softCap;
    for (var tau = minTau; tau <= maxTau; tau++) {
      final v = cmndf[tau];
      if (v >= bestVal) continue;
      final left = tau > minTau ? cmndf[tau - 1] : v + 1;
      final right = tau < maxTau ? cmndf[tau + 1] : v + 1;
      if (v <= left && v <= right) {
        bestVal = v;
        bestTau = tau;
      }
    }
    return bestTau;
  }

  /// True when another trough is nearly as deep (noise / chords / clutter).
  static bool _isAmbiguous(
    Float64List cmndf,
    int bestTau,
    int minTau,
    int maxTau,
  ) {
    final best = cmndf[bestTau];
    var second = 1.0;
    for (var tau = minTau; tau <= maxTau; tau++) {
      if ((tau - bestTau).abs() < 4) continue;
      // Ignore exact octave relatives of the winner.
      if (tau == bestTau * 2 ||
          (bestTau % 2 == 0 && tau == bestTau ~/ 2)) {
        continue;
      }
      final v = cmndf[tau];
      final left = tau > minTau ? cmndf[tau - 1] : v + 1;
      final right = tau < maxTau ? cmndf[tau + 1] : v + 1;
      if (v <= left && v <= right && v < second) {
        second = v;
      }
    }
    // Competing trough within 25% of best depth → unreliable.
    return second < 0.45 && second < best * 1.35;
  }

  /// Prefer the lower octave when 2τ is competitive — critical for piano bass
  /// where the 2nd partial often wins the first CMNDF trough.
  static int _octaveCorrect(
    Float64List cmndf,
    int tau,
    int minTau,
    int maxTau,
  ) {
    final doubleTau = tau * 2;
    if (doubleTau > maxTau) return tau;
    final at = cmndf[tau];
    final at2 = cmndf[doubleTau];
    // Bass-friendly: accept 2τ when nearly as deep (was 1.05 / 0.22).
    if (at2 <= at * 1.12 && at2 < 0.26) {
      return doubleTau;
    }
    return tau;
  }

  static double _parabolic(
    Float64List cmndf,
    int tauEstimate,
    int minTau,
    int maxTau,
  ) {
    final x0 = tauEstimate <= minTau ? tauEstimate : tauEstimate - 1;
    final x2 = tauEstimate >= maxTau ? tauEstimate : tauEstimate + 1;
    if (x0 == tauEstimate || x2 == tauEstimate) {
      return tauEstimate.toDouble();
    }
    final s0 = cmndf[x0];
    final s1 = cmndf[tauEstimate];
    final s2 = cmndf[x2];
    final denom = 2 * s1 - s2 - s0;
    if (denom.abs() <= 1e-12) return tauEstimate.toDouble();
    return tauEstimate + (s2 - s0) / (2 * denom);
  }

  static Float64List _hann(Float64List input) {
    final n = input.length;
    final out = Float64List(n);
    if (n < 2) return Float64List.fromList(input);
    for (var i = 0; i < n; i++) {
      final w = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
      out[i] = input[i] * w;
    }
    return out;
  }

  /// MIDI from Hz; rejects if farther than [maxCents] from equal-tempered center.
  static int? hzToMidi(double hz, {double maxCents = 35}) {
    if (hz <= 0) return null;
    final exact = 69 + 12 * math.log(hz / 440.0) / math.ln2;
    final midi = exact.round();
    final cents = (exact - midi).abs() * 100;
    if (cents > maxCents) return null;
    if (midi < 21 || midi > 108) return null; // 88-key A0–C8
    return midi;
  }

  static String midiLabel(int midi) {
    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ];
    return '${names[midi % 12]}${(midi ~/ 12) - 1}';
  }
}

/// Convert little-endian PCM16 mono bytes to floats.
Float64List pcm16ToFloat(Uint8List bytes) {
  final count = bytes.length ~/ 2;
  final out = Float64List(count);
  final bd = ByteData.sublistView(bytes);
  for (var i = 0; i < count; i++) {
    out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// RMS and peak of float samples in [-1, 1].
({double rms, double peak}) measureLevel(Float64List samples) {
  var energy = 0.0;
  var peak = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final a = samples[i].abs();
    if (a > peak) peak = a;
    energy += samples[i] * samples[i];
  }
  final rms = math.sqrt(energy / samples.length);
  return (rms: rms, peak: peak);
}

/// Linear amplitude 0..1 → dBFS (0 = full scale).
double amplitudeToDb(double amp) {
  if (amp <= 1e-9) return -96;
  return (20 * math.log(amp) / math.ln10).clamp(-96.0, 0.0);
}
