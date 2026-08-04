part of 'score_audio_player.dart';

/// Metronome click synthesis (piano tones come from bundled Acoustic Grand samples).

/// Zero-PCM one-shot for audio-device warmup (never audible).
Uint8List _renderSilentWav({double duration = 0.05}) {
  return SilentWarmWav.render(
    sampleRate: ScoreAudioPlayer._sampleRate,
    durationSeconds: duration,
  );
}

Uint8List _renderClickWav({required bool accent}) {
  const duration = 0.045;
  final n = (ScoreAudioPlayer._sampleRate * duration).round();
  final data = ByteData(44 + n * 2);
  _writeWavHeader(data, n);
  final freq = accent ? 1400.0 : 1000.0;
  final amp =
      (accent ? 0.7 : 0.45) *
      PracticeConstants.metroClickGain *
      PracticeConstants.volumeMax;
  for (var i = 0; i < n; i++) {
    final t = i / ScoreAudioPlayer._sampleRate;
    final env = math.exp(-70 * t);
    final sample = env * math.sin(2 * math.pi * freq * t);
    // Soft-clip so metroClickGain > 1 does not hard-clip the envelope peak.
    final shaped = _softClip(sample * amp);
    final v = (shaped * 32767).round().clamp(-32768, 32767);
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Soft-clip for PCM gain > 1 (avoids hard digital clipping).
/// Equivalent to tanh(x) via exp (dart:math has no tanh on all targets).
double _softClip(double x) {
  final e = math.exp((2.0 * x).clamp(-40.0, 40.0));
  return (e - 1.0) / (e + 1.0);
}

/// Amplify, decay, and truncate a 16-bit PCM WAV so practice one-shots don't
/// ring for the full ~3s sample length.
Uint8List _shapePianoWav(
  Uint8List input, {
  required double gain,
  required double maxSeconds,
  required double fadeSeconds,
  required double decayTau,
}) {
  if (input.length < 44) return input;
  final src = ByteData.sublistView(input);

  var audioFmt = 1;
  var channels = 1;
  var sampleRate = ScoreAudioPlayer._sampleRate;
  var bitsPerSample = 16;
  var dataOffset = 44;
  var dataSize = input.length - 44;

  if (input[0] == 0x52 /* R */) {
    var offset = 12;
    while (offset + 8 <= input.length) {
      final id0 = input[offset];
      final id1 = input[offset + 1];
      final id2 = input[offset + 2];
      final id3 = input[offset + 3];
      final size = src.getUint32(offset + 4, Endian.little);
      if (id0 == 0x66 && id1 == 0x6d && id2 == 0x74 /* fmt */) {
        audioFmt = src.getUint16(offset + 8, Endian.little);
        channels = src.getUint16(offset + 10, Endian.little);
        sampleRate = src.getUint32(offset + 12, Endian.little);
        bitsPerSample = src.getUint16(offset + 22, Endian.little);
      } else if (id0 == 0x64 && id1 == 0x61 && id2 == 0x74 && id3 == 0x61) {
        dataOffset = offset + 8;
        dataSize = size;
        break;
      }
      offset += 8 + size;
      if (size.isOdd) offset++;
    }
  }

  if (audioFmt != 1 || bitsPerSample != 16 || channels < 1) {
    return _amplifyWavPcm16(input, gain);
  }

  final bytesPerFrame = 2 * channels;
  final maxFrames = math.max(1, (sampleRate * maxSeconds).round());
  final srcFrames = dataSize ~/ bytesPerFrame;
  final outFrames = math.min(srcFrames, maxFrames);
  final fadeFrames = math.max(
    1,
    math.min(outFrames, (sampleRate * fadeSeconds).round()),
  );
  final fadeStart = outFrames - fadeFrames;

  final out = ByteData(44 + outFrames * bytesPerFrame);
  _writeWavHeaderFlexible(
    out,
    frames: outFrames,
    sampleRate: sampleRate,
    channels: channels,
  );

  for (var f = 0; f < outFrames; f++) {
    final t = f / sampleRate;
    var env = math.exp(-t / math.max(decayTau, 0.05));
    if (f >= fadeStart) {
      final u = (f - fadeStart) / fadeFrames;
      env *= (1.0 - u).clamp(0.0, 1.0);
    }
    for (var c = 0; c < channels; c++) {
      final si = dataOffset + f * bytesPerFrame + c * 2;
      final di = 44 + f * bytesPerFrame + c * 2;
      if (si + 1 >= input.length) break;
      final s = src.getInt16(si, Endian.little) / 32768.0;
      final y = _softClip(s * gain * env);
      out.setInt16(
        di,
        (y * 32767.0).round().clamp(-32768, 32767),
        Endian.little,
      );
    }
  }
  return out.buffer.asUint8List();
}

/// Apply [gain] to a 16-bit mono/stereo PCM WAV body (standard 44-byte header).
Uint8List _amplifyWavPcm16(Uint8List input, double gain) {
  if (input.length < 44 || gain == 1.0) return input;
  final out = Uint8List.fromList(input);
  final bd = ByteData.sublistView(out);
  // Prefer the `data` chunk offset; fall back to 44 for simple PCM WAVs.
  var dataOffset = 44;
  if (out.length >= 44 &&
      out[0] == 0x52 && // R
      out[12] == 0x66) {
    // f of 'fmt '
    var offset = 12;
    while (offset + 8 <= out.length) {
      final id0 = out[offset];
      final id1 = out[offset + 1];
      final id2 = out[offset + 2];
      final id3 = out[offset + 3];
      final size = bd.getUint32(offset + 4, Endian.little);
      if (id0 == 0x64 && id1 == 0x61 && id2 == 0x74 && id3 == 0x61) {
        // 'data'
        dataOffset = offset + 8;
        break;
      }
      offset += 8 + size;
      if (size.isOdd) offset++; // word align
    }
  }
  for (var i = dataOffset; i + 1 < out.length; i += 2) {
    final s = bd.getInt16(i, Endian.little) / 32768.0;
    final y = _softClip(s * gain);
    bd.setInt16(
      i,
      (y * 32767.0).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  return out;
}

void _writeWavHeader(ByteData data, int n) {
  _writeWavHeaderFlexible(
    data,
    frames: n,
    sampleRate: ScoreAudioPlayer._sampleRate,
    channels: 1,
  );
}

void _writeWavHeaderFlexible(
  ByteData data, {
  required int frames,
  required int sampleRate,
  required int channels,
}) {
  void str(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  final blockAlign = channels * 2;
  final dataBytes = frames * blockAlign;
  str(0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * blockAlign, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);
}
