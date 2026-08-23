import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';

/// Piano-roll canvas for editing [ScoreNote]s (time × pitch).
///
/// 双击空白添加；点选后拖移 / 拉右边改时值；双指或滚轮外区域平移缩放。
class WorkshopNotePianoRoll extends StatefulWidget {
  const WorkshopNotePianoRoll({
    super.key,
    required this.notes,
    required this.selectedIndex,
    required this.handFilter,
    required this.beatsPerMeasure,
    required this.onSelect,
    required this.onChangeNote,
    required this.onAddAt,
    required this.onDeleteSelected,
    required this.onEditSelected,
  });

  final List<ScoreNote> notes;
  final int? selectedIndex;
  final Hand? handFilter;
  final double beatsPerMeasure;
  final ValueChanged<int?> onSelect;
  final void Function(int index, ScoreNote note) onChangeNote;
  final void Function({required double start, required int midi}) onAddAt;
  final VoidCallback onDeleteSelected;
  final VoidCallback onEditSelected;

  static const midiMin = 21;
  static const midiMax = 108;
  static const rowHeight = 16.0;
  static const pxPerBeat = 56.0;
  static const keyLaneWidth = 44.0;
  static const resizeHandleW = 10.0;

  @override
  State<WorkshopNotePianoRoll> createState() => _WorkshopNotePianoRollState();
}

class _WorkshopNotePianoRollState extends State<WorkshopNotePianoRoll> {
  final _transform = TransformationController();
  int? _dragIndex;
  _DragKind? _dragKind;
  Offset? _dragOriginScene;
  ScoreNote? _dragSeed;
  Matrix4? _panStartMatrix;
  Offset? _panStartFocal;
  double _scaleStart = 1;
  DateTime? _lastTapAt;
  Offset? _lastTapScene;
  bool _suppressTap = false;
  bool _noteMoved = false;

  int get _rowCount =>
      WorkshopNotePianoRoll.midiMax - WorkshopNotePianoRoll.midiMin + 1;

  double get _contentHeight =>
      _rowCount * WorkshopNotePianoRoll.rowHeight;

  double get _endBeat {
    var end = widget.beatsPerMeasure * 4;
    for (final n in widget.notes) {
      end = math.max(end, n.end + widget.beatsPerMeasure);
    }
    return math.max(end, 8.0);
  }

  double get _contentWidth =>
      WorkshopNotePianoRoll.keyLaneWidth +
      _endBeat * WorkshopNotePianoRoll.pxPerBeat +
      80;

  bool _visible(ScoreNote n) =>
      widget.handFilter == null || n.hand == widget.handFilter;

  int _midiAtY(double y) {
    final row = (y / WorkshopNotePianoRoll.rowHeight).floor();
    final midi = WorkshopNotePianoRoll.midiMax - row;
    return midi.clamp(
      WorkshopNotePianoRoll.midiMin,
      WorkshopNotePianoRoll.midiMax,
    );
  }

  double _beatAtX(double x) {
    final local = x - WorkshopNotePianoRoll.keyLaneWidth;
    return math.max(0, local / WorkshopNotePianoRoll.pxPerBeat);
  }

  double _snapBeat(double b) {
    const step = 0.125;
    return (b / step).round() * step;
  }

  Offset _sceneFromViewport(Offset viewport) {
    final m = _transform.value.clone()..invert();
    return MatrixUtils.transformPoint(m, viewport);
  }

  int? _hitNote(Offset scene) {
    if (scene.dx < WorkshopNotePianoRoll.keyLaneWidth) return null;
    int? hit;
    for (var i = 0; i < widget.notes.length; i++) {
      final n = widget.notes[i];
      if (!_visible(n)) continue;
      if (_noteRect(n).inflate(1).contains(scene)) hit = i;
    }
    return hit;
  }

  bool _hitResize(ScoreNote n, Offset scene) {
    final r = _noteRect(n);
    return Rect.fromLTWH(
      r.right - WorkshopNotePianoRoll.resizeHandleW,
      r.top,
      WorkshopNotePianoRoll.resizeHandleW + 4,
      r.height,
    ).contains(scene);
  }

