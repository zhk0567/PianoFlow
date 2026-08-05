import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';

/// Disk layout under ApplicationDocuments/pianoflow_user/.
abstract final class UserImportPaths {
  static const folderName = 'pianoflow_user';
  static const catalogFileName = 'user_catalog.json';

  static Future<Directory> rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, folderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final xml = Directory(p.join(dir.path, 'musicxml'));
    if (!await xml.exists()) {
      await xml.create(recursive: true);
    }
    return dir;
  }

  static Future<File> catalogFile() async {
    final root = await rootDir();
    return File(p.join(root.path, catalogFileName));
  }

  static Future<File> scoreJson(String id) async {
    final root = await rootDir();
    return File(p.join(root.path, '$id.json'));
  }
}

/// Pure merge: bundled catalog ∪ user catalog (user wins on same id).
abstract final class UserCatalogMerge {
  static List<SongSummary> merge({
    required List<SongSummary> bundled,
    required List<SongSummary> user,
  }) {
    if (user.isEmpty) return List<SongSummary>.from(bundled);
    final byId = <String, SongSummary>{
      for (final s in bundled) s.id: s,
    };
    for (final s in user) {
      byId[s.id] = s;
    }
    // Bundled order first, then user-only ids appended.
    final out = <SongSummary>[];
    final seen = <String>{};
    for (final s in bundled) {
      out.add(byId[s.id]!);
      seen.add(s.id);
    }
    for (final s in user) {
      if (seen.add(s.id)) out.add(s);
    }
    return out;
  }

  static List<SongSummary> parseCatalogJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = map['songs'] as List<dynamic>? ?? const [];
    return list
        .map((e) => SongSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class UserImportStore {
  Future<List<SongSummary>> loadUserCatalog() async {
    try {
      final file = await UserImportPaths.catalogFile();
      if (!await file.exists()) return const [];
      final raw = await file.readAsString();
      final songs = UserCatalogMerge.parseCatalogJson(raw);
      for (final s in songs) {
        if (s.scoreKind != ScoreKind.userImport) {
          pianoFlowLog(
            'Workshop',
            'user catalog ${s.id} has scoreKind=${s.scoreKind.name} '
            '(expected userImport)',
          );
        }
      }
      return songs;
    } catch (e, st) {
      pianoFlowLog('Workshop', 'user catalog load failed: $e\n$st');
      return const [];
    }
  }

  Future<SongScore?> loadUserScore(String id) async {
    try {
      final file = await UserImportPaths.scoreJson(id);
      if (!await file.exists()) {
        pianoFlowLog('Workshop', 'user score missing: $id');
        return null;
      }
      final raw = await file.readAsString();
      return SongScore.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      pianoFlowLog('Workshop', 'user score load failed ($id): $e\n$st');
      return null;
    }
  }
}
