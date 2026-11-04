import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';
import '../practice_stage_theme.dart';

/// Display-only 88-key piano (A0–C8). No tap-to-play (avoids speaker→mic echo).
///
/// FX off: waiting keys use [AppColors.keyWait]. FX on: waiting stays the hand
/// hue ([PracticeStageTheme.waitingFillForHand]) and lit keys get a hand-colored
/// edge — no blur shadow.
class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({
    super.key,
    required this.geometry,
    required this.highlighted,
    required this.pressed,
    this.waitingFor = const {},
    this.visualFxEnabled = false,
  });

  final KeyboardGeometry geometry;

  /// MIDI → hand for active/waiting highlights. Presence means highlighted.
  final Map<int, Hand> highlighted;
  final Set<int> pressed;

  /// Wait-mode targets. FX off uses amber; FX on uses the hand hue.
  final Set<int> waitingFor;
  final bool visualFxEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                for (var i = 0; i < geometry.whiteMidis.length; i++)
                  _WhiteKey(
                    midi: geometry.whiteMidis[i],
                    width: geometry.whiteKeyWidth(i),
                    height: h,
                    hand: highlighted[geometry.whiteMidis[i]],
                    waiting: waitingFor.contains(geometry.whiteMidis[i]),
                    pressed: pressed.contains(geometry.whiteMidis[i]),
                    visualFx: visualFxEnabled,
                  ),
              ],
            ),
            ...geometry.blackMidis.map((m) {
              final left = geometry.blackKeyLeft(m);
              if (left == null) return const SizedBox.shrink();
              return Positioned(
                left: left,
                top: 0,
                width: geometry.blackWidth,
                height: h * 0.62,
                child: _BlackKey(
                  midi: m,
                  width: geometry.blackWidth,
                  hand: highlighted[m],
                  waiting: waitingFor.contains(m),
                  pressed: pressed.contains(m),
                  visualFx: visualFxEnabled,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

Color _handHighlight(Hand hand, {required bool onBlack}) {
  final base = PracticeStageTheme.colorForHand(hand);
  if (onBlack) {
    return Color.lerp(base, Colors.white, 0.12)!;
  }
  return base.withValues(alpha: 0.82);
}

Color _waitingFill({required bool onBlack}) {
  if (onBlack) {
    return Color.lerp(AppColors.keyWait, Colors.white, 0.22)!;
  }
  return AppColors.keyWait;
}

Color _keyLabel(Color fill) =>
    fill.computeLuminance() < 0.18 ? AppColors.onAccent : AppColors.textPrimary;

class _WhiteKey extends StatelessWidget {
  const _WhiteKey({
    required this.midi,
    required this.width,
    required this.height,
    required this.hand,
    required this.waiting,
    required this.pressed,
    this.visualFx = false,
  });

  final int midi;
  final double width;
  final double height;
  final Hand? hand;
  final bool waiting;
  final bool pressed;
  final bool visualFx;

  @override
  Widget build(BuildContext context) {
    Color fill = AppColors.pianoWhite;
    // Waiting target wins over stray mic pressed (avoids lighting C when
    // waiting for C# — pressed still shows if this key is the target).
    if (waiting) {
      fill = visualFx
          ? PracticeStageTheme.waitingFillForHand(hand ?? Hand.right)
          : _waitingFill(onBlack: false);
    } else if (pressed || hand != null) {
      fill = hand != null
          ? _handHighlight(hand!, onBlack: false)
          : AppColors.keyWait;
    }

    final lit = pressed || waiting || hand != null;
    final fontSize = (width * 0.55).clamp(6.0, 11.0);
    final identity = hand == null
        ? null
        : PracticeStageTheme.colorForHand(hand!);
    final fxEdge = visualFx && lit && identity != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(
          color: fxEdge ? identity : const Color(0xFFC4B5A4),
          width: fxEdge ? 1.5 : 0.8,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
        boxShadow:
            null, // FX edge is a border; blur shadows stall Windows raster
      ),
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: height * 0.06),
      child: lit
          ? Text(
              KeyboardGeometry.midiWhiteKeyLabel(midi),
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _keyLabel(fill),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: -0.2,
              ),
            )
          : null,
    );
  }
}

class _BlackKey extends StatelessWidget {
  const _BlackKey({
    required this.midi,
    required this.width,
    required this.hand,
    required this.waiting,
    required this.pressed,
    this.visualFx = false,
  });

  final int midi;
  final double width;
  final Hand? hand;
  final bool waiting;
  final bool pressed;
  final bool visualFx;

  @override
  Widget build(BuildContext context) {
    Color fill = AppColors.pianoBlack;
    if (waiting) {
      fill = visualFx
          ? PracticeStageTheme.waitingFillForHand(hand ?? Hand.right)
          : _waitingFill(onBlack: true);
    } else if (pressed || hand != null) {
      fill = hand != null
          ? _handHighlight(hand!, onBlack: true)
          : AppColors.keyWait;
    }

    final lit = pressed || waiting || hand != null;
    final fontSize = (width * 0.32).clamp(5.5, 9.0);
    final identity = hand == null
        ? null
        : PracticeStageTheme.colorForHand(hand!);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        border: waiting
            ? Border.all(
                color: visualFx && identity != null
                    ? identity
                    : Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              )
            : (visualFx && lit && identity != null)
            ? Border.all(color: identity, width: 1.2)
            : null,
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 4),
      child: lit
          ? Text(
              KeyboardGeometry.midiPitchLabel(midi),
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _keyLabel(fill),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: -0.4,
              ),
            )
          : null,
    );
  }
}
