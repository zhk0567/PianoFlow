import 'dart:io';

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';

/// Open userImport MusicXML in the OS default app (e.g. MuseScore).
abstract final class WorkshopExternalEditor {
  static Future<String> openMusicXml(String scoreId) async {
    final file = await UserImportPaths.musicXml(scoreId);
    if (!await file.exists()) {
      throw StateError('找不到自导入 MusicXML：$scoreId（请先导入）');
    }
    return openPath(file.path);
  }

  static Future<String> openPath(String path) async {
    final f = File(path);
    if (!await f.exists()) {
      throw StateError('文件不存在：$path');
    }
    pianoFlowLog('Workshop', 'open external: $path');
    try {
      if (Platform.isWindows) {
        await Process.start(
          'cmd',
          ['/c', 'start', '', path],
          runInShell: false,
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isMacOS) {
        await Process.start(
          'open',
          [path],
          mode: ProcessStartMode.detached,
        );
      } else {
        await Process.start(
          'xdg-open',
          [path],
          mode: ProcessStartMode.detached,
        );
      }
      return '已用系统默认程序打开（请校对后必要时重新导入）。仍为自导入，非正式谱。';
    } catch (e, st) {
      pianoFlowLog('Workshop', 'open external failed: $e\n$st');
      throw StateError('无法打开外部编辑器：$e');
    }
  }
}
