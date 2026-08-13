import 'practice_pitch_match.dart';

/// When a guide cue armed the retrigger gate, how noteOn vs frames count.
///
/// Frames still need quiet-gap then re-hear (anti level-hold). noteOn is an
/// attack edge: after speaker→mic suppress ends it may count without waiting
/// for quiet first (otherwise holding the key resets the quiet streak forever).
///
/// Cue must **not** clear emitted during suppress — that would spend the only
/// re-edge inside the echo window. Defer clear to suppress end, and only for
/// pitches already emitted before the cue (held / common tones).
abstract final class PracticeGuideHitPolicy {
  /// Map a noteOn onto a waiting pitch after suppress has ended.
  /// Returns null while still echo-suppressed or if not near any waiting pitch.
  static int? resolveNoteOnHit({
    required int midi,
    required Set<int> waitingFor,
    required bool echoSuppressed,
  }) {
    if (echoSuppressed) return null;
    return PracticePitchMatch.matchNoteOn(
      midi: midi,
      waitingFor: waitingFor,
    );
  }

  /// Midis that should re-edge after [echoSuppressGuide]: already emitted at
  /// cue time (incl. ±1 bins), so a held common tone can noteOn once suppress ends.
  static Set<int> midisToReedgeAfterSuppress({
    required Set<int> cued,
    required bool Function(int midi) isEmitted,
  }) {
    final out = <int>{};
    for (final m in cued) {
      for (final x in [m - 1, m, m + 1]) {
        if (isEmitted(x)) out.add(x);
      }
    }
    return out;
  }

  /// Soft-cue only pitches still owed (skip early-hit / already satisfied).
  static Set<int> midisToSoftCue({
    required Set<int> expected,
    required Set<int> satisfied,
  }) =>
      expected.difference(satisfied);
}
