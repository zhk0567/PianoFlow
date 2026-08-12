import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/piano_flow_log.dart';
import 'practice_models.dart';

abstract final class PracticeGhostStore {
  static Future<Directory> _dir() async {
    final root = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(root.path, 'pianoflow_ghosts'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> _file(String songId) async {
    final d = await _dir();
    final safe = songId.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return File(p.join(d.path, '$safe.json'));
  }

  static Future<List<GhostHit>> load(String songId) async {
    try {
      final f = await _file(songId);
      if (!await f.exists()) return const [];
      final raw = jsonDecode(await f.readAsString()) as List<dynamic>;
      return raw
          .map((e) => GhostHit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      pianoFlowLog('Practice', 'ghost load failed: $e\n$st');
      return const [];
    }
  }

  static Future<void> save(String songId, List<GhostHit> hits) async {
    try {
      final f = await _file(songId);
      await f.writeAsString(jsonEncode(hits.map((h) => h.toJson()).toList()));
    } catch (e, st) {
      pianoFlowLog('Practice', 'ghost save failed: $e\n$st');
    }
  }
}
