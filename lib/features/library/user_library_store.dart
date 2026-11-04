import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/piano_flow_log.dart';

class UserLibraryStore {
  static const _favKey = 'fav_song_ids';
  static const _recentKey = 'recent_song_ids';

  Future<Set<String>> favorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favKey) ?? const []).toSet();
  }

  Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favKey) ?? <String>[];
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    await prefs.setStringList(_favKey, list);
  }

  Future<bool> isFavorite(String id) async {
    final set = await favorites();
    return set.contains(id);
  }

  Future<List<String>> recent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
  }

  Future<void> touchRecent(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentKey) ?? <String>[];
    list.remove(id);
    list.insert(0, id);
    if (list.length > 20) {
      list.removeRange(20, list.length);
    }
    await prefs.setStringList(_recentKey, list);
  }

  /// Drop id from favorites and recent (e.g. after deleting a userImport).
  Future<void> forgetSong(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final fav = prefs.getStringList(_favKey) ?? <String>[];
    final recent = prefs.getStringList(_recentKey) ?? <String>[];
    fav.remove(id);
    recent.remove(id);
    await prefs.setStringList(_favKey, fav);
    await prefs.setStringList(_recentKey, recent);
  }
}

class UserLibraryState {
  const UserLibraryState({
    this.favorites = const {},
    this.recent = const [],
    this.ready = false,
  });

  final Set<String> favorites;
  final List<String> recent;
  final bool ready;

  UserLibraryState copyWith({
    Set<String>? favorites,
    List<String>? recent,
    bool? ready,
  }) {
    return UserLibraryState(
      favorites: favorites ?? this.favorites,
      recent: recent ?? this.recent,
      ready: ready ?? this.ready,
    );
  }
}

class UserLibraryController extends Notifier<UserLibraryState> {
  final _store = UserLibraryStore();

  @override
  UserLibraryState build() {
    Future.microtask(_reload);
    return const UserLibraryState();
  }

  Future<void> _reload() async {
    try {
      final fav = await _store.favorites();
      final recent = await _store.recent();
      state = UserLibraryState(favorites: fav, recent: recent, ready: true);
    } catch (e, st) {
      pianoFlowLog('Library', 'user library reload failed: $e\n$st');
      state = const UserLibraryState(ready: true);
    }
  }

  Future<void> toggleFavorite(String id) async {
    try {
      await _store.toggleFavorite(id);
      await _reload();
    } catch (e, st) {
      pianoFlowLog('Library', 'toggleFavorite failed ($id): $e\n$st');
    }
  }

  Future<void> touchRecent(String id) async {
    try {
      await _store.touchRecent(id);
      await _reload();
    } catch (e, st) {
      pianoFlowLog('Library', 'touchRecent failed ($id): $e\n$st');
    }
  }

  Future<void> forgetSong(String id) async {
    try {
      await _store.forgetSong(id);
      await _reload();
    } catch (e, st) {
      pianoFlowLog('Library', 'forgetSong failed ($id): $e\n$st');
    }
  }

  bool isFavorite(String id) => state.favorites.contains(id);
}

final userLibraryProvider =
    NotifierProvider<UserLibraryController, UserLibraryState>(
  UserLibraryController.new,
);

/// 曲库「仅看收藏」筛选（跨首页→曲库跳转保留；由曲库 chip 切换）。
class LibraryFavoritesOnlyController extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) => state = value;

  void toggle() => state = !state;

  void clear() => state = false;
}

final libraryFavoritesOnlyProvider =
    NotifierProvider<LibraryFavoritesOnlyController, bool>(
  LibraryFavoritesOnlyController.new,
);
