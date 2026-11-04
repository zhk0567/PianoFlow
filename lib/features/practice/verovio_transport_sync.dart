/// Pure Verovio playhead sync decisions (seek / loop snap vs ease).
abstract final class VerovioTransportSync {
  static const posMinDelta = 0.01;
  static const rateMinDelta = 0.01;
  static const seekSnapBeats = 0.35;

  /// While transport advances, coalesce WebView pushes (~2× 16ms clock).
  /// Viewer extrapolates with MAX_EXTRAPOLATE_SEC; seek/freeze still immediate.
  static const playPushMinIntervalMs = 32;

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

  /// Drop mid-play bridge ticks that arrive sooner than [playPushMinIntervalMs].
  /// Large jumps, play/pause edges, and freeze snaps must not be throttled.
  static bool shouldThrottlePlayPush({
    required double beatsPerSec,
    required int msSinceLastPush,
    required double posDelta,
    required bool playChanged,
    required bool forceImmediate,
  }) {
    if (forceImmediate || playChanged) return false;
    if (beatsPerSec <= rateMinDelta) return false;
    if (posDelta > seekSnapBeats) return false;
    return msSinceLastPush < playPushMinIntervalMs;
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

  /// Freeze (rate → 0) must snap so staff does not ease across the wait
  /// line with a stale throttle sample. Play / unfreeze (rate → positive)
  /// hard-tracks via beatsPerSec>0 — snapping there only adds play-start jank.
  static bool shouldSnapForFreezeRateCrossing({
    required double previousRate,
    required double currentRate,
  }) {
    if (!shouldSnapForRateZeroCrossing(
      previousRate: previousRate,
      currentRate: currentRate,
    )) {
      return false;
    }
    return currentRate <= rateMinDelta;
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
