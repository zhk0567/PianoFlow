import 'dart:io';

import 'package:path/path.dart' as p;

import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';
import 'workshop_import_common.dart';

/// PDF → OMR → scan → import staging (never formal).
abstract final class WorkshopPdfGuide {
  static const chineseSteps = [
    '① 选择 PDF（一键：暂存 → 启动本机 OMR → 自动扫描导入 → 进练习）',
    '② 依赖仓库 scripts/omr-from-pdf.ps1 与本机 Audiveris',
    '③ 可跟弹入库（自导入/OMR 质量档）；未校对不会标成正式谱',
    '④ 也可分步：暂存 → 启动 OMR → 扫描 → 导入',
  ];

  static const defaultPollTimeout = Duration(minutes: 4);
  static const defaultPollInterval = Duration(seconds: 3);

  /// How many poll attempts fit in [timeout] at [interval] (min 1).
  static int pollAttempts({
    Duration timeout = defaultPollTimeout,
    Duration interval = defaultPollInterval,
  }) {
    if (interval.inMilliseconds <= 0) return 1;
    final n = (timeout.inMilliseconds / interval.inMilliseconds).ceil();
    return n < 1 ? 1 : n;
  }

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
      guidance: 'PDF 已暂存。一键流水线将启动 OMR 并自动扫描导入并可练习'
          '（质量档为自导入/OMR，未校对不标正式谱）。',
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
          '一键流水线将自动扫描输出。';
    } catch (e, st) {
      pianoFlowLog('Workshop', 'OMR launch failed: $e\n$st');
      return '无法自动启动 OMR。请在仓库根目录手动执行：\n${staged.omrCommand}';
    }
  }

  /// Poll until MusicXML appears or [timeout]. [delay] injectable for tests.
  static Future<List<WorkshopOmrCandidate>> pollOmrUntilFound({
    required String scoreIdHint,
    String? repoRoot,
    Duration timeout = defaultPollTimeout,
    Duration interval = defaultPollInterval,
    Future<void> Function(Duration d)? delay,
    Future<List<WorkshopOmrCandidate>> Function()? scanOnce,
    void Function(int attempt, int total)? onPoll,
  }) async {
    final wait = delay ?? Future<void>.delayed;
    final scan = scanOnce ??
        () => findOmrMusicXml(scoreIdHint: scoreIdHint, repoRoot: repoRoot);
    final attempts = pollAttempts(timeout: timeout, interval: interval);
    for (var i = 0; i < attempts; i++) {
      onPoll?.call(i + 1, attempts);
      final found = await scan();
      if (found.isNotEmpty) return found;
      if (i + 1 < attempts) await wait(interval);
    }
    return const [];
  }

  /// One-shot: stage → launch OMR → poll → return candidates (never formal).
  static Future<WorkshopPdfOneShotResult> runOneShotPipeline({
    required String pdfPath,
    void Function(String status)? onProgress,
    Duration timeout = defaultPollTimeout,
    Duration interval = defaultPollInterval,
    Future<void> Function(Duration d)? delay,
  }) async {
    onProgress?.call('正在暂存 PDF…');
    final staged = await stagePdf(pdfPath: pdfPath);
    if (!staged.hasOmrScript) {
      return WorkshopPdfOneShotResult(
        staged: staged,
        candidates: const [],
        ok: false,
        message: '未找到 scripts/omr-from-pdf.ps1。'
            '请安装/配置 Audiveris 脚本后重试，或手动 OMR 后「扫描 OMR 输出」。',
      );
    }
    onProgress?.call('正在启动本机 OMR…');
    final launchMsg = await tryLaunchOmr(staged: staged);
    onProgress?.call(launchMsg);
    onProgress?.call('等待 OMR 输出（最长约 ${timeout.inMinutes} 分钟）…');
    final found = await pollOmrUntilFound(
      scoreIdHint: staged.scoreIdHint,
      repoRoot: staged.repoRoot,
      timeout: timeout,
      interval: interval,
      delay: delay,
      onPoll: (i, total) {
        onProgress?.call('等待 OMR 输出… ($i/$total)');
      },
    );
    if (found.isEmpty) {
      final hint = staged.omrWorkDir ?? '_omr_work/…';
      return WorkshopPdfOneShotResult(
        staged: staged,
        candidates: const [],
        ok: false,
        message: '超时未找到 MusicXML。请确认 Audiveris 已跑完，输出目录：\n$hint'
            '\n也可稍后点「扫描 OMR 输出」。',
      );
    }
    return WorkshopPdfOneShotResult(
      staged: staged,
      candidates: found,
      ok: true,
      message: '找到 ${found.length} 个 MusicXML，将导入并可练习（自导入/OMR 质量档）。',
    );
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

class WorkshopPdfOneShotResult {
  const WorkshopPdfOneShotResult({
    required this.staged,
    required this.candidates,
    required this.ok,
    required this.message,
  });

  final WorkshopPdfStageResult staged;
  final List<WorkshopOmrCandidate> candidates;
  final bool ok;
  final String message;

  WorkshopOmrCandidate? get preferred =>
      candidates.isEmpty ? null : candidates.first;
}
