import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../shared/models/song.dart';
import '../verovio_runtime.dart';

/// Verovio-engraved staff (MusicXML). Falls back to generated MusicXML from [SongScore].
///
/// Relies on [VerovioRuntime] singleton — does not recreate WebView/WASM per visit.
class VerovioStaffLane extends StatefulWidget {
  const VerovioStaffLane({
    super.key,
    required this.score,
    required this.positionBeats,
    required this.hand,
    this.isPlaying = false,
    this.beatsPerSec = 0,
  });

  final SongScore score;
  final double positionBeats;
  final Hand hand;

  /// When false, viewer must freeze (rate 0) even if [positionBeats] is unchanged.
  final bool isPlaying;

  /// Transport rate in quarter-notes per second (bpm/60*speed while playing).
  final double beatsPerSec;

  @override
  State<VerovioStaffLane> createState() => _VerovioStaffLaneState();
}

class _VerovioStaffLaneState extends State<VerovioStaffLane> {
  final _runtime = VerovioRuntime.instance;

  bool _bound = false;
  bool _pushing = false;
  bool _disposed = false;
  String? _error;
  Size _viewport = const Size(800, 288);
  Size _heldSize = const Size(800, 288);
  Size? _pendingViewport;
  Timer? _resizeDebounce;
  Timer? _posThrottle;
  Timer? _playHeartbeat;
  double? _pendingPosBeats;
  double? _pendingPosRate;
  bool _pendingPosSnap = false;
  bool _posGateOpen = true;
  Future<String>? _xmlFuture;
  int? _scheduledConstraintHash;

  static const _resizeSlop = 16.0;
  static const _resizeDebounceMs = 450;
  /// Viewer free-runs on Dart rate; sparse hard-corrects avoid WebView2 bridge pile-up
  /// (dense executeScript was the main cause of staff lag / "越来越慢").
  static const _posThrottleMs = 100;
  /// Slow tempos can move < [_posMinDelta] per engine tick — heartbeat resyncs beats.
  static const _posMinDelta = 0.01;
  static const _playHeartbeatMs = 400;

