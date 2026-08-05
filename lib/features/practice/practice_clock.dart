import 'package:flutter/foundation.dart';

/// Live transport clock for the practice stage (waterfall / staff / seek UI).
///
/// Updated every engine tick without going through Riverpod — so the scaffold
/// does not rebuild at ~60 Hz. [PracticeSnapshot] only changes on events
/// (play/pause, hits, settings, waiting/active set changes).
@immutable
class PracticeClockValue {
  const PracticeClockValue({
    required this.positionBeats,
    required this.beatsPerSec,
    this.seekEpoch = 0,
  });

  final double positionBeats;

  /// Staff transport rate (0 when paused / wait-frozen / end-hang).
  final double beatsPerSec;

  /// Bumped only on intentional seek / loop wrap — staff snaps only then.
  final int seekEpoch;

  static const zero = PracticeClockValue(positionBeats: 0, beatsPerSec: 0);

  @override
  bool operator ==(Object other) =>
      other is PracticeClockValue &&
      other.positionBeats == positionBeats &&
      other.beatsPerSec == beatsPerSec &&
      other.seekEpoch == seekEpoch;

  @override
  int get hashCode => Object.hash(positionBeats, beatsPerSec, seekEpoch);
}

class PracticeClock extends ValueNotifier<PracticeClockValue> {
  PracticeClock([super.value = PracticeClockValue.zero]);

  double get positionBeats => value.positionBeats;
  double get beatsPerSec => value.beatsPerSec;
  int get seekEpoch => value.seekEpoch;

  void setTransport({
    required double positionBeats,
    required double beatsPerSec,
    bool intentionalSeek = false,
  }) {
    final next = PracticeClockValue(
      positionBeats: positionBeats,
      beatsPerSec: beatsPerSec,
      seekEpoch: intentionalSeek ? value.seekEpoch + 1 : value.seekEpoch,
    );
    if (next == value) return;
    value = next;
  }
}
