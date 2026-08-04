import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';
import '../practice_constants.dart';

class FallingNotesLane extends StatelessWidget {
  const FallingNotesLane({
    super.key,
    required this.geometry,
    required this.notes,
    required this.positionBeats,
    required this.pixelsPerBeat,
    required this.waitingFor,
    required this.loopEnabled,
    required this.loopStart,
    required this.loopEnd,
  });

  final KeyboardGeometry geometry;
  final List<ScoreNote> notes;
  final double positionBeats;
  final double pixelsPerBeat;
  final Set<int> waitingFor;
  final bool loopEnabled;
  final double loopStart;
  final double loopEnd;

  @override
  Widget build(BuildContext context) {
    // Round only the top — bottom meets the keyboard hit line flush (Flowkey).
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.md),
      ),
      child: ColoredBox(
        color: AppColors.surface,
        child: CustomPaint(
          painter: _FallingNotesPainter(
            geometry: geometry,
            notes: notes,
            positionBeats: positionBeats,
            pixelsPerBeat: pixelsPerBeat,
            waitingFor: waitingFor,
            loopEnabled: loopEnabled,
            loopStart: loopStart,
            loopEnd: loopEnd,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _FallingNotesPainter extends CustomPainter {
  _FallingNotesPainter({
    required this.geometry,
    required this.notes,
    required this.positionBeats,
    required this.pixelsPerBeat,
    required this.waitingFor,
    required this.loopEnabled,
    required this.loopStart,
    required this.loopEnd,
  });

  final KeyboardGeometry geometry;
  final List<ScoreNote> notes;
  final double positionBeats;
  final double pixelsPerBeat;
  final Set<int> waitingFor;
  final bool loopEnabled;
  final double loopStart;
  final double loopEnd;

  @override
  void paint(Canvas canvas, Size size) {
    // Hit line at the lane bottom so onsets meet the keyboard top edge.
    final hitY = size.height - PracticeConstants.fallingHitLineInset;

    // Soft vertical key guides — align with white-key seams on the piano.
    final guidePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var i = 1; i < geometry.whiteKeyCount; i++) {
      final x = geometry.whiteKeyLeft(i);
      canvas.drawLine(Offset(x, 0), Offset(x, hitY), guidePaint);
    }

    if (loopEnabled) {
      final top = hitY - (loopEnd - positionBeats) * pixelsPerBeat;
      final bottom = hitY - (loopStart - positionBeats) * pixelsPerBeat;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            0,
            top.clamp(-size.height, size.height * 2),
            size.width,
            bottom.clamp(-size.height, size.height * 2),
          ),
          const Radius.circular(8),
        ),
        Paint()..color = AppColors.accent.withValues(alpha: 0.07),
      );
    }

    for (final n in notes) {
      final cx = geometry.midiToCenterX(n.midi);
      if (cx == null) continue;

      final barH = (n.duration * pixelsPerBeat).clamp(14.0, size.height * 2);
      // Onset (note start) sits on the hit line when positionBeats == n.start.
      final bottom = hitY - (n.start - positionBeats) * pixelsPerBeat;
      final top = bottom - barH;
      if (bottom < -8 || top > size.height + 8) continue;

      final barW = geometry.noteBarWidth(n.midi);
      final rect = Rect.fromCenter(
        center: Offset(cx, (top + bottom) / 2),
        width: barW,
        height: barH,
      );
      final radius = Radius.circular((barW * 0.45).clamp(3.0, 14.0));
      final rrect = RRect.fromRectAndRadius(rect, radius);

      final waiting = waitingFor.contains(n.midi) &&
          (n.start - positionBeats) <= PracticeConstants.waitEarlyHitBeats &&
          (n.start - positionBeats) >= -0.12;
      final base = n.hand == Hand.left ? AppColors.leftHand : AppColors.rightHand;
      final c0 = waiting ? AppColors.accent : base;
      final c1 = Color.lerp(c0, Colors.white, 0.22)!;

      // Soft shadow
      canvas.drawRRect(
        rrect.shift(const Offset(0, 2)),
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );

      // Gradient body
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c1, c0],
        ).createShader(rect);
      canvas.drawRRect(rrect, fill);

      // Top sheen
      final sheenH = (barH * 0.22).clamp(4.0, 16.0);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(rect.left + 1.5, rect.top + 1.5, rect.width - 3, sheenH),
          topLeft: radius,
          topRight: radius,
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );

      // Outline
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: waiting ? 0.85 : 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = waiting ? 1.8 : 1.0,
      );
    }

    // Hit line with soft glow — flush with keyboard.
    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.35)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _FallingNotesPainter oldDelegate) {
    return oldDelegate.positionBeats != positionBeats ||
        oldDelegate.notes != notes ||
        oldDelegate.waitingFor != waitingFor ||
        oldDelegate.geometry != geometry ||
        oldDelegate.pixelsPerBeat != pixelsPerBeat ||
        oldDelegate.loopEnabled != loopEnabled ||
        oldDelegate.loopStart != loopStart ||
        oldDelegate.loopEnd != loopEnd;
  }
}
