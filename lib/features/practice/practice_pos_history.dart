/// Short wall-clock → playhead ring so hits can grade at mic capture time.
class PracticePosHistory {
  PracticePosHistory({this.maxSamples = 64});

  final int maxSamples;
  final List<({DateTime at, double beats})> _samples = [];

  void clear() => _samples.clear();

  void record(DateTime at, double beats) {
    _samples.add((at: at, beats: beats));
    while (_samples.length > maxSamples) {
      _samples.removeAt(0);
    }
  }

  /// Interpolate playhead at [t]; falls back to [fallback] if empty.
  double beatsAt(DateTime t, {required double fallback}) {
    if (_samples.isEmpty) return fallback;
    if (_samples.length == 1) return _samples.first.beats;

    final first = _samples.first;
    if (!t.isAfter(first.at)) return first.beats;

    final last = _samples.last;
    if (!t.isBefore(last.at)) {
      // Brief extrapolate past last sample using last segment rate.
      if (_samples.length >= 2) {
        final a = _samples[_samples.length - 2];
        final b = last;
        final dtMs = b.at.difference(a.at).inMicroseconds / 1000.0;
        if (dtMs > 0.5) {
          final rate = (b.beats - a.beats) / (dtMs / 1000.0);
          final ageSec = t.difference(b.at).inMicroseconds / 1e6;
          // Cap 80ms — same order as staff extrapolate cushion.
          final age = ageSec.clamp(0.0, 0.08);
          return b.beats + rate * age;
        }
      }
      return last.beats;
    }

    for (var i = 1; i < _samples.length; i++) {
      final b = _samples[i];
      final a = _samples[i - 1];
      if (t.isAfter(b.at)) continue;
      final span = b.at.difference(a.at).inMicroseconds;
      if (span <= 0) return b.beats;
      final u = t.difference(a.at).inMicroseconds / span;
      return a.beats + (b.beats - a.beats) * u;
    }
    return last.beats;
  }
}
