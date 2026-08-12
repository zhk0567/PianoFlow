import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../practice/staff/score_to_musicxml.dart';

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

  static Future<File> musicXml(String id) async {
    final root = await rootDir();
    return File(p.join(root.path, 'musicxml', '$id.musicxml'));
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

  static String encodeCatalog(List<SongSummary> songs) {
    final data = {
      'songs': songs.map((s) => s.toJson()).toList(),
    };
    return '${const JsonEncoder.withIndent('  ').convert(data)}\n';
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

  Future<void> _writeCatalog(List<SongSummary> songs) async {
    final file = await UserImportPaths.catalogFile();
    await file.writeAsString(UserCatalogMerge.encodeCatalog(songs), flush: true);
  }

  /// Rename / tweak metadata for a userImport only. Never changes scoreKind.
  Future<SongSummary> updateUserMetadata({
    required String id,
    String? title,
    String? artist,
    int? bpm,
  }) async {
    final songs = await loadUserCatalog();
    final idx = songs.indexWhere((s) => s.id == id);
    if (idx < 0) {
      throw StateError('找不到自导入曲目：$id');
    }
    final prev = songs[idx];
    if (prev.scoreKind != ScoreKind.userImport) {
      throw StateError('只能编辑自导入曲目（不会改正式谱/OMR草稿）');
    }
    final nextBpm = bpm ?? prev.bpm;
    if (nextBpm < 20 || nextBpm > 400) {
      throw StateError('BPM 须在 20–400 之间');
    }
    final next = prev.copyWith(
      title: (title ?? prev.title).trim().isEmpty
          ? prev.title
          : (title ?? prev.title).trim(),
      artist: (artist ?? prev.artist).trim().isEmpty
          ? prev.artist
          : (artist ?? prev.artist).trim(),
      bpm: nextBpm,
      scoreKind: ScoreKind.userImport,
    );
    songs[idx] = next;
    await _writeCatalog(songs);

    final scoreFile = await UserImportPaths.scoreJson(id);
    if (await scoreFile.exists()) {
      try {
        final map =
            jsonDecode(await scoreFile.readAsString()) as Map<String, dynamic>;
        map['title'] = next.title;
        map['bpm'] = next.bpm;
        await scoreFile.writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(map)}\n',
          flush: true,
        );
      } catch (e, st) {
        pianoFlowLog('Workshop', 'score json meta sync failed ($id): $e\n$st');
      }
    }
    pianoFlowLog(
      'Workshop',
      'user metadata updated id=$id title=${next.title} '
      'artist=${next.artist} bpm=${next.bpm}',
    );
    return next;
  }

  /// Replace notes for a userImport score. Writes JSON + regenerated MusicXML.
  /// Never promotes [ScoreKind] — always stays userImport.
  Future<SongScore> saveUserNotes({
    required String id,
    required List<ScoreNote> notes,
  }) async {
    final songs = await loadUserCatalog();
    final idx = songs.indexWhere((s) => s.id == id);
    if (idx < 0) {
      throw StateError('找不到自导入曲目：$id');
    }
    final summary = songs[idx];
    if (summary.scoreKind != ScoreKind.userImport) {
      throw StateError('只能编辑自导入曲目的音符（不会改正式谱/OMR草稿）');
    }

    for (final n in notes) {
      if (n.midi < 21 || n.midi > 108) {
        throw StateError('MIDI 须在 21–108（88 键）之间，收到 ${n.midi}');
      }
      if (n.start < 0) {
        throw StateError('起始拍不能为负');
      }
      if (n.duration <= 0) {
        throw StateError('时值须大于 0');
      }
      if (n.hand == Hand.both) {
        throw StateError('单音手部须为左手或右手');
      }
    }

    final prev = await loadUserScore(id);
    if (prev == null) {
      throw StateError('找不到自导入 JSON：$id');
    }

    final sorted = [...notes]..sort((a, b) {
        final c = a.start.compareTo(b.start);
        if (c != 0) return c;
        return a.midi.compareTo(b.midi);
      });
    final next = prev.copyWith(notes: sorted);

    final scoreFile = await UserImportPaths.scoreJson(id);
    await scoreFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(next.toJson())}\n',
      flush: true,
    );

    final xmlFile = await UserImportPaths.musicXml(id);
    final xml = songScoreToMusicXml(next);
    await xmlFile.writeAsString(xml, flush: true);

    final durationHint = next.bpm > 0 && next.durationBeats > 0
        ? (next.durationBeats * 60 / next.bpm).round().clamp(1, 36000)
        : summary.durationHint;
    if (durationHint != summary.durationHint) {
      songs[idx] = summary.copyWith(durationHint: durationHint);
      await _writeCatalog(songs);
    }

    pianoFlowLog(
      'Workshop',
      'user notes saved id=$id count=${sorted.length} '
      'durationBeats=${next.durationBeats.toStringAsFixed(2)} '
      '(仍为自导入，非正式谱)',
    );
    return next;
  }

  /// Remove userImport entry + JSON + MusicXML. Bundled assets untouched.
  Future<void> deleteUserScore(String id) async {
    final songs = await loadUserCatalog();
    final idx = songs.indexWhere((s) => s.id == id);
    if (idx < 0) {
      throw StateError('找不到自导入曲目：$id');
    }
    final target = songs[idx];
    if (target.scoreKind != ScoreKind.userImport) {
      throw StateError('只能删除自导入曲目');
    }
    final next = songs.where((s) => s.id != id).toList();
    await _writeCatalog(next);

    Future<void> tryDelete(File f) async {
      try {
        if (await f.exists()) await f.delete();
      } catch (e, st) {
        pianoFlowLog('Workshop', 'delete failed ${f.path}: $e\n$st');
      }
    }

    await tryDelete(await UserImportPaths.scoreJson(id));
    await tryDelete(await UserImportPaths.musicXml(id));
    // Absolute asset path may differ from id.json naming.
    if (_looksLikeAbsJson(target.asset)) {
      await tryDelete(File(target.asset));
    }
    pianoFlowLog('Workshop', 'user score deleted id=$id');
  }

  static bool _looksLikeAbsJson(String asset) {
    if (asset.startsWith('assets/')) return false;
    return asset.endsWith('.json');
  }
}
