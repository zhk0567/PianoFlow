import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/piano_flow_log.dart';
import '../../shared/theme/app_theme.dart';
import '../library/library_repository.dart';
import 'workshop_musicxml_import.dart';
import 'workshop_tools.dart';

/// Score import / edit workshop — left-rail tab「工坊」.
class WorkshopPage extends ConsumerWidget {
  const WorkshopPage({super.key, this.initialTool});

  final WorkshopToolId? initialTool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        WorkshopTool.byId(initialTool ?? WorkshopToolId.pdfToScore) ??
            WorkshopTool.all.first;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return ColoredBox(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 960 : 880),
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
                '把 PDF、MusicXML 等变成可跟弹的曲谱，并在入库前完成校对。',
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
                              tool.available ? '可用' : '筹备中',
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

  Future<void> _importMusicXml() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '选择文件…';
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['musicxml', 'xml', 'mxl'],
        dialogTitle: '选择 MusicXML / MXL',
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _status = '已取消');
        return;
      }
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        throw StateError('无法读取所选文件路径');
      }
      setState(() => _status = '正在转换…');
      final msg = await WorkshopMusicXmlImporter.importFile(inputPath: path);
      ref.invalidate(catalogProvider);
      setState(() => _status = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e, st) {
      pianoFlowLog('Workshop', 'import UI failed: $e\n$st');
      final msg = e is StateError ? e.message : '导入失败：$e';
      setState(() => _status = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
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
          FilledButton(
            onPressed: _busy
                ? null
                : () {
                    if (tool.id == WorkshopToolId.importMusicXml &&
                        tool.available) {
                      _importMusicXml();
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tool.available
                              ? '正在打开：${tool.title}'
                              : '「${tool.title}」正在筹备，请先用命令行导入脚本（见曲谱导入 SOP）',
                        ),
                      ),
                    );
                  },
            child: Text(
              _busy
                  ? '处理中…'
                  : (tool.id == WorkshopToolId.importMusicXml && tool.available
                      ? '选择 MusicXML 文件'
                      : (tool.available ? '开始' : '了解流程')),
            ),
          ),
        ],
      ),
    );
  }

  static String _detailBody(WorkshopToolId id) {
    switch (id) {
      case WorkshopToolId.pdfToScore:
        return '流程：PDF → OMR 识别 → 人工校对 MusicXML → 入库。'
            '未校对结果只能标为「OMR草稿」，不可冒充正式谱。';
      case WorkshopToolId.editScore:
        return '在 App 内修正错音、时值与小节结构，保存后同步练习用 JSON 与 MusicXML。';
      case WorkshopToolId.importMusicXml:
        return '选择本机 .musicxml / .xml / .mxl，转换为跟弹 JSON 并写入「自导入」曲库。'
            '需要本机 Python 与仓库 scripts/musicxml_to_score.py；'
            '自导入不会标为正式谱。';
      case WorkshopToolId.importMidi:
        return 'MIDI 仅作节奏与音高草稿。正式精确谱禁止用 MIDI→MusicXML 冒充。';
      case WorkshopToolId.importOther:
        return '压缩包 MusicXML（MXL）等格式将逐步接入；当前请解压后按 MusicXML 导入。';
    }
  }
}
