import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';
import '../note_window_index.dart';
import '../practice_constants.dart';
import '../practice_models.dart';
import '../practice_stage_theme.dart';

class FallingNotesLane extends StatelessWidget {
  const FallingNotesLane({
    super.key,
    required this.geometry,
    required this.notes,
    required this.positionBeats,
    required this.pixelsPerBeat,
    required this.waitingFor,
    this.visualFxEnabled = false,
    this.ghostHits = const [],
    this.showGhost = false,
  });

  final KeyboardGeometry geometry;
  final List<ScoreNote> notes;
  final double positionBeats;
  final double pixelsPerBeat;
  final Set<int> waitingFor;
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
        color: visualFxEnabled
            ? PracticeStageTheme.midnight.waterfallMid
            : AppColors.surface,
        child: CustomPaint(
          painter: _FallingNotesPainter(
            geometry: geometry,
            notes: notes,
            positionBeats: positionBeats,
            pixelsPerBeat: pixelsPerBeat,
            waitingFor: waitingFor,
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
    required this.visualFxEnabled,
    required this.ghostHits,
  });

  final KeyboardGeometry geometry;
  final List<ScoreNote> notes;
  final double positionBeats;
  final double pixelsPerBeat;
  final Set<int> waitingFor;
  final bool visualFxEnabled;
  final List<GhostHit> ghostHits;

  @override
  void paint(Canvas canvas, Size size) {
    final hitY = size.height - PracticeConstants.fallingHitLineInset;
    final stage = PracticeStageTheme.of(visualFxEnabled: visualFxEnabled);

    final lookAhead = (hitY / pixelsPerBeat) + 2.0;
    final lookBehind = (size.height / pixelsPerBeat) + 4.0;
    final visible = NoteWindowIndex.visibleAround(
      notes: notes,
      pos: positionBeats,
      lookBehind: lookBehind,
      lookAhead: lookAhead,
    );

    final phase = (positionBeats * 2.2).remainder(1.0).abs();

    if (visualFxEnabled) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              stage.waterfallTop,
              stage.waterfallMid,
              stage.waterfallNear,
              stage.waterfallHitGlow,
            ],
            stops: const [0.0, 0.55, 0.88, 1.0],
          ).createShader(Offset.zero & size),
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              stage.auroraCool.withValues(alpha: 0.14),
              Colors.transparent,
              Colors.transparent,
              stage.auroraCool.withValues(alpha: 0.14),
            ],
            stops: const [0.0, 0.16, 0.84, 1.0],
          ).createShader(Offset.zero & size),
      );
    }

    final guidePaint = Paint()
      ..color = visualFxEnabled
          ? stage.accent.withValues(alpha: 0.10 + 0.04 * phase)
          : AppColors.borderSubtle.withValues(alpha: 0.55)
      ..strokeWidth = visualFxEnabled ? 1.2 : 1;
    for (var i = 1; i < geometry.whiteKeyCount; i++) {
      final x = geometry.whiteKeyLeft(i);
      canvas.drawLine(Offset(x, 0), Offset(x, hitY), guidePaint);
    }

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
      final fillColor = waiting ? stage.accent : base;

      // FX path: solid fill (no top sheen).
      if (visualFxEnabled && waiting) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(2.0),
            Radius.circular((barW * 0.45).clamp(3.0, 12.0)),
          ),
          Paint()..color = fillColor.withValues(alpha: 0.22 + 0.08 * phase),
        );
      }

      canvas.drawRRect(rrect, Paint()..color = fillColor);

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(
            alpha: waiting
                ? (visualFxEnabled ? 0.72 : 0.85)
                : (visualFxEnabled ? 0.28 : 0.18),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = waiting
              ? (visualFxEnabled ? 1.35 : 1.8)
              : (visualFxEnabled ? 0.9 : 1.0),
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
            : stage.accent;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          Paint()..color = ghostColor.withValues(alpha: 0.22),
        );
      }
    }

    if (!visualFxEnabled) {
      canvas.drawLine(
        Offset(0, hitY),
        Offset(size.width, hitY),
        Paint()
          ..color = stage.accent.withValues(alpha: 0.025)
          ..strokeWidth = 36
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(0, hitY),
        Offset(size.width, hitY),
        Paint()
          ..color = stage.accent.withValues(alpha: 0.05)
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FallingNotesPainter oldDelegate) {
    return oldDelegate.positionBeats != positionBeats ||
        oldDelegate.notes != notes ||
        oldDelegate.waitingFor != waitingFor ||
        oldDelegate.geometry != geometry ||
        oldDelegate.pixelsPerBeat != pixelsPerBeat ||
        oldDelegate.visualFxEnabled != visualFxEnabled ||
        oldDelegate.ghostHits != ghostHits;
  }
}
