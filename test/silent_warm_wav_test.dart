import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/silent_warm_wav.dart';

void main() {
  test('render is zero-PCM mono 16-bit at practice sample rate', () {
    final wav = SilentWarmWav.render(sampleRate: 22050);
    expect(SilentWarmWav.isZeroPcm16Mono(wav), isTrue);
    expect(SilentWarmWav.peakAbsSample(wav), 0);
    expect(wav.length, greaterThan(SilentWarmWav.headerBytes));
    // 0.05s * 22050 → 1102.5 → 1103 frames * 2 bytes
    expect(wav.length, SilentWarmWav.headerBytes + 1103 * 2);
  });

  test('keeper buffer is several seconds of zeros', () {
    const rate = SilentWarmWav.defaultSampleRate;
    final wav = SilentWarmWav.render(
      sampleRate: rate,
      durationSeconds: SilentWarmWav.keeperDurationSeconds,
    );
    expect(SilentWarmWav.isZeroPcm16Mono(wav), isTrue);
    final frames = (rate * SilentWarmWav.keeperDurationSeconds).round();
    expect(wav.length, SilentWarmWav.headerBytes + frames * 2);
    expect(frames, greaterThanOrEqualTo(rate * 2));
  });

  test('default duration produces at least one zero frame', () {
    final wav = SilentWarmWav.render(durationSeconds: 0);
    expect(SilentWarmWav.isZeroPcm16Mono(wav), isTrue);
    expect(wav.length, SilentWarmWav.headerBytes + 2);
  });

  test('rejects non-zero PCM as warm-unsafe', () {
    final wav = SilentWarmWav.render();
    final dirty = Uint8List.fromList(wav);
    // Spike a sample in the data chunk.
    final bd = ByteData.sublistView(dirty);
    bd.setInt16(44, 1200, Endian.little);
    expect(SilentWarmWav.isZeroPcm16Mono(dirty), isFalse);
    expect(SilentWarmWav.peakAbsSample(dirty), 1200);
  });

  test('rejects truncated / non-WAV buffers', () {
    expect(SilentWarmWav.isZeroPcm16Mono(Uint8List(10)), isFalse);
    expect(SilentWarmWav.peakAbsSample(Uint8List(10)), isNull);
  });
}
