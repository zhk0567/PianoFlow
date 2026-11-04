import '../../shared/models/song.dart';

/// Shared practice-page constants (avoid scattered magic numbers).
abstract final class PracticeConstants {
  /// Speaker guide → mic feedback suppress window (full self-play / loud demo).
  /// Samples ring ~1s+ after the 12× gain boost; 700ms was far too short.
  static const echoSuppress = Duration(milliseconds: 1700);

  /// Soft practice guide cue → mic bleed window (shorter so user can re-hit
  /// the same pitch after a quiet gap; see [GuideRetriggerGate]).
  /// Aligned with ~0.25s pitch capture + ~30ms hop (was 300ms).
  static const echoSuppressGuide = Duration(milliseconds: 250);

  /// Pitch-frame quiet streak after guide before [GuideRetriggerGate] opens
  /// (~30ms hop × 2 ≈ 60ms). One empty frame is often estimator flicker /
  /// residual guide ring — keep 2 to avoid false advance.
  static const guideQuietFramesNeeded = 2;

  /// Soft cue level for guide tones while the mic is live (practice mode).
  /// Auto-play still uses full level (mic is off). Slightly softer → less bleed.
  static const guideVolumeWithMic = 0.22;

  /// Practice engine ticker (~60 Hz).
  static const tickPeriod = Duration(milliseconds: 16);

  /// Speed slider / audio clamp.
  static const speedMin = 0.4;
  static const speedMaxUi = 2.0;
  static const speedMaxAudio = 2.0;

  /// Master volume slider. 1.0 = 100% (same loudness as before).
  /// Values above 1.0 go past 100% up to [volumeMax] (AudioPlayer is still 0–1;
  /// headroom is baked into the sample cache as [sampleGain] * [volumeMax]).
  static const volumeMin = 0.0;
  static const volumeMax = 2.0;
  static const volumeDefault = 1.0;

  /// Soft-clip gain at slider 100%. Cache is baked at [sampleGain] * [volumeMax]
  /// so 200% can still use setVolume(1.0).
  /// MusyngKite peaks are only ~3–9% FS, so ~12× is needed for a normal level.
  static const sampleGain = 12.0;

  /// Effective PCM gain written into the play-cache.
  static double get sampleCacheGain => sampleGain * volumeMax;

  /// Max one-shot length after cache shaping (bundled samples are ~3s).
  /// Long enough for half and dotted notes to keep a piano body; the tail
  /// still fades before the raw sample ends.
  static const noteMaxSeconds = 2.6;

  /// Fade-out window at the end of the shaped one-shot.
  static const noteFadeSeconds = 0.4;

  /// Exponential decay time constant. 0.58s made most notes die as a short
  /// pluck; ~1.6s keeps the body while the end still fades out.
  static const noteDecayTau = 1.6;

  /// Pitch-based stereo width (−1…+1 scale factor). Real piano: bass left,
  /// treble right. Combined with [handBalanceLeft]/[handBalanceRight].
  static const pitchPanAmount = 0.55;

  /// Hand separation on the stereo field (AudioPlayer balance −1…+1).
  /// Strong enough to hear LH/RH sides without hard-muting the opposite ear.
  static const handBalanceLeft = -0.62;
  static const handBalanceRight = 0.62;

  /// Blend weights for hand vs pitch pan (hand dominates “左右两边”).
  static const handPanWeight = 0.72;
  static const pitchPanWeight = 0.48;

  /// Stereo balance for a note (−1 = full left, +1 = full right, 0 = center).
  ///
  /// Uses score hand when known (demo / guide), plus MIDI pitch for keyboard
  /// width. Without [hand], pitch alone still spreads the keyboard spatially.
  static double stereoBalanceFor({required int midi, Hand? hand}) {
    final t = ((midi - midiMin) / (midiMax - midiMin)).clamp(0.0, 1.0);
    final pitchPan = (t * 2.0 - 1.0) * pitchPanAmount;

    var handPan = 0.0;
    if (hand == Hand.left) {
      handPan = handBalanceLeft;
    } else if (hand == Hand.right) {
      handPan = handBalanceRight;
    }

    if (hand == null) {
      return pitchPan.clamp(-1.0, 1.0);
    }
    return (handPan * handPanWeight + pitchPan * pitchPanWeight)
        .clamp(-1.0, 1.0);
  }

  /// Metronome click amplitude multiplier (synth path). Slightly less than piano
  /// sample boost so clicks stay clear without overpowering notes.
  static const metroClickGain = 1.35;

  /// Metronome BPM bounds (practice transport).
  static const metroBpmMin = 30.0;
  static const metroBpmMax = 300.0;

  /// Compact layout breakpoint (keyboard height).
  static const compactScreenHeight = 700.0;
  static const keyboardHCompact = 110.0;
  static const keyboardHComfort = 128.0;

