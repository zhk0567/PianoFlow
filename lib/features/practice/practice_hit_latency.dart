/// Lightweight hit-latency observation for 跟弹体感 (ms: capture→判定).
///
/// Logs via caller; keeps a rolling window for tests / future UI.
abstract final class PracticeHitLatency {
  static const maxSamples = 32;

  static final List<int> _samplesMs = [];

  static void reset() => _samplesMs.clear();

  static List<int> get samplesMs => List.unmodifiable(_samplesMs);

  /// Record [elapsedMs] (≥0). Returns the value for logging.
  static int record(int elapsedMs) {
    final v = elapsedMs < 0 ? 0 : elapsedMs;
    _samplesMs.add(v);
    while (_samplesMs.length > maxSamples) {
      _samplesMs.removeAt(0);
    }
    return v;
  }

  static double? get averageMs {
    if (_samplesMs.isEmpty) return null;
    final sum = _samplesMs.fold<int>(0, (a, b) => a + b);
    return sum / _samplesMs.length;
  }
}
