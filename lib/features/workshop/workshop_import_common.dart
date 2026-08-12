import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';

/// Result of a workshop self-import (always [ScoreKind.userImport] on disk).
class WorkshopImportResult {
  const WorkshopImportResult({
    required this.scoreId,
    required this.message,
  });

  final String scoreId;
  final String message;
}

/// Shared helpers for MusicXML / MIDI / PDF workshop imports.
abstract final class WorkshopImportCommon {
  /// Prefer [Directory.current], then walk up from the executable.
  static Future<Directory?> findRepoRoot() async {
    final candidates = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final start in candidates) {
      var dir = start;
      for (var i = 0; i < 8; i++) {
        final script = File(
          p.join(dir.path, 'scripts', 'musicxml_to_score.py'),
        );
        if (await script.exists()) return dir;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return null;
  }

  static String slugFromPath(String filePath, {String prefix = 'user_'}) {
    var base = p.basenameWithoutExtension(filePath).toLowerCase();
    base = base.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    base = base.replaceAll(RegExp(r'_+'), '_');
    base = base.replaceAll(RegExp(r'^_|_$'), '');
    if (base.isEmpty) base = 'import';
    if (!base.startsWith(prefix)) base = '$prefix$base';
    return base.length > 48 ? base.substring(0, 48) : base;
  }

  static Future<String?> findPython() async {
    for (final cmd in ['python', 'py', 'python3']) {
      try {
        final r = await Process.run(
          cmd,
          cmd == 'py' ? ['-3', '--version'] : ['--version'],
          runInShell: false,
        );
        if (r.exitCode == 0) return cmd;
      } catch (_) {}
    }
    return null;
  }

  static List<String> pythonArgPrefix(String pythonCmd) =>
      pythonCmd == 'py' ? const ['-3'] : const [];

  /// Resolve a usable on-disk path from FilePicker (Windows path may be null).
  static Future<String> materializePickerFile({
    required String? path,
    required Uint8List? bytes,
    required String fallbackName,
  }) async {
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (await f.exists()) return f.path;
    }
    if (bytes == null || bytes.isEmpty) {
      throw StateError('无法读取所选文件路径或内容（Windows 请允许访问该文件）');
    }
    final tmp = await getTemporaryDirectory();
    final safe = fallbackName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final out = File(p.join(tmp.path, 'pianoflow_pick_$safe'));
    await out.writeAsBytes(bytes, flush: true);
    pianoFlowLog('Workshop', 'materialized picker bytes → ${out.path}');
    return out.path;
  }

  static Future<WorkshopImportResult> runMusicXmlToUserImport({
    required String inputPath,
    required String scoreId,
    String? title,
    String? artist,
    String? description,
  }) async {
    final repo = await findRepoRoot();
    if (repo == null) {
      pianoFlowLog(
        'Workshop',
        'repo root not found (need scripts/musicxml_to_score.py)',
      );
      throw StateError(
        '找不到仓库脚本 scripts/musicxml_to_score.py（请从项目目录启动 App）',
      );
    }
    final python = await findPython();
    if (python == null) {
      pianoFlowLog('Workshop', 'python not found on PATH');
      throw StateError('未找到 Python，请安装并加入 PATH 后重试');
    }

    final userDir = await UserImportPaths.rootDir();

    final script = p.join(repo.path, 'scripts', 'musicxml_to_score.py');
    final args = <String>[
      ...pythonArgPrefix(python),
      script,
      '--id',
      scoreId,
      '--input',
      inputPath,
      '--user-import-dir',
      userDir.path,
      '--score-kind',
      'userImport',
      if (title != null && title.trim().isNotEmpty) ...['--title', title.trim()],
      if (artist != null && artist.trim().isNotEmpty) ...[
        '--artist',
        artist.trim(),
      ],
      if (description != null && description.trim().isNotEmpty) ...[
        '--description',
        description.trim(),
      ],
    ];

    pianoFlowLog('Workshop', 'import $scoreId via $python …');
    final result = await Process.run(
      python,
      args,
      workingDirectory: repo.path,
      runInShell: false,
    );
    final out = '${result.stdout}\n${result.stderr}'.trim();
    if (out.isNotEmpty) {
      for (final line in out.split('\n')) {
        if (line.trim().isEmpty) continue;
        pianoFlowLog('Workshop', line.trim());
      }
    }
    if (result.exitCode != 0) {
      throw StateError(
        '导入失败（退出码 ${result.exitCode}，详见控制台 [PianoFlow/Workshop]）',
      );
    }
    return WorkshopImportResult(
      scoreId: scoreId,
      message: '已入库「自导入」：$scoreId — 可去曲库或直接练习',
    );
  }
}
