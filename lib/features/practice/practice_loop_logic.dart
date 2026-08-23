import 'dart:math' as math;

import 'practice_constants.dart';

/// Pure loop / lead-in helpers — unit-tested without Riverpod or audio.
abstract final class PracticeLoopLogic {
  /// Earliest onset among [starts] (0 if empty / non-finite).
  static double firstOnsetBeats(Iterable<double> starts) {
    double? min;
    for (final s in starts) {
      if (!s.isFinite) continue;
      if (min == null || s < min) min = s;
    }
    return min ?? 0.0;
  }

  /// Park transport this many beats before [firstOnset] (negative when onset is 0).
  static double startParkBeats({double firstOnset = 0}) {
    final onset = firstOnset.isFinite ? firstOnset : 0.0;
    final lead = PracticeConstants.playbackLeadInBeats;
    return lead > 0 ? onset - lead : onset;
  }

  /// Apply pre-roll when [pos] is at/near the piece start (relative to first note).
  ///
  /// Songs whose first note is late (e.g. onset 2 or 4) must park at
  /// `onset − lead`, not absolute −lead — otherwise the staff playhead sits on
  /// the first note while wait-mode still has to crawl empty beats.
  static double withStartLeadIn(double pos, {double firstOnset = 0}) {
    final onset = firstOnset.isFinite ? firstOnset : 0.0;
    final park = startParkBeats(firstOnset: onset);
    // Already inside the lead-in window before the first note.
    if (pos + 1e-9 >= park && pos < onset - 1e-9) return pos;
    // Classic restart at beat ≈0 (including late-onset pieces).
    if (pos <= PracticeConstants.playbackLeadInSeekEps) return park;
    // Seek/restart landing on/near the first sounding onset.
    if ((pos - onset).abs() <= PracticeConstants.playbackLeadInSeekEps) {
      return park;
    }
    return pos;
  }

  /// Transport origin for the seek slider — same as [startParkBeats].
  ///
  /// Late-onset pieces park at `onset − lead` (>0). Mapping the slider from
  /// that origin keeps the thumb at the left edge on initial open / restart.
  static double seekSliderOrigin({double firstOnset = 0}) =>
      startParkBeats(firstOnset: firstOnset);

  /// Slider max (span from [seekSliderOrigin] to score end).
  static double seekSliderMax({
    required double durationBeats,
    double firstOnset = 0,
  }) {
    final origin = seekSliderOrigin(firstOnset: firstOnset);
    final dur = durationBeats.isFinite && durationBeats > 0 ? durationBeats : 1.0;
    final span = dur - origin;
    return span > 1e-6 ? span : 1.0;
  }

  /// Map transport beats → slider thumb value (0 at start park).
  static double seekSliderValue({
    required double positionBeats,
    required double durationBeats,
    double firstOnset = 0,
  }) {
    final origin = seekSliderOrigin(firstOnset: firstOnset);
    final max = seekSliderMax(
      durationBeats: durationBeats,
      firstOnset: firstOnset,
    );
    final pos = positionBeats.isFinite ? positionBeats : origin;
    return (pos - origin).clamp(0.0, max);
  }

  /// Map slider thumb → transport beats (seek target before lead-in clamp).
  static double seekBeatsFromSlider({
    required double sliderValue,
    double firstOnset = 0,
  }) {
    final origin = seekSliderOrigin(firstOnset: firstOnset);
    final v = sliderValue.isFinite ? sliderValue : 0.0;
    return origin + v;
  }

  /// When transport [next] crosses [loopEnd], return the wrap target
  /// (with lead-in when [loopStart] is near the piece start); otherwise null.
  static double? wrapIfPastEnd({
    required double next,
    required double loopStart,
    required double loopEnd,
    double firstOnset = 0,
  }) {
    if (next < loopEnd) return null;
    return withStartLeadIn(loopStart, firstOnset: firstOnset);
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

  /// Ease for end-of-piece rewind (smooth scrub back to start).
  static double easeInOutCubic(double t) {
    final x = t.clamp(0.0, 1.0);
    return x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;
  }
}
