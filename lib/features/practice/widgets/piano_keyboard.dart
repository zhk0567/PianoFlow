import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';

/// Display-only 88-key piano (A0–C8). No tap-to-play (avoids speaker→mic echo).
///
/// Highlights are colored by hand ([AppColors.leftHand] / [AppColors.rightHand]),
/// not by black vs white key type.
class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({
    super.key,
    required this.geometry,
    required this.highlighted,
    required this.pressed,
    this.visualFxEnabled = false,
  });

  final KeyboardGeometry geometry;

  /// MIDI → hand for active/waiting highlights. Presence means highlighted.
  final Map<int, Hand> highlighted;
  final Set<int> pressed;
  final bool visualFxEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < geometry.whiteMidis.length; i++)
                  _WhiteKey(
                    midi: geometry.whiteMidis[i],
                    width: geometry.whiteKeyWidth(i),
                    height: h,
                    hand: highlighted[geometry.whiteMidis[i]],
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
  final base = hand == Hand.left ? AppColors.leftHand : AppColors.rightHand;
  if (onBlack) {
    return Color.lerp(base, Colors.white, 0.12)!;
  }
  return base.withValues(alpha: 0.82);
}

class _WhiteKey extends StatelessWidget {
  const _WhiteKey({
    required this.midi,
    required this.width,
    required this.height,
    required this.hand,
    required this.pressed,
    this.visualFx = false,
  });

  final int midi;
  final double width;
  final double height;
  final Hand? hand;
  final bool pressed;
  final bool visualFx;

  @override
  Widget build(BuildContext context) {
    Color fill = AppColors.pianoWhite;
    if (pressed) {
      fill = AppColors.accent;
    } else if (hand != null) {
      fill = _handHighlight(hand!, onBlack: false);
    }

    final lit = pressed || hand != null;
    final fontSize = (width * 0.55).clamp(6.0, 11.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: AppColors.border, width: 0.8),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
        boxShadow: null, // FX glow removed — blur shadows stall Windows raster
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
                color: Colors.white.withValues(alpha: 0.92),
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
    required this.pressed,
    this.visualFx = false,
  });

  final int midi;
  final double width;
  final Hand? hand;
  final bool pressed;
  final bool visualFx;

  @override
  Widget build(BuildContext context) {
    Color fill = AppColors.pianoBlack;
    if (pressed) {
      fill = AppColors.accent;
    } else if (hand != null) {
      fill = _handHighlight(hand!, onBlack: true);
    }

    final lit = pressed || hand != null;
    final fontSize = (width * 0.32).clamp(5.5, 9.0);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
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
                color: Colors.white.withValues(alpha: 0.95),
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
