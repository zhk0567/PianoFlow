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
  static const speedMaxUi = 1.2;
  static const speedMaxAudio = 1.5;

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
  /// Kept under ~2s so polyphony / echo-suppress stay manageable, but long
  /// enough that chords retain piano body instead of a dry 0.5s pluck.
  static const noteMaxSeconds = 1.65;

  /// Fade-out window at the end of the shaped one-shot.
  static const noteFadeSeconds = 0.28;

  /// Extra exponential decay so the tail dies before [noteMaxSeconds].
  static const noteDecayTau = 0.58;

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
  /// Staff gets the larger share so grand-staff notation stays Flowkey-readable;
  /// waterfall keeps a floor via [fallingMinHeight*] so notes still approach.
  static const fallingNotesFlex = 2;
  static const staffFlex = 5;

  /// Minimum staff lane height (px). Must fit Verovio grand staff at [verovioScale]
  /// (~316–340 CSS px); shorter lanes + vertical centering clipped the clef
  /// under the keyboard (looked like occlusion).
  static const staffMinHeightCompact = 200.0;
  static const staffMinHeightComfort = 340.0;

  /// Soft cap so ultra-tall windows still leave room for the waterfall.
  static const staffMaxHeightCompact = 260.0;
  static const staffMaxHeightComfort = 440.0;

  /// Minimum falling-notes lane height (px) so the waterfall is not crushed.
  static const fallingMinHeightCompact = 80.0;
  static const fallingMinHeightComfort = 110.0;

  /// Gaps between falling / keyboard / staff in the stage column.
  /// Falling↔keyboard is 0 so the hit line meets the key tops (Flowkey).
  static const stageLaneGap = 4.0;
  static const stageFallingKeyboardGap = 0.0;

  /// Hit line sits this many px above the falling-lane bottom (≈ half stroke).
  static const fallingHitLineInset = 1.0;

  /// Split usable stage height (excluding keyboard + gaps) between lanes.
  static ({double falling, double staff}) splitStageLanes({
    required double usableHeight,
    required bool compact,
  }) {
    final usable = usableHeight.clamp(0.0, double.infinity);
    if (usable <= 0) return (falling: 0.0, staff: 0.0);

    final minStaff = compact ? staffMinHeightCompact : staffMinHeightComfort;
    final maxStaff = compact ? staffMaxHeightCompact : staffMaxHeightComfort;
    final minFalling =
        compact ? fallingMinHeightCompact : fallingMinHeightComfort;
    final totalFlex = fallingNotesFlex + staffFlex;
    var staffH = usable * staffFlex / totalFlex;

    // Prefer a readable staff floor when there is room.
    if (usable >= minStaff + minFalling) {
      final upper = (usable - minFalling).clamp(minStaff, maxStaff);
      staffH = staffH.clamp(minStaff, upper);
    } else {
      // Cramped window: still keep most height for the grand staff so the bass
      // staff is not almost entirely clipped ("一边遮挡完了").
      final staffFloor = (usable * 0.62).clamp(minFalling, usable - minFalling);
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
  /// is ~300–340 CSS px tall and fits [staffMinHeightComfort]–[staffMaxHeightComfort]
  /// when top-aligned (taller scores clip at the bottom via the WebView wrap).
  static const verovioScale = 60;

  /// Pre-roll before the first note when starting/seeking near beat 0.
  /// Transport runs at negative [positionBeats] for this many quarter-notes
  /// (~1 beat ≈ 0.5–1s depending on BPM) so guide/autoplay do not fire immediately.
  static const playbackLeadInBeats = 1.0;

  /// Seek/play counts as "at start" (apply lead-in) at or below this beat.
  static const playbackLeadInSeekEps = 0.05;

  /// Parked transport position while idle at the piece start (negative pre-roll).
  /// Idle and play share this so pressing play does not snap 0 → −lead.
  static double get playbackStartParkBeats {
    final lead = playbackLeadInBeats;
    return lead > 0 ? -lead : 0.0;
  }

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

  /// Hold last chord visuals before settlement sheet (末音悬停).
  static const endHangMs = 1400;

  /// Hands-dialogue arc: both hands graded within this window.
  static const handsDialogueMs = 220;

  /// Flowkey-style daily practice goal (minutes).
  static const dailyPracticeGoalMinutes = 20;
}
