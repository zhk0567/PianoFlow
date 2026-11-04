import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../keyboard_geometry.dart';
import '../practice_clock.dart';
import '../practice_fx_budget.dart';
import '../practice_fx_onsets.dart';
import '../practice_models.dart';
import '../practice_stage_theme.dart';

/// Hit bursts + ambient shimmer when「视觉特效」is on.
///
/// Display-only: reads geometry / note onsets / graded hits.
/// No spark particles — rings / pillar / wash only.
///
/// One ring per sounding pitch. Chords keep a ring on each note instead of
/// replacing a single slot. The ticker runs only while rings are alive.
///
/// Performance: [PracticeFxBudget], no [ImageFilter.blur], own
/// [RepaintBoundary], idle when [enabled] is false.
class PracticeVisualFxOverlay extends StatefulWidget {
  const PracticeVisualFxOverlay({
    super.key,
    required this.enabled,
    required this.geometry,
    required this.hits,
    this.hitLineYFraction = 0.92,
    this.notes = const [],
    this.clock,
    this.autoplayVisual = false,
  });

  final bool enabled;
  final KeyboardGeometry geometry;

  /// Graded practice hits. New entries each get a ring (same-frame chords too).
  final List<GhostHit> hits;

  /// 0–1 from top of the falling lane (hit line near bottom).
  final double hitLineYFraction;

  /// Read-only notes for autoplay onset flashes (never mutates score).
  final List<ScoreNote> notes;

  /// Optional transport clock — listened only for autoplay flashes (no 60 Hz rebuild).
  final PracticeClock? clock;

  /// When true, spawn visual-only flashes as notes cross the hit line.
  final bool autoplayVisual;

  @override
  State<PracticeVisualFxOverlay> createState() =>
      _PracticeVisualFxOverlayState();
}

class _LiveRipple {
  _LiveRipple({
    required this.x,
    required this.hand,
    required this.grade,
    required this.bornMs,
  });

  final double x;
  final Hand hand;
  final HitGrade grade;
  final int bornMs;
}

