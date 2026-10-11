import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../library/user_import_store.dart';
import 'practice_constants.dart';
import 'staff/score_to_musicxml.dart';
import 'verovio_transport_sync.dart';
import 'verovio_web_host.dart';
import 'verovio_web_host_factory.dart';

void _verovioLog(String message) => pianoFlowLog('Verovio', message);

void _verovioLogVerbose(String message) =>
    pianoFlowLogVerbose('Verovio', message);

/// Bridge only failures / empty-staff / exceptions — not engrave OK chatter.
bool _jsMessageWorthLogging(String raw) {
  final s = raw.toLowerCase();
  if (s.isEmpty) return false;
  if (s.contains('"type":"ready"') || s.contains("'type':'ready'")) {
    return false;
  }
  const keys = [
    'fail',
    'error',
    'exception',
    'empty',
    'false',
    '失败',
    '为空',
    '缺少',
  ];
  for (final k in keys) {
    if (s.contains(k)) return true;
  }
  return false;
}


/// Process-wide Verovio WebView + WASM runtime (Windows WebView2 / Android System WebView).
///
/// Serves viewer assets + MusicXML over localhost HTTP (file:// XHR is
/// unreliable). Practice pages call [pushScore] / [pushResize] / [pushPosition].
class VerovioRuntime {
  VerovioRuntime._();
  static final VerovioRuntime instance = VerovioRuntime._();

  final VerovioWebHost host = createVerovioWebHost();

  Future<void>? _readyFuture;
  bool _toolkitReady = false;
  String? _loadedViewerStamp;
  String? lastScoreKey;
  Size? lastViewport;
  bool scoreLoaded = false;

  /// Bumps on every full score load / switch so stale HTTP polls cannot commit.
  int _loadEpoch = 0;
  int get loadEpoch => _loadEpoch;

  double? _queuedBeats;
  bool _queuedSnap = false;
  double? _queuedRate;
  bool _positionPushing = false;
  double _lastPushedBeats = double.nan;
  double _lastPushedRate = double.nan;

  final Map<String, String> _musicXmlCache = {};

  String? _viewerDir;
  HttpServer? _httpServer;
  int? _httpPort;
  StreamSubscription<String>? _webMessageSub;

  bool get isToolkitReady => _toolkitReady;

  void prewarm() {
    if (!verovioPlatformSupported) return;
    unawaited(ensureReady());
  }

  Future<void> ensureReady() {
    if (!verovioPlatformSupported) {
      return Future.error(
        StateError('Verovio 仅支持 Windows / Android'),
      );
    }
    return _readyFuture ??= () async {
      try {
        await _init();
      } catch (e, st) {
        _verovioLog('ensureReady FAILED: $e\n$st');
        _readyFuture = null;
        _toolkitReady = false;
        rethrow;
      }
    }();
  }

  Future<void> reloadViewer() async {
    _readyFuture = null;
    _toolkitReady = false;
    scoreLoaded = false;
    lastScoreKey = null;
    lastViewport = null;
    _loadedViewerStamp = null;
    _loadEpoch++;
    _resetPositionTracking();
    await ensureReady();
  }

  void _resetPositionTracking() {
    _lastPushedBeats = double.nan;
    _lastPushedRate = double.nan;
    _queuedBeats = null;
    _queuedSnap = false;
    _queuedRate = null;
  }

  /// Call before loading a different song so the old SVG/playhead cannot linger.
  Future<void> beginScoreSwitch({String? reason}) async {
    _loadEpoch++;
    scoreLoaded = false;
    lastScoreKey = null;
    _resetPositionTracking();
      _verovioLogVerbose('beginScoreSwitch epoch=$_loadEpoch ${reason ?? ""}');
    if (!_toolkitReady) return;
    try {
      await host.runJs(
        'typeof pfClearScore==="function"&&pfClearScore();',
      );
    } catch (e) {
      _verovioLog('pfClearScore skipped: $e');
    }
  }

