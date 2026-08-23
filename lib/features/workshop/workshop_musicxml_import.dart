import 'dart:io';

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';
import 'workshop_import_common.dart';

/// MusicXML / MXL → userImport via `scripts/musicxml_to_score.py --user-import-dir`.
abstract final class WorkshopMusicXmlImporter {
  static Future<Directory?> findRepoRoot() =>
      WorkshopImportCommon.findRepoRoot();

  static String slugFromPath(String filePath) =>
      WorkshopImportCommon.slugFromPath(filePath);

  /// Import [inputPath] into the user documents catalog.
  ///
  /// Throws [StateError] on hard failure.
  static Future<WorkshopImportResult> importFile({
    required String inputPath,
    String? scoreId,
    String? title,
    String? artist,
    String? description,
  }) async {
    // Ensure layout exists before the Python script writes.
    await UserImportPaths.rootDir();
    final id = (scoreId != null && scoreId.trim().isNotEmpty)
        ? WorkshopImportCommon.slugFromPath(scoreId, prefix: 'user_')
        : WorkshopImportCommon.slugFromPath(inputPath);
    pianoFlowLog('Workshop', 'MusicXML → userImport id=$id path=$inputPath');
    return WorkshopImportCommon.runMusicXmlToUserImport(
      inputPath: inputPath,
      scoreId: id,
      title: title,
      artist: artist ?? '自导入',
      description: description ??
          '工坊 MusicXML 导入（可跟弹；自导入质量档，未做教材级校对）。',
    );
  }
}
