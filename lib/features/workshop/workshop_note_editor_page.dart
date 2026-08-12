import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/theme/app_theme.dart';
import '../library/library_repository.dart';
import '../library/user_import_store.dart';

/// Lightweight note-table editor for [ScoreKind.userImport] only.
///
/// Edits midi / start / duration / hand, then saves JSON + regenerated MusicXML.
/// Not a full score engraving editor — honest “音符表” surface.
class WorkshopNoteEditorPage extends ConsumerStatefulWidget {
  const WorkshopNoteEditorPage({super.key, required this.scoreId});

  final String scoreId;

  @override
  ConsumerState<WorkshopNoteEditorPage> createState() =>
      _WorkshopNoteEditorPageState();
}

class _WorkshopNoteEditorPageState
    extends ConsumerState<WorkshopNoteEditorPage> {
  SongScore? _score;
  List<ScoreNote> _notes = const [];
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  String? _error;
  Hand? _handFilter; // null = all
  final _startFromCtrl = TextEditingController();
  final _startToCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _startFromCtrl.dispose();
    _startToCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await UserImportStore().loadUserCatalog();
      SongSummary? summary;
      for (final s in catalog) {
        if (s.id == widget.scoreId) {
          summary = s;
          break;
        }
      }
      if (summary == null || !summary.isUserImport) {
        throw StateError('仅可编辑自导入曲目（非正式谱）');
      }
      final score = await UserImportStore().loadUserScore(widget.scoreId);
      if (score == null) {
        throw StateError('找不到自导入 JSON：${widget.scoreId}');
      }
      if (!mounted) return;
      setState(() {
        _score = score;
        _notes = List<ScoreNote>.from(score.notes);
        _loading = false;
        _dirty = false;
      });
    } catch (e, st) {
      pianoFlowLog('Workshop', 'note editor load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is StateError ? e.message : '加载失败：$e';
      });
    }
  }

  List<int> get _visibleIndices {
    final from = double.tryParse(_startFromCtrl.text.trim());
    final to = double.tryParse(_startToCtrl.text.trim());
    final out = <int>[];
    for (var i = 0; i < _notes.length; i++) {
      final n = _notes[i];
      if (_handFilter != null && n.hand != _handFilter) continue;
      if (from != null && n.start < from) continue;
      if (to != null && n.start > to) continue;
      out.add(i);
    }
    return out;
  }

  Future<void> _save() async {
    if (_busy || _score == null) return;
    setState(() => _busy = true);
    try {
      await UserImportStore().saveUserNotes(
        id: widget.scoreId,
        notes: _notes,
      );
      ref.invalidate(catalogProvider);
      ref.invalidate(songByIdProvider(widget.scoreId));
      // scoreProvider is family on SongSummary — invalidate catalog-driven loads.
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已保存音符表（JSON + MusicXML）。仍为自导入，非正式谱。'),
        ),
      );
    } catch (e, st) {
      pianoFlowLog('Workshop', 'note editor save failed: $e\n$st');
      final msg = e is StateError ? e.message : '保存失败：$e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('有未保存修改'),
        content: const Text('离开将丢弃音符表改动。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('丢弃离开'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _editAt(int index, {bool isNew = false}) async {
    final seed = isNew
        ? ScoreNote(
            midi: 60,
            start: _notes.isEmpty ? 0 : _notes.last.end,
            duration: 1,
            hand: Hand.right,
          )
        : _notes[index];
    final midiCtrl = TextEditingController(text: '${seed.midi}');
    final startCtrl = TextEditingController(text: _fmt(seed.start));
    final durCtrl = TextEditingController(text: _fmt(seed.duration));
    var hand = seed.hand == Hand.left ? Hand.left : Hand.right;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(isNew ? '添加音符' : '编辑音符 #${index + 1}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: midiCtrl,
                      decoration: const InputDecoration(
                        labelText: 'MIDI（21–108）',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(labelText: '起始拍'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    TextField(
                      controller: durCtrl,
                      decoration: const InputDecoration(labelText: '时值（拍）'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Hand>(
                      // ignore: deprecated_member_use — need live value under StatefulBuilder
                      value: hand,
                      decoration: const InputDecoration(labelText: '手'),
                      items: const [
                        DropdownMenuItem(
                          value: Hand.right,
                          child: Text('右手'),
                        ),
                        DropdownMenuItem(
                          value: Hand.left,
                          child: Text('左手'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => hand = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;

    final midi = int.tryParse(midiCtrl.text.trim());
    final start = double.tryParse(startCtrl.text.trim());
    final dur = double.tryParse(durCtrl.text.trim());
    if (midi == null || start == null || dur == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写有效数字')),
      );
      return;
    }
    if (midi < 21 || midi > 108) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MIDI 须在 21–108')),
      );
      return;
    }
    if (start < 0 || dur <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('起始拍 ≥ 0，时值 > 0')),
      );
      return;
    }

    final next = ScoreNote(
      midi: midi,
      start: start,
      duration: dur,
      hand: hand,
    );
    setState(() {
      if (isNew) {
        _notes = [..._notes, next];
      } else {
        final copy = List<ScoreNote>.from(_notes);
        copy[index] = next;
        _notes = copy;
      }
      _dirty = true;
    });
  }

  void _deleteAt(int index) {
    setState(() {
      final copy = List<ScoreNote>.from(_notes)..removeAt(index);
      _notes = copy;
      _dirty = true;
    });
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
          RegExp(r'\.$'),
          '',
        );
  }

  static String _midiLabel(int midi) {
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final name = names[midi % 12];
    final oct = (midi ~/ 12) - 1;
    return '$name$oct';
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeaveIfDirty();
        if (!leave || !mounted) return;
        this.context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            score == null ? '编辑音符表' : '编辑音符表 · ${score.title}',
            style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: _busy || !_dirty ? null : _save,
              child: Text(_busy ? '保存中…' : '保存'),
            ),
          ],
        ),
        floatingActionButton: score == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _busy
                    ? null
                    : () => _editAt(_notes.length, isNew: true),
                icon: const Icon(Icons.add),
                label: const Text('添加音符'),
              ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: AppTheme.body(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final score = _score!;
    final visible = _visibleIndices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '轻量音符表编辑（MIDI / 起始拍 / 时值 / 手）。'
              '保存会写回自导入 JSON，并用跟弹同款逻辑重生成 MusicXML。'
              '不是 MuseScore 级排版编辑器；仍为自导入，非正式谱。'
              '${_dirty ? ' · 有未保存修改' : ''}',
              style: AppTheme.body(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${score.id} · ${_notes.length} 音 · ${score.bpm} BPM'
                '${_dirty ? ' · 未保存' : ''}',
                style: AppTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SegmentedButton<Hand?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('全部')),
                  ButtonSegment(value: Hand.right, label: Text('右手')),
                  ButtonSegment(value: Hand.left, label: Text('左手')),
                ],
                selected: {_handFilter},
                onSelectionChanged: (s) {
                  setState(() => _handFilter = s.first);
                },
              ),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _startFromCtrl,
                  decoration: const InputDecoration(
                    labelText: '起始≥',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _startToCtrl,
                  decoration: const InputDecoration(
                    labelText: '起始≤',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '显示 ${visible.length} / ${_notes.length}',
            style: AppTheme.body(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    _notes.isEmpty ? '尚无音符，点右下角添加。' : '当前筛选无匹配音符。',
                    style: AppTheme.body(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: visible.length,
                  itemBuilder: (context, vi) {
                    final i = visible[vi];
                    final n = _notes[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: AppColors.surface.withValues(alpha: 0.92),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '#${i + 1}  ${_midiLabel(n.midi)}  MIDI ${n.midi}',
                          style: AppTheme.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '起始 ${_fmt(n.start)} · 时值 ${_fmt(n.duration)} · '
                          '${n.hand == Hand.left ? '左手' : '右手'}',
                          style: AppTheme.body(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '编辑',
                              onPressed: _busy ? null : () => _editAt(i),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: '删除',
                              onPressed: _busy ? null : () => _deleteAt(i),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ],
                        ),
                        onTap: _busy ? null : () => _editAt(i),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
