/// Map estimator MIDI (±1) onto expected waiting pitches.
///
/// Basic Pitch / YIN often lock one semitone off; treating that as a hit
/// keeps wait-mode from freezing while still preferring exact matches.
abstract final class PracticePitchMatch {
  static const int semitoneTolerance = 1;

  /// True if [heard] is within [semitoneTolerance] of [expected].
  static bool isNear(int expected, int heard) =>
      (expected - heard).abs() <= semitoneTolerance;

  /// True if any pitch in [heard] is near [expected] (incl. exact).
  static bool isHeardNear(int expected, Set<int> heard) {
    for (final h in heard) {
      if (isNear(expected, h)) return true;
    }
    return false;
  }

  /// Resolve [heard] onto [waitingFor]: exact first, then nearest ±1.
  /// Each heard MIDI consumes at most one waiting pitch.
  static Set<int> matchWaiting({
    required Set<int> heard,
    required Set<int> waitingFor,
  }) {
    if (heard.isEmpty || waitingFor.isEmpty) return {};
    final remaining = {...waitingFor};
    final hits = <int>{};

    for (final h in heard) {
      if (remaining.remove(h)) {
        hits.add(h);
      }
    }

    for (final h in heard) {
      int? best;
      var bestDist = semitoneTolerance + 1;
      for (final e in remaining) {
        final d = (e - h).abs();
        if (d == 0 || d > semitoneTolerance) continue;
        if (d < bestDist || (d == bestDist && (best == null || e < best))) {
          best = e;
          bestDist = d;
        }
      }
      if (best != null) {
        remaining.remove(best);
        hits.add(best);
      }
    }
    return hits;
  }

  /// Map a single note-on onto one waiting pitch, or null.
  static int? matchNoteOn({
    required int midi,
    required Set<int> waitingFor,
  }) {
    if (waitingFor.isEmpty) return null;
    if (waitingFor.contains(midi)) return midi;
    final hits = matchWaiting(heard: {midi}, waitingFor: waitingFor);
    if (hits.isEmpty) return null;
    return hits.first;
  }
}
