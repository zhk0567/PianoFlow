/// Map estimator MIDI onto expected waiting pitches (score-conditioned).
///
/// Policy (战役 C / Flowkey-style):
/// - Exact match first, then octave fold (mic H2).
/// - Soft ±1 only when waiting is **monophonic** (size ≤ [softSemitoneMaxWaiting]).
///   Chords require exact/octave — reduces false advances on neighbor bleed.
/// - [conditionHeard] drops estimator junk outside the waiting neighborhood
///   before matching.
abstract final class PracticePitchMatch {
  static const int semitoneTolerance = 1;

  /// Soft ±1 allowed only when |waitingFor| ≤ this (1 = single-note waits).
  static const int softSemitoneMaxWaiting = 1;

  /// Bass register where mic H2→fund fold is especially common (≤C3).
  static const int bassOctaveCeiling = 48;

  /// True if [heard] is within [semitoneTolerance] of [expected].
  static bool isNear(int expected, int heard) =>
      (expected - heard).abs() <= semitoneTolerance;

  /// True if [heard] is H2 of a bass [expected] (same pitch class, +12).
  static bool isBassOctave(int expected, int heard) =>
      expected <= bassOctaveCeiling && heard == expected + 12;

  /// Same pitch class one octave away (mic H2 / low-fold), any register.
  static bool isOctaveRelative(int expected, int heard) =>
      (expected - heard).abs() == 12;

  /// Soft ±1 allowed for this waiting set (monophonic waits only).
  static bool softSemitoneAllowed(Set<int> waitingFor) =>
      waitingFor.length <= softSemitoneMaxWaiting;

  /// True if any pitch in [heard] is near [expected] (exact / ±1 / octave).
  /// ±1 only when [allowSoftSemitone] is true.
  static bool isHeardNear(
    int expected,
    Set<int> heard, {
    bool allowSoftSemitone = true,
  }) {
    for (final h in heard) {
      if (h == expected || isOctaveRelative(expected, h)) return true;
      if (allowSoftSemitone && isNear(expected, h)) return true;
    }
    return false;
  }

  /// Keep heard midis that lie in the score neighborhood of [waitingFor].
  /// Drops stray BP ghosts that would soft-steal wrong waits.
  static Set<int> conditionHeard({
    required Set<int> heard,
    required Set<int> waitingFor,
  }) {
    if (heard.isEmpty || waitingFor.isEmpty) return heard;
    final soft = softSemitoneAllowed(waitingFor);
    final out = <int>{};
    for (final h in heard) {
      for (final e in waitingFor) {
        if (h == e || isOctaveRelative(e, h)) {
          out.add(h);
          break;
        }
        if (soft && isNear(e, h)) {
          out.add(h);
          break;
        }
      }
    }
    return out;
  }

  /// Prior MIDI bins (±1, ±12) for Basic Pitch score boost.
  static Set<int> priorBins(Set<int> waitingFor) {
    if (waitingFor.isEmpty) return {};
    final out = <int>{};
    for (final m in waitingFor) {
      for (final x in [m - 12, m - 1, m, m + 1, m + 12]) {
        if (x >= 21 && x <= 108) out.add(x);
      }
    }
    return out;
  }

  /// Frozen-line miss: estimator ±1 noise is forgivable only on monophonic waits.
  static bool isForgivableWrongPitch({
    required int heard,
    required Set<int> waitingFor,
  }) {
    if (waitingFor.isEmpty) return false;
    final soft = softSemitoneAllowed(waitingFor);
    for (final e in waitingFor) {
      if (isOctaveRelative(e, heard)) return true;
      if (soft && isNear(e, heard)) return true;
    }
    return false;
  }

  /// Resolve [heard] onto [waitingFor]: exact → (±1 if allowed) → ±12 octave.
  /// Each heard MIDI consumes at most one waiting pitch.
  static Set<int> matchWaiting({
    required Set<int> heard,
    required Set<int> waitingFor,
  }) {
    if (heard.isEmpty || waitingFor.isEmpty) return {};
    final conditioned = conditionHeard(heard: heard, waitingFor: waitingFor);
    if (conditioned.isEmpty) return {};
    final remaining = {...waitingFor};
    final hits = <int>{};
    final usedHeard = <int>{};
    final soft = softSemitoneAllowed(waitingFor);

    for (final h in conditioned) {
      if (remaining.remove(h)) {
        hits.add(h);
        usedHeard.add(h);
      }
    }

    if (soft) {
      for (final h in conditioned) {
        if (usedHeard.contains(h)) continue;
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
          usedHeard.add(h);
        }
      }
    }

    // Mic / BP octave ambiguity: fold onto waiting only when that octave bin
    // is not itself still owed (true octave chord keeps exact match above).
    for (final h in conditioned) {
      if (usedHeard.contains(h)) continue;
      if (waitingFor.contains(h)) continue;
      int? best;
      for (final e in remaining) {
        if (!isOctaveRelative(e, h)) continue;
        if (best == null || e < best) best = e;
      }
      if (best == null) continue;
      remaining.remove(best);
      hits.add(best);
      usedHeard.add(h);
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
