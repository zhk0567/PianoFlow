/// Pure Verovio playhead sync decisions (seek / loop snap vs ease).
abstract final class VerovioTransportSync {
  static const posMinDelta = 0.01;
  static const rateMinDelta = 0.01;
  static const seekSnapBeats = 0.35;

  static double positionDelta(double fromBeats, double toBeats) =>
      (fromBeats - toBeats).abs();

  static double rateDelta(double fromBps, double toBps) =>
      (fromBps - toBps).abs();

  static bool shouldSkipPush({
    required double posDelta,
    required bool playChanged,
    required double rateDelta,
  }) {
    return !playChanged &&
        posDelta <= posMinDelta &&
        rateDelta <= rateMinDelta;
  }

  static bool shouldSnapSeek(
    double posDelta, {
    bool intentionalSeek = false,
  }) {
    if (intentionalSeek) return true;
    return posDelta > seekSnapBeats;
  }

  static bool shouldSnapForEpoch({
    required int previousEpoch,
    required int currentEpoch,
  }) =>
      currentEpoch != previousEpoch;

  /// Freeze ↔ free-advance toggles beatsPerSec through 0 — snap so staff
  /// does not ease across the wait line with a stale throttle sample.
  static bool shouldSnapForRateZeroCrossing({
    required double previousRate,
    required double currentRate,
  }) {
    final wasMoving = previousRate > rateMinDelta;
    final isMoving = currentRate > rateMinDelta;
    return wasMoving != isMoving;
  }

  static bool shouldDeferResize({required bool pushing}) => pushing;

  static String resizeFallbackLog(Object error) =>
      'pfResize failed → full score push: $error';

  static String positionPushFailedLog({
    required double beats,
    required bool snap,
    required Object error,
  }) =>
      'pfSetPosition failed beats=$beats snap=$snap: $error';
}
