import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/pitch_yin.dart';

Float64List _sine(double hz, {int n = 4096, int sr = 44100, double amp = 0.4}) {
  final samples = Float64List(n);
  for (var i = 0; i < n; i++) {
    samples[i] = amp * math.sin(2 * math.pi * hz * i / sr);
  }
  return samples;
}

Float64List _pianoish(double hz, {int n = 4096, int sr = 44100}) {
  final samples = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    samples[i] = 0.35 * math.sin(2 * math.pi * hz * t) +
        0.28 * math.sin(2 * math.pi * hz * 2 * t) +
        0.18 * math.sin(2 * math.pi * hz * 3 * t) +
        0.08 * math.sin(2 * math.pi * hz * 4 * t);
  }
  return samples;
}

void main() {
  test('hzToMidi maps A4 and C4', () {
    expect(YinPitch.hzToMidi(440), 69);
    expect(YinPitch.hzToMidi(261.63), 60);
  });

  test('hzToMidi rejects detuned pitches', () {
    // ~50 cents sharp of A4
    final sharp = 440 * math.pow(2, 50 / 1200);
    expect(YinPitch.hzToMidi(sharp.toDouble(), maxCents: 35), isNull);
  });

  test('YIN detects a synthetic sine near A4', () {
    const sr = 44100;
    final samples = _sine(440);
    final yin = YinPitch(sampleRate: sr);
    final estimated = yin.estimate(samples);
    expect(estimated, isNotNull);
    expect(estimated!.hz, closeTo(440, 3));
    expect(estimated.clarity, greaterThan(0.72));
    expect(YinPitch.hzToMidi(estimated.hz), 69);
  });

  test('YIN detects harmonic-rich A4 (piano-like)', () {
    final yin = YinPitch(sampleRate: 44100, threshold: 0.15);
    final estimated = yin.estimate(_pianoish(440));
    expect(estimated, isNotNull);
    expect(estimated!.hz, closeTo(440, 8));
    expect(YinPitch.hzToMidi(estimated.hz), 69);
  });

  test('YIN detects mid C4 with harmonics', () {
    final yin = YinPitch(sampleRate: 44100, threshold: 0.15);
    final estimated = yin.estimate(_pianoish(261.63));
    expect(estimated, isNotNull);
    expect(YinPitch.hzToMidi(estimated!.hz), 60);
  });

  test('YIN detects piano-like C#2 (Moonlight bass) in 0.25s window', () {
    // PitchService window = 11025 @44.1k; C#2 ≈ 69.3 Hz (MIDI 37).
    const sr = 44100;
    const hz = 69.29565774421802; // MIDI 37 exact
    final yin = YinPitch(sampleRate: sr, threshold: 0.15);
    final estimated = yin.estimate(_pianoish(hz, n: 11025, sr: sr));
    expect(estimated, isNotNull);
    expect(YinPitch.hzToMidi(estimated!.hz, maxCents: 40), 37);
  });

  test('YIN detects piano-like C2 in practice window', () {
    const sr = 44100;
    const hz = 65.40639132514966; // MIDI 36
    final yin = YinPitch(sampleRate: sr, threshold: 0.15);
    final estimated = yin.estimate(_pianoish(hz, n: 11025, sr: sr));
    expect(estimated, isNotNull);
    expect(YinPitch.hzToMidi(estimated!.hz, maxCents: 40), 36);
  });

  test('YIN rejects noise-like signal', () {
    final yin = YinPitch(sampleRate: 44100);
    final rng = math.Random(1);
    final samples = Float64List(4096);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = (rng.nextDouble() * 2 - 1) * 0.2;
    }
    expect(yin.estimate(samples), isNull);
  });
}
