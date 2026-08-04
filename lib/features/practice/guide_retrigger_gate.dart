/// Flowkey-style hit gate: after speaker guide of a pitch, accept a user hit
/// only once the mic has gone quiet on that pitch (gap), then heard it again.
///
/// Prevents guide→mic echo from auto-advancing wait mode, without permanently
/// blocking the same MIDI the user must play.
class GuideRetriggerGate {
  GuideRetriggerGate({this.quietFramesNeeded = defaultQuietFramesNeeded});

  /// Pitch frames (~40ms hop) of unbroken quiet required before [gapSeen].
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
  bool blocks(int midi) {
    return _awaitingGap.contains(midi) && !_gapSeen.contains(midi);
  }

  /// Update gap state from current heard midis; return waiting pitches that
  /// should register as user hits this frame.
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
      if (stillSuppressed.contains(m)) {
        // Suppress filter hides the pitch — reset streak; not a real gap.
        _quietFrames[m] = 0;
        continue;
      }
      if (!heard.contains(m)) {
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

    final hits = <int>{};
    for (final m in waitingFor) {
      if (!heard.contains(m)) continue;
      if (_awaitingGap.contains(m)) {
        if (!_gapSeen.contains(m)) continue; // still guide bleed
        _awaitingGap.remove(m);
        _gapSeen.remove(m);
        _quietFrames.remove(m);
      }
      hits.add(m);
    }
    return hits;
  }
}
