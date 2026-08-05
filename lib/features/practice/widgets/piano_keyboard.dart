import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';

/// 88-key piano (A0–C8). Practice page is display-only; pass [onKeyTap] for sandbox.
///
/// Highlights are colored by hand ([AppColors.leftHand] / [AppColors.rightHand]),
/// not by black vs white key type.
class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({
    super.key,
    required this.geometry,
    required this.highlighted,
    required this.pressed,
    this.onKeyTap,
  });

  final KeyboardGeometry geometry;

  /// MIDI → hand for active/waiting highlights. Presence means highlighted.
  final Map<int, Hand> highlighted;
  final Set<int> pressed;

  /// When set, keys are tappable (sandbox try-out). Practice leaves this null.
  final ValueChanged<int>? onKeyTap;

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
                    onTap: onKeyTap,
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
                  onTap: onKeyTap,
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
  // Same LH/RH hue on both key types; slight shade tweak for black-key visibility.
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
    this.onTap,
  });

  final int midi;
  final double width;
  final double height;
  final Hand? hand;
  final bool pressed;
  final ValueChanged<int>? onTap;

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

    final child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: AppColors.border, width: 0.8),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
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

    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap!(midi),
      child: child,
    );
  }
}

class _BlackKey extends StatelessWidget {
  const _BlackKey({
    required this.midi,
    required this.width,
    required this.hand,
    required this.pressed,
    this.onTap,
  });

  final int midi;
  final double width;
  final Hand? hand;
  final bool pressed;
  final ValueChanged<int>? onTap;

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

    final child = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
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
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: -0.4,
              ),
            )
          : null,
    );

    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap!(midi),
      child: child,
    );
  }
}
