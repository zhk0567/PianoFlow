import 'package:flutter/foundation.dart';

/// High-frequency transport clock for waterfall / staff / seek UI.
///
/// Updated every engine tick **without** going through Riverpod, so the
/// practice scaffold is not rebuilt at ~60 Hz (which freezes buttons).
class PracticeClock extends ChangeNotifier {
  double _positionBeats = 0;
  double _beatsPerSec = 0;
  bool _playing = false;
  int _seekEpoch = 0;

  double get positionBeats => _positionBeats;
  double get beatsPerSec => _beatsPerSec;
  bool get isPlaying => _playing;

  /// Bumped only on intentional seek / loop wrap — staff snaps only then.
  int get seekEpoch => _seekEpoch;

  void sync({
    required double positionBeats,
    required double beatsPerSec,
    required bool isPlaying,
    bool intentionalSeek = false,
  }) {
    final posChanged = (positionBeats - _positionBeats).abs() > 1e-9;
    final rateChanged = (beatsPerSec - _beatsPerSec).abs() > 1e-9;
    final playChanged = isPlaying != _playing;
    final seekChanged = intentionalSeek;
    if (!posChanged && !rateChanged && !playChanged && !seekChanged) return;
    _positionBeats = positionBeats;
    _beatsPerSec = beatsPerSec;
    _playing = isPlaying;
    if (intentionalSeek) _seekEpoch++;
    notifyListeners();
  }

  void setParked(double positionBeats) {
    sync(
      positionBeats: positionBeats,
      beatsPerSec: 0,
      isPlaying: false,
      intentionalSeek: true,
    );
  }
}
