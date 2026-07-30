import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';

class LibraryRepository {
  Future<List<SongSummary>> loadCatalog() async {
    final raw = await rootBundle.loadString('assets/scores/catalog.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = map['songs'] as List<dynamic>;
    return list
        .map((e) => SongSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SongScore> loadScore(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return SongScore.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
