import 'dart:io';

import 'package:path/path.dart' as p;

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';
import 'workshop_import_common.dart';

/// PDF → OMR guided staging (does NOT mark formal; does not claim OMR finished).
abstract final class WorkshopPdfGuide {
  static const chineseSteps = [
    '① 选择 PDF，暂存到本机「自导入」目录的 pdf_inbox',
    '② 用本仓库 OMR 脚本或 Audiveris 识别（结果仅为草稿）',
    '③ 对照 PDF 人工校对 MusicXML（未校对禁止标正式谱）',
    '④ 点「扫描 OMR 输出」或「导入 MusicXML」写入自导入曲库',
  ];

  /// Copy PDF into user `pdf_inbox/` and return staging info + suggested commands.
  static Future<WorkshopPdfStageResult> stagePdf({
    required String pdfPath,
    String? preferredId,
  }) async {
    final src = File(pdfPath);
    if (!await src.exists()) {
      throw StateError('找不到 PDF：$pdfPath');
    }
    final root = await UserImportPaths.rootDir();
    final inbox = Directory(p.join(root.path, 'pdf_inbox'));
    if (!await inbox.exists()) {
      await inbox.create(recursive: true);
    }

    final id = preferredId?.trim().isNotEmpty == true
        ? WorkshopImportCommon.slugFromPath(preferredId!, prefix: 'user_')
        : WorkshopImportCommon.slugFromPath(pdfPath, prefix: 'user_pdf_');

    final dest = File(p.join(inbox.path, '$id.pdf'));
    await src.copy(dest.path);
    pianoFlowLog('Workshop', 'PDF staged → ${dest.path}');

    final repo = await WorkshopImportCommon.findRepoRoot();
    final hasOmrScript = repo != null &&
        await File(p.join(repo.path, 'scripts', 'omr-from-pdf.ps1')).exists();

    final omrCmd = hasOmrScript
        ? '.\\scripts\\omr-from-pdf.ps1 -Id $id -Pdf "${dest.path}"'
        : '(仓库内暂无 omr-from-pdf.ps1 — 请用 Audiveris 等 OMR 工具导出 MusicXML)';

    final workHint = repo == null
        ? null
        : p.join(
            repo.path,
            'third_party',
            'scores_musicxml',
            '_omr_work',
            id,
          );

    return WorkshopPdfStageResult(
      scoreIdHint: id,
      stagedPdfPath: dest.path,
      repoRoot: repo?.path,
      omrWorkDir: workHint,
      omrCommand: omrCmd,
      hasOmrScript: hasOmrScript,
      guidance: 'PDF 已暂存。请按步骤：OMR → 校对 → 扫描/导入 MusicXML 为「自导入」'
          '（未校对绝不能标正式谱）。',
    );
  }

  /// Best-effort: launch PowerShell OMR helper if Audiveris script exists.
  /// Returns a Chinese status; does not wait for OMR to finish.
  static Future<String> tryLaunchOmr({
    required WorkshopPdfStageResult staged,
  }) async {
    if (!staged.hasOmrScript || staged.repoRoot == null) {
      return '本机未找到 omr-from-pdf.ps1，请手动 OMR 后导入 MusicXML';
    }
    final ps1 = p.join(staged.repoRoot!, 'scripts', 'omr-from-pdf.ps1');
    pianoFlowLog('Workshop', 'launching OMR helper: $ps1');
    try {
      await Process.start(
        'powershell',
        [
          '-NoExit',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          ps1,
          '-Id',
          staged.scoreIdHint,
          '-Pdf',
          staged.stagedPdfPath,
        ],
        workingDirectory: staged.repoRoot,
        runInShell: false,
        mode: ProcessStartMode.detached,
      );
      return '已打开 PowerShell 运行 OMR 脚本（需本机 Audiveris）。'
          '完成后点「扫描 OMR 输出」再一键导入为自导入草稿。';
    } catch (e, st) {
      pianoFlowLog('Workshop', 'OMR launch failed: $e\n$st');
      return '无法自动启动 OMR。请在仓库根目录手动执行：\n${staged.omrCommand}';
    }
  }

  /// Look for Audiveris / omr-from-pdf outputs under `_omr_work/<id>/`.
  static Future<List<WorkshopOmrCandidate>> findOmrMusicXml({
    required String scoreIdHint,
    String? repoRoot,
  }) async {
    final root = repoRoot ?? (await WorkshopImportCommon.findRepoRoot())?.path;
    if (root == null) return const [];

    final work = Directory(
      p.join(root, 'third_party', 'scores_musicxml', '_omr_work', scoreIdHint),
    );
    if (!await work.exists()) {
      pianoFlowLog('Workshop', 'OMR work dir missing: ${work.path}');
      return const [];
    }

    final found = <File>[];
    Future<void> consider(File f) async {
      if (!await f.exists()) return;
      final ext = p.extension(f.path).toLowerCase();
      if (ext != '.musicxml' && ext != '.xml' && ext != '.mxl') return;
      found.add(f);
    }

    await consider(File(p.join(work.path, 'omr_draft.musicxml')));
    await consider(File(p.join(work.path, 'omr_draft.xml')));
    await consider(File(p.join(work.path, 'omr_draft.mxl')));
    await consider(File(p.join(work.path, 'corrected.musicxml')));

    Future<void> walk(Directory dir) async {
      if (!await dir.exists()) return;
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is File) await consider(ent);
      }
    }

    await walk(Directory(p.join(work.path, 'audiveris_out')));
    await walk(work);

    // Prefer canonical names, then newest mtime.
    final byPath = <String, File>{};
    for (final f in found) {
      byPath[p.normalize(f.path).toLowerCase()] = f;
    }
    final unique = byPath.values.toList();
    int rank(File f) {
      final name = p.basename(f.path).toLowerCase();
      if (name.startsWith('corrected')) return 0;
      if (name.startsWith('omr_draft')) return 1;
      return 2;
    }

    unique.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final am = a.statSync().modified;
      final bm = b.statSync().modified;
      return bm.compareTo(am);
    });

    final out = <WorkshopOmrCandidate>[];
    for (final f in unique) {
      out.add(
        WorkshopOmrCandidate(
          path: f.path,
          label: p.basename(f.path),
          preferred: out.isEmpty,
        ),
      );
    }
    pianoFlowLog(
      'Workshop',
      'OMR scan id=$scoreIdHint found=${out.length}',
    );
    return out;
  }
}

class WorkshopPdfStageResult {
  const WorkshopPdfStageResult({
    required this.scoreIdHint,
    required this.stagedPdfPath,
    required this.repoRoot,
    required this.omrCommand,
    required this.hasOmrScript,
    required this.guidance,
    this.omrWorkDir,
  });

  final String scoreIdHint;
  final String stagedPdfPath;
  final String? repoRoot;
  final String? omrWorkDir;
  final String omrCommand;
  final bool hasOmrScript;
  final String guidance;
}

class WorkshopOmrCandidate {
  const WorkshopOmrCandidate({
    required this.path,
    required this.label,
    required this.preferred,
  });

  final String path;
  final String label;
  final bool preferred;
}
