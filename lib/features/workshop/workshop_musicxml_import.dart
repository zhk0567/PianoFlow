import 'dart:io';

import 'package:path/path.dart' as p;

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';

/// Locate repo + run `scripts/musicxml_to_score.py --user-import-dir`.
abstract final class WorkshopMusicXmlImporter {
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

  static String slugFromPath(String filePath) {
    var base = p.basenameWithoutExtension(filePath).toLowerCase();
    base = base.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    base = base.replaceAll(RegExp(r'_+'), '_');
    base = base.replaceAll(RegExp(r'^_|_$'), '');
    if (base.isEmpty) base = 'user_import';
    if (!base.startsWith('user_')) base = 'user_$base';
    return base.length > 48 ? base.substring(0, 48) : base;
  }

  static Future<String?> _findPython() async {
    for (final cmd in ['python', 'python3', 'py']) {
      try {
        final r = await Process.run(
          cmd,
          ['--version'],
          runInShell: true,
        );
        if (r.exitCode == 0) return cmd;
      } catch (_) {}
    }
    return null;
  }

  /// Import [inputPath] into the user documents catalog.
  ///
  /// Returns a short Chinese status message; throws on hard failure.
  static Future<String> importFile({
    required String inputPath,
    String? title,
    String? artist,
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
    final python = await _findPython();
    if (python == null) {
      pianoFlowLog('Workshop', 'python not found on PATH');
      throw StateError('未找到 Python，请安装并加入 PATH 后重试');
    }

    final userDir = await UserImportPaths.rootDir();
    final id = slugFromPath(inputPath);
    final script = p.join(repo.path, 'scripts', 'musicxml_to_score.py');
    final args = <String>[
      script,
      '--id',
      id,
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
    ];

    pianoFlowLog('Workshop', 'import $id via $python …');
    final result = await Process.run(
      python,
      args,
      workingDirectory: repo.path,
      runInShell: true,
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
    return '已入库「自导入」：$id — 可去曲库练习';
  }
}
