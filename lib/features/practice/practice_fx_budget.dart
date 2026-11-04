/// Hard budget for「视觉特效」— glamorous *display* only.
///
/// Isolation rules (do not violate):
/// - Never write practice clock / wait / grade logic.
/// - Never resize or transform the Verovio staff WebView for FX.
/// - [enabled]==false → no AnimationController ticking.
/// - No spark particles, no [ImageFilter.blur], no 3D engine.
/// - No always-on ambient AnimationController (that was a 60 Hz paint tax).
abstract final class PracticeFxBudget {
  /// Burst animation length (rings linger a beat without feeling sticky).
  static const burstMs = 980;

  /// Fixed ambient wash strength (no ticking controller).
  static const ambientT = 0.4;

  /// Live rings. A chord needs one per sounding pitch; oldest drops first.
  static const maxLiveRipples = 24;
}
