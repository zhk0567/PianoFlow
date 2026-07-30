import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
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
    final hitY = size.height - 3.0;

    // Soft vertical key guides
    final guidePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var i = 1; i < geometry.whiteKeyCount; i++) {
      final x = geometry.whiteKeyLeft(i);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guidePaint);
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
      final bottom = hitY - (n.start - positionBeats) * pixelsPerBeat;
      final top = bottom - barH;
      if (bottom < -8 || top > size.height + 8) continue;

      final barW = geometry.noteBarWidth(n.midi) * 0.92;
      final rect = Rect.fromCenter(
        center: Offset(cx, (top + bottom) / 2),
        width: barW,
        height: barH,
      );
      final radius = Radius.circular((barW * 0.45).clamp(3.0, 14.0));
      final rrect = RRect.fromRectAndRadius(rect, radius);

      final waiting =
          waitingFor.contains(n.midi) && (n.start - positionBeats).abs() < 0.08;
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

    // Hit line with soft glow
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
