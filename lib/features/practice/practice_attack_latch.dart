import 'practice_pitch_match.dart';

/// Consumes a wait-mode hit so the **same lock / ring** cannot satisfy the next
/// time-position (common on repeated pitches: 月光 / 夜的钢琴曲 / 诀别书).
///
/// Same-beat chords still work: each distinct MIDI is a root. [blocks] treats
/// ±1 and exact ±12 of a root as the same attack.
///
/// Re-arm paths:
/// - Quiet for [postHitReleaseFrames] after a wait hit (stricter than bare
///   [releaseFrames] so BP empty flicker cannot auto-advance the next same pitch).
/// - [releaseOnOnset] only after [onsetRefractoryFrames] (连击 OK; sustain flux
///   on one physical strike must not clear the latch immediately).
///
/// Carryover (phrase false-advance):
/// When waiting jumps to the next onset, pitches **already sounding** (BP ~2s
/// window / sustain / lock flicker) must not satisfy the new wait until they
/// have gone quiet. Spurious onset flux must **not** clear this — that was the
/// remaining “弹了前几个后面自己过” path.
class PracticeAttackLatch {
  PracticeAttackLatch({
    this.releaseFrames = defaultReleaseFrames,
    this.postHitReleaseFrames = defaultPostHitReleaseFrames,
    this.onsetRefractoryFrames = defaultOnsetRefractoryFrames,
    this.carryoverQuietFrames = defaultCarryoverQuietFrames,
  });

  /// Pitch frames (~30ms) of unbroken quiet for a non-hit release (legacy).
  static const defaultReleaseFrames = 2;

  /// After a wait hit: need ~150ms quiet before the same pitch can count again.
  static const defaultPostHitReleaseFrames = 5;

  /// Frames after consume during which onset cannot unlock (~180ms).
  static const defaultOnsetRefractoryFrames = 6;

  /// Carryover linger must be quiet this many frames (~240ms) before it may
  /// satisfy a later wait (even with a real onset).
  static const defaultCarryoverQuietFrames = 8;

  final int releaseFrames;
  final int postHitReleaseFrames;
  final int onsetRefractoryFrames;
  final int carryoverQuietFrames;

  final Set<int> _spent = {};
  final Map<int, int> _quietFrames = {};
  /// Quiet frames required to clear this root (post-hit uses a higher bar).
  final Map<int, int> _quietNeeded = {};
  /// Remaining frames before onset may unlock this root.
  final Map<int, int> _onsetRefractory = {};

  /// Already-heard midis when the next waiting set armed.
  final Set<int> _carryover = {};
  final Map<int, int> _carryQuiet = {};

  /// Test/inspection.
  Set<int> get spent => {..._spent};

  /// Test/inspection.
  Set<int> get carryover => {..._carryover};

  void clear() {
    _spent.clear();
    _quietFrames.clear();
    _quietNeeded.clear();
    _onsetRefractory.clear();
    _carryover.clear();
    _carryQuiet.clear();
  }

  /// Snapshot pitches already in the air when a new wait becomes active.
  /// Merges with any existing carryover (advance may arm before the next frame).
  void armCarryover(Set<int> sounding) {
    for (final m in sounding) {
      if (m < 21 || m > 108) continue;
      _carryover.add(m);
      _carryQuiet[m] = 0;
    }
  }

  /// After a successful wait hit: block this pitch until quiet / post-refractory
  /// onset re-attack.
  ///
  /// Roots only. [blocks] then applies ±1 and exact ±12. Do **not** also store
  /// octave bins as roots — `isNear` on those bins blocks a chord tone 11
  /// semitones away (C4 blocked after B4 in C–E–G–B).
  void markConsumed(int waitingMidi, {int? heardMidi}) {
    _arm(waitingMidi, postHit: true);
    if (heardMidi != null) _arm(heardMidi, postHit: true);
  }

  /// True if [midi] must not count as a new wait hit yet (post-consume spent).
  bool blocks(int midi) {
    for (final s in _spent) {
      if (PracticePitchMatch.isNear(s, midi)) return true;
      if (PracticePitchMatch.isOctaveRelative(s, midi)) return true;
    }
    return false;
  }

