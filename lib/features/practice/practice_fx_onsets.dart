import '../../shared/models/song.dart';

/// Score notes that would actually sound while the playhead crosses `(prev, pos]`.
///
/// Matches autoplay `_playGuideAt`: every newly crossed onset is eligible, and
/// within one tick the same MIDI sounds only once (LH+RH unison, or two starts
/// that land in the same hitch). Different pitches in a chord each count.
List<ScoreNote> soundingOnsetsCrossing({
  required List<ScoreNote> notes,
  required double prev,
  required double pos,
}) {
  if (!(pos > prev)) return const [];
  final seenMidi = <int>{};
  final out = <ScoreNote>[];
  for (final n in notes) {
    if (n.start <= prev || n.start > pos) continue;
    if (!seenMidi.add(n.midi)) continue;
    out.add(n);
  }
  return out;
}
