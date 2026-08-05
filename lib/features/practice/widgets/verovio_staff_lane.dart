import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../shared/models/song.dart';
import '../../../shared/piano_flow_log.dart';
import '../practice_clock.dart';
import '../verovio_runtime.dart';
import '../verovio_transport_sync.dart';

/// Verovio-engraved staff (MusicXML). Falls back to generated MusicXML from [SongScore].
///
/// Relies on [VerovioRuntime] singleton — does not recreate WebView/WASM per visit.
///
/// Prefer [clock] for live playhead: listens + throttled pushPosition without
/// rebuilding this widget at 60 Hz (WebView2 rebuild storms freeze the UI).
class VerovioStaffLane extends StatefulWidget {
  const VerovioStaffLane({
    super.key,
    required this.score,
    required this.hand,
    this.clock,
    this.positionBeats = 0,
    this.isPlaying = false,
    this.beatsPerSec = 0,
  });

  final SongScore score;
  final Hand hand;

  /// When set, live beats/rate come from this listenable (not parent rebuilds).
  final PracticeClock? clock;

  final double positionBeats;
  final bool isPlaying;
  final double beatsPerSec;

  @override
  State<VerovioStaffLane> createState() => _VerovioStaffLaneState();
}

class _VerovioStaffLaneState extends State<VerovioStaffLane> {
  final _runtime = VerovioRuntime.instance;

  bool _bound = false;
  bool _pushing = false;
  bool _disposed = false;
  bool _switching = false;
  String? _error;
  Size _viewport = const Size(800, 340);
  Size _heldSize = const Size(800, 340);
  Size? _pendingViewport;
  Timer? _resizeDebounce;
  Timer? _posThrottle;
  double? _pendingPosBeats;
  double? _pendingPosRate;
  bool _pendingPosSnap = false;
  bool _posGateOpen = true;
  Future<String>? _xmlFuture;
  int? _scheduledConstraintHash;
  _PendingScorePush? _pendingScorePush;
  /// Set when resize arrives during [_pushing]; flushed after the busy op ends.
  bool _pendingResize = false;

  double _lastHeardBeats = 0;
  double _lastHeardRate = 0;
  int _lastSeekEpoch = 0;

  static const _resizeSlop = 16.0;
  static const _resizeDebounceMs = 450;
  /// Anchor pushes only (~8 Hz). Motion continues via JS extrapolation.
  static const _posThrottleMs = 125;

  double get _liveBeats =>
      widget.clock?.positionBeats ?? widget.positionBeats;

  double get _transportRate {
    if (!widget.isPlaying) return 0;
    final r = widget.clock?.beatsPerSec ?? widget.beatsPerSec;
    return r.clamp(0.0, 40.0);
  }

  @override
  void initState() {
    super.initState();
    _lastHeardBeats = _liveBeats;
    _lastHeardRate = _transportRate;
    _lastSeekEpoch = widget.clock?.seekEpoch ?? 0;
    if (!Platform.isWindows) {
      _error = 'Verovio 谱面目前仅支持 Windows';
      return;
    }
    _runtime.controller.addListener(_onController);
    widget.clock?.addListener(_onClock);
    // Parallel: MusicXML read + toolkit ensure (often already prewarmed).
    _xmlFuture = _runtime.resolveMusicXml(widget.score, widget.hand);
    if (_runtime.isToolkitReady) {
      _bound = true;
      if (_runtime.hasScoreFor(widget.score, widget.hand)) {
        unawaited(
          _runtime.pushPosition(
            _liveBeats,
            snap: true,
            beatsPerSec: _transportRate,
          ),
        );
      }
    }
    unawaited(_bind());
  }

  void _onClock() {
    if (_disposed || !mounted) return;
    final beats = _liveBeats;
    final rate = _transportRate;
    final epoch = widget.clock?.seekEpoch ?? _lastSeekEpoch;
    final seek = VerovioTransportSync.shouldSnapForEpoch(
      previousEpoch: _lastSeekEpoch,
      currentEpoch: epoch,
    );
    final posDelta =
        VerovioTransportSync.positionDelta(_lastHeardBeats, beats);
    final rateDelta =
        VerovioTransportSync.rateDelta(_lastHeardRate, rate);
    if (!seek &&
        VerovioTransportSync.shouldSkipPush(
          posDelta: posDelta,
          playChanged: false,
          rateDelta: rateDelta,
        )) {
      return;
    }
    _lastHeardBeats = beats;
    _lastHeardRate = rate;
    _lastSeekEpoch = epoch;
    _schedulePosition(beats, snap: seek, rate: rate);
  }

