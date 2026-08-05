import 'practice_constants.dart';

/// Timing grade for a wait-mode hit relative to chord onset.
enum HitGrade { perfect, good, miss }

extension HitGradeX on HitGrade {
  /// User-facing flash label. Miss has **no** label (no negative copy).
  String? get labelZh => switch (this) {
        HitGrade.perfect => '完美',
        HitGrade.good => '不错',
        HitGrade.miss => null,
      };

  bool get showsFeedback => this != HitGrade.miss;
}

/// Pure timing → grade mapping (unit-tested).
abstract final class PracticeJudgeLogic {
  /// [deltaBeats] = playhead − chord onset (negative = early).
  static HitGrade gradeFromDelta(double deltaBeats) {
    final abs = deltaBeats.abs();
    if (abs <= PracticeConstants.judgePerfectBeats) {
      return HitGrade.perfect;
    }
    if (abs <= PracticeConstants.waitEarlyHitBeats) {
      return HitGrade.good;
    }
    // Outside early window should not normally count as a hit; treat as good
    // if the engine still accepted it (edge / freeze slack).
    return HitGrade.good;
  }

  /// Hit rate 0–1 from session counters (misses count in denominator).
  static double accuracy({
    required int perfects,
    required int goods,
    required int misses,
  }) {
    final total = perfects + goods + misses;
    if (total <= 0) return 0;
    return (perfects + goods) / total;
  }

  /// Weighted score 0–100 (perfect=1, good=0.6, miss=0).
  static double score100({
    required int perfects,
    required int goods,
    required int misses,
  }) {
    final total = perfects + goods + misses;
    if (total <= 0) return 0;
    return ((perfects + goods * 0.6) / total) * 100;
  }
}
