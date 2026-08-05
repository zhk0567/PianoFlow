import '../../shared/models/song.dart';

/// Beat-window helpers over notes sorted by [ScoreNote.start] (ascending).
abstract final class NoteWindowIndex {
  /// Lower bound: first index with `notes[i].start >= t`.
  static int lowerBoundStart(List<ScoreNote> notes, double t) {
    var lo = 0;
    var hi = notes.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (notes[mid].start < t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Upper bound: first index with `notes[i].start > t`.
  static int upperBoundStart(List<ScoreNote> notes, double t) {
    var lo = 0;
    var hi = notes.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (notes[mid].start <= t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Notes whose onset falls in `[pos - lookBehind, pos + lookAhead]`,
  /// plus a small expansion for long bars still on screen (end > window start).
  ///
  /// [notes] must be sorted by start ascending (catalog scores are).
  static List<ScoreNote> visibleAround({
    required List<ScoreNote> notes,
    required double pos,
    required double lookBehind,
    required double lookAhead,
  }) {
    if (notes.isEmpty) return const [];
    final from = pos - lookBehind;
    final to = pos + lookAhead;
    // Start search slightly earlier so long notes that began before [from]
    // but still overlap the window can be included with a linear scan back.
    final startIdx = lowerBoundStart(notes, from - lookBehind);
    final endIdx = upperBoundStart(notes, to);
    if (startIdx >= endIdx) {
      // Still check a few notes before startIdx for long-held bars.
      final back = (startIdx - 8).clamp(0, notes.length);
      final out = <ScoreNote>[];
      for (var i = back; i < notes.length && notes[i].start <= to; i++) {
        final n = notes[i];
        if (n.end >= from && n.start <= to) out.add(n);
      }
      return out;
    }
    final out = <ScoreNote>[];
    final back = (startIdx - 8).clamp(0, notes.length);
    for (var i = back; i < endIdx; i++) {
      final n = notes[i];
      if (n.end >= from && n.start <= to) out.add(n);
    }
    return out;
  }

  /// Active MIDI at [pos] using a start-sorted list (scan a local window).
  static Set<int> activeMidiAt(List<ScoreNote> notes, double pos) {
    if (notes.isEmpty) return const {};
    // Notes sounding at pos started at or before pos; search nearby onsets.
    final hi = upperBoundStart(notes, pos);
    final lo = (hi - 64).clamp(0, notes.length);
    final out = <int>{};
    for (var i = lo; i < hi; i++) {
      final n = notes[i];
      if (pos >= n.start && pos < n.end) out.add(n.midi);
    }
    // Long notes that started much earlier: walk further back briefly.
    for (var i = lo - 1; i >= 0 && i >= lo - 32; i--) {
      final n = notes[i];
      if (n.end <= pos) continue;
      if (pos >= n.start && pos < n.end) out.add(n.midi);
    }
    return out;
  }
}

/// Monotonic guide/oneshot cursor over notes sorted by start.
class NoteOnsetCursor {
  NoteOnsetCursor();

  int _index = 0;

  void reset() => _index = 0;

  /// Advance past notes with `start < pos - epsilon` without visiting them.
  void seekBefore(List<ScoreNote> notes, double pos, {double epsilon = 0.01}) {
    _index = NoteWindowIndex.upperBoundStart(notes, pos - epsilon);
  }

  /// Mark through notes with `start <= pos` (same as arm through).
  void seekThrough(List<ScoreNote> notes, double pos) {
    _index = NoteWindowIndex.upperBoundStart(notes, pos);
  }

  /// Notes whose onset is newly reached at [pos] (`start <= pos`), advancing cursor.
  Iterable<ScoreNote> takeDue(List<ScoreNote> notes, double pos) sync* {
    while (_index < notes.length && notes[_index].start <= pos) {
      yield notes[_index];
      _index++;
    }
  }
}