  double get _transportRate =>
      widget.isPlaying ? widget.beatsPerSec.clamp(0.0, 40.0) : 0.0;

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) {
      _error = 'Verovio 谱面目前仅支持 Windows';
      return;
    }
    _runtime.controller.addListener(_onController);
    // Parallel: MusicXML read + toolkit ensure (often already prewarmed).
    _xmlFuture = _runtime.resolveMusicXml(widget.score, widget.hand);
    if (_runtime.isToolkitReady) {
      _bound = true;
      if (_runtime.hasScoreFor(widget.score, widget.hand)) {
        unawaited(
          _runtime.pushPosition(
            widget.positionBeats,
            snap: true,
            beatsPerSec: _transportRate,
          ),
        );
      }
    }
    unawaited(_bind());
    _syncPlayHeartbeat();
  }

  void _syncPlayHeartbeat() {
    _playHeartbeat?.cancel();
    _playHeartbeat = null;
    if (!widget.isPlaying || _transportRate <= 0 || _disposed) return;
    _playHeartbeat = Timer.periodic(
      const Duration(milliseconds: _playHeartbeatMs),
      (_) {
        if (_disposed || !mounted || !widget.isPlaying) return;
        unawaited(
          _runtime.pushPosition(
            widget.positionBeats,
            snap: false,
            beatsPerSec: _transportRate,
          ),
        );
      },
    );
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  Future<void> _bind() async {
    try {
      final xmlFuture = _xmlFuture ??=
          _runtime.resolveMusicXml(widget.score, widget.hand);
      final results = await Future.wait<Object?>([
        _runtime.ensureReady(),
        xmlFuture,
      ]);
      if (_disposed || !mounted) return;
      final xml = results[1] as String;
      setState(() {
        _bound = true;
        _error = null;
      });

      final sameScore = _runtime.hasScoreFor(widget.score, widget.hand);
      if (sameScore) {
        await _runtime.pushPosition(
          widget.positionBeats,
          snap: true,
          beatsPerSec: _transportRate,
        );
      }
      // Always force-load: cached blank SVG must not short-circuit paint.
      await _pushScore(musicXml: xml, force: true);
    } catch (e) {
      if (_disposed || !mounted) return;
      // ignore: avoid_print
      print('[PianoFlow/Verovio] staff lane bind failed: $e');
      debugPrint('[PianoFlow/Verovio] staff lane bind failed: $e');
      setState(() => _error = 'WebView2 / Verovio 初始化失败：$e');
    }
  }

  Future<void> _pushScore({String? musicXml, bool force = false}) async {
    if (!_runtime.isToolkitReady || _disposed || _pushing) return;
    _pushing = true;
    try {
      await _runtime.pushScore(
        score: widget.score,
        hand: widget.hand,
        viewport: _viewport,
        musicXml: musicXml,
        force: force,
      );
      if (_disposed) return;
      await _runtime.pushPosition(
        widget.positionBeats,
        snap: true,
        beatsPerSec: _transportRate,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[PianoFlow/Verovio] 加载乐谱失败: $e');
      // ignore: avoid_print
      print('[PianoFlow/Verovio] $st');
      debugPrint('[PianoFlow/Verovio] 加载乐谱失败: $e\n$st');
      if (mounted) setState(() => _error = '加载乐谱失败：$e');
    } finally {
      _pushing = false;
    }
  }

  Future<void> _pushResize() async {
    if (!_runtime.isToolkitReady || _disposed || _pushing) return;
    _pushing = true;
    try {
      await _runtime.pushResize(_viewport);
      if (_disposed) return;
      await _runtime.pushPosition(
        widget.positionBeats,
        snap: true,
        beatsPerSec: _transportRate,
      );
    } catch (_) {
      // Viewer without pfResize (stale cache) — full push as fallback.
      await _pushScore(force: true);
    } finally {
      _pushing = false;
    }
  }

  Size _quantize(Size s) =>
      Size(s.width.roundToDouble(), s.height.roundToDouble());

  void _onViewport(Size raw) {
    final next = _quantize(raw);
    if (next.width < 8 || next.height < 8) return;

    // Before first score paint: adopt lane size immediately (no debounce flash).
    if (!_runtime.scoreLoaded) {
      if ((next.width - _viewport.width).abs() >= 1 ||
          (next.height - _viewport.height).abs() >= 1) {
        _viewport = next;
        _heldSize = next;
        if (mounted) setState(() {});
      }
      return;
    }

    if ((next.width - _heldSize.width).abs() < 1 &&
        (next.height - _heldSize.height).abs() < 1) {
      return;
    }

    _pendingViewport = next;

    _resizeDebounce?.cancel();
    _resizeDebounce =
        Timer(const Duration(milliseconds: _resizeDebounceMs), () {
      if (_disposed || !mounted) return;
      final applied = _pendingViewport ?? next;
      final bigEnough = (applied.width - _viewport.width).abs() >= _resizeSlop ||
          (applied.height - _viewport.height).abs() >= _resizeSlop;
      _viewport = applied;
      _heldSize = applied;
      setState(() {});
      if (bigEnough && _runtime.isToolkitReady) {
        unawaited(_pushResize());
      }
    });
  }

  @override
  void didUpdateWidget(covariant VerovioStaffLane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score.id != widget.score.id ||
        oldWidget.hand != widget.hand) {
      _xmlFuture = _runtime.resolveMusicXml(widget.score, widget.hand);
      unawaited(() async {
        final xml = await _xmlFuture!;
        if (!_disposed && mounted) {
          await _pushScore(musicXml: xml, force: true);
        }
      }());
      return;
    }

    final posDelta =
        (oldWidget.positionBeats - widget.positionBeats).abs();
    final playChanged = oldWidget.isPlaying != widget.isPlaying;
    final rateDelta =
        (oldWidget.beatsPerSec - widget.beatsPerSec).abs();

    // Pause/resume must push even when positionBeats is unchanged — otherwise
    // the viewer keeps extrapolating (or stays frozen) after transport stops.
    if (!playChanged && posDelta <= _posMinDelta && rateDelta <= 0.01) return;

    _syncPlayHeartbeat();

    // Snap only on real seeks / large jumps — not on play/pause alone.
    // Rate-only updates must ease so start does not flash scroll.
    final seek = posDelta > 0.35;
    _schedulePosition(
      widget.positionBeats,
      snap: seek,
      rate: _transportRate,
    );
  }

  void _schedulePosition(
    double beats, {
    required bool snap,
    required double rate,
  }) {
    if (snap) {
      _posThrottle?.cancel();
      _posThrottle = null;
      _pendingPosBeats = null;
      _pendingPosRate = null;
      _pendingPosSnap = false;
      _posGateOpen = true;
      unawaited(
        _runtime.pushPosition(beats, snap: true, beatsPerSec: rate),
      );
      return;
    }
    if (!_posGateOpen) {
      _pendingPosBeats = beats;
      _pendingPosRate = rate;
      _pendingPosSnap = _pendingPosSnap || snap;
      return;
    }
    _posGateOpen = false;
    unawaited(
      _runtime.pushPosition(beats, snap: false, beatsPerSec: rate),
    );
    _posThrottle = Timer(const Duration(milliseconds: _posThrottleMs), () {
      if (_disposed) return;
      _posGateOpen = true;
      final b = _pendingPosBeats;
      final r = _pendingPosRate ?? _transportRate;
      final s = _pendingPosSnap;
      _pendingPosBeats = null;
      _pendingPosRate = null;
      _pendingPosSnap = false;
      if (b != null) _schedulePosition(b, snap: s, rate: r);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _resizeDebounce?.cancel();
    _posThrottle?.cancel();
    _playHeartbeat?.cancel();
    _runtime.controller.removeListener(_onController);
    // Do NOT dispose shared WebviewController — kept warm for next visit.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ColoredBox(
        color: const Color(0xFFFFFBF5),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF664422), fontSize: 13),
            ),
          ),
        ),
      );
    }

    if (!Platform.isWindows) {
      return const ColoredBox(
        color: Color(0xFFFFFBF5),
        child: Center(child: Text('Verovio 谱面仅 Windows')),
      );
    }

    // Spinner only while WASM cold-starts. Warm toolkit → show WebView immediately
    // (cached SVG or cream page) without a long blank spinner.
    final showSpinner = !_runtime.isToolkitReady && !_bound;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xFFFFFBF5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = Size(constraints.maxWidth, constraints.maxHeight);
            final hash = Object.hash(box.width.round(), box.height.round());
            if (_scheduledConstraintHash != hash) {
              _scheduledConstraintHash = hash;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _onViewport(box);
              });
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                if (_runtime.controller.value.isInitialized)
                  Positioned.fill(
                    child: Webview(
                      _runtime.controller,
                      permissionRequested:
                          (url, kind, isUserInitiated) async =>
                              WebviewPermissionDecision.deny,
                    ),
                  ),
                if (showSpinner)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