  /// True if [midi] is leftover sound from before this wait and must not count.
  ///
  /// Stays blocked until the related carryover pitch has been quiet for
  /// [carryoverQuietFrames] — **including** when a spurious onset flux re-edges
  /// the linger. Real next notes that are not near/octave of carryover pass.
  bool blocksCarryover(int midi, {bool hasOnset = false}) {
    if (_carryover.isEmpty) return false;
    for (final s in _carryover) {
      if (s == midi ||
          PracticePitchMatch.isNear(s, midi) ||
          PracticePitchMatch.isOctaveRelative(s, midi)) {
        return true;
      }
    }
    return false;
  }

  /// Advance release streaks from the current heard / locked set.
  void onHeard(Set<int> heard) {
    _tickOnsetRefractory();
    _decayCarryover(heard);
    if (_spent.isEmpty) return;
    for (final m in [..._spent]) {
      if (_isStillHeard(m, heard)) {
        _quietFrames[m] = 0;
        continue;
      }
      final needed = _quietNeeded[m] ?? (releaseFrames < 1 ? 1 : releaseFrames);
      final n = (_quietFrames[m] ?? 0) + 1;
      if (n >= needed) {
        _clearRoot(m);
      } else {
        _quietFrames[m] = n;
      }
    }
  }

  void _decayCarryover(Set<int> heard) {
    if (_carryover.isEmpty) return;
    final needed = carryoverQuietFrames < 1 ? 1 : carryoverQuietFrames;
    for (final m in [..._carryover]) {
      if (_isStillHeard(m, heard)) {
        _carryQuiet[m] = 0;
        continue;
      }
      final n = (_carryQuiet[m] ?? 0) + 1;
      if (n >= needed) {
        _carryover.remove(m);
        _carryQuiet.remove(m);
      } else {
        _carryQuiet[m] = n;
      }
    }
  }

  /// Strong re-attack while pitch still heard (连击 / 同音再击 without full quiet).
  /// Ignored during the post-hit onset refractory (anti sustain false-advance).
  void releaseOnOnset(Set<int> heard) {
    if (_spent.isEmpty || heard.isEmpty) return;
    for (final m in [..._spent]) {
      if (!_isStillHeard(m, heard)) continue;
      if (_onsetRefractoryActive(m)) continue;
      _clearRoot(m);
    }
  }

  void _arm(int midi, {required bool postHit}) {
    if (midi < 21 || midi > 108) return;
    _spent.add(midi);
    _quietFrames[midi] = 0;
    if (postHit) {
      final q = postHitReleaseFrames < 1 ? 1 : postHitReleaseFrames;
      final r = onsetRefractoryFrames < 0 ? 0 : onsetRefractoryFrames;
      _quietNeeded[midi] = q;
      _onsetRefractory[midi] = r;
    }
  }

  void _clearRoot(int midi) {
    _spent.remove(midi);
    _quietFrames.remove(midi);
    _quietNeeded.remove(midi);
    _onsetRefractory.remove(midi);
  }

  void _tickOnsetRefractory() {
    if (_onsetRefractory.isEmpty) return;
    for (final m in [..._onsetRefractory.keys]) {
      final n = (_onsetRefractory[m] ?? 0) - 1;
      if (n <= 0) {
        _onsetRefractory.remove(m);
      } else {
        _onsetRefractory[m] = n;
      }
    }
  }

  bool _onsetRefractoryActive(int midi) {
    for (final e in _onsetRefractory.entries) {
      if (e.value <= 0) continue;
      if (PracticePitchMatch.isNear(e.key, midi)) return true;
      if (PracticePitchMatch.isOctaveRelative(e.key, midi)) return true;
    }
    return false;
  }

  bool _isStillHeard(int spentMidi, Set<int> heard) {
    if (heard.isEmpty) return false;
    return PracticePitchMatch.isHeardNear(spentMidi, heard);
  }
}