  Future<void> _ensureHttpServer(String dir) async {
    if (_httpServer != null && _httpPort != null) return;
    final root = p.normalize(dir);
    _httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _httpPort = _httpServer!.port;
    _verovioLogVerbose('HTTP server on http://127.0.0.1:$_httpPort/ root=$root');
    unawaited(() async {
      await for (final req in _httpServer!) {
        try {
          var rel = Uri.decodeComponent(req.uri.path);
          if (rel.startsWith('/')) rel = rel.substring(1);
          if (rel.isEmpty) rel = 'viewer.html';
          final full = p.normalize(p.join(root, rel));
          // Avoid path traversal; prefer startsWith over isWithin for Windows drives.
          if (!_isPathInsideRoot(root, full)) {
            req.response.statusCode = 403;
            await req.response.close();
            continue;
          }
          final file = File(full);
          if (!await file.exists()) {
            _verovioLog('HTTP 404 $rel');
            req.response.statusCode = 404;
            await req.response.close();
            continue;
          }
          final lower = full.toLowerCase();
          if (lower.endsWith('.html')) {
            req.response.headers.contentType = ContentType.html;
          } else if (lower.endsWith('.js')) {
            req.response.headers.contentType =
                ContentType('application', 'javascript', charset: 'utf-8');
          } else if (lower.endsWith('.musicxml') || lower.endsWith('.xml')) {
            req.response.headers.contentType =
                ContentType('application', 'xml', charset: 'utf-8');
          } else if (lower.endsWith('.wasm')) {
            req.response.headers.contentType =
                ContentType('application', 'wasm');
          }
          req.response.headers.set('Cache-Control', 'no-store');
          await req.response.addStream(file.openRead());
          await req.response.close();
        } catch (e) {
          _verovioLog('HTTP serve error: $e');
          try {
            req.response.statusCode = 500;
            await req.response.close();
          } catch (closeErr) {
            _verovioLog('HTTP response close after 500 failed: $closeErr');
          }
        }
      }
    }());
  }