  /// Vertical flex split in the practice stage (falling notes vs staff).
  /// Staff stays readable; waterfall keeps approach distance via
  /// [fallingMinHeight*] and a soft staff cap (avoid a tall empty cream box).
  /// When FX is off, the falling lane collapses to 0 — leftover height is
  /// absorbed below the staff (not a black empty waterfall slot above keys).
  static const fallingNotesFlex = 3;
  static const staffFlex = 4;

  /// When「视觉特效」is on, give the waterfall/FX stage a larger share.
  static const fallingNotesFlexFx = 4;
  static const staffFlexFx = 4;

  /// Minimum staff lane height (px). Must fit Verovio grand staff at [verovioScale]
  /// (~300–340 CSS px + bottom pad). Floor ≈ ink height — not a tall empty frame.
  static const staffMinHeightCompact = 220.0;
  static const staffMinHeightComfort = 310.0;

  /// Soft cap so tall windows leave room for waterfall/keyboard; do not grow
  /// far past engraved ink (viewer shrinks if still taller — never crop bass).
  static const staffMaxHeightCompact = 280.0;
  static const staffMaxHeightComfort = 350.0;

  /// One grand-staff line before the viewer reports cropped ink height.
  /// Not a tall cream well — [stageColumn] hugs [staffInk] once it arrives.
  static const staffInkFallbackCompact = 200.0;
  static const staffInkFallbackComfort = 240.0;

  /// Slightly tighter staff caps when FX stage is boosted.
  static const staffMaxHeightCompactFx = 250.0;
  static const staffMaxHeightComfortFx = 330.0;

  /// Minimum falling-notes lane height (px) so the waterfall is not crushed.
  static const fallingMinHeightCompact = 80.0;
  static const fallingMinHeightComfort = 140.0;
  static const fallingMinHeightCompactFx = 120.0;
  static const fallingMinHeightComfortFx = 160.0;

  /// Gaps between falling / keyboard / staff in the stage column.
  /// Falling↔keyboard is 0 so the hit line meets the key tops (Flowkey).
  static const stageLaneGap = 4.0;
  static const stageFallingKeyboardGap = 0.0;

  /// Hit line sits this many px above the falling-lane bottom (≈ half stroke).
  static const fallingHitLineInset = 3.0;

  /// Soft staff height cap for the current layout density.
  static double staffMaxHeight({
    required bool compact,
    bool boostFalling = false,
  }) {
    if (compact) {
      return boostFalling ? staffMaxHeightCompactFx : staffMaxHeightCompact;
    }
    return boostFalling ? staffMaxHeightComfortFx : staffMaxHeightComfort;
  }

  /// Practice column:
  /// - FX on: staff hugs one engraved line; leftover → waterfall.
  /// - FX off: keyboard and staff each take ~half the column (no giant keys).
  ///
  /// [stageHeight] is the full column (waterfall + keyboard + gap + staff).
  /// [staffInk] is the cropped system height from the viewer, when known.
  static ({double falling, double keyboard, double staff}) stageColumn({
    required double stageHeight,
    required bool compact,
    required bool showFalling,
    double? staffInk,
  }) {
    const gap = stageLaneGap;
    final baseKeys = compact ? keyboardHCompact : keyboardHComfort;
    final fallback =
        compact ? staffInkFallbackCompact : staffInkFallbackComfort;
    final ink = (staffInk ?? fallback).clamp(140.0, 400.0);
    final room = (stageHeight - gap).clamp(0.0, double.infinity);
    if (room <= 0) {
      return (falling: 0, keyboard: 0, staff: 0);
    }

    if (!showFalling) {
      // Equal split — leftover must not all pile onto the keyboard.
      final minKeys = compact ? 88.0 : 104.0;
      var staff = room * 0.5;
      var keys = room - staff;
      if (keys < minKeys) {
        keys = minKeys.clamp(0.0, room);
        staff = (room - keys).clamp(0.0, room);
      } else if (staff < ink && room - minKeys >= ink) {
        // Prefer at least one engraved line when half would crush the staff.
        staff = ink;
        keys = room - staff;
      }
      return (falling: 0, keyboard: keys, staff: staff);
    }

    var staff = ink;
    var keys = baseKeys;
    var fall = room - staff - keys;
    if (fall < 0) {
      // Ink + keys do not fit. Keep a usable keyboard; the viewer scales the
      // staff down instead of clipping the bass. Waterfall takes whatever remains.
      final minKeys = compact ? 72.0 : 88.0;
      keys = minKeys.clamp(0.0, room);
      staff = (room - keys).clamp(0.0, ink);
      fall = (room - staff - keys).clamp(0.0, double.infinity);
    }
    return (falling: fall, keyboard: keys, staff: staff);
  }

