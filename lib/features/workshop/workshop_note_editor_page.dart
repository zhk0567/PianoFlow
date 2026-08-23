import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/theme/app_theme.dart';
import '../library/library_repository.dart';
import '../library/user_import_store.dart';
import 'workshop_note_piano_roll.dart';

/// Visual piano-roll editor for [ScoreKind.userImport] only.
///
/// Edits midi / start / duration / hand, then saves JSON + regenerated MusicXML.
/// Not a MuseScore engraving editor — honest visual「音符卷帘」.
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
  int? _selected;

  @override
  void initState() {
    super.initState();
    _load();
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
        _selected = null;
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
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已保存音符卷帘（JSON + MusicXML）。仍为自导入，非正式谱。'),
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
        content: const Text('离开将丢弃音符改动。'),
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

  void _replaceNote(int index, ScoreNote note) {
    setState(() {
      final copy = List<ScoreNote>.from(_notes);
      copy[index] = note;
      _notes = copy;
      _dirty = true;
      _selected = index;
    });
  }

  void _addAt({required double start, required int midi}) {
    final note = ScoreNote(
      midi: midi.clamp(21, 108),
      start: start < 0 ? 0 : start,
      duration: 0.5,
      hand: midi >= 60 ? Hand.right : Hand.left,
    );
    setState(() {
      _notes = [..._notes, note];
      _selected = _notes.length - 1;
      _dirty = true;
    });
  }

  void _deleteSelected() {
    final i = _selected;
    if (i == null || i < 0 || i >= _notes.length) return;
    setState(() {
      final copy = List<ScoreNote>.from(_notes)..removeAt(i);
      _notes = copy;
      _selected = null;
      _dirty = true;
    });
  }

  Future<void> _editSelected({bool isNew = false}) async {
    final score = _score;
    if (score == null) return;
    final index = isNew ? _notes.length : (_selected ?? -1);
    if (!isNew && (index < 0 || index >= _notes.length)) return;

    final seed = isNew
        ? ScoreNote(
            midi: 60,
            start: _notes.isEmpty ? 0 : _notes.last.end,
            duration: 0.5,
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
              title: Text(isNew ? '添加音符' : '精细编辑 #${index + 1}'),
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
                      // ignore: deprecated_member_use — live value under StatefulBuilder
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
        _selected = _notes.length - 1;
      } else {
        final copy = List<ScoreNote>.from(_notes);
        copy[index] = next;
        _notes = copy;
        _selected = index;
      }
      _dirty = true;
    });
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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
            score == null ? '编辑音符卷帘' : '编辑音符 · ${score.title}',
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
                onPressed: _busy ? null : () => _editSelected(isNew: true),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '钢琴卷帘可视化编辑：横轴=拍、纵轴=音高；橙=左手、青=右手。'
              '保存写回自导入 JSON 并重生成 MusicXML。'
              '不是 MuseScore 级排版；仍为自导入，非正式谱。'
              '${_dirty ? ' · 有未保存修改' : ''}',
              style: AppTheme.body(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${_notes.length} 音 · ${score.bpm} BPM · '
                '${score.timeNum}/${score.timeDen}'
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
                  setState(() {
                    _handFilter = s.first;
                    _selected = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: WorkshopNotePianoRoll(
              notes: _notes,
              selectedIndex: _selected,
              handFilter: _handFilter,
              beatsPerMeasure: score.beatsPerMeasure,
              onSelect: (i) => setState(() => _selected = i),
              onChangeNote: _replaceNote,
              onAddAt: ({required start, required midi}) =>
                  _addAt(start: start, midi: midi),
              onDeleteSelected: _deleteSelected,
              onEditSelected: () => _editSelected(),
            ),
          ),
        ],
      ),
    );
  }
}
