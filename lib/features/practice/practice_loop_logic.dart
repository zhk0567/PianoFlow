import 'practice_constants.dart';

/// Pure loop / lead-in helpers — unit-tested without Riverpod or audio.
abstract final class PracticeLoopLogic {
  /// Apply negative pre-roll when [pos] is at/near the piece beginning.
  static double withStartLeadIn(double pos) {
    // Already in pre-roll — keep current beats (do not snap back to −lead).
    if (pos < -1e-6) return pos;
    if (pos <= PracticeConstants.playbackLeadInSeekEps) {
      return PracticeConstants.playbackStartParkBeats;
    }
    return pos;
  }

  /// When transport [next] crosses [loopEnd], return the wrap target
  /// (with lead-in when [loopStart] is near 0); otherwise null.
  static double? wrapIfPastEnd({
    required double next,
    required double loopStart,
    required double loopEnd,
  }) {
    if (next < loopEnd) return null;
    return withStartLeadIn(loopStart);
  }

  /// Metronome beat index for a practice playhead (matches [ScoreAudioPlayer]).
  static int metronomeBeatIndexForPosition(double positionBeats) {
    if (!positionBeats.isFinite) return 0;
    final beat = positionBeats.floor();
    return beat < 0 ? 0 : beat;
  }

  /// While transport runs with metronome, speed changes (and turning metro on)
  /// must re-phase clicks to [positionBeats] — same contract as seek / loop wrap.
  static bool shouldRealignMetronome({
    required bool isPlaying,
    required bool metronomeEnabled,
    required bool speedChanged,
    required bool metronomeJustEnabled,
  }) {
    if (!isPlaying || !metronomeEnabled) return false;
    return speedChanged || metronomeJustEnabled;
  }

  /// Metronome may click only while the practice playhead is advancing
  /// (not wait-mode freeze / end hang).
  static bool metronomeShouldAdvance({
    required double transportBeatsPerSec,
  }) =>
      transportBeatsPerSec > 0;
}
