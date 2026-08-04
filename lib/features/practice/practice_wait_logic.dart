import '../../shared/models/song.dart';
import 'practice_constants.dart';

/// Pure wait-mode helpers (Flowkey-style) — unit-tested without Riverpod.
abstract final class PracticeWaitLogic {
  /// Next note at/after [pos] (onset search).
  static ScoreNote? nextTarget(List<ScoreNote> notes, double pos) {
    if (notes.isEmpty) return null;
    for (final n in notes) {
      if (n.start + 0.001 >= pos - 0.001) return n;
    }
    return null;
  }

  /// MIDI set for the chord clustered at [target.start].
  static Set<int> chordMidis(List<ScoreNote> notes, ScoreNote target) {
    final start = target.start;
    final cluster = PracticeConstants.waitChordClusterBeats;
    return notes
        .where((n) => (n.start - start).abs() < cluster)
        .map((n) => n.midi)
        .toSet();
  }

  /// Expected midis for wait mode at [pos].
  ///
  /// Empty while still approaching (beyond early-hit window) so transport
  /// free-advances and falling notes keep moving (Flowkey gap travel).
  static Set<int> expectedAt({
    required List<ScoreNote> notes,
    required double pos,
  }) {
    final target = nextTarget(notes, pos);
    if (target == null) return {};
    // Far before onset — keep falling; no wait UI yet.
    if (target.start > pos + PracticeConstants.waitEarlyHitBeats) return {};
    return chordMidis(notes, target);
  }

  /// Freeze transport once the playhead reaches the chord onset.
  static bool shouldFreezeAt({
    required double pos,
    required double chordStart,
  }) {
    return pos >= chordStart - PracticeConstants.waitFreezeSlackBeats;
  }

  /// After a correct hit: nudge just past this onset so free-advance resumes
  /// through rests/gaps instead of teleporting to the next note.
  static double nudgePastChord({
    required List<ScoreNote> notes,
    required double pos,
  }) {
    final cluster = PracticeConstants.waitChordClusterBeats;
    final atPos = notes.where((n) => (n.start - pos).abs() < cluster).toList();
    if (atPos.isNotEmpty) {
      return atPos.first.start + PracticeConstants.waitAdvanceEpsilonBeats;
    }
    final target = nextTarget(notes, pos);
    if (target != null &&
        target.start <= pos + PracticeConstants.waitEarlyHitBeats) {
      return target.start + PracticeConstants.waitAdvanceEpsilonBeats;
    }
    return pos + PracticeConstants.waitAdvanceEpsilonBeats;
  }

  /// Onset beat of the chord represented by [expected] near [pos].
  static double? chordStartForExpected({
    required List<ScoreNote> notes,
    required Set<int> expected,
    required double pos,
  }) {
    if (expected.isEmpty) return null;
    final target = nextTarget(notes, pos);
    if (target == null) return null;
    if (!expected.contains(target.midi)) {
      // Expected may be a subset after partial hits — still use cluster start.
      final cluster = PracticeConstants.waitChordClusterBeats;
      for (final n in notes) {
        if (expected.contains(n.midi) &&
            (n.start - (target.start)).abs() < cluster * 4) {
          return n.start;
        }
      }
    }
    return target.start;
  }
}