class _PracticeVisualFxOverlayState extends State<PracticeVisualFxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  final Stopwatch _age = Stopwatch();
  final List<_LiveRipple> _ripples = [];
  int _seenHits = 0;
  double? _lastAutoPos;
  final Set<String> _firedOnsets = {};

  @override
  void initState() {
    super.initState();
    _age.start();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: PracticeFxBudget.burstMs),
    )..addListener(_cullRipples);
    _seenHits = widget.hits.length;
    widget.clock?.addListener(_onClock);
  }

  void _onClock() {
    if (!mounted || !widget.enabled || !widget.autoplayVisual) return;
    final clock = widget.clock;
    if (clock == null) return;
    _pollAutoplayOnsets(clock.positionBeats);
  }

  @override
  void didUpdateWidget(covariant PracticeVisualFxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clock != oldWidget.clock) {
      oldWidget.clock?.removeListener(_onClock);
      widget.clock?.addListener(_onClock);
    }
    if (!widget.enabled && oldWidget.enabled) {
      _stopRings();
      _lastAutoPos = null;
      _firedOnsets.clear();
    }
    if (!widget.enabled) {
      _seenHits = widget.hits.length;
      return;
    }
    if (!oldWidget.enabled) {
      _seenHits = widget.hits.length;
      _lastAutoPos = null;
      _firedOnsets.clear();
    }
    _syncPracticeHits();
  }

  void _stopRings() {
    _ripples.clear();
    _burst.stop();
    _burst.value = 0;
  }

  void _cullRipples() {
    final now = _age.elapsedMilliseconds;
    _ripples.removeWhere((r) => now - r.bornMs >= PracticeFxBudget.burstMs);
    if (_ripples.isEmpty && _burst.isAnimating) {
      _burst.stop();
      _burst.value = 0;
    }
  }

  void _syncPracticeHits() {
    final log = widget.hits;
    if (log.length < _seenHits) _seenHits = 0;
    for (var i = _seenHits; i < log.length; i++) {
      final g = log[i];
      if (!g.grade.showsFeedback) continue;
      _spawnRipple(
        midi: g.midi,
        grade: g.grade,
        hand: _handNear(g.midi, g.beat),
      );
    }
    _seenHits = log.length;
  }

  Hand _handNear(int midi, double beat) {
    Hand? best;
    var bestDist = double.infinity;
    for (final n in widget.notes) {
      if (n.midi != midi) continue;
      final d = (n.start - beat).abs();
      if (d < bestDist) {
        bestDist = d;
        best = n.hand;
      }
    }
    return best ?? Hand.right;
  }

  void _pollAutoplayOnsets(double pos) {
    if (widget.notes.isEmpty) return;
    final prev = _lastAutoPos;
    _lastAutoPos = pos;
    // First sample, seek, or a hitch: only notes just under the playhead.
    // 0.08 beats covers one late frame so the downbeat is not skipped.
    // The gap itself is not flashed — autoplay audio does not sound it either.
    if (prev == null || pos + 0.08 < prev || pos - prev > 1.5) {
      _firedOnsets.clear();
      _flashWindow(pos - 0.08, pos);
      return;
    }
    _flashWindow(prev, pos);
  }

  void _flashWindow(double prev, double pos) {
    final crossed = soundingOnsetsCrossing(
      notes: widget.notes,
      prev: prev,
      pos: pos,
    );
    for (final n in crossed) {
      final key = '${n.midi}_${n.start.toStringAsFixed(4)}';
      if (!_firedOnsets.add(key)) continue;
      _spawnRipple(midi: n.midi, grade: HitGrade.perfect, hand: n.hand);
    }
  }

  void _spawnRipple({
    required int midi,
    required HitGrade grade,
    required Hand hand,
  }) {
    final x = widget.geometry.midiToCenterX(midi);
    if (x == null) return;
    _ripples.add(
      _LiveRipple(
        x: x,
        hand: hand,
        grade: grade,
        bornMs: _age.elapsedMilliseconds,
      ),
    );
    while (_ripples.length > PracticeFxBudget.maxLiveRipples) {
      _ripples.removeAt(0);
    }
    if (!_burst.isAnimating) {
      _burst.repeat();
    }
  }

  @override
  void dispose() {
    widget.clock?.removeListener(_onClock);
    _burst.removeListener(_cullRipples);
    _burst.dispose();
    _age.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _burst,
          builder: (context, _) {
            final now = _age.elapsedMilliseconds;
            return CustomPaint(
              painter: _FxPainter(
                nowMs: now,
                ripples: [
                  for (final r in _ripples)
                    _RingPaint(
                      x: r.x,
                      hand: r.hand,
                      perfect: r.grade == HitGrade.perfect,
                      t: ((now - r.bornMs) / PracticeFxBudget.burstMs).clamp(
                        0.0,
                        1.0,
                      ),
                    ),
                ],
                ambientT: PracticeFxBudget.ambientT,
                hitLineYFraction: widget.hitLineYFraction,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _RingPaint {
  const _RingPaint({
    required this.x,
    required this.hand,
    required this.perfect,
    required this.t,
  });

  final double x;
  final Hand hand;
  final bool perfect;
  final double t;
}

class _FxPainter extends CustomPainter {
  _FxPainter({
    required this.nowMs,
    required this.ripples,
    required this.ambientT,
    required this.hitLineYFraction,
  });

  final int nowMs;
  final List<_RingPaint> ripples;
  final double ambientT;
  final double hitLineYFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final hitY = size.height * hitLineYFraction;
    const stage = PracticeStageTheme.decorated;

    final aurora = 0.10 + 0.08 * ambientT;
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, size.height * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            stage.auroraWarm.withValues(alpha: aurora),
            stage.auroraCool.withValues(alpha: aurora * 0.45),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5)),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, hitY - 70, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            stage.auroraWarm.withValues(alpha: 0.14 + 0.08 * ambientT),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(0, hitY - 70, size.width, size.height)),
    );

    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = stage.accent.withValues(alpha: 0.035 + 0.02 * ambientT)
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = stage.accent.withValues(alpha: 0.10)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    for (final ring in ripples) {
      final origin = Offset(ring.x, hitY);
      final burstT = Curves.easeOutCubic.transform(ring.t);
      final life = (1.0 - Curves.easeInQuad.transform(ring.t)).clamp(0.0, 1.0);
      final burstColor = PracticeStageTheme.colorForHand(ring.hand);
      final perfect = ring.perfect;

      final pillarH = size.height * (perfect ? 0.55 : 0.38);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(origin.dx, hitY - pillarH * 0.45),
          width: perfect ? 14 : 10,
          height: pillarH,
        ),
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  burstColor.withValues(alpha: 0.34 * life),
                  burstColor.withValues(alpha: 0.10 * life),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCenter(
                  center: Offset(origin.dx, hitY - pillarH * 0.45),
                  width: 22,
                  height: pillarH,
                ),
              ),
      );

      for (final scale in perfect ? const [1.0, 0.62] : const [1.0]) {
        final ringR = (8 + burstT * (perfect ? 52 : 36)) * scale;
        canvas.drawCircle(
          origin,
          ringR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (perfect ? 2.2 : 1.6) * (1.35 - 0.25 * scale)
            ..color = burstColor.withValues(alpha: 0.62 * life * scale),
        );
      }

      canvas.drawCircle(
        origin,
        14 * life,
        Paint()..color = burstColor.withValues(alpha: 0.22 * life),
      );
      canvas.drawCircle(
        origin,
        5 * life,
        Paint()..color = const Color(0xFFFFF9F0).withValues(alpha: 0.55 * life),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) {
    if (old.nowMs != nowMs ||
        old.ambientT != ambientT ||
        old.hitLineYFraction != hitLineYFraction ||
        old.ripples.length != ripples.length) {
      return true;
    }
    for (var i = 0; i < ripples.length; i++) {
      final a = old.ripples[i];
      final b = ripples[i];
      if (a.x != b.x ||
          a.hand != b.hand ||
          a.perfect != b.perfect ||
          a.t != b.t) {
        return true;
      }
    }
    return false;
  }
}
