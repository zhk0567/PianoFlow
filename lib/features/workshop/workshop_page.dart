import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/theme/app_theme.dart';
import '../library/library_repository.dart';
import '../library/user_import_store.dart';
import '../library/user_library_store.dart';
import 'workshop_audio_draft_worker.dart';
import 'workshop_audio_import.dart';
import 'workshop_external_editor.dart';
import 'workshop_import_common.dart';
import 'workshop_midi_import.dart';
import 'workshop_musicxml_import.dart';
import 'workshop_pdf_guide.dart';
import 'workshop_tools.dart';

/// Score import / edit workshop — left-rail tab「工坊」.
class WorkshopPage extends ConsumerWidget {
  const WorkshopPage({super.key, this.initialTool});

  final WorkshopToolId? initialTool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        WorkshopTool.byId(initialTool ?? WorkshopToolId.importMusicXml) ??
            WorkshopTool.all.first;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return ColoredBox(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 960 : 880),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 48 : 20,
                wide ? 36 : 24,
                wide ? 48 : 20,
                40,
              ),
              children: [
              Text(
                '谱面工坊',
                style: AppTheme.display(
                  fontSize: wide ? 40 : 32,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '各入口已可跟弹入库；质量档诚实标注为「自导入/OMR」，未校对不会标成正式谱。',
                style: AppTheme.body(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              ...WorkshopTool.all.map((tool) {
                final active = tool.id == selected.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      onTap: () =>
                          context.go('/workshop?tool=${tool.id.name}'),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(
                            color: active
                                ? AppColors.accent.withValues(alpha: 0.55)
                                : AppColors.borderSubtle,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              tool.icon,
                              color: active
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tool.title,
                                    style: AppTheme.body(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tool.subtitle,
                                    style: AppTheme.body(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              tool.badge,
                              style: AppTheme.body(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tool.available
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              _ToolDetail(tool: selected),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolDetail extends ConsumerStatefulWidget {
  const _ToolDetail({required this.tool});

  final WorkshopTool tool;

  @override
  ConsumerState<_ToolDetail> createState() => _ToolDetailState();
}

class _ToolDetailState extends ConsumerState<_ToolDetail> {
  bool _busy = false;
  String? _status;
  /// `null` while busy → indeterminate bar; `0..1` when fraction known.
  double? _progress;
  String? _lastScoreId;
  WorkshopPdfStageResult? _pdfStage;
  List<WorkshopOmrCandidate> _omrCandidates = const [];
  List<SongSummary> _userSongs = const [];
  bool _userSongsLoaded = false;
  /// 音频：默认尝试 Demucs；无 demucs 时脚本会跳过并诚实标「未分轨」。
  bool _useDemucs = true;

  /// Parse `progress=3/24`, `progress=decode=1/8`, or `(3/40)` → 0..1.
  static double? _fractionFromLine(String line) {
    final m = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(line);
    if (m == null) return null;
    final a = int.tryParse(m.group(1)!);
    final b = int.tryParse(m.group(2)!);
    if (a == null || b == null || b <= 0) return null;
    return (a / b).clamp(0.0, 1.0);
  }

  void _setBusy(String status, {double? progress}) {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _status = status;
      _progress = progress;
    });
  }

  void _setStatus(String status, {double? progress, bool clearProgress = false}) {
    if (!mounted) return;
    setState(() {
      _status = status;
      if (clearProgress) {
        _progress = null;
      } else if (progress != null) {
        _progress = progress;
      }
    });
  }

  void _clearBusy() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _reloadUserSongs();
  }

  @override
  void didUpdateWidget(covariant _ToolDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool.id != widget.tool.id &&
        widget.tool.id == WorkshopToolId.editScore) {
      _reloadUserSongs();
    }
  }

  Future<void> _reloadUserSongs() async {
    final songs = await UserImportStore().loadUserCatalog();
    if (!mounted) return;
    setState(() {
      _userSongs = songs.where((s) => s.isUserImport).toList();
      _userSongsLoaded = true;
    });
  }

  Future<void> _afterImportOk(WorkshopImportResult result) async {
    ref.invalidate(catalogProvider);
    await _reloadUserSongs();
    if (!mounted) return;
    setState(() {
      _status = '${result.message} → 进入练习';
      _lastScoreId = result.scoreId;
    });
    // 成谱秒级验收：出完可练谱就直接进跟弹，不再二次点「去练习」。
    pianoFlowLog(
      'Workshop',
      'import ok → practice id=${result.scoreId}',
    );
    context.push('/practice/${result.scoreId}');
  }

  Future<String> _pickPath({
    required List<String> extensions,
    required String dialogTitle,
    required String fallbackName,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      dialogTitle: dialogTitle,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw const _Cancelled();
    }
    final f = result.files.single;
    return WorkshopImportCommon.materializePickerFile(
      path: f.path,
      bytes: f.bytes,
      fallbackName: f.name.isNotEmpty ? f.name : fallbackName,
    );
  }

  Future<void> _importMusicXml({String? presetPath, String? preferredId}) async {
    if (_busy && presetPath == null) return;
    _setBusy(
      presetPath == null ? '选择文件…' : '正在导入检测到的 MusicXML…',
      progress: presetPath == null ? 0.05 : 0.82,
    );
    setState(() => _lastScoreId = null);
    try {
      final path = presetPath ??
          await _pickPath(
            extensions: const ['musicxml', 'xml', 'mxl'],
            dialogTitle: '选择 MusicXML / MXL',
            fallbackName: 'import.musicxml',
          );
      _setStatus('正在转换（Python / musicxml_to_score）…', progress: 0.35);
      final derivedTitle = preferredId
          ?.replaceFirst(RegExp(r'^user_pdf_'), '')
          .replaceFirst(RegExp(r'^user_'), '');
      final result = await WorkshopMusicXmlImporter.importFile(
        inputPath: path,
        scoreId: preferredId,
        title: derivedTitle,
      );
      _setStatus('写入曲库…', progress: 0.9);
      await _afterImportOk(result);
    } on _Cancelled {
      _setStatus('已取消', clearProgress: true);
    } catch (e, st) {
      pianoFlowLog('Workshop', 'MusicXML import UI failed: $e\n$st');
      final msg = e is StateError ? e.message : '导入失败：$e';
      _setStatus(msg, clearProgress: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      _clearBusy();
    }
  }

  Future<void> _importMidi() async {
    if (_busy) return;
    _setBusy('选择 MIDI…', progress: 0.05);
    setState(() => _lastScoreId = null);
    try {
      final path = await _pickPath(
        extensions: const ['mid', 'midi'],
        dialogTitle: '选择 MIDI',
        fallbackName: 'import.mid',
      );
      _setStatus('正在转换 MIDI（两步）…', progress: 0.25);
      final result = await WorkshopMidiImporter.importFile(inputPath: path);
      _setStatus('写入曲库…', progress: 0.9);
      await _afterImportOk(result);
    } on _Cancelled {
      _setStatus('已取消', clearProgress: true);
    } catch (e, st) {
      pianoFlowLog('Workshop', 'MIDI import UI failed: $e\n$st');
      final msg = e is StateError ? e.message : '导入失败：$e';
      _setStatus(msg, clearProgress: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      _clearBusy();
    }
  }

  Future<void> _importAudio() async {
    if (_busy) return;
    _setBusy('选择音频…', progress: 0.04);
    setState(() => _lastScoreId = null);
    // Warm ORT while the user picks a file (first import pays less cold start).
    unawaited(
      WorkshopAudioDraftWorker.instance.ensureStarted(
        onProgress: (line) {
          if (!mounted || !_busy) return;
          if (line.contains('ORT')) {
            _setStatus(
              '预热转录引擎… $line',
              progress: _fractionFromLine(line) ?? 0.08,
            );
          }
        },
      ).catchError((Object e) {
        pianoFlowLog('Workshop', 'audio worker prewarm: $e');
      }),
    );
    try {
      final path = await _pickPath(
        extensions: const ['wav', 'mp3', 'flac', 'ogg', 'm4a'],
        dialogTitle: '选择音频（短片段）',
        fallbackName: 'import.wav',
      );
      _setStatus(
        '正在本地转录（Basic Pitch ONNX，短片段约数秒）…',
        progress: 0.12,
      );
      final result = await WorkshopAudioImporter.importFile(
        inputPath: path,
        useDemucs: _useDemucs,
        onProgress: (line) {
          if (!mounted) return;
          final frac = _fractionFromLine(line);
          if (line.startsWith('progress=') ||
              line.contains('progress=') ||
              line.contains('dur=') ||
              line.contains('notes=') ||
              line.contains('truncate') ||
              line.contains('ORT') ||
              line.contains('demucs')) {
            _setStatus(
              '正在本地转录… $line',
              progress: frac ?? (_progress == null ? 0.2 : null),
            );
          }
        },
      );
      _setStatus('写入曲库…', progress: 0.92);
      await _afterImportOk(result);
    } on _Cancelled {
      _setStatus('已取消', clearProgress: true);
    } catch (e, st) {
      pianoFlowLog('Workshop', 'Audio import UI failed: $e\n$st');
      final msg = e is StateError ? e.message : '导入失败：$e';
      _setStatus(msg, clearProgress: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      _clearBusy();
    }
  }

  Future<void> _stagePdf() async {
    if (_busy) return;
    _setBusy('选择 PDF…', progress: 0.05);
    setState(() {
      _pdfStage = null;
      _omrCandidates = const [];
    });
    try {
      final path = await _pickPath(
        extensions: const ['pdf'],
        dialogTitle: '选择 PDF 乐谱',
        fallbackName: 'score.pdf',
      );
      _setStatus('正在暂存 PDF…', progress: 0.4);
      final staged = await WorkshopPdfGuide.stagePdf(pdfPath: path);
      setState(() {
        _pdfStage = staged;
        _status =
            '${staged.guidance}\n暂存：${staged.stagedPdfPath}\n命令：${staged.omrCommand}';
        _progress = 1.0;
      });
    } on _Cancelled {
      _setStatus('已取消', clearProgress: true);
    } catch (e, st) {
      pianoFlowLog('Workshop', 'PDF stage UI failed: $e\n$st');
      final msg = e is StateError ? e.message : '暂存失败：$e';
      _setStatus(msg, clearProgress: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      _clearBusy();
    }
  }

  /// One-shot: pick PDF -> OMR -> poll -> import -> practice (draft only).
  Future<void> _pdfOneShotToPractice() async {
    if (_busy) return;
    _setBusy('选择 PDF…', progress: 0.04);
    setState(() {
      _pdfStage = null;
      _omrCandidates = const [];
      _lastScoreId = null;
    });
    try {
      final path = await _pickPath(
        extensions: const ['pdf'],
        dialogTitle: 'PDF 一键成谱并练习',
        fallbackName: 'score.pdf',
      );
      final result = await WorkshopPdfGuide.runOneShotPipeline(
        pdfPath: path,
        onProgress: (s) {
          if (!mounted) return;
          final frac = _fractionFromLine(s);
          double? mapped = frac;
          if (mapped == null) {
            if (s.contains('暂存')) {
              mapped = 0.12;
            } else if (s.contains('启动')) {
              mapped = 0.2;
            } else if (s.contains('等待 OMR')) {
              mapped = 0.25;
            }
          }
          _setStatus(s, progress: mapped);
        },
      );
      setState(() {
        _pdfStage = result.staged;
        _omrCandidates = result.candidates;
        _status = result.message;
        _progress = result.ok ? 0.8 : null;
      });
      if (!result.ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
        }
        return;
      }
      final preferred = result.preferred;
      if (preferred == null) return;
      await _importMusicXml(
        presetPath: preferred.path,
        preferredId: result.staged.scoreIdHint,
      );
    } on _Cancelled {
      _setStatus('已取消', clearProgress: true);
    } catch (e, st) {
      pianoFlowLog('Workshop', 'PDF one-shot failed: $e\n$st');
      final msg = e is StateError ? e.message : 'PDF 一键成谱失败：$e';
      _setStatus(msg, clearProgress: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      _clearBusy();
    }
  }

  Future<void> _launchOmr() async {
    final staged = _pdfStage;
    if (staged == null || _busy) return;
    _setBusy('正在启动 OMR…', progress: 0.3);
    try {
      final msg = await WorkshopPdfGuide.tryLaunchOmr(staged: staged);
      _setStatus(msg, progress: 1.0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      _clearBusy();
    }
  }

  Future<void> _scanOmrOutputs() async {
    final staged = _pdfStage;
    if (staged == null || _busy) return;
    _setBusy('正在扫描 OMR 输出…', progress: 0.35);
    try {
      final found = await WorkshopPdfGuide.findOmrMusicXml(
        scoreIdHint: staged.scoreIdHint,
        repoRoot: staged.repoRoot,
      );
      setState(() {
        _omrCandidates = found;
        _progress = 1.0;
        if (found.isEmpty) {
          final hint = staged.omrWorkDir ?? 'third_party/scores_musicxml/_omr_work/…';
          _status = '未找到 MusicXML。请确认 OMR 已完成，并检查：\n$hint';
        } else {
          _status =
              '找到 ${found.length} 个 MusicXML（含 corrected / omr_draft）。'
              '下一步请点「导入并练习」。';
        }
      });
    } catch (e, st) {
      pianoFlowLog('Workshop', 'OMR scan failed: $e\n$st');
      _setStatus('扫描失败：$e', clearProgress: true);
    } finally {
      _clearBusy();
    }
  }

  Future<void> _importOmrCandidate(WorkshopOmrCandidate c) async {
    final staged = _pdfStage;
    await _importMusicXml(
      presetPath: c.path,
      preferredId: staged?.scoreIdHint,
    );
  }

  void _showUnavailableHint() {
    final tool = widget.tool;
    final body = switch (tool.id) {
      WorkshopToolId.importOther =>
        'MXL 请直接使用「导入 MusicXML」。其余专用格式后续扩展。',
      _ => '「${tool.title}」请用上方对应入口；详见控制台 [PianoFlow/Workshop]。',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body)));
    setState(() => _status = body);
  }

  Future<void> _editMetadata(SongSummary song) async {
    final titleCtrl = TextEditingController(text: song.title);
    final artistCtrl = TextEditingController(text: song.artist);
    final bpmCtrl = TextEditingController(text: '${song.bpm}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑自导入元数据'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '仅改标题 / 艺术家 / BPM，不改记谱。质量档仍为自导入。',
                style: AppTheme.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              TextField(
                controller: artistCtrl,
                decoration: const InputDecoration(labelText: '艺术家'),
              ),
              TextField(
                controller: bpmCtrl,
                decoration: const InputDecoration(labelText: 'BPM'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final bpm = int.tryParse(bpmCtrl.text.trim());
    if (bpm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BPM 须为数字')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在保存元数据…';
    });
    try {
      await UserImportStore().updateUserMetadata(
        id: song.id,
        title: titleCtrl.text,
        artist: artistCtrl.text,
        bpm: bpm,
      );
      ref.invalidate(catalogProvider);
      await _reloadUserSongs();
      setState(() => _status = '已更新「${titleCtrl.text.trim()}」（仍为自导入）');
    } catch (e, st) {
      pianoFlowLog('Workshop', 'metadata edit failed: $e\n$st');
      final msg = e is StateError ? e.message : '保存失败：$e';
      setState(() => _status = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteUserScore(SongSummary song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除自导入？'),
        content: Text('将删除「${song.title}」及其本地 JSON / MusicXML。曲库打包曲目不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _status = '正在删除…';
    });
    try {
      await UserImportStore().deleteUserScore(song.id);
      await ref.read(userLibraryProvider.notifier).forgetSong(song.id);
      ref.invalidate(catalogProvider);
      await _reloadUserSongs();
      setState(() {
        _status = '已删除 ${song.id}';
        if (_lastScoreId == song.id) _lastScoreId = null;
      });
    } catch (e, st) {
      pianoFlowLog('Workshop', 'delete failed: $e\n$st');
      final msg = e is StateError ? e.message : '删除失败：$e';
      setState(() => _status = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openExternal(SongSummary song) async {
    setState(() => _busy = true);
    try {
      final msg = await WorkshopExternalEditor.openMusicXml(song.id);
      setState(() => _status = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      pianoFlowLog('Workshop', 'external open UI failed: $e\n$st');
      final msg = e is StateError ? e.message : '打开失败：$e';
      setState(() => _status = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tool.title,
            style: AppTheme.display(fontSize: 22, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(
            _detailBody(tool.id),
            style: AppTheme.body(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (_honestyBanner(tool.id) != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _honestyBanner(tool.id)!,
                style: AppTheme.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (tool.id == WorkshopToolId.importAudio) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '尝试 Demucs 分轨',
                style: AppTheme.body(fontSize: 14, color: AppColors.textPrimary),
              ),
              subtitle: Text(
                '默认开：本机有 demucs 则先取伴奏轨再转录；无则跳过并标「未分轨直转录」',
                style: AppTheme.body(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              value: _useDemucs,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _useDemucs = v),
            ),
          ],
          if (tool.id == WorkshopToolId.pdfToScore) ...[
            const SizedBox(height: 12),
            ...WorkshopPdfGuide.chineseSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  step,
                  style: AppTheme.body(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                color: AppColors.accent,
              ),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(
              _status!,
              style: AppTheme.body(
                fontSize: 13,
                color: AppColors.accent,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (tool.id != WorkshopToolId.editScore)
                FilledButton(
                  onPressed: _busy ? null : () => _onPrimary(tool),
                  child: Text(_busy ? '处理中…' : _primaryLabel(tool)),
                ),
              if (tool.id == WorkshopToolId.editScore)
                OutlinedButton(
                  onPressed: _busy ? null : _reloadUserSongs,
                  child: const Text('刷新列表'),
                ),
              if (tool.id == WorkshopToolId.pdfToScore) ...[
                TextButton(
                  onPressed: _busy ? null : _stagePdf,
                  child: const Text('仅暂存 PDF（分步）'),
                ),
              ],
              if (tool.id == WorkshopToolId.pdfToScore && _pdfStage != null) ...[
                OutlinedButton(
                  onPressed: _busy ? null : _launchOmr,
                  child: const Text('尝试启动 OMR 脚本'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _scanOmrOutputs,
                  child: const Text('扫描 OMR 输出'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => context.go(
                            '/workshop?tool=${WorkshopToolId.importMusicXml.name}',
                          ),
                  child: const Text('手动导入 MusicXML'),
                ),
              ],
              if (_lastScoreId != null) ...[
                OutlinedButton(
                  onPressed: () => context.push('/practice/$_lastScoreId'),
                  child: const Text('打开练习'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/library'),
                  child: const Text('打开曲库'),
                ),
              ],
            ],
          ),
          if (tool.id == WorkshopToolId.pdfToScore &&
              _omrCandidates.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '检测到的 MusicXML',
              style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._omrCandidates.map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.preferred ? '★ ${c.label}' : c.label,
                        style: AppTheme.body(fontSize: 13),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _busy ? null : () => _importOmrCandidate(c),
                      child: const Text('一键导入自导入'),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (tool.id == WorkshopToolId.editScore) ...[
            const SizedBox(height: 16),
            _buildUserImportList(),
          ],
        ],
      ),
    );
  }

  Widget _buildUserImportList() {
    if (!_userSongsLoaded) {
      return Text(
        '加载自导入列表…',
        style: AppTheme.body(fontSize: 13, color: AppColors.textSecondary),
      );
    }
    if (_userSongs.isEmpty) {
      return Text(
        '尚无自导入曲目。请先用「导入 MusicXML / MIDI / 音频」或 PDF 流程入库。',
        style: AppTheme.body(fontSize: 13, color: AppColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '我的自导入（${_userSongs.length}）',
          style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ..._userSongs.map((s) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.id} · ${s.artist} · ${s.bpm} BPM · ${s.scoreKindLabelDetail}',
                  style: AppTheme.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => context.push('/practice/${s.id}'),
                      child: const Text('打开练习'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => context.push('/workshop/edit-notes/${s.id}'),
                      child: const Text('编辑音符'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _editMetadata(s),
                      child: const Text('改元数据'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _openExternal(s),
                      child: const Text('外部打开 MusicXML'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _deleteUserScore(s),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _onPrimary(WorkshopTool tool) {
    switch (tool.id) {
      case WorkshopToolId.importMusicXml:
        _importMusicXml();
      case WorkshopToolId.importMidi:
        _importMidi();
      case WorkshopToolId.importAudio:
        _importAudio();
      case WorkshopToolId.pdfToScore:
        _pdfOneShotToPractice();
      case WorkshopToolId.editScore:
        _reloadUserSongs();
      case WorkshopToolId.importOther:
        _showUnavailableHint();
    }
  }

  static String _primaryLabel(WorkshopTool tool) {
    switch (tool.id) {
      case WorkshopToolId.importMusicXml:
        return '选择 MusicXML 文件';
      case WorkshopToolId.importMidi:
        return '选择 MIDI';
      case WorkshopToolId.importAudio:
        return '选择音频';
      case WorkshopToolId.pdfToScore:
        return 'PDF 一键成谱并练习';
      case WorkshopToolId.editScore:
        return '刷新自导入列表';
      case WorkshopToolId.importOther:
        return '查看格式说明';
    }
  }

  static String? _honestyBanner(WorkshopToolId id) {
    switch (id) {
      case WorkshopToolId.importMidi:
        return '质量说明：${WorkshopMidiImporter.honestyDescription}';
      case WorkshopToolId.importAudio:
        return '质量说明：${WorkshopAudioImporter.honestyDescription}';
      case WorkshopToolId.pdfToScore:
        return '流程可用。${SongSummary.omrHonestyNotice}'
            '入库为自导入/OMR 质量档，未校对不会标成正式谱。';
      case WorkshopToolId.importMusicXml:
        return SongSummary.userImportHonestyNotice;
      case WorkshopToolId.editScore:
        return '自导入可编辑：① 元数据（标题/艺术家/BPM）② 钢琴卷帘可视化改音高/拍/手（保存写回 JSON+MusicXML）'
            '③ 外部打开 MusicXML ④ 删除。质量档仍为自导入；不是 MuseScore 级排版编辑器。';
      case WorkshopToolId.importOther:
        return null;
    }
  }

  static String _detailBody(WorkshopToolId id) {
    switch (id) {
      case WorkshopToolId.pdfToScore:
        return '流程：选 PDF → 启动本机 OMR（omr-from-pdf.ps1 / Audiveris）→ '
            '自动扫描导入 → 进练习。可跟弹；质量档为自导入/OMR，未校对不标正式谱。'
            '也可下方分步：仅暂存 / 启动 OMR / 扫描。';
      case WorkshopToolId.editScore:
        return '管理本机自导入：改元数据、打开「编辑音符」钢琴卷帘改音高/拍/手并保存、'
            '外部打开 MusicXML、删除、打开练习。仅编辑自导入曲目。';
      case WorkshopToolId.importMusicXml:
        return '选择本机 .musicxml / .xml / .mxl，转换为跟弹 JSON 并写入曲库。'
            '需要本机 Python 与仓库 scripts/musicxml_to_score.py；'
            '写入后可跟弹；质量档为自导入。成功后自动进入练习。';
      case WorkshopToolId.importMidi:
        return '选择 .mid / .midi，转换后写入曲库并可练习。'
            '适合节奏/音高跟弹参考；未校对精确谱请勿当作教材级正式谱。'
            '成功后自动进入练习。';
      case WorkshopToolId.importAudio:
        return '选择 wav/mp3 等，本机 Basic Pitch ONNX 转录后入库并进练习；'
            '可选 Demucs 分轨（无则跳过并标注）。短钢琴片段目标数秒。'
            '需 Python + onnxruntime。可跟弹；质量档为自导入。';
      case WorkshopToolId.importOther:
        return '压缩的 MusicXML（.mxl）已由「导入 MusicXML」支持；'
            '点此仅作指引，请改用 MusicXML 入口。';
    }
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
