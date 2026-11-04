import 'dart:math' as math;
import 'dart:typed_data';

/// Lightweight piano-attack detector (no FFT).
///
/// Uses first-difference energy as a high-frequency proxy; a rising flux
/// spike marks an onset. Cooldown avoids double-fires on one strike.
class OnsetFluxDetector {
  OnsetFluxDetector({
    this.fluxThresh = defaultFluxThresh,
    this.ratioThresh = defaultRatioThresh,
    this.minRms = defaultMinRms,
    this.cooldownHops = defaultCooldownHops,
  });

  /// Absolute HF energy jump (first-diff RMS).
  static const defaultFluxThresh = 0.028;

  /// Current HF must exceed previous × this.
  static const defaultRatioThresh = 1.55;

  /// Ignore onsets in near-silence.
  static const defaultMinRms = 0.008;

  /// Hops (~30ms) before another onset may fire.
  static const defaultCooldownHops = 3;

  final double fluxThresh;
  final double ratioThresh;
  final double minRms;
  final int cooldownHops;

  double _prevHf = 0;
  int _cooldown = 0;
  double _lastFlux = 0;

  double get lastFlux => _lastFlux;

  void reset() {
    _prevHf = 0;
    _cooldown = 0;
    _lastFlux = 0;
  }

  /// Push one analysis hop. Returns true on a fresh attack onset.
  bool push(Float64List samples) {
    if (samples.length < 64) {
      _lastFlux = 0;
      return false;
    }
    if (_cooldown > 0) {
      _cooldown--;
      // Still update envelope so post-cooldown baseline is fresh.
      final hf = highFreqEnergy(samples);
      _prevHf = _prevHf * 0.65 + hf * 0.35;
      _lastFlux = 0;
      return false;
    }

    final hf = highFreqEnergy(samples);
    final rms = _rms(samples);
    final flux = math.max(0.0, hf - _prevHf);
    _lastFlux = flux;

    final rising = _prevHf <= 1e-6
        ? hf >= fluxThresh
        : hf >= _prevHf * ratioThresh;
    final onset = rms >= minRms && flux >= fluxThresh && rising;

    _prevHf = _prevHf * 0.55 + hf * 0.45;
    if (onset) {
      _cooldown = cooldownHops < 1 ? 1 : cooldownHops;
    }
    return onset;
  }

  /// First-difference RMS — proxy for high-frequency / attack energy.
  static double highFreqEnergy(Float64List samples) {
    if (samples.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < samples.length; i++) {
      final d = samples[i] - samples[i - 1];
      sum += d * d;
    }
    return math.sqrt(sum / (samples.length - 1));
  }

  static double _rms(Float64List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }
}