  Rect _noteRect(ScoreNote n) {
    final left = WorkshopNotePianoRoll.keyLaneWidth +
        n.start * WorkshopNotePianoRoll.pxPerBeat;
    final top = (WorkshopNotePianoRoll.midiMax - n.midi) *
        WorkshopNotePianoRoll.rowHeight;
    final width = math.max(
      8.0,
      n.duration * WorkshopNotePianoRoll.pxPerBeat,
    );
    return Rect.fromLTWH(
      left,
      top,
      width,
      WorkshopNotePianoRoll.rowHeight - 1.5,
    );
  }

  void _handleTap(Offset scene) {
    final now = DateTime.now();
    final last = _lastTapAt;
    final lastScene = _lastTapScene;
    final isDouble = last != null &&
        lastScene != null &&
        now.difference(last) < const Duration(milliseconds: 350) &&
        (lastScene - scene).distance < 28;

    _lastTapAt = now;
    _lastTapScene = scene;

    final hit = _hitNote(scene);
    if (isDouble) {
      if (hit != null) {
        widget.onSelect(hit);
        widget.onEditSelected();
      } else if (scene.dx >= WorkshopNotePianoRoll.keyLaneWidth) {
        widget.onAddAt(
          start: _snapBeat(_beatAtX(scene.dx)),
          midi: _midiAtY(scene.dy),
        );
      }
      return;
    }

    widget.onSelect(hit);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _noteMoved = false;
    final scene = _sceneFromViewport(d.localFocalPoint);
    final hit = _hitNote(scene);
    if (d.pointerCount <= 1 && hit != null) {
      final n = widget.notes[hit];
      widget.onSelect(hit);
      _dragIndex = hit;
      _dragOriginScene = scene;
      _dragSeed = n;
      _dragKind = _hitResize(n, scene) ? _DragKind.resize : _DragKind.move;
      _panStartMatrix = null;
      return;
    }
    _dragIndex = null;
    _dragKind = null;
    _dragSeed = null;
    _dragOriginScene = null;
    _panStartMatrix = _transform.value.clone();
    _panStartFocal = d.localFocalPoint;
    _scaleStart = _transform.value.getMaxScaleOnAxis();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final i = _dragIndex;
    final origin = _dragOriginScene;
    final seed = _dragSeed;
    final kind = _dragKind;
    if (i != null && origin != null && seed != null && kind != null) {
      final scene = _sceneFromViewport(d.localFocalPoint);
      final dx = scene.dx - origin.dx;
      final dy = scene.dy - origin.dy;
      if (dx.abs() > 2 || dy.abs() > 2) _noteMoved = true;
      if (kind == _DragKind.move) {
        final start = _snapBeat(
          math.max(0, seed.start + dx / WorkshopNotePianoRoll.pxPerBeat),
        );
        final midiDelta = -(dy / WorkshopNotePianoRoll.rowHeight).round();
        final midi = (seed.midi + midiDelta).clamp(
          WorkshopNotePianoRoll.midiMin,
          WorkshopNotePianoRoll.midiMax,
        );
        widget.onChangeNote(i, seed.copyWith(start: start, midi: midi));
      } else {
        final dur = _snapBeat(
          math.max(
            0.125,
            seed.duration + dx / WorkshopNotePianoRoll.pxPerBeat,
          ),
        );
        widget.onChangeNote(i, seed.copyWith(duration: dur));
      }
      return;
    }

    final startM = _panStartMatrix;
    final startFocal = _panStartFocal;
    if (startM == null || startFocal == null) return;

    final next = Matrix4.copy(startM);
    final scale = (_scaleStart * d.scale).clamp(0.45, 2.4);
    final applied = scale / _scaleStart;
    next.scaleByDouble(applied, applied, 1, 1);
    final focalScene = MatrixUtils.transformPoint(
      Matrix4.copy(startM)..invert(),
      startFocal,
    );
    final dx = d.localFocalPoint.dx - startFocal.dx;
    final dy = d.localFocalPoint.dy - startFocal.dy;
    // Keep focal point stable under scale, then pan.
    final scaledFocal = MatrixUtils.transformPoint(next, focalScene);
    next.leftTranslateByDouble(
      startFocal.dx - scaledFocal.dx + dx,
      startFocal.dy - scaledFocal.dy + dy,
      0,
      1,
    );
    _transform.value = next;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_noteMoved) _suppressTap = true;
    _dragIndex = null;
    _dragKind = null;
    _dragSeed = null;
    _dragOriginScene = null;
    _panStartMatrix = null;
    _panStartFocal = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirstVisible());
  }

  void _focusFirstVisible() {
    ScoreNote? first;
    for (final n in widget.notes) {
      if (!_visible(n)) continue;
      if (first == null || n.start < first.start) first = n;
    }
    if (first == null) {
      final y = (WorkshopNotePianoRoll.midiMax - 60) *
          WorkshopNotePianoRoll.rowHeight;
      _transform.value = Matrix4.identity()
        ..translateByDouble(0, -math.max(0.0, y - 120), 0, 1);
      return;
    }
    final x = WorkshopNotePianoRoll.keyLaneWidth +
        first.start * WorkshopNotePianoRoll.pxPerBeat;
    final y = (WorkshopNotePianoRoll.midiMax - first.midi) *
        WorkshopNotePianoRoll.rowHeight;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -math.max(0.0, x - 80),
        -math.max(0.0, y - 140),
        0,
        1,
      );
  }

  @override
  void didUpdateWidget(covariant WorkshopNotePianoRoll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notes.isEmpty && widget.notes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirstVisible());
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedIndex;
    final selNote = (selected != null &&
            selected >= 0 &&
            selected < widget.notes.length)
        ? widget.notes[selected]
        : null;

    return Column(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = math.max(box.maxWidth, _contentWidth);
                  final h = math.max(box.maxHeight, _contentHeight);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      if (_suppressTap) {
                        _suppressTap = false;
                        return;
                      }
                      _handleTap(_sceneFromViewport(d.localPosition));
                    },
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    child: AnimatedBuilder(
                      animation: _transform,
                      builder: (context, _) {
                        return ClipRect(
                          child: Transform(
                            transform: _transform.value,
                            child: CustomPaint(
                              painter: _PianoRollPainter(
                                notes: widget.notes,
                                handFilter: widget.handFilter,
                                selectedIndex: widget.selectedIndex,
                                beatsPerMeasure: widget.beatsPerMeasure,
                                endBeat: _endBeat,
                              ),
                              size: Size(w, h),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SelectionBar(
          note: selNote,
          index: selected,
          onEdit: selected == null ? null : widget.onEditSelected,
          onDelete: selected == null ? null : widget.onDeleteSelected,
        ),
      ],
    );
  }
}

enum _DragKind { move, resize }

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.note,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final ScoreNote? note;
  final int? index;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (note == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          '拖空白处平移 · 双指缩放 · 拖音符改音高/起始 · 拖右边改长短 · 双击空白添加',
          style: AppTheme.body(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }
    final n = note!;
    final color =
        n.hand == Hand.left ? AppColors.leftHand : AppColors.rightHand;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '#${(index ?? 0) + 1}  ${_midiLabel(n.midi)}  ·  '
              '起始 ${_fmt(n.start)}  ·  时值 ${_fmt(n.duration)}  ·  '
              '${n.hand == Hand.left ? '左手' : '右手'}',
              style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('精细编辑')),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String _midiLabel(int midi) {
    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ];
    return '${names[midi % 12]}${(midi ~/ 12) - 1}';
  }
}