  Future<void> _init() async {
    await host.initialize();

    _webMessageSub ??= host.messages.listen(
      (msg) {
        final s = msg;
        if (_jsMessageWorthLogging(s)) {
          _verovioLog('JS: $s');
        }
      },
      onError: (Object e) => _verovioLog('JS webMessage error: $e'),
    );

    final prepared = await prepareLocalViewer();
    final dir = prepared.path;
    final stamp = prepared.stamp;
    _viewerDir = dir;
    await _ensureHttpServer(dir);

    final needReload = _loadedViewerStamp != stamp || !_toolkitReady;
    if (needReload) {
      final url =
          'http://127.0.0.1:$_httpPort/viewer.html?v=${Uri.encodeQueryComponent(stamp)}';
      _verovioLogVerbose('Loading viewer $url');
      await host.loadUrl(url);
      _toolkitReady = false;
      scoreLoaded = false;
      lastScoreKey = null;
      _loadedViewerStamp = stamp;
    }

    for (var i = 0; i < 120; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        final ready = await host.runJs('window.pfReady()');
        if (ready == true ||
            ready == 'true' ||
            ready?.toString() == 'true') {
          _toolkitReady = true;
          _verovioLogVerbose('toolkit ready');
          return;
        }
      } catch (e) {
        if (i == 0 || i % 20 == 19) {
          _verovioLog('pfReady poll #$i: $e');
        }
      }
    }
    throw StateError(
      'Verovio 未就绪。请确认 assets/verovio/verovio-toolkit-wasm.js 完整（见 docs/五线谱.md）',
    );
  }

  static Future<({String path, String stamp})> prepareLocalViewer() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}piano_flow_verovio',
    );
    if (!await dir.exists()) await dir.create(recursive: true);

    final htmlAsset = await rootBundle.load('assets/verovio/viewer.html');
    late final ByteData wasmAsset;
    try {
      wasmAsset =
          await rootBundle.load('assets/verovio/verovio-toolkit-wasm.js');
    } catch (e) {
      _verovioLog('missing verovio-toolkit-wasm.js: $e');
      throw StateError(
        '缺少 assets/verovio/verovio-toolkit-wasm.js，请运行 scripts/download-verovio.ps1',
      );
    }

    // v72: staff glyphs stay at native page px (诀别书). Crop no longer
    // squeezes short scores by crop/page.
    final stamp = '${htmlAsset.lengthInBytes}:${wasmAsset.lengthInBytes}:v72';
    final marker = File('${dir.path}${Platform.pathSeparator}.asset_stamp');
    final htmlOut = File('${dir.path}${Platform.pathSeparator}viewer.html');
    final wasmOut = File(
      '${dir.path}${Platform.pathSeparator}verovio-toolkit-wasm.js',
    );

    final existing =
        await marker.exists() ? (await marker.readAsString()).trim() : '';
    if (existing == stamp && await htmlOut.exists() && await wasmOut.exists()) {
      return (path: dir.path, stamp: stamp);
    }

    await htmlOut.writeAsBytes(
      htmlAsset.buffer.asUint8List(
        htmlAsset.offsetInBytes,
        htmlAsset.lengthInBytes,
      ),
      flush: true,
    );
    await wasmOut.writeAsBytes(
      wasmAsset.buffer.asUint8List(
        wasmAsset.offsetInBytes,
        wasmAsset.lengthInBytes,
      ),
      flush: true,
    );
    await marker.writeAsString(stamp, flush: true);
    return (path: dir.path, stamp: stamp);
  }

  static String musicXmlCacheKey(String songId, Hand hand) =>
      '$songId|${hand.name}';

  static String scoreKey(SongScore score, Hand hand, {String layout = 'strip'}) =>
      '${score.id}|${hand.name}|$layout';

  /// Practice strip layout (default) or full-score paged browse.
  static Map<String, dynamic> layoutOpts(
    Size viewport, {
    int? bpm,
    String layoutMode = 'strip',
  }) {
    const scale = PracticeConstants.verovioScale;
    // pageHeight is a Verovio layout ceiling (adjustPageHeight shrinks to content).
    // Note CSS size comes from engraver [scale], not from stretching to [h].
    final h = viewport.height.clamp(260.0, 900.0);
    final w = viewport.width.clamp(200.0, 4000.0);
    if (layoutMode == 'paged') {
      final browseH = viewport.height.clamp(400.0, 1600.0);
      final browseW = viewport.width.clamp(280.0, 2400.0);
      return {
        'bpm': ?bpm,
        'cssWidth': browseW.round(),
        'cssHeight': browseH.round(),
        'scale': scale,
        'layoutMode': 'paged',
        'pageWidth': (browseW * 100 / scale).round().clamp(1200, 4000),
        'pageHeight': (browseH * 100 / scale).round().clamp(1600, 6000),
      };
    }
    return {
      'bpm': ?bpm,
      'cssWidth': w.round(),
      'cssHeight': h.round(),
      'scale': scale,
      'layoutMode': 'strip',
      'pageHeight': (h * 100 / scale).round().clamp(450, 4000),
    };
  }

  Future<String> resolveMusicXml(SongScore score, Hand hand) async {
    final key = musicXmlCacheKey(score.id, hand);
    final hit = _musicXmlCache[key];
    if (hit != null) return hit;
    final xml = await _loadMusicXml(score, hand);
    _musicXmlCache[key] = xml;
    return xml;
  }

  /// Packaged / user MusicXML for full-score engraving (prefer over JSON→XML).
  Future<String> resolveEngravingMusicXml(SongScore score) async {
    final cacheKey = 'engrave|${score.id}';
    final hit = _musicXmlCache[cacheKey];
    if (hit != null) return hit;

    for (final path in [
      'assets/scores/musicxml/${score.id}.musicxml',
      'assets/scores/musicxml/${score.id}.xml',
    ]) {
      try {
        final xml = await rootBundle.loadString(path);
        if (xml.trim().length > 32) {
          _musicXmlCache[cacheKey] = xml;
          _verovioLogVerbose('engrave MusicXML from $path chars=${xml.length}');
          return xml;
        }
      } catch (_) {
        // try next
      }
    }

    try {
      final file = await UserImportPaths.musicXml(score.id);
      if (await file.exists()) {
        final xml = await file.readAsString();
        if (xml.trim().length > 32) {
          _musicXmlCache[cacheKey] = xml;
          _verovioLogVerbose(
            'engrave MusicXML from userImport chars=${xml.length}',
          );
          return xml;
        }
      }
    } catch (e) {
      _verovioLogVerbose('userImport MusicXML skip: $e');
    }

    // Dev-only third_party source (not packaged).
    try {
      final candidates = [
        p.join('third_party', 'scores_musicxml', '${score.id}.musicxml'),
        p.join('third_party', 'scores_musicxml', '${score.id}.xml'),
      ];
      for (final rel in candidates) {
        final f = File(rel);
        if (await f.exists()) {
          final xml = await f.readAsString();
          if (xml.trim().length > 32) {
            _musicXmlCache[cacheKey] = xml;
            _verovioLogVerbose('engrave MusicXML from $rel chars=${xml.length}');
            return xml;
          }
        }
      }
    } catch (e) {
      _verovioLogVerbose('third_party MusicXML skip: $e');
    }

    final fallback = await resolveMusicXml(score, Hand.both);
    _verovioLog(
      'engrave fallback SongScore→MusicXML id=${score.id} '
      '(no packaged MusicXML)',
    );
    return fallback;
  }

  Future<void> prefetchMusicXml(SongScore score, {Hand hand = Hand.both}) {
    return resolveMusicXml(score, hand);
  }

  /// Practice staff always engraves from [SongScore] (same notes/beats as
  /// waterfall + guide audio). Packaged MusicXML may expand repeats differently
  /// and must not drive the playhead clock.
  Future<String> _loadMusicXml(SongScore score, Hand hand) async {
    final xml = songScoreToMusicXml(score, hand: hand);
    _verovioLogVerbose(
      'musicXml hand=${hand.name} from SongScore notes='
      '${score.notesForHand(hand).length}',
    );
    return xml;
  }

  String _layoutMode = 'strip';
  String get layoutMode => _layoutMode;

  Future<void> pushScore({
    required SongScore score,
    required Hand hand,
    required Size viewport,
    String? musicXml,
    bool force = false,
    String layoutMode = 'strip',
  }) async {
    if (!_toolkitReady) return;
    final key = scoreKey(score, hand, layout: layoutMode);
    if (!force && key == lastScoreKey && scoreLoaded) {
      final prev = lastViewport;
      if (prev != null &&
          (prev.width - viewport.width).abs() < 16 &&
          (prev.height - viewport.height).abs() < 16) {
        return;
      }
      await pushResize(viewport, layoutMode: layoutMode);
      return;
    }

    final epoch = ++_loadEpoch;
    var ownedEpoch = epoch;
    // Mark unloaded immediately so pushPosition cannot steer the previous piece.
    scoreLoaded = false;
    lastScoreKey = null;
    _layoutMode = layoutMode;
    _resetPositionTracking();

    // Practice + full-score browse share SongScore→MusicXML (waterfall clock).
    final xml = musicXml ?? await resolveMusicXml(score, hand);
    if (ownedEpoch != _loadEpoch) {
      _verovioLog('pushScore aborted (stale after resolve) epoch=$ownedEpoch');
      return;
    }
    final opts = jsonEncode(
      layoutOpts(
        viewport,
        bpm: score.bpm,
        layoutMode: layoutMode,
      ),
    );
    _verovioLogVerbose(
      'pushScore id=${score.id} layout=$layoutMode epoch=$ownedEpoch '
      'xmlChars=${xml.length} '
      'viewport=${viewport.width.toStringAsFixed(0)}x${viewport.height.toStringAsFixed(0)}',
    );

    await _loadScoreXml(xml, opts, epoch: ownedEpoch);
    if (ownedEpoch != _loadEpoch) {
      _verovioLog('pushScore aborted (stale after load) epoch=$ownedEpoch');
      return;
    }

    var info = await _scoreInfo();
    _verovioLogVerbose('after load info=$info');
    if (!_infoHasNotes(info)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (ownedEpoch != _loadEpoch) return;
      info = await _scoreInfo();
      _verovioLog('retry info=$info');
    }
    if (!_infoHasNotes(info)) {
      _verovioLog('reloadViewer + retry');
      await reloadViewer();
      ownedEpoch = _loadEpoch;
      _layoutMode = layoutMode;
      await _loadScoreXml(xml, opts, epoch: ownedEpoch);
      if (ownedEpoch != _loadEpoch) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (ownedEpoch != _loadEpoch) return;
      info = await _scoreInfo();
      _verovioLog('after reload info=$info');
    }
    if (ownedEpoch != _loadEpoch) {
      _verovioLog('pushScore skip commit stale epoch=$ownedEpoch');
      return;
    }
    if (!_infoHasNotes(info)) {
      final detail = info == null ? 'no-info' : jsonEncode(info);
      _verovioLog('FAIL staff empty detail=$detail');
      throw StateError('五线谱渲染为空（$detail）');
    }

    _verovioLogVerbose(
      'pushScore OK layout=$layoutMode notes=${info?['notes']} '
      'htmlLen=${info?['htmlLen']}',
    );
    scoreLoaded = true;
    lastScoreKey = key;
    lastViewport = viewport;
    _layoutMode = layoutMode;
  }

  bool _infoHasNotes(Map<String, dynamic>? info) {
    if (info == null) return false;
    if (info['ready'] == false) return false;
    final notes = info['notes'];
    if (notes is num && notes > 0) return true;
    final htmlLen = info['htmlLen'];
    if (htmlLen is num && htmlLen > 5000) return true;
    return false;
  }

  /// True when [full] is [root] or a file under it (case-insensitive on Windows).
  static bool _isPathInsideRoot(String root, String full) {
    final r = p.normalize(root);
    final f = p.normalize(full);
    if (p.equals(r, f)) return true;
    try {
      if (p.isWithin(r, f)) return true;
    } catch (e) {
      _verovioLog('path isWithin failed root=$r full=$f: $e');
    }
    // Fallback when isWithin is picky about separators / drive letters.
    final rs = r.replaceAll('/', '\\').toLowerCase();
    final fs = f.replaceAll('/', '\\').toLowerCase();
    if (fs == rs) return true;
    final prefix = rs.endsWith('\\') ? rs : '$rs\\';
    return fs.startsWith(prefix);
  }

  Future<void> _loadScoreXml(
    String xml,
    String optsJson, {
    required int epoch,
  }) async {
    final dir = _viewerDir;
    final port = _httpPort;
    if (dir == null || port == null) {
      throw StateError('Verovio HTTP server not ready');
    }
    final file = File(p.join(dir, 'current_score.musicxml'));
    await file.writeAsString(xml, flush: true);
    if (epoch != _loadEpoch) return;
    final url =
        'http://127.0.0.1:$port/current_score.musicxml?t=${DateTime.now().millisecondsSinceEpoch}';
    _verovioLogVerbose(
      'pfLoadFromUrl $url bytes=${xml.length} epoch=$epoch',
    );

    // Async fetch path (preferred over sync XHR). Never let a missing JS
    // helper abort before the sync fallback.
    try {
      final result = await host.runJs(
        'pfLoadFromUrlAsync(${jsonEncode(url)}, $optsJson)',
      );
      _verovioLogVerbose('pfLoadFromUrlAsync scheduled result=$result');
    } catch (e) {
      _verovioLog('pfLoadFromUrlAsync exception: $e');
    }

    // Poll until ready/notes or timeout (~8s).
    for (var i = 0; i < 40; i++) {
      if (epoch != _loadEpoch) {
        _verovioLog('load poll aborted stale epoch=$epoch');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final info = await _scoreInfo();
      if (_infoHasNotes(info)) {
        _verovioLogVerbose('load OK via HTTP poll #$i info=$info');
        return;
      }
      if (info != null && info['loadErr'] != null) {
        _verovioLog('loadErr=${info['loadErr']}');
        break;
      }
    }

    if (epoch != _loadEpoch) return;

    // Sync fallback.
    try {
      final sync = await host.runJs(
        'pfLoadFromUrl(${jsonEncode(url)}, $optsJson);',
      );
      _verovioLogVerbose('pfLoadFromUrl sync result=$sync');
    } catch (e) {
      _verovioLog('sync load exception: $e');
    }
  }

  Future<Map<String, dynamic>?> _scoreInfo() async {
    try {
      final raw = await host.runJs('window.pfScoreInfo()');
      if (raw == null) return null;
      var s = raw is String ? raw : raw.toString();
      if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
        s = jsonDecode(s) as String;
      }
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      _verovioLog('_scoreInfo parse error: $e');
    }
    return null;
  }

  /// Cropped strip height in CSS px (one grand staff). 0 / missing → null.
  Future<double?> stripInkHeight() async {
    final info = await _scoreInfo();
    final raw = info?['inkHeight'];
    if (raw is num && raw >= 80) return raw.toDouble();
    return null;
  }

  Future<void> pushResize(
    Size viewport, {
    String? layoutMode,
  }) async {
    if (!_toolkitReady || !scoreLoaded) return;
    final mode = layoutMode ?? _layoutMode;
    final prev = lastViewport;
    if (prev != null &&
        (prev.width - viewport.width).abs() < 8 &&
        (prev.height - viewport.height).abs() < 8 &&
        mode == _layoutMode) {
      return;
    }
    final opts = jsonEncode(layoutOpts(viewport, layoutMode: mode));
    try {
      await host.runJs('pfResize($opts);');
      lastViewport = viewport;
      _layoutMode = mode;
    } catch (e) {
      _verovioLog('pfResize script failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> pageInfo() async {
    if (!_toolkitReady) return null;
    try {
      final raw = await host.runJs('window.pfPageInfo()');
      if (raw == null) return null;
      var s = raw is String ? raw : raw.toString();
      if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
        s = jsonDecode(s) as String;
      }
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      _verovioLog('pageInfo parse error: $e');
    }
    return null;
  }

  Future<bool> setBrowsePage(int page) async {
    if (!_toolkitReady || !scoreLoaded) return false;
    try {
      final raw = await host.runJs('window.pfSetPage($page)');
      return raw == true || raw == 'true' || raw == 1;
    } catch (e) {
      _verovioLog('setBrowsePage failed: $e');
      return false;
    }
  }

  Future<bool> nextBrowsePage() async {
    if (!_toolkitReady || !scoreLoaded) return false;
    try {
      final raw = await host.runJs('window.pfNextPage()');
      return raw == true || raw == 'true' || raw == 1;
    } catch (e) {
      _verovioLog('nextBrowsePage failed: $e');
      return false;
    }
  }

  Future<bool> prevBrowsePage() async {
    if (!_toolkitReady || !scoreLoaded) return false;
    try {
      final raw = await host.runJs('window.pfPrevPage()');
      return raw == true || raw == 'true' || raw == 1;
    } catch (e) {
      _verovioLog('prevBrowsePage failed: $e');
      return false;
    }
  }

  Future<void> pushPosition(
    double beats, {
    bool snap = false,
    double? beatsPerSec,
  }) async {
    if (!_toolkitReady || !scoreLoaded) return;
    if (_layoutMode == 'paged') return;
    final rate = beatsPerSec;
    final sameBeats = _lastPushedBeats.isFinite &&
        (beats - _lastPushedBeats).abs() < 0.002;
    final sameRate = rate == null
        ? true
        : (_lastPushedRate.isFinite && (rate - _lastPushedRate).abs() < 1e-6);
    if (!snap && sameBeats && sameRate) {
      return;
    }
    if (_positionPushing) {
      _queuedBeats = beats;
      _queuedSnap = _queuedSnap || snap;
      if (rate != null) _queuedRate = rate;
      return;
    }
    _positionPushing = true;
    try {
      var b = beats;
      var s = snap;
      double? r = rate;
      while (true) {
        final rateArg = r != null ? ', $r' : '';
        var delivered = false;
        final sw = Stopwatch()..start();
        try {
          await host.runJs(
            'pfSetPosition($b, ${s ? 'true' : 'false'}$rateArg);',
          );
          delivered = true;
        } catch (e) {
          _verovioLog(
            VerovioTransportSync.positionPushFailedLog(
              beats: b,
              snap: s,
              error: e,
            ),
          );
        }
        sw.stop();
        if (sw.elapsedMilliseconds >= 25) {
          _verovioLogVerbose(
            'pushPosition rttMs=${sw.elapsedMilliseconds} '
            'beats=${b.toStringAsFixed(3)} snap=$s',
          );
        }
        if (delivered) {
          _lastPushedBeats = b;
          if (r != null) _lastPushedRate = r;
        }
        if (_queuedBeats == null) break;
        b = _queuedBeats!;
        s = _queuedSnap;
        r = _queuedRate ?? r;
        _queuedBeats = null;
        _queuedSnap = false;
        _queuedRate = null;
      }
    } finally {
      _positionPushing = false;
    }
    // Race: a push may enqueue after the while-drain but before the flag clears.
    // Re-enter so the latest beats/rate are never dropped (dropped syncs → staff lag).
    if (_queuedBeats != null) {
      final b = _queuedBeats!;
      final s = _queuedSnap;
      final r = _queuedRate;
      _queuedBeats = null;
      _queuedSnap = false;
      _queuedRate = null;
      await pushPosition(b, snap: s, beatsPerSec: r);
    }
  }

  bool hasScoreFor(SongScore score, Hand hand, {String layout = 'strip'}) {
    return scoreLoaded && lastScoreKey == scoreKey(score, hand, layout: layout);
  }
}
