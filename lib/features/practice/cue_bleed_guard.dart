import 'practice_constants.dart';
import 'practice_pitch_match.dart';

/// Adaptive soft-cue bleed filter (战役 E).
///
/// Does **not** retune [PracticeConstants.echoSuppressGuide] / quiet / hop.
/// After a soft guide cue, speaker→mic leakage of **only** cued pitches without
/// a real attack onset is treated as bleed — especially in a short soft tail
/// after the hard suppress window ends (cue sample ring ≫ 250ms).
class CueBleedGuard {
  CueBleedGuard({this.softTail = defaultSoftTail});

  /// Extra observation after hard suppress — cue one-shots still ring.
  static const defaultSoftTail = Duration(milliseconds: 180);

  final Duration softTail;

  Set<int> _cued = {};
  DateTime? _cueAt;

  Set<int> get cued => {..._cued};

  void arm(Iterable<int> midis, {DateTime? at}) {
    _cued = {...midis};
    _cueAt = at ?? DateTime.now();
  }

  void clear() {
    _cued = {};
    _cueAt = null;
  }

  bool get isArmed => _cued.isNotEmpty && _cueAt != null;

  /// True while within hard suppress + soft soft tail.
  bool inWindow([DateTime? now]) {
    final at = _cueAt;
    if (at == null || _cued.isEmpty) return false;
    final n = now ?? DateTime.now();
    final end = at.add(PracticeConstants.echoSuppressGuide).add(softTail);
    return n.isBefore(end);
  }

  bool _nearCue(int midi) {
    for (final c in _cued) {
      if (PracticePitchMatch.isNear(c, midi)) return true;
      if (PracticePitchMatch.isOctaveRelative(c, midi)) return true;
    }
    return false;
  }

  bool _onlyCueNeighborhood(Set<int> heard) {
    if (heard.isEmpty) return true;
    for (final h in heard) {
      if (!_nearCue(h)) return false;
    }
    return true;
  }

  /// Speaker bleed of the soft cue — not a user re-strike.
  ///
  /// [hasOnset]: strong HF attack this edge/frame (user hammer).
  /// [heardAll]: currently locked/heard set (for "only cue pitches" check).
  bool isBleed({
    required int midi,
    required bool hasOnset,
    required Set<int> heardAll,
    DateTime? now,
  }) {
    final at = _cueAt;
    if (at == null || _cued.isEmpty) return false;
    if (!_nearCue(midi)) return false;
    // Real re-strike always wins.
    if (hasOnset) return false;

    final n = now ?? DateTime.now();
    final hardEnd = at.add(PracticeConstants.echoSuppressGuide);
    final softEnd = hardEnd.add(softTail);

    if (n.isBefore(hardEnd)) {
      // Hard window: time suppress usually already blocks; still flag
      // onset-less cue-neighborhood edges as bleed (defense in depth).
      return true;
    }
    if (n.isBefore(softEnd)) {
      // Grace for deferred held-tone reedge at suppress end (~1 hop).
      final sinceHard = n.difference(hardEnd);
      if (sinceHard < const Duration(milliseconds: 50)) return false;
      // Soft tail: only treat as bleed when mic shows solely cue neighborhood
      // (user playing other waiting tones must pass).
      return _onlyCueNeighborhood(heardAll);
    }
    return false;
  }
}