  /// Split usable stage height (excluding keyboard + gaps) between lanes.
  /// Used when the waterfall lane is visible (decorative FX on).
  ///
  /// [boostFalling]: larger waterfall share (avoid for FX — staff readability
  /// first; FX glamour comes from paint quality, not stealing staff height).
  static ({double falling, double staff}) splitStageLanes({
    required double usableHeight,
    required bool compact,
    bool boostFalling = false,
  }) {
    final usable = usableHeight.clamp(0.0, double.infinity);
    if (usable <= 0) return (falling: 0.0, staff: 0.0);

    final minStaff = compact ? staffMinHeightCompact : staffMinHeightComfort;
    final maxStaff = staffMaxHeight(compact: compact, boostFalling: boostFalling);
    final minFalling = compact
        ? (boostFalling ? fallingMinHeightCompactFx : fallingMinHeightCompact)
        : (boostFalling ? fallingMinHeightComfortFx : fallingMinHeightComfort);
    final fallFlex = boostFalling ? fallingNotesFlexFx : fallingNotesFlex;
    final stFlex = boostFalling ? staffFlexFx : staffFlex;
    final totalFlex = fallFlex + stFlex;
    var staffH = usable * stFlex / totalFlex;

    // Prefer a readable staff floor when there is room.
    if (usable >= minStaff + minFalling) {
      final upper = (usable - minFalling).clamp(minStaff, maxStaff);
      staffH = staffH.clamp(minStaff, upper);
    } else {
      // Cramped window: still keep most height for the grand staff so the bass
      // staff is not almost entirely clipped ("一边遮挡完了").
      // With FX boost, still protect staff but leave more for falling.
      final staffShare = boostFalling ? 0.52 : 0.62;
      final staffFloor =
          (usable * staffShare).clamp(minFalling * 0.5, usable - minFalling);
      staffH = staffH.clamp(staffFloor, usable - minFalling * 0.5);
    }
    return (falling: usable - staffH, staff: staffH);
  }

  /// Falling notes vertical scale (fallback when lane height unknown).
  static const pixelsPerBeat = 80.0;

  /// How many beats of waterfall should fit above the hit line.
  static const fallingLookAheadBeats = 3.25;

  static const pixelsPerBeatMin = 52.0;
  static const pixelsPerBeatMax = 110.0;

  /// Scale px/beat so compact/short lanes still show approach distance.
  static double pixelsPerBeatForHeight(double fallingHeight) {
    final usable =
        (fallingHeight - fallingHitLineInset).clamp(1.0, double.infinity);
    final ppb = usable / fallingLookAheadBeats;
    return ppb.clamp(pixelsPerBeatMin, pixelsPerBeatMax);
  }

  /// Standard 88-key layout: A0..C8 (MIDI 21–108).
  static const startMidi = 21;
  static const whiteKeyCount = 52;
  static const midiMin = 21;
  static const midiMax = 108;

  /// Verovio engraver scale (percent). Outer SVG viewBox units map 1:1 to CSS
  /// px in the viewer — do not stretch-to-lane. Tuned so a piano grand staff
  /// is the cropped system height (viewer reports it). The lane hugs that
  /// line — see [stageColumn] — and does not keep a tall empty page.
  static const verovioScale = 60;

  /// Pre-roll before the first note when starting/seeking near beat 0.
  /// Transport runs at negative [positionBeats] for this many quarter-notes
  /// (~1 beat ≈ 0.5–1s depending on BPM) so guide/autoplay do not fire immediately.
  static const playbackLeadInBeats = 1.0;

  /// Seek/play counts as "at start" (apply lead-in) at or below this beat.
  static const playbackLeadInSeekEps = 0.05;

  /// Parked transport position while idle at the piece start (negative pre-roll
  /// when the first note is at beat 0). Prefer
  /// [PracticeLoopLogic.startParkBeats] with the score's first onset.
  static double get playbackStartParkBeats =>
      -playbackLeadInBeats;

  // —— Wait-mode (跟弹) timing — Flowkey-style ————————————————

  /// Accept correct pitches this many beats *before* the onset while notes
  /// are still falling toward the hit line (early hit window).
  static const waitEarlyHitBeats = 0.45;

  /// Freeze playhead when within this many beats of the chord onset.
  static const waitFreezeSlackBeats = 0.02;

  /// Notes whose onsets are within this window count as one chord.
  static const waitChordClusterBeats = 0.02;

  /// After a correct chord: nudge past the onset by this amount so transport
  /// free-advances through gaps (do **not** teleport to the next note start).
  static const waitAdvanceEpsilonBeats = 0.04;

  // —— Hit grading (跟弹 / 考试判定) ——————————————————————————

  /// `|pos - onset| ≤ this` → Perfect; else within [waitEarlyHitBeats] → Good.
  static const judgePerfectBeats = 0.08;

  // —— Lightweight visual FX ————————————————————————————————

  /// Hold last chord briefly is replaced by animated rewind to start.
  static const endRewindMs = 750;

  /// Hands-dialogue arc: both hands graded within this window.
  static const handsDialogueMs = 220;
}
