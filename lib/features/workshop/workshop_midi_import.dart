import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';
import 'workshop_import_common.dart';

/// MIDI → draft MusicXML → userImport (never formal).
abstract final class WorkshopMidiImporter {
  static const honestyDescription =
      '工坊 MIDI 自导入草稿（非正式精确谱；MIDI→MusicXML 会丢声部/记谱细节，禁止冒充正式谱）。';

  static Future<WorkshopImportResult> importFile({
    required String inputPath,
    String? title,
  }) async {
    final repo = await WorkshopImportCommon.findRepoRoot();
    if (repo == null) {
      throw StateError(
        '找不到仓库脚本 scripts/midi_to_musicxml_draft.py（请从项目目录启动 App）',
      );
    }
    final python = await WorkshopImportCommon.findPython();
    if (python == null) {
      throw StateError('未找到 Python，请安装并加入 PATH 后重试');
    }

    await UserImportPaths.rootDir();
    final id = WorkshopImportCommon.slugFromPath(inputPath, prefix: 'user_midi_');
    final tmp = await getTemporaryDirectory();
    final draftXml = p.join(tmp.path, '$id.musicxml');
    final script = p.join(repo.path, 'scripts', 'midi_to_musicxml_draft.py');
    final convArgs = <String>[
      ...WorkshopImportCommon.pythonArgPrefix(python),
      script,
      '--input',
      inputPath,
      '--output',
      draftXml,
      if (title != null && title.trim().isNotEmpty) ...['--title', title.trim()],
    ];

    pianoFlowLog('Workshop', 'MIDI draft convert id=$id …');
    final conv = await Process.run(
      python,
      convArgs,
      workingDirectory: repo.path,
      runInShell: false,
    );
    final cout = '${conv.stdout}\n${conv.stderr}'.trim();
    if (cout.isNotEmpty) {
      for (final line in cout.split('\n')) {
        if (line.trim().isEmpty) continue;
        pianoFlowLog('Workshop', line.trim());
      }
    }
    if (conv.exitCode != 0) {
      throw StateError(
        'MIDI 转草稿失败（退出码 ${conv.exitCode}，详见控制台 [PianoFlow/Workshop]）',
      );
    }
    if (!await File(draftXml).exists()) {
      throw StateError('MIDI 转草稿未生成 MusicXML');
    }

    final result = await WorkshopImportCommon.runMusicXmlToUserImport(
      inputPath: draftXml,
      scoreId: id,
      title: title ?? p.basenameWithoutExtension(inputPath),
      artist: 'MIDI草稿',
      description: honestyDescription,
    );
    return WorkshopImportResult(
      scoreId: result.scoreId,
      message:
          '已入库「自导入·MIDI草稿」：${result.scoreId} — 非正式精确谱，可去曲库练习',
    );
  }
}
