/// Pure Verovio playhead sync decisions (seek / loop snap vs ease).
///
/// Used by [VerovioStaffLane] so seek/loop jumps hard-correct the cursor while
/// normal ticks and rate-only updates ease without flash-scrolling.
abstract final class VerovioTransportSync {
  /// Ignore smaller beat moves unless play/rate also changed (slow tempos use heartbeat).
  static const posMinDelta = 0.01;

  /// Ignore tiny rate noise.
  static const rateMinDelta = 0.01;

  /// Absolute beat jump above this → hard snap (seek / loop wrap).
  /// Equal to this value still eases (strict `>`), matching legacy lane behavior.
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

  /// True → [pushPosition] with `snap: true` (seek / loop wrap).
  static bool shouldSnapSeek(double posDelta) => posDelta > seekSnapBeats;

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
