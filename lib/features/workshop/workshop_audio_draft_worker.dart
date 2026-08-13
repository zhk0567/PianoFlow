import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../shared/piano_flow_log.dart';
import 'workshop_import_common.dart';

/// Long-lived Python + ORT session for audio→practice drafts (warm re-imports).
class WorkshopAudioDraftWorker {
  WorkshopAudioDraftWorker._();
  static final WorkshopAudioDraftWorker instance = WorkshopAudioDraftWorker._();

  Process? _proc;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Completer<Map<String, dynamic>>? _pending;
  Completer<void>? _ready;
  Future<void>? _startFuture;
  void Function(String line)? _onProgress;

  Future<void> ensureStarted({void Function(String line)? onProgress}) {
    _onProgress = onProgress;
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    final repo = await WorkshopImportCommon.findRepoRoot();
    if (repo == null) {
      throw StateError(
        '找不到仓库脚本 scripts/audio_to_practice_draft.py（请从项目目录启动 App）',
      );
    }
    final python = await WorkshopImportCommon.findPython();
    if (python == null) {
      throw StateError('未找到 Python，请安装并加入 PATH 后重试');
    }
    final script = p.join(repo.path, 'scripts', 'audio_to_practice_draft.py');
    final args = <String>[
      ...WorkshopImportCommon.pythonArgPrefix(python),
      script,
      '--serve',
    ];
    pianoFlowLog('Workshop', 'audio draft worker starting…');
    final ready = Completer<void>();
    _ready = ready;
    final proc = await Process.start(
      python,
      args,
      workingDirectory: repo.path,
      runInShell: false,
    );
    _proc = proc;
    _stdoutSub = proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onStdoutLine, onError: (Object e) {
      pianoFlowLog('Workshop', 'worker stdout error: $e');
    });
    _stderrSub = proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final t = line.trim();
      if (t.isEmpty) return;
      pianoFlowLog('Workshop', t);
      _onProgress?.call(t);
    });
    unawaited(proc.exitCode.then((code) {
      pianoFlowLog('Workshop', 'audio draft worker exited code=$code');
      _failPending('worker 已退出 ($code)');
      _reset();
    }));
    await ready.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        throw StateError('音频草稿 worker 启动超时（ORT 加载）');
      },
    );
    pianoFlowLog('Workshop', 'audio draft worker ready');
  }

  void _onStdoutLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return;
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      pianoFlowLog('Workshop', t);
      _onProgress?.call(t);
      return;
    }
    if (json == null) return;
    if (json['ready'] == true && _ready != null && !_ready!.isCompleted) {
      _ready!.complete();
      return;
    }
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(json);
      _pending = null;
      return;
    }
    pianoFlowLog('Workshop', 'worker unexpected: $t');
  }

  void _failPending(String msg) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError(msg));
      _pending = null;
    }
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(StateError(msg));
    }
  }

  void _reset() {
    _proc = null;
    _startFuture = null;
    _ready = null;
    unawaited(_stdoutSub?.cancel());
    unawaited(_stderrSub?.cancel());
    _stdoutSub = null;
    _stderrSub = null;
  }

  Future<Map<String, dynamic>> transcribe({
    required String inputPath,
    required String userImportDir,
    required String scoreId,
    String? title,
    double hopSec = 0.4,
    double maxSec = 45,
    bool emphasizePiano = false,
    bool useDemucs = true,
    void Function(String line)? onProgress,
  }) async {
    await ensureStarted(onProgress: onProgress);
    _onProgress = onProgress;
    if (_proc == null) {
      throw StateError('音频草稿 worker 未运行');
    }
    if (_pending != null) {
      throw StateError('上一次音频转录尚未完成');
    }
    final completer = Completer<Map<String, dynamic>>();
    _pending = completer;
    final req = <String, dynamic>{
      'cmd': 'transcribe',
      'input': inputPath,
      'user_import_dir': userImportDir,
      'id': scoreId,
      'hop_sec': hopSec,
      'max_sec': maxSec,
      'emphasize_piano': emphasizePiano,
      'demucs': useDemucs,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
    };
    _proc!.stdin.writeln(jsonEncode(req));
    await _proc!.stdin.flush();
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pending = null;
        throw StateError('音频转录超时');
      },
    );
  }

  Future<void> dispose() async {
    try {
      if (_proc != null) {
        _proc!.stdin.writeln(jsonEncode({'cmd': 'quit'}));
        await _proc!.stdin.flush();
      }
    } catch (_) {}
    try {
      _proc?.kill();
    } catch (_) {}
    _failPending('worker disposed');
    _reset();
  }
}