class _PianoRollPainter extends CustomPainter {
  _PianoRollPainter({
    required this.notes,
    required this.handFilter,
    required this.selectedIndex,
    required this.beatsPerMeasure,
    required this.endBeat,
  });

  final List<ScoreNote> notes;
  final Hand? handFilter;
  final int? selectedIndex;
  final double beatsPerMeasure;
  final double endBeat;

  @override
  void paint(Canvas canvas, Size size) {
    final lane = WorkshopNotePianoRoll.keyLaneWidth;
    final rowH = WorkshopNotePianoRoll.rowHeight;
    final ppb = WorkshopNotePianoRoll.pxPerBeat;
    final midiMin = WorkshopNotePianoRoll.midiMin;
    final midiMax = WorkshopNotePianoRoll.midiMax;

    for (var midi = midiMax; midi >= midiMin; midi--) {
      final top = (midiMax - midi) * rowH;
      final black = _isBlack(midi);
      canvas.drawRect(
        Rect.fromLTWH(lane, top, size.width - lane, rowH),
        Paint()
          ..color = black
              ? const Color(0xFF10151C)
              : const Color(0xFF161C26),
      );
      if (midi % 12 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(lane, top, size.width - lane, 1),
          Paint()..color = AppColors.border.withValues(alpha: 0.55),
        );
      }
    }

