import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';
import '../practice_clock.dart';
import '../practice_fx_budget.dart';
import '../practice_stage_theme.dart';
import '../practice_judge_logic.dart';

/// Hit bursts + ambient shimmer when「视觉特效」is on.
///
/// Display-only: reads geometry / optional note onsets / grade events.
/// No spark particles — rings / pillar / wash only.
///
/// Performance: [PracticeFxBudget], no [ImageFilter.blur], own
/// [RepaintBoundary], idle when [enabled] is false.
class PracticeVisualFxOverlay extends StatefulWidget {
  const PracticeVisualFxOverlay({
    super.key,
    required this.enabled,
    required this.geometry,
    required this.grade,
    required this.midi,
    required this.nonce,
    required this.combo,
    this.hitLineYFraction = 0.92,
    this.notes = const [],
    this.clock,
    this.autoplayVisual = false,
  });

  final bool enabled;
  final KeyboardGeometry geometry;
  final HitGrade? grade;
  final int? midi;
  final int nonce;
  final int combo;

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

class _PracticeVisualFxOverlayState extends State<PracticeVisualFxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  HitGrade? _burstGrade;
  double? _burstX;
  int _burstCombo = 0;
  int _lastNonce = 0;
  bool _burstShowLabel = true;
  double? _lastAutoPos;
  final Map<int, double> _lastAutoFlashBeat = {};

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: PracticeFxBudget.burstMs),
    );
    widget.clock?.addListener(_onClock);
    if (widget.enabled) {
      _lastNonce = widget.nonce;
    }
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
      _burst.stop();
      _burst.value = 0;
      _lastAutoPos = null;
      _lastAutoFlashBeat.clear();
    }
    if (!widget.enabled) return;

    if (widget.nonce != _lastNonce &&
        widget.grade != null &&
        widget.grade!.showsFeedback) {
      _lastNonce = widget.nonce;
      _spawnBurst(
        grade: widget.grade!,
        midi: widget.midi,
        combo: widget.combo,
        showLabel: true,
      );
    }
  }

  void _pollAutoplayOnsets(double pos) {
    final prev = _lastAutoPos;
    _lastAutoPos = pos;
    if (prev == null) return;
    if (pos + 0.08 < prev || pos - prev > 1.5) {
      _lastAutoFlashBeat.clear();
      return;
    }
    if (widget.notes.isEmpty) return;
    if (_burst.isAnimating && _burst.value < 0.55) return;

    var fired = 0;
    for (final n in widget.notes) {
      if (fired >= PracticeFxBudget.autoplayOnsetsPerFrame) break;
      if (n.start <= prev || n.start > pos) continue;
      final last = _lastAutoFlashBeat[n.midi];
      if (last != null &&
          (pos - last) < PracticeFxBudget.autoplayFlashCooldownBeats) {
        continue;
      }
      _lastAutoFlashBeat[n.midi] = pos;
      _spawnBurst(
        grade: HitGrade.perfect,
        midi: n.midi,
        combo: 0,
        showLabel: false,
      );
      fired++;
    }
  }

  void _spawnBurst({
    required HitGrade grade,
    required int? midi,
    required int combo,
    required bool showLabel,
  }) {
    final cx = midi != null ? widget.geometry.midiToCenterX(midi) : null;
    _burstX = cx ?? widget.geometry.width * 0.5;
    _burstGrade = grade;
    _burstCombo = combo;
    _burstShowLabel = showLabel;
    _burst.forward(from: 0);
  }

  @override
  void dispose() {
    widget.clock?.removeListener(_onClock);
    _burst.dispose();
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
            final animating = _burst.isAnimating || _burst.value > 0;
            return CustomPaint(
              painter: _FxPainter(
                burstT: animating
                    ? Curves.easeOutCubic.transform(_burst.value)
                    : 0,
                burstLife: animating
                    ? (1.0 - Curves.easeInQuad.transform(_burst.value))
                        .clamp(0.0, 1.0)
                    : 0,
                ambientT: PracticeFxBudget.ambientT,
                burstX: _burstX,
                grade: _burstGrade,
                combo: _burstCombo,
                showLabel: _burstShowLabel,
                hitLineYFraction: widget.hitLineYFraction,
                width: widget.geometry.width,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter({
    required this.burstT,
    required this.burstLife,
    required this.ambientT,
    required this.burstX,
    required this.grade,
    required this.combo,
    required this.showLabel,
    required this.hitLineYFraction,
    required this.width,
  });

  final double burstT;
  final double burstLife;
  final double ambientT;
  final double? burstX;
  final HitGrade? grade;
  final int combo;
  final bool showLabel;
  final double hitLineYFraction;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final hitY = size.height * hitLineYFraction;
    const stage = PracticeStageTheme.midnight;

    final aurora = 0.12 + 0.10 * ambientT;
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, size.height * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            stage.auroraWarm.withValues(alpha: aurora),
            stage.auroraCool.withValues(alpha: aurora * 0.55),
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
            stage.auroraWarm.withValues(alpha: 0.16 + 0.10 * ambientT),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(0, hitY - 70, size.width, size.height)),
    );

    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = stage.accent.withValues(alpha: 0.01 + 0.01 * ambientT)
        ..strokeWidth = 96
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = stage.accent.withValues(alpha: 0.04)
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(0, hitY),
      Offset(size.width, hitY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.025 + 0.015 * ambientT)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    if (burstT <= 0 || burstX == null || grade == null) return;

    final origin = Offset(burstX!, hitY);
    final life = burstLife.clamp(0.0, 1.0);
    final perfect = grade == HitGrade.perfect;
    final burstColor = perfect ? stage.accent : AppColors.success;

    final pillarH = size.height * (perfect ? 0.55 : 0.38);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(origin.dx, hitY - pillarH * 0.45),
        width: perfect ? 18 : 12,
        height: pillarH,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            burstColor.withValues(alpha: 0.32 * life),
            burstColor.withValues(alpha: 0.10 * life),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCenter(
            center: Offset(origin.dx, hitY - pillarH * 0.45),
            width: 28,
            height: pillarH,
          ),
        ),
    );

    // Quiet ripples — modest radius; lifetime from [PracticeFxBudget.burstMs].
    for (final scale in perfect ? const [1.0, 0.62] : const [1.0]) {
      final ringR = (8 + burstT * (perfect ? 52 : 36)) * scale;
      canvas.drawCircle(
        origin,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (perfect ? 2.0 : 1.5) * (1.35 - 0.25 * scale)
          ..color = burstColor.withValues(alpha: 0.42 * life * scale),
      );
    }

    canvas.drawCircle(
      origin,
      16 * life,
      Paint()..color = burstColor.withValues(alpha: 0.16 * life),
    );
    canvas.drawCircle(
      origin,
      7 * life,
      Paint()..color = Colors.white.withValues(alpha: 0.32 * life),
    );

    if (showLabel && life > 0.12) {
      final gradeLabel = perfect ? '完美' : '不错';
      final comboBit = combo >= 3 ? '  ×$combo' : '';
      final tp = TextPainter(
        text: TextSpan(
          text: '$gradeLabel$comboBit',
          style: AppTheme.body(
            fontSize: perfect ? 26 : 20,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.95 * life),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = Offset(
        (origin.dx - tp.width / 2).clamp(4.0, width - tp.width - 4),
        hitY - 72 - 28 * burstT,
      );
      final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(pos.dx - 12, pos.dy - 6, tp.width + 24, tp.height + 12),
        const Radius.circular(14),
      );
      canvas.drawRRect(
        bg,
        Paint()..color = burstColor.withValues(alpha: 0.7 * life),
      );
      tp.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) {
    return old.burstT != burstT ||
        old.burstLife != burstLife ||
        old.burstX != burstX ||
        old.grade != grade ||
        old.combo != combo ||
        old.showLabel != showLabel ||
        old.hitLineYFraction != hitLineYFraction ||
        old.width != width;
  }
}
