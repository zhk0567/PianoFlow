import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/score_kind_policy.dart';

class LibraryRepository {
  Future<List<SongSummary>> loadCatalog() async {
    try {
      final raw = await rootBundle.loadString('assets/scores/catalog.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['songs'] as List<dynamic>;
      final songs = list
          .map((e) => SongSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      final violations = ScoreKindPolicy.catalogViolations(songs);
      for (final v in violations) {
        pianoFlowLog('Library', 'scoreKind policy: $v');
      }
      return songs;
    } catch (e, st) {
      pianoFlowLog('Library', 'catalog load failed: $e\n$st');
      rethrow;
    }
  }

  Future<SongScore> loadScore(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return SongScore.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      pianoFlowLog('Library', 'score load failed ($assetPath): $e\n$st');
      rethrow;
    }
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
