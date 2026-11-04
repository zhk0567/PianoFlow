import 'dart:typed_data';

/// Zero-PCM WAV used only to open the Windows audio device (no audible warm).
///
/// North-star: app / practice open must not ghost-note. Warm pipeline may only
/// play buffers that pass [isZeroPcm16Mono].
abstract final class SilentWarmWav {
  static const defaultSampleRate = 22050;
  static const defaultDurationSeconds = 0.05;

  /// Long zero buffer for the process-lifetime device keeper.
  ///
  /// A ~50ms loop point buzzes if Media Foundation inserts a gap. Several
  /// seconds of zeros keeps that boundary rare; the body stays digital silence.
  static const keeperDurationSeconds = 4.0;
  static const headerBytes = 44;

  /// Render a mono 16-bit PCM WAV with every sample at 0.
  static Uint8List render({
    int sampleRate = defaultSampleRate,
    double durationSeconds = defaultDurationSeconds,
  }) {
    final n = durationSeconds <= 0
        ? 1
        // Cap keeps a mistaken huge duration from allocating a giant buffer.
        // Keeper is several seconds; 8s at 22.05 kHz mono is still small.
        : (sampleRate * durationSeconds).round().clamp(1, sampleRate * 8);
    final data = ByteData(headerBytes + n * 2);
    _writeMonoPcm16Header(data, frames: n, sampleRate: sampleRate);
    // PCM body left as zeros (ByteData default).
    return data.buffer.asUint8List();
  }

  /// True when [wav] is RIFF/WAVE mono PCM16 and every sample is 0.
  static bool isZeroPcm16Mono(Uint8List wav) {
    final peak = peakAbsSample(wav);
    return peak != null && peak == 0;
  }

  /// Absolute peak of int16 samples in the `data` chunk; null if not PCM16 mono.
  static int? peakAbsSample(Uint8List wav) {
    if (wav.length < headerBytes) return null;
    if (wav[0] != 0x52 || wav[1] != 0x49 || wav[2] != 0x46 || wav[3] != 0x46) {
      return null; // RIFF
    }
    if (wav[8] != 0x57 || wav[9] != 0x41 || wav[10] != 0x56 || wav[11] != 0x45) {
      return null; // WAVE
    }
    final bd = ByteData.sublistView(wav);
    var dataOffset = headerBytes;
    var dataSize = wav.length - headerBytes;
    var audioFmt = 1;
    var channels = 1;
    var bits = 16;
    var offset = 12;
    while (offset + 8 <= wav.length) {
      final id0 = wav[offset];
      final id1 = wav[offset + 1];
      final id2 = wav[offset + 2];
      final id3 = wav[offset + 3];
      final size = bd.getUint32(offset + 4, Endian.little);
      if (id0 == 0x66 && id1 == 0x6d && id2 == 0x74 /* fmt */) {
        audioFmt = bd.getUint16(offset + 8, Endian.little);
        channels = bd.getUint16(offset + 10, Endian.little);
        bits = bd.getUint16(offset + 22, Endian.little);
      } else if (id0 == 0x64 && id1 == 0x61 && id2 == 0x74 && id3 == 0x61) {
        dataOffset = offset + 8;
        dataSize = size;
        break;
      }
      offset += 8 + size;
      if (size.isOdd) offset++;
    }
    if (audioFmt != 1 || channels != 1 || bits != 16) return null;
    if (dataOffset + dataSize > wav.length) return null;
    var peak = 0;
    for (var i = dataOffset; i + 1 < dataOffset + dataSize; i += 2) {
      final s = bd.getInt16(i, Endian.little).abs();
      if (s > peak) peak = s;
    }
    return peak;
  }

  static void _writeMonoPcm16Header(
    ByteData data, {
    required int frames,
    required int sampleRate,
  }) {
    void str(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    const channels = 1;
    const blockAlign = 2;
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
}
