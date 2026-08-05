import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/piano_flow_log.dart';

/// Tee raw PCM16 from the pitch path into a WAV file (exam recording).
class ExamPcmRecorder {
  IOSink? _sink;
  File? _file;
  int _dataBytes = 0;
  bool _active = false;

  bool get isActive => _active;
  String? get path => _file?.path;

  Future<void> start({required String songId}) async {
    await stop();
    try {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(root.path, 'pianoflow_exam_takes', songId));
      if (!await dir.exists()) await dir.create(recursive: true);
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      _file = File(p.join(dir.path, '$ts.wav'));
      _sink = _file!.openWrite();
      // Placeholder header — rewritten on stop.
      _sink!.add(Uint8List(44));
      _dataBytes = 0;
      _active = true;
      pianoFlowLog('Practice', 'exam record start ${_file!.path}');
    } catch (e, st) {
      pianoFlowLog('Practice', 'exam record start failed: $e\n$st');
      _active = false;
    }
  }

  void addPcm16(Uint8List pcm) {
    if (!_active || _sink == null) return;
    _sink!.add(pcm);
    _dataBytes += pcm.length;
  }

  Future<String?> stop() async {
    if (!_active) return null;
    _active = false;
    final file = _file;
    final sink = _sink;
    _sink = null;
    _file = null;
    try {
      await sink?.flush();
      await sink?.close();
      if (file == null || _dataBytes <= 0) {
        if (file != null && await file.exists()) await file.delete();
        return null;
      }
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.setPosition(0);
        await raf.writeFrom(_wavHeader(dataBytes: _dataBytes));
      } finally {
        await raf.close();
      }
      pianoFlowLog('Practice', 'exam record saved ${file.path} ($_dataBytes B)');
      return file.path;
    } catch (e, st) {
      pianoFlowLog('Practice', 'exam record stop failed: $e\n$st');
      return null;
    }
  }

  static Uint8List _wavHeader({
    required int dataBytes,
    int sampleRate = 44100,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final out = BytesBuilder(copy: false);
    void ascii(String s) => out.add(s.codeUnits);
    void u32(int v) {
      out.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    }

    void u16(int v) => out.add([v & 0xff, (v >> 8) & 0xff]);

    ascii('RIFF');
    u32(36 + dataBytes);
    ascii('WAVE');
    ascii('fmt ');
    u32(16);
    u16(1); // PCM
    u16(channels);
    u32(sampleRate);
    u32(byteRate);
    u16(blockAlign);
    u16(bitsPerSample);
    ascii('data');
    u32(dataBytes);
    return out.toBytes();
  }
}