    final bpm = beatsPerMeasure <= 0 ? 4.0 : beatsPerMeasure;
    for (var b = 0.0; b <= endBeat + 0.01; b += 1) {
      final x = lane + b * ppb;
      final isBar = (b % bpm).abs() < 1e-6;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = isBar
              ? AppColors.accent.withValues(alpha: 0.28)
              : AppColors.borderSubtle.withValues(alpha: 0.85)
          ..strokeWidth = isBar ? 1.4 : 0.7,
      );
      if (isBar) {
        final m = (b / bpm).round() + 1;
        final tp = TextPainter(
          text: TextSpan(
            text: '$m',
            style: const TextStyle(
              color: Color(0xFF6E7686),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 3, 2));
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, lane, size.height),
      Paint()..color = const Color(0xFF0E1218),
    );
    canvas.drawLine(
      Offset(lane, 0),
      Offset(lane, size.height),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1,
    );
    for (var midi = midiMax; midi >= midiMin; midi--) {
      final top = (midiMax - midi) * rowH;
      final black = _isBlack(midi);
      if (!black) {
        canvas.drawRect(
          Rect.fromLTWH(2, top + 1, lane - 4, rowH - 2),
          Paint()..color = const Color(0xFF1C2430),
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(lane * 0.42, top + 1, lane * 0.52, rowH - 2),
          Paint()..color = const Color(0xFF080A0E),
        );
      }
      if (midi % 12 == 0) {
        final label = 'C${(midi ~/ 12) - 1}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF9AA3B2),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: lane - 6);
        tp.paint(canvas, Offset(4, top + (rowH - tp.height) / 2));
      }
    }

    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (handFilter != null && n.hand != handFilter) continue;
      final selected = i == selectedIndex;
      final base =
          n.hand == Hand.left ? AppColors.leftHand : AppColors.rightHand;
      final left = lane + n.start * ppb;
      final top = (midiMax - n.midi) * rowH;
      final width = math.max(8.0, n.duration * ppb);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top + 0.8, width, rowH - 1.8),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = base.withValues(alpha: selected ? 0.95 : 0.78),
      );
      if (selected) {
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.85),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              left + width - WorkshopNotePianoRoll.resizeHandleW,
              top + 2,
              WorkshopNotePianoRoll.resizeHandleW,
              rowH - 4,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      }
      if (width >= 28) {
        final tp = TextPainter(
          text: TextSpan(
            text: _midiLabel(n.midi),
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.78),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width - 6);
        tp.paint(canvas, Offset(left + 4, top + (rowH - tp.height) / 2));
      }
    }
  }

  static bool _isBlack(int midi) {
    const black = {1, 3, 6, 8, 10};
    return black.contains(midi % 12);
  }

  static String _midiLabel(int midi) {
    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ];
    return '${names[midi % 12]}${(midi ~/ 12) - 1}';
  }

  @override
  bool shouldRepaint(covariant _PianoRollPainter old) {
    return old.notes != notes ||
        old.handFilter != handFilter ||
        old.selectedIndex != selectedIndex ||
        old.beatsPerMeasure != beatsPerMeasure ||
        old.endBeat != endBeat;
  }
}
