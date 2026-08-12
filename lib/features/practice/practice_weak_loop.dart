/// Suggest a practice loop around miss beats (再练闭环).
abstract final class PracticeWeakLoopLogic {
  /// Pad around clustered misses (beats).
  static const padBeats = 1.0;

  /// Max span for one weak-loop suggestion (beats).
  static const maxSpanBeats = 8.0;

  /// Cluster radius: misses within this of each other merge.
  static const clusterGapBeats = 2.0;

  /// Returns (loopStart, loopEnd) or null if not enough signal.
  static ({double start, double end})? suggest({
    required List<double> missBeats,
    required double durationBeats,
  }) {
    if (missBeats.isEmpty || durationBeats <= 0.5) return null;
    final sorted = [...missBeats]..sort();
    // Densest cluster: sliding window maximizing count within maxSpan.
    var bestCount = 0;
    var bestLo = sorted.first;
    var bestHi = sorted.first;
    var j = 0;
    for (var i = 0; i < sorted.length; i++) {
      while (j < sorted.length &&
          sorted[j] - sorted[i] <= maxSpanBeats + 1e-9) {
        j++;
      }
      final count = j - i;
      if (count > bestCount) {
        bestCount = count;
        bestLo = sorted[i];
        bestHi = sorted[j - 1];
      }
    }
    if (bestCount < 1) return null;

    // Also accept single miss — still useful for 再练.
    var start = (bestLo - padBeats).clamp(0.0, durationBeats);
    var end = (bestHi + padBeats).clamp(0.0, durationBeats);
    if (end - start < 1.0) {
      end = (start + 2.0).clamp(0.0, durationBeats);
      if (end - start < 1.0) {
        start = (end - 2.0).clamp(0.0, durationBeats);
      }
    }
    if (end <= start + 0.5) return null;
    return (start: start, end: end);
  }

  static String labelZh(({double start, double end}) loop) {
    final a = loop.start.ceil();
    final b = loop.end.ceil();
    return '练薄弱段（约 $a–$b 拍）';
  }
}
