import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';
import 'workshop_import_common.dart';

/// Audio → basic-pitch → MIDI draft → userImport (never formal).
///
/// Seconds-level for short piano clips; see scripts/audio_to_practice_draft.py.
abstract final class WorkshopAudioImporter {
  static const honestyDescription =
      '工坊音频转录草稿（非正式精确谱；本地 Basic Pitch ONNX→练习 JSON，'
      '可选钢琴频段强调——不是真分轨。禁止冒充正式谱）。短片段目标秒级。';

  static Future<WorkshopImportResult> importFile({
    required String inputPath,
    String? title,
    /// 默认关：纯 Python STFT 强调会拖慢秒级链路；混音曲可手动开。
    bool emphasizePiano = false,
    void Function(String line)? onProgress,
  }) async {
    final repo = await WorkshopImportCommon.findRepoRoot();
    if (repo == null) {
      throw StateError(
        '找不到仓库脚本 scripts/audio_to_practice_draft.py（请从项目目录启动 App）',
      );
    }
    final python = await WorkshopImportCommon.findPython();
    if (python == null) {
      throw StateError('未找到 Python，请安装并加入 PATH 后重试');
    }

    final userDir = await UserImportPaths.rootDir();
    final id = WorkshopImportCommon.slugFromPath(
      inputPath,
      prefix: 'user_audio_',
    );
    final script = p.join(repo.path, 'scripts', 'audio_to_practice_draft.py');
    final args = <String>[
      ...WorkshopImportCommon.pythonArgPrefix(python),
      script,
      '--input',
      inputPath,
      '--id',
      id,
      '--user-import-dir',
      userDir.path,
      // 练习草稿默认更大 hop：秒级优先（短音更糊可接受）
      '--hop-sec',
      '0.4',
      // 长曲只取前 45s，避免掉出「秒级」叙事
      '--max-sec',
      '45',
      if (title != null && title.trim().isNotEmpty) ...['--title', title.trim()],
      if (emphasizePiano) '--emphasize-piano',
    ];

    pianoFlowLog('Workshop', 'audio draft convert id=$id …');
    final sw = Stopwatch()..start();
    final proc = await Process.start(
      python,
      args,
      workingDirectory: repo.path,
      runInShell: false,
    );
    Future<void> pump(Stream<List<int>> stream) async {
      await for (final line in stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final t = line.trim();
        if (t.isEmpty) continue;
        pianoFlowLog('Workshop', t);
        onProgress?.call(t);
      }
    }

    await Future.wait([
      pump(proc.stdout),
      pump(proc.stderr),
    ]);
    final code = await proc.exitCode;
    sw.stop();
    pianoFlowLog(
      'Workshop',
      'audio draft done exit=$code elapsedMs=${sw.elapsedMilliseconds}',
    );
    if (code != 0) {
      throw StateError(
        '音频转草稿失败（退出码 $code）。'
        '已安装: Python + onnxruntime（用仓库 assets/models/basic_pitch.onnx）。'
        '详情见控制台 [PianoFlow/Workshop]',
      );
    }
    return WorkshopImportResult(
      scoreId: id,
      message:
          '已入库「自导入·音频草稿」：$id（${sw.elapsedMilliseconds}ms）— '
          '非正式精确谱，可去曲库练习',
    );
  }
}
