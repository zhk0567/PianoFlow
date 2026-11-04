import 'practice_pitch_match.dart';

/// Flowkey-style hit gate: after speaker guide of a pitch, accept a user hit
/// only once the mic has gone quiet on that pitch (gap), then heard it again.
///
/// Prevents guide→mic echo from auto-advancing wait mode, without permanently
/// blocking the same MIDI the user must play.
class GuideRetriggerGate {
  GuideRetriggerGate({this.quietFramesNeeded = defaultQuietFramesNeeded});

  /// Pitch frames (~30ms hop) of unbroken quiet required before [gapSeen].
  /// One empty frame after suppress ends is often estimator flicker, not a real gap.
  static const defaultQuietFramesNeeded = 2;

  final int quietFramesNeeded;

  final Set<int> _awaitingGap = {};
  final Set<int> _gapSeen = {};
  final Map<int, int> _quietFrames = {};

  Set<int> get awaitingGap => {..._awaitingGap};

  /// Test/inspection: midis that already satisfied the quiet streak.
  Set<int> get gapSeen => {..._gapSeen};

  void arm(Iterable<int> midis) {
    for (final m in midis) {
      _awaitingGap.add(m);
      _gapSeen.remove(m);
      _quietFrames[m] = 0;
    }
  }

  void disarm(Iterable<int> midis) {
    for (final m in midis) {
      _awaitingGap.remove(m);
      _gapSeen.remove(m);
      _quietFrames.remove(m);
    }
  }

  void clear() {
    _awaitingGap.clear();
    _gapSeen.clear();
    _quietFrames.clear();
  }

  /// True while we still need a quiet gap before this MIDI can count as a hit.
  /// Neighbor bins (±1) and octave relatives of an awaiting pitch are blocked
  /// the same way — the estimator often lands there on guide bleed.
  bool blocks(int midi) {
    for (final m in _awaitingGap) {
      if (_gapSeen.contains(m)) continue;
      if (PracticePitchMatch.isNear(m, midi)) return true;
      if (PracticePitchMatch.isOctaveRelative(m, midi)) return true;
    }
    return false;
  }

  /// Update gap state from current heard midis; return waiting pitches that
  /// should register as **post-guide re-strikes** this frame.
  ///
  /// Ungated / no-guide practice hits come from noteOn edges only — sustained
  /// level in [heard] must not auto-advance (common tones / held notes).
  ///
  /// [stillSuppressed]: midis inside the speaker→mic suppress window — do **not**
  /// treat their absence from [heard] as a real quiet gap (filter hides them).
  Set<int> acceptHits({
    required Set<int> heard,
    required Set<int> waitingFor,
    Set<int> stillSuppressed = const {},
  }) {
    final needed = quietFramesNeeded < 1 ? 1 : quietFramesNeeded;
    for (final m in [..._awaitingGap]) {
      // Neighbor bins are also armed on suppress — treat ±1 as still suppressed.
      final suppressedNear = stillSuppressed.any(
        (s) => PracticePitchMatch.isNear(m, s),
      );
      if (suppressedNear) {
        // Suppress filter hides the pitch — reset streak; not a real gap.
        _quietFrames[m] = 0;
        continue;
      }
      // Estimator often lands ±1 on guide bleed — still counts as "hearing".
      if (!PracticePitchMatch.isHeardNear(m, heard)) {
        final n = (_quietFrames[m] ?? 0) + 1;
        _quietFrames[m] = n;
        if (n >= needed) {
          _gapSeen.add(m);
        }
      } else if (!_gapSeen.contains(m)) {
        // Still hearing guide bleed before a confirmed gap — restart streak.
        _quietFrames[m] = 0;
      }
    }

    if (_awaitingGap.isEmpty) return {};

    final matched = PracticePitchMatch.matchWaiting(
      heard: heard,
      waitingFor: waitingFor,
    );
    final hits = <int>{};
    for (final m in matched) {
      // Only armed pitches after a quiet gap — never level-hold hits.
      if (!_awaitingGap.contains(m)) continue;
      if (!_gapSeen.contains(m)) continue;
      _awaitingGap.remove(m);
      _gapSeen.remove(m);
      _quietFrames.remove(m);
      hits.add(m);
    }
    return hits;
  }
}
