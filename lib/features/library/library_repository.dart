import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/score_kind_policy.dart';
import 'user_import_store.dart';

class LibraryRepository {
  LibraryRepository({UserImportStore? userImports})
      : _userImports = userImports ?? UserImportStore();

  final UserImportStore _userImports;

  Future<List<SongSummary>> loadCatalog() async {
    try {
      final raw = await rootBundle.loadString('assets/scores/catalog.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['songs'] as List<dynamic>;
      final bundled = list
          .map((e) => SongSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      final user = await _userImports.loadUserCatalog();
      final songs = UserCatalogMerge.merge(bundled: bundled, user: user);
      final violations = ScoreKindPolicy.catalogViolations(
        songs.where((s) => !s.isUserImport),
      );
      for (final v in violations) {
        pianoFlowLog('Library', 'scoreKind policy: $v');
      }
      pianoFlowLog(
        'Library',
        'catalog loaded bundled=${bundled.length} user=${user.length} '
        'merged=${songs.length}',
      );
      return songs;
    } catch (e, st) {
      pianoFlowLog('Library', 'catalog load failed: $e\n$st');
      rethrow;
    }
  }

  Future<SongScore> loadScore(String assetPath) async {
    try {
      // User-import scores store absolute paths (or bare id.json) in catalog.asset.
      if (_looksLikeFilePath(assetPath)) {
        final file = File(assetPath);
        if (await file.exists()) {
          final raw = await file.readAsString();
          return SongScore.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
        final id = assetPath
            .split(RegExp(r'[\\/]'))
            .last
            .replaceAll(RegExp(r'\.json$'), '');
        final score = await _userImports.loadUserScore(id);
        if (score != null) return score;
        throw StateError('user score file missing: $assetPath');
      }
      // Also try user import by id when asset looks like assets/... but kind is user
      // (handled by caller via absolute asset from user catalog).
      final raw = await rootBundle.loadString(assetPath);
      return SongScore.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      pianoFlowLog('Library', 'score load failed ($assetPath): $e\n$st');
      rethrow;
    }
  }

  static bool _looksLikeFilePath(String assetPath) {
    if (assetPath.startsWith('assets/')) return false;
    return assetPath.contains(r'\') ||
        assetPath.contains('/') && !assetPath.startsWith('assets/') ||
        (assetPath.endsWith('.json') && !assetPath.startsWith('assets/'));
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

final catalogProvider = FutureProvider<List<SongSummary>>((ref) async {
  return ref.watch(libraryRepositoryProvider).loadCatalog();
});

final songByIdProvider =
    Provider.family<AsyncValue<SongSummary?>, String>((ref, id) {
  final catalog = ref.watch(catalogProvider);
  return catalog.whenData((songs) {
    for (final song in songs) {
      if (song.id == id) return song;
    }
    return null;
  });
});

final scoreProvider =
    FutureProvider.family<SongScore, SongSummary>((ref, song) async {
  return ref.watch(libraryRepositoryProvider).loadScore(song.asset);
});
