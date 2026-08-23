import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';
import 'workshop_audio_draft_worker.dart';
import 'workshop_import_common.dart';

/// Audio → basic-pitch → practice draft → userImport (never formal).
///
/// Prefers a warm ORT worker; falls back to one-shot Process if worker fails.
abstract final class WorkshopAudioImporter {
  static const honestyDescription =
      '工坊音频导入（可跟弹；本地 Basic Pitch ONNX→练习 JSON；'
      '可选 Demucs 分轨，无 demucs 时直转录并标注。质量档为自导入，非教材级正式谱）。'
      '短片段目标秒级。';

  static Future<WorkshopImportResult> importFile({
    required String inputPath,
    String? title,
    /// 默认关：纯 Python STFT 强调会拖慢秒级链路；混音曲可手动开。
    bool emphasizePiano = false,
    /// 默认开：本机有 demucs 则先分轨；无则日志跳过并直转录。
    bool useDemucs = true,
    void Function(String line)? onProgress,
  }) async {
    final userDir = await UserImportPaths.rootDir();
    final id = WorkshopImportCommon.slugFromPath(
      inputPath,
      prefix: 'user_audio_',
    );

    pianoFlowLog('Workshop', 'audio draft convert id=$id demucs=$useDemucs …');
    final sw = Stopwatch()..start();
    try {
      final out = await WorkshopAudioDraftWorker.instance.transcribe(
        inputPath: inputPath,
        userImportDir: userDir.path,
        scoreId: id,
        title: title,
        emphasizePiano: emphasizePiano,
        useDemucs: useDemucs,
        onProgress: onProgress,
      );
      sw.stop();
      if (out['ok'] != true) {
        throw StateError(
          out['error']?.toString() ??
              '音频导入失败。详情见控制台 [PianoFlow/Workshop]',
        );
      }
      final elapsed = out['elapsed_ms'] is int
          ? out['elapsed_ms'] as int
          : sw.elapsedMilliseconds;
      final demucsOk = out['demucs'] == true;
      pianoFlowLog(
        'Workshop',
        'audio draft done (worker) elapsedMs=$elapsed demucs=$demucsOk',
      );
      return WorkshopImportResult(
        scoreId: id,
        message:
            '已入库并可练习：$id（${elapsed}ms·暖会话·'
            '${demucsOk ? '含Demucs分轨' : '未分轨直转录'}）— '
            '自导入质量档',
      );
    } catch (e, st) {
      pianoFlowLog('Workshop', 'worker path failed, one-shot fallback: $e\n$st');
      return _importOneShot(
        inputPath: inputPath,
        title: title,
        emphasizePiano: emphasizePiano,
        useDemucs: useDemucs,
        onProgress: onProgress,
        id: id,
        userDir: userDir,
      );
    }
  }

  static Future<WorkshopImportResult> _importOneShot({
    required String inputPath,
    String? title,
    required bool emphasizePiano,
    required bool useDemucs,
    void Function(String line)? onProgress,
    required String id,
    required Directory userDir,
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
      '--hop-sec',
      '0.4',
      '--max-sec',
      '45',
      if (title != null && title.trim().isNotEmpty) ...['--title', title.trim()],
      if (emphasizePiano) '--emphasize-piano',
      if (useDemucs) '--demucs',
    ];

    final sw = Stopwatch()..start();
    final proc = await Process.start(
      python,
      args,
      workingDirectory: repo.path,
      runInShell: false,
    );
    Future<void> pump(Stream<List<int>> stream) async {
      await for (final line in stream
          .transform(const Utf8Decoder(allowMalformed: true))
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
        '音频导入失败（退出码 $code）。'
        '已安装: Python + onnxruntime（用仓库 assets/models/basic_pitch.onnx）。'
        '详情见控制台 [PianoFlow/Workshop]',
      );
    }
    return WorkshopImportResult(
      scoreId: id,
      message:
          '已入库并可练习：$id（${sw.elapsedMilliseconds}ms）— '
          '自导入质量档',
    );
  }
}
