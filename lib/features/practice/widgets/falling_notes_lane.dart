import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';
import '../note_window_index.dart';
import '../practice_constants.dart';
import '../practice_models.dart';

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
    this.visualFxEnabled = false,
    this.ghostHits = const [],
    this.showGhost = false,
  });

  final KeyboardGeometry geometry;
  final List<ScoreNote> notes;
  final double positionBeats;
  final double pixelsPerBeat;
  final Set<int> waitingFor;
  final bool loopEnabled;
  final double loopStart;
  final double loopEnd;
  final bool visualFxEnabled;
  final List<GhostHit> ghostHits;
  final bool showGhost;

  @override
  Widget build(BuildContext context) {
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
            visualFxEnabled: visualFxEnabled,
            ghostHits: (showGhost && visualFxEnabled) ? ghostHits : const [],
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
    required this.visualFxEnabled,
    required this.ghostHits,
  });

  final KeyboardGeometry geometry;
  final List<ScoreNote> notes;
  final double positionBeats;
  final double pixelsPerBeat;
  final Set<int> waitingFor;
  final bool loopEnabled;
  final double loopStart;
  final double loopEnd;
  final bool visualFxEnabled;
  final List<GhostHit> ghostHits;

  @override
  void paint(Canvas canvas, Size size) {
    final hitY = size.height - PracticeConstants.fallingHitLineInset;

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

    final lookAhead = (hitY / pixelsPerBeat) + 2.0;
    final lookBehind = (size.height / pixelsPerBeat) + 4.0;
    final visible = NoteWindowIndex.visibleAround(
      notes: notes,
      pos: positionBeats,
      lookBehind: lookBehind,
      lookAhead: lookAhead,
    );

    for (final n in visible) {
      final cx = geometry.midiToCenterX(n.midi);
      if (cx == null) continue;

      final barH = (n.duration * pixelsPerBeat).clamp(14.0, size.height * 2);
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
      final base =
          n.hand == Hand.left ? AppColors.leftHand : AppColors.rightHand;
      final fillColor = waiting ? AppColors.accent : base;

      canvas.drawRRect(rrect, Paint()..color = fillColor);

      if (visualFxEnabled) {
        final sheenH = (barH * 0.14).clamp(2.0, 8.0);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              rect.left + 1.5,
              rect.top + 1.5,
              rect.width - 3,
              sheenH,
            ),
            topLeft: radius,
            topRight: radius,
            bottomLeft: const Radius.circular(3),
            bottomRight: const Radius.circular(3),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.08),
        );
      }

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: waiting ? 0.85 : 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = waiting ? 1.8 : 1.0,
      );
    }

    if (ghostHits.isNotEmpty) {
      for (final g in ghostHits) {
        final cx = geometry.midiToCenterX(g.midi);
        if (cx == null) continue;
        final bottom = hitY - (g.beat - positionBeats) * pixelsPerBeat;
        if (bottom < -20 || bottom > size.height + 20) continue;
        final barW = geometry.noteBarWidth(g.midi);
        final rect = Rect.fromCenter(
          center: Offset(cx, bottom - 10),
          width: barW * 0.85,
          height: 20,
        );
        final ghostColor = g.grade == HitGrade.perfect
            ? AppColors.success
            : AppColors.accent;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          Paint()..color = ghostColor.withValues(alpha: 0.16),
        );
      }
    }

    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.85)
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
        oldDelegate.loopEnd != loopEnd ||
        oldDelegate.visualFxEnabled != visualFxEnabled ||
        oldDelegate.ghostHits != ghostHits;
  }
}
