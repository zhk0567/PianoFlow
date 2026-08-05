/// Pure Verovio playhead sync decisions (seek / loop snap vs ease).
///
/// Used by [VerovioStaffLane] so intentional seek/loop jumps hard-correct the
/// cursor while normal ticks, freeze, and end-hang ease without flash-scrolling.
abstract final class VerovioTransportSync {
  /// Ignore smaller beat moves unless play/rate also changed.
  /// With ~8 Hz Dart anchors, normal ticks often exceed 0.01 — throttle still gates IPC.
  static const posMinDelta = 0.02;

  /// Ignore tiny rate noise.
  static const rateMinDelta = 0.01;

  /// Absolute beat jump above this → hard snap **only when used without epoch**.
  /// Prefer [shouldSnapForEpoch] from [PracticeClock.seekEpoch].
  static const seekSnapBeats = 0.35;

  static double positionDelta(double fromBeats, double toBeats) =>
      (fromBeats - toBeats).abs();

  static double rateDelta(double fromBps, double toBps) =>
      (fromBps - toBps).abs();

  /// True → do not call pushPosition (widget update is a no-op for transport).
  static bool shouldSkipPush({
    required double posDelta,
    required bool playChanged,
    required double rateDelta,
  }) {
    return !playChanged &&
        posDelta <= posMinDelta &&
        rateDelta <= rateMinDelta;
  }

  /// True → [pushPosition] with `snap: true`.
  ///
  /// When [intentionalSeek] is true, always snap. Otherwise only large deltas
  /// snap (legacy). Lane should prefer [shouldSnapForEpoch] instead.
  static bool shouldSnapSeek(
    double posDelta, {
    bool intentionalSeek = false,
  }) {
    if (intentionalSeek) return true;
    return posDelta > seekSnapBeats;
  }

  /// Lane helper: snap only when the clock seek epoch advanced.
  static bool shouldSnapForEpoch({
    required int previousEpoch,
    required int currentEpoch,
  }) =>
      currentEpoch != previousEpoch;

  /// While a score push holds the bridge, resize must not be dropped — defer.
  static bool shouldDeferResize({required bool pushing}) => pushing;

  /// Console + UI dual-channel message prefixes (kept stable for grepping).
  static String resizeFallbackLog(Object error) =>
      'pfResize failed → full score push: $error';

  static String positionPushFailedLog({
    required double beats,
    required bool snap,
    required Object error,
  }) =>
      'pfSetPosition failed beats=$beats snap=$snap: $error';
}
