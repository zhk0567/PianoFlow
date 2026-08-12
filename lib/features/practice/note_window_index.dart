import '../../shared/models/song.dart';

/// Binary-search helpers for falling-note visibility (notes sorted by start).
class NoteWindowIndex {
  NoteWindowIndex._();

  /// Notes whose bars may intersect the visible falling lane around [pos].
  static List<ScoreNote> visibleAround({
    required List<ScoreNote> notes,
    required double pos,
    required double lookBehind,
    required double lookAhead,
  }) {
    if (notes.isEmpty) return const [];
    final from = pos - lookBehind;
    final to = pos + lookAhead;

    // First note with start >= from (bars may still extend into view from earlier).
    var lo = 0;
    var hi = notes.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (notes[mid].start < from - 8.0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final startIdx = lo;

    lo = startIdx;
    hi = notes.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (notes[mid].start <= to) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final endIdx = lo;
    if (startIdx >= endIdx) return const [];
    return notes.sublist(startIdx, endIdx);
  }
}
