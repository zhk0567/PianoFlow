import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';
import '../note_window_index.dart';
import '../practice_constants.dart';
import '../practice_models.dart';

/// Falling-note lane with optional lightweight SeeMusic-style gem bars + bursts.
class FallingNotesLane extends StatefulWidget {
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
    this.visualFxEnabled = true,
    this.feedbackNonce = 0,
    this.lastGrade,
    this.burstMidi,
    this.pressedMidi = const {},
    this.ghostHits = const [],
    this.showGhost = false,
    this.leadInRitual = false,
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

  /// Wait-mode hit flash — spawn burst when nonce advances (non-miss).
  final int feedbackNonce;
  final HitGrade? lastGrade;
  final int? burstMidi;

  /// Mic pressed keys → pitch trail at hit line.
  final Set<int> pressedMidi;

  /// Residual shadow (exam ghost).
  final List<GhostHit> ghostHits;
  final bool showGhost;

  /// Opening one-beat ritual glow on hit line.
  final bool leadInRitual;

  @override
  State<FallingNotesLane> createState() => _FallingNotesLaneState();
}

class _BurstParticle {
  _BurstParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.born,
    required this.color,
    required this.size,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final Duration born;
  final Color color;
  final double size;
}

class _FallingNotesLaneState extends State<FallingNotesLane>
    with SingleTickerProviderStateMixin {
  final List<_BurstParticle> _particles = [];
  double _lastPos = double.nan;
  int _lastFeedbackNonce = 0;
  Ticker? _ticker;
  Duration _now = Duration.zero;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _lastPos = widget.positionBeats;
    _lastFeedbackNonce = widget.feedbackNonce;
    _ticker = createTicker((elapsed) {
      _now = elapsed;
      _pruneParticles();
      if (_particles.isNotEmpty && mounted) {
        setState(() {});
      } else {
        _ticker?.stop();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FallingNotesLane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visualFxEnabled) {
      if (_particles.isNotEmpty) {
        _particles.clear();
      }
      _lastPos = widget.positionBeats;
      _lastFeedbackNonce = widget.feedbackNonce;
      return;
    }

    _detectOnsetCrossings();

    if (widget.feedbackNonce != _lastFeedbackNonce) {
      _lastFeedbackNonce = widget.feedbackNonce;
      final grade = widget.lastGrade;
      if (grade != null && grade.showsFeedback) {
        final midi = widget.burstMidi;
        if (midi != null) {
          _spawnBurstAtMidi(midi, gradeColor(grade));
        }
      }
    }
  }

  Color gradeColor(HitGrade g) => switch (g) {
        HitGrade.perfect => AppColors.success,
        HitGrade.good => AppColors.accent,
        HitGrade.miss => AppColors.accent,
      };

  void _detectOnsetCrossings() {
    final oldPos = _lastPos;
    final newPos = widget.positionBeats;
    if (oldPos.isNaN) {
      _lastPos = newPos;
      return;
    }
    // Seek / rewind: don't spray bursts.
    if (newPos + 0.05 < oldPos || newPos - oldPos > 1.5) {
      _lastPos = newPos;
      return;
    }
    if (newPos <= oldPos) {
      _lastPos = newPos;
      return;
    }

    final from = oldPos;
    final to = newPos;
    // Only scan notes near the playhead window.
    final candidates = NoteWindowIndex.visibleAround(
      notes: widget.notes,
      pos: to,
      lookBehind: 0.5,
      lookAhead: 0.5,
    );
    for (final n in candidates) {
      if (n.start > from && n.start <= to) {
        final base =
            n.hand == Hand.left ? AppColors.leftHand : AppColors.rightHand;
        _spawnBurstAtMidi(n.midi, base);
      }
    }
    _lastPos = newPos;
  }

  void _spawnBurstAtMidi(int midi, Color color) {
    final cx = widget.geometry.midiToCenterX(midi);
    if (cx == null) return;
    // Hit line Y is applied in paint via size; store relative — use 0 and
    // painter maps. Store x only; y set in paint from hitY.
    _spawnBurst(cx, color);
  }

  void _spawnBurst(double x, Color color) {
    final room =
        PracticeConstants.visualFxMaxParticles - _particles.length;
    if (room <= 0) {
      _particles.removeRange(0, math.min(8, _particles.length));
    }
    final count = math.min(
      PracticeConstants.visualFxBurstCount,
      PracticeConstants.visualFxMaxParticles - _particles.length,
    );
    final born = _now;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 1.4;
      final speed = 40 + _rng.nextDouble() * 90;
      _particles.add(
        _BurstParticle(
          x: x + (_rng.nextDouble() - 0.5) * 6,
          y: 0, // relative to hit line in paint
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          born: born,
          color: color,
          size: 1.5 + _rng.nextDouble() * 2.2,
        ),
      );
    }
    if (!(_ticker?.isActive ?? false)) {
      _ticker?.start();
    }
    if (mounted) setState(() {});
  }

  void _pruneParticles() {
    final life = PracticeConstants.visualFxParticleMs;
    _particles.removeWhere(
      (p) => (_now - p.born).inMilliseconds > life,
    );
  }

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
            geometry: widget.geometry,
            notes: widget.notes,
            positionBeats: widget.positionBeats,
            pixelsPerBeat: widget.pixelsPerBeat,
            waitingFor: widget.waitingFor,
            loopEnabled: widget.loopEnabled,
            loopStart: widget.loopStart,
            loopEnd: widget.loopEnd,
            visualFxEnabled: widget.visualFxEnabled,
            particles: List<_BurstParticle>.from(_particles),
            particleNow: _now,
            pressedMidi: widget.pressedMidi,
            ghostHits: widget.showGhost ? widget.ghostHits : const [],
            leadInRitual: widget.leadInRitual,
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
    required this.particles,
    required this.particleNow,
    required this.pressedMidi,
    required this.ghostHits,
    required this.leadInRitual,
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
  final List<_BurstParticle> particles;
  final Duration particleNow;
  final Set<int> pressedMidi;
  final List<GhostHit> ghostHits;
  final bool leadInRitual;

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

    if (leadInRitual && visualFxEnabled) {
      final breath = 0.12 + 0.10 * (0.5 + 0.5 * math.sin(positionBeats * 6));
      canvas.drawRect(
        Rect.fromLTWH(0, hitY - 10, size.width, 20),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.accent.withValues(alpha: 0),
              AppColors.accent.withValues(alpha: breath),
              AppColors.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, hitY - 10, size.width, 20)),
      );
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

    final lookAhead = (hitY / pixelsPerBeat) + 1.0;
    final lookBehind = ((size.height - hitY) / pixelsPerBeat) + 4.0;
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
      final c0 = waiting ? AppColors.accent : base;
      final c1 = Color.lerp(c0, Colors.white, visualFxEnabled ? 0.32 : 0.22)!;
      final c2 = Color.lerp(c0, Colors.black, visualFxEnabled ? 0.12 : 0.0)!;

      // Soft drop shadow
      canvas.drawRRect(
        rrect.shift(const Offset(0, 2)),
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );

      // Short trail under the bar (gem motion cue).
      if (visualFxEnabled) {
        final trailH = (barH * 0.12).clamp(4.0, 10.0);
        final trailRect = Rect.fromLTWH(
          rect.left + 2,
          rect.bottom,
          rect.width - 4,
          trailH,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(trailRect, const Radius.circular(3)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c0.withValues(alpha: 0.35),
                c0.withValues(alpha: 0.0),
              ],
            ).createShader(trailRect),
        );
      }

      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: visualFxEnabled ? [c1, c0, c2] : [c1, c0],
          stops: visualFxEnabled ? const [0.0, 0.55, 1.0] : const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rrect, fill);

      // Top gem sheen
      final sheenH = (barH * (visualFxEnabled ? 0.28 : 0.22)).clamp(4.0, 18.0);
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
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: visualFxEnabled ? 0.28 : 0.18),
      );

      // Edge highlight (gem rim)
      if (visualFxEnabled) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = Color.lerp(c0, Colors.white, 0.55)!
                .withValues(alpha: waiting ? 0.95 : 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = waiting ? 2.0 : 1.15,
        );
      } else {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = Colors.white.withValues(alpha: waiting ? 0.85 : 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = waiting ? 1.8 : 1.0,
        );
      }
    }

    // Residual shadow (只狼残影) — translucent bars at prior exam hits.
    if (visualFxEnabled && ghostHits.isNotEmpty) {
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
          Paint()..color = ghostColor.withValues(alpha: 0.18),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          Paint()
            ..color = ghostColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    // Pitch trail — mic pressed keys glow at the hit line.
    if (visualFxEnabled && pressedMidi.isNotEmpty) {
      for (final midi in pressedMidi) {
        final cx = geometry.midiToCenterX(midi);
        if (cx == null) continue;
        final matched = waitingFor.contains(midi);
        final c = matched ? AppColors.success : AppColors.accent;
        canvas.drawCircle(
          Offset(cx, hitY),
          matched ? 14 : 10,
          Paint()
            ..color = c.withValues(alpha: matched ? 0.35 : 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(
          Offset(cx, hitY),
          matched ? 4.5 : 3.2,
          Paint()..color = c.withValues(alpha: matched ? 0.9 : 0.55),
        );
      }
    }

    // Hit line bloom when particles active
    final bloom = visualFxEnabled && particles.isNotEmpty;
    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = AppColors.accent.withValues(alpha: bloom ? 0.55 : 0.35)
        ..strokeWidth = bloom ? 8 : 5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bloom ? 7 : 4),
    );
    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2,
    );

    if (visualFxEnabled && particles.isNotEmpty) {
      _paintParticles(canvas, hitY);
    }
  }

  void _paintParticles(Canvas canvas, double hitY) {
    final lifeMs = PracticeConstants.visualFxParticleMs.toDouble();
    for (final p in particles) {
      final age = (particleNow - p.born).inMilliseconds / lifeMs;
      if (age < 0 || age > 1) continue;
      final t = age;
      final opacity = (1.0 - t) * (1.0 - t);
      final px = p.x + p.vx * t * (lifeMs / 1000.0);
      final py = hitY + p.y + p.vy * t * (lifeMs / 1000.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(Offset(px, py), p.size * (1.0 + t * 0.4), paint);
      // Tiny streak
      canvas.drawLine(
        Offset(px, py),
        Offset(px - p.vx * 0.02, py - p.vy * 0.02),
        Paint()
          ..color = p.color.withValues(alpha: opacity * 0.7)
          ..strokeWidth = 1.2
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
        oldDelegate.loopEnabled != loopEnabled ||
        oldDelegate.loopStart != loopStart ||
        oldDelegate.loopEnd != loopEnd ||
        oldDelegate.visualFxEnabled != visualFxEnabled ||
        oldDelegate.particleNow != particleNow ||
        oldDelegate.particles.length != particles.length ||
        oldDelegate.pressedMidi != pressedMidi ||
        oldDelegate.ghostHits != ghostHits ||
        oldDelegate.leadInRitual != leadInRitual;
  }
}