  void _onController() {
    // Only refresh chrome while binding/switching — avoid setState storms
    // whenever WebView2 fires controller notifications during playback.
    if (!_bound || _switching) {
      if (mounted) setState(() {});
    }
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
          _liveBeats,
          snap: true,
          beatsPerSec: _transportRate,
        );
      } else {
        if (mounted) setState(() => _switching = true);
        await _runtime.beginScoreSwitch(reason: 'bind ${widget.score.id}');
      }
      // Always force-load: cached blank SVG must not short-circuit paint.
      await _pushScore(musicXml: xml, force: true);
    } catch (e) {
      if (_disposed || !mounted) return;
      pianoFlowLog('Verovio', 'staff lane bind failed: $e');
      setState(() => _error = '五线谱引擎初始化失败（详情见控制台 [PianoFlow/Verovio]）');
    }
  }

  Future<void> _pushScore({String? musicXml, bool force = false}) async {
    if (!_runtime.isToolkitReady || _disposed) return;
    if (_pushing) {
      // Never drop a song/hand switch — keep the latest request.
      _pendingScorePush = _PendingScorePush(
        musicXml: musicXml,
        force: force,
        score: widget.score,
        hand: widget.hand,
      );
      return;
    }
    _pushing = true;
    try {
      do {
        final pending = _pendingScorePush;
        _pendingScorePush = null;
        final score = pending?.score ?? widget.score;
        final hand = pending?.hand ?? widget.hand;
        final xml = pending?.musicXml ?? musicXml;
        final doForce = pending?.force ?? force;
        await _runtime.pushScore(
          score: score,
          hand: hand,
          viewport: _viewport,
          musicXml: xml,
          force: doForce,
        );
        if (_disposed) return;
        await _runtime.pushPosition(
          _liveBeats,
          snap: true,
          beatsPerSec: _transportRate,
        );
        if (mounted) {
          setState(() {
            _switching = false;
            _error = null;
          });
        }
      } while (_pendingScorePush != null && !_disposed);
    } catch (e, st) {
      pianoFlowLog('Verovio', '加载乐谱失败: $e\n$st');
      if (mounted) {
        setState(() {
          _switching = false;
          _error = '加载乐谱失败（详情见控制台 [PianoFlow/Verovio]）';
        });
      }
    } finally {
      _pushing = false;
      if (_pendingScorePush != null && !_disposed) {
        unawaited(_pushScore(
          musicXml: _pendingScorePush!.musicXml,
          force: _pendingScorePush!.force,
        ));
      } else if (_pendingResize && !_disposed) {
        _pendingResize = false;
        unawaited(_pushResize());
      }
    }
  }

  Future<void> _pushResize() async {
    if (!_runtime.isToolkitReady || _disposed) return;
    if (VerovioTransportSync.shouldDeferResize(pushing: _pushing)) {
      _pendingResize = true;
      pianoFlowLogVerbose('Verovio', 'resize deferred (push in flight)');
      return;
    }
    _pushing = true;
    _pendingResize = false;
    try {
      await _runtime.pushResize(_viewport);
      if (_disposed) return;
      await _runtime.pushPosition(
        _liveBeats,
        snap: true,
        beatsPerSec: _transportRate,
      );
    } catch (e, st) {
      // Viewer without pfResize (stale cache) — full push as fallback.
      pianoFlowLog(
        'Verovio',
        '${VerovioTransportSync.resizeFallbackLog(e)}\n$st',
      );
      await _pushScore(force: true);
    } finally {
      _pushing = false;
      if (_pendingScorePush != null && !_disposed) {
        unawaited(_pushScore(
          musicXml: _pendingScorePush!.musicXml,
          force: _pendingScorePush!.force,
        ));
      } else if (_pendingResize && !_disposed) {
        _pendingResize = false;
        unawaited(_pushResize());
      }
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
    if (oldWidget.clock != widget.clock) {
      oldWidget.clock?.removeListener(_onClock);
      widget.clock?.addListener(_onClock);
    }

    if (oldWidget.score.id != widget.score.id ||
        oldWidget.hand != widget.hand) {
      _posThrottle?.cancel();
      _posThrottle = null;
      _pendingPosBeats = null;
      _pendingPosRate = null;
      _pendingPosSnap = false;
      _posGateOpen = true;
      _xmlFuture = _runtime.resolveMusicXml(widget.score, widget.hand);
      setState(() {
        _switching = true;
        _error = null;
      });
      unawaited(() async {
        await _runtime.beginScoreSwitch(
          reason: '${oldWidget.score.id}->${widget.score.id}',
        );
        final xml = await _xmlFuture!;
        if (!_disposed && mounted) {
          await _pushScore(musicXml: xml, force: true);
        }
      }());
      return;
    }

    // Live beats/rate from [clock] — never drive pushPosition via 60 Hz rebuilds.
    if (widget.clock != null) {
      final playChanged = oldWidget.isPlaying != widget.isPlaying;
      if (playChanged) {
        final beats = _liveBeats;
        final rate = _transportRate;
        _lastHeardBeats = beats;
        _lastHeardRate = rate;
        _schedulePosition(beats, snap: false, rate: rate);
      }
      return;
    }

    final posDelta = VerovioTransportSync.positionDelta(
      oldWidget.positionBeats,
      widget.positionBeats,
    );
    final playChanged = oldWidget.isPlaying != widget.isPlaying;
    final rateDelta = VerovioTransportSync.rateDelta(
      oldWidget.beatsPerSec,
      widget.beatsPerSec,
    );

    if (VerovioTransportSync.shouldSkipPush(
      posDelta: posDelta,
      playChanged: playChanged,
      rateDelta: rateDelta,
    )) {
      return;
    }

    final seek = VerovioTransportSync.shouldSnapSeek(posDelta);
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
    widget.clock?.removeListener(_onClock);
    _resizeDebounce?.cancel();
    _posThrottle?.cancel();
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

    // Spinner while WASM cold-starts or song switch clears the previous SVG.
    final showSpinner =
        (!_runtime.isToolkitReady && !_bound) || _switching;

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

class _PendingScorePush {
  const _PendingScorePush({
    required this.score,
    required this.hand,
    this.musicXml,
    this.force = false,
  });

  final SongScore score;
  final Hand hand;
  final String? musicXml;
  final bool force;
}
