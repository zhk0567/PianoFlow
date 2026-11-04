import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/piano_flow_log.dart';
import '../practice_clock.dart';
import '../verovio_runtime.dart';
import '../verovio_transport_sync.dart';
import '../verovio_web_host_factory.dart';

/// Verovio-engraved staff (MusicXML). Falls back to generated MusicXML from [SongScore].
///
/// Always engraves **both** hands. Practice hand filter (左/右/双手) only affects
/// waterfall / matching / guide audio — not staff visibility.
///
/// Relies on [VerovioRuntime] singleton — does not recreate WebView/WASM per visit.
/// Transport follows [clock] so the parent scaffold is not rebuilt at ~60 Hz.
///
/// Horizontal drag on the staff scrubs [onSeek] (same path as the bottom SeekBar).
/// WebView pointer input is ignored so Flutter owns the gesture without fighting
/// programmatic follow-scroll inside the viewer.
class VerovioStaffLane extends StatefulWidget {
  const VerovioStaffLane({
    super.key,
    required this.score,
    required this.clock,
    required this.durationBeats,
    this.onSeek,
    this.allowsSeek = true,
    this.onInkHeight,
  });

  final SongScore score;
  final PracticeClock clock;

  /// Score length for clamp / fallback px-per-beat when JS metrics are unavailable.
  final double durationBeats;

  /// Same callback as bottom progress slider (`PracticeEngine.seek`).
  final ValueChanged<double>? onSeek;

  /// False in exam mode — drag is a no-op (matches SeekBar disabled).
  final bool allowsSeek;

  /// Cropped grand-staff height in CSS px (one engraved line, before lane fit).
  final ValueChanged<double>? onInkHeight;

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
  Future<String>? _xmlFuture;
  int? _scheduledConstraintHash;
  _PendingScorePush? _pendingScorePush;
  /// Set when resize arrives during [_pushing]; flushed after the busy op ends.
  bool _pendingResize = false;

  /// Staff scrub: accumulate from drag-start position; do not fight play follow-scroll
  /// (user drag → intentional seek / seekEpoch snap only).
  bool _scrubbing = false;
  double _scrubOriginBeats = 0;
  double _scrubAccumDx = 0;
  double _scrubPxPerBeat = 40;
  bool _scrubMetricsLoading = false;

  static const _resizeSlop = 16.0;
  static const _resizeDebounceMs = 450;
  /// One viewport ≈ this many beats when engraved width is unknown.
  static const _fallbackVisibleBeats = 12.0;
  static const _minPxPerBeat = 12.0;
  /// Shared clock with waterfall/audio: push only from PracticeClock.
  /// Runtime already coalesces in-flight pushes — no Timer gate here.

  double get _transportRate =>
      widget.clock.isPlaying
          ? widget.clock.beatsPerSec.clamp(0.0, 40.0)
          : 0.0;

  double get _positionBeats => widget.clock.positionBeats;

  @override
  void initState() {
    super.initState();
    if (!verovioPlatformSupported) {
      _error = 'Verovio 谱面目前仅支持 Windows / Android';
      return;
    }
    _runtime.host.addListener(_onController);
    widget.clock.addListener(_onClock);
    _lastClockPos = widget.clock.positionBeats;
    _lastClockPlaying = widget.clock.isPlaying;
    _lastClockRate = widget.clock.beatsPerSec;
    _lastSeekEpoch = widget.clock.seekEpoch;
    // Parallel: MusicXML read + toolkit ensure (often already prewarmed).
    // Staff always uses both hands so L/R practice mode never hides a stave.
    _xmlFuture = _runtime.resolveMusicXml(widget.score, Hand.both);
    if (_runtime.isToolkitReady) {
      _bound = true;
      if (_runtime.hasScoreFor(widget.score, Hand.both)) {
        unawaited(
          _runtime.pushPosition(
            _positionBeats,
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
    final pos = _positionBeats;
    final playing = widget.clock.isPlaying;
    final rate = _transportRate;
    final epoch = widget.clock.seekEpoch;
    final seek = VerovioTransportSync.shouldSnapForEpoch(
      previousEpoch: _lastSeekEpoch,
      currentEpoch: epoch,
    );
    final rateZeroCross = VerovioTransportSync.shouldSnapForRateZeroCrossing(
      previousRate: _lastClockRate,
      currentRate: rate,
    );
    // Freeze (rate→0): snap so wait-line does not ease with a stale sample.
    // Play / unfreeze (rate→positive): viewer already hard-tracks when
    // beatsPerSec>0 — avoid an extra forceSnap on every play press.
    final snapForFreeze = VerovioTransportSync.shouldSnapForFreezeRateCrossing(
      previousRate: _lastClockRate,
      currentRate: rate,
    );
    final posDelta = VerovioTransportSync.positionDelta(_lastClockPos, pos);
    final playChanged = playing != _lastClockPlaying;
    final rateDelta = VerovioTransportSync.rateDelta(_lastClockRate, rate);
    _lastClockPos = pos;
    _lastClockPlaying = playing;
    _lastClockRate = rate;
    _lastSeekEpoch = epoch;

    final forceImmediate = seek || snapForFreeze || rateZeroCross;
    if (!forceImmediate &&
        VerovioTransportSync.shouldSkipPush(
          posDelta: posDelta,
          playChanged: playChanged,
          rateDelta: rateDelta,
        )) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sincePush =
        _lastPushMs == 0 ? VerovioTransportSync.playPushMinIntervalMs : nowMs - _lastPushMs;
    if (VerovioTransportSync.shouldThrottlePlayPush(
      beatsPerSec: rate,
      msSinceLastPush: sincePush,
      posDelta: posDelta,
      playChanged: playChanged,
      forceImmediate: forceImmediate,
    )) {
      return;
    }
    _lastPushMs = nowMs;

    _schedulePosition(pos, snap: seek || snapForFreeze, rate: rate);
  }

  double _lastClockPos = 0;
  bool _lastClockPlaying = false;
  double _lastClockRate = 0;
  int _lastSeekEpoch = 0;
  int _lastPushMs = 0;

  void _onController() {
    if (mounted) setState(() {});
  }

  Future<void> _bind() async {
    try {
      final xmlFuture = _xmlFuture ??=
          _runtime.resolveMusicXml(widget.score, Hand.both);
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

      final sameScore = _runtime.hasScoreFor(widget.score, Hand.both);
      if (sameScore) {
        await _runtime.pushPosition(
          _positionBeats,
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
      // Never drop a song switch — keep the latest request.
      _pendingScorePush = _PendingScorePush(
        musicXml: musicXml,
        force: force,
        score: widget.score,
      );
      return;
    }
    _pushing = true;
    try {
      do {
        final pending = _pendingScorePush;
        _pendingScorePush = null;
        final score = pending?.score ?? widget.score;
        final xml = pending?.musicXml ?? musicXml;
        final doForce = pending?.force ?? force;
        await _runtime.pushScore(
          score: score,
          hand: Hand.both,
          viewport: _viewport,
          musicXml: xml,
          force: doForce,
        );
        if (_disposed) return;
        await _runtime.pushPosition(
          _positionBeats,
          snap: true,
          beatsPerSec: _transportRate,
        );
        if (mounted) {
          setState(() {
            _switching = false;
            _error = null;
          });
        }
        await _publishInk();
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
        _positionBeats,
        snap: true,
        beatsPerSec: _transportRate,
      );
      await _publishInk();
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

  Future<void> _publishInk() async {
    if (_disposed) return;
    final h = await _runtime.stripInkHeight();
    if (_disposed || !mounted || h == null) return;
    if (h < 80 || h > 480) return;
    widget.onInkHeight?.call(h);
  }

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
      // Avoid WebView rebuild flash on tiny layout jitter.
      if (!bigEnough) return;
      if (mounted) setState(() {});
      if (_runtime.isToolkitReady) {
        unawaited(_pushResize());
      }
    });
  }

  @override
  void didUpdateWidget(covariant VerovioStaffLane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock) {
      oldWidget.clock.removeListener(_onClock);
      widget.clock.addListener(_onClock);
      _lastClockPos = widget.clock.positionBeats;
      _lastClockPlaying = widget.clock.isPlaying;
      _lastClockRate = widget.clock.beatsPerSec;
    }
    // Hand filter changes must NOT reload / hide staves — only song switches.
    if (oldWidget.score.id != widget.score.id) {
      _xmlFuture = _runtime.resolveMusicXml(widget.score, Hand.both);
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
    }
  }

  void _schedulePosition(
    double beats, {
    required bool snap,
    required double rate,
  }) {
    // VerovioRuntime.pushPosition already queues latest while in-flight.
    unawaited(
      _runtime.pushPosition(beats, snap: snap, beatsPerSec: rate),
    );
  }

  double _fallbackPxPerBeat() {
    final w = _viewport.width;
    if (!(w > 8)) return 40;
    return (w / _fallbackVisibleBeats).clamp(_minPxPerBeat, 200.0);
  }

  Future<void> _refreshScrubMetrics() async {
    if (_scrubMetricsLoading || !_runtime.isToolkitReady || !_runtime.scoreLoaded) {
      return;
    }
    _scrubMetricsLoading = true;
    try {
      final raw = await _runtime.host.runJs('window.pfScrubMetrics()');
      if (raw == null || _disposed) return;
      var s = raw is String ? raw : raw.toString();
      if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
        s = jsonDecode(s) as String;
      }
      final decoded = jsonDecode(s);
      if (decoded is! Map) return;
      final contentW = (decoded['contentW'] as num?)?.toDouble() ?? 0;
      final endQ = (decoded['endQ'] as num?)?.toDouble() ?? 0;
      final dur = widget.durationBeats > 0.5
          ? widget.durationBeats
          : (endQ > 0.5 ? endQ : 0.0);
      if (contentW > 32 && dur > 0.5) {
        final next = (contentW / dur).clamp(_minPxPerBeat, 400.0);
        // Avoid mid-drag sensitivity jumps once the finger has moved.
        if (!_scrubbing || _scrubAccumDx.abs() < 2) {
          _scrubPxPerBeat = next;
        }
      }
    } catch (e) {
      pianoFlowLogVerbose('Verovio', 'pfScrubMetrics: $e');
    } finally {
      _scrubMetricsLoading = false;
    }
  }

  void _onScrubStart(DragStartDetails _) {
    if (!widget.allowsSeek || widget.onSeek == null) return;
    _scrubbing = true;
    _scrubOriginBeats = widget.clock.positionBeats;
    _scrubAccumDx = 0;
    _scrubPxPerBeat = _fallbackPxPerBeat();
    // Pause immediately on grab (same as bottom slider onChangeStart).
    if (widget.clock.isPlaying) {
      widget.onSeek!(_scrubOriginBeats);
    }
    unawaited(_refreshScrubMetrics());
  }

  void _onScrubUpdate(DragUpdateDetails details) {
    if (!_scrubbing || !widget.allowsSeek) return;
    final onSeek = widget.onSeek;
    if (onSeek == null) return;
    _scrubAccumDx += details.delta.dx;
    // Finger right → earlier music (grab score); matches timeline scrub feel.
    final px = _scrubPxPerBeat > 1 ? _scrubPxPerBeat : _fallbackPxPerBeat();
    final next = (_scrubOriginBeats - _scrubAccumDx / px)
        .clamp(0.0, widget.durationBeats <= 0 ? 1.0 : widget.durationBeats);
    onSeek(next);
  }

  void _onScrubEnd(DragEndDetails _) {
    if (!_scrubbing) return;
    _scrubbing = false;
    // Final snap already applied via last onSeek → seekEpoch.
  }

  void _onScrubCancel() {
    _scrubbing = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _resizeDebounce?.cancel();
    widget.clock.removeListener(_onClock);
    _runtime.host.removeListener(_onController);
    // Do NOT dispose shared WebView host — kept warm for next visit.
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

    if (!verovioPlatformSupported) {
      return const ColoredBox(
        color: Color(0xFFFFFBF5),
        child: Center(child: Text('Verovio 谱面仅 Windows / Android')),
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
                if (_runtime.host.isInitialized)
                  Positioned.fill(
                    // Staff SVG is display-only; Flutter owns horizontal scrub.
                    child: IgnorePointer(
                      child: _runtime.host.buildView(),
                    ),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart:
                        widget.allowsSeek && widget.onSeek != null
                            ? _onScrubStart
                            : null,
                    onHorizontalDragUpdate:
                        widget.allowsSeek && widget.onSeek != null
                            ? _onScrubUpdate
                            : null,
                    onHorizontalDragEnd:
                        widget.allowsSeek && widget.onSeek != null
                            ? _onScrubEnd
                            : null,
                    onHorizontalDragCancel:
                        widget.allowsSeek && widget.onSeek != null
                            ? _onScrubCancel
                            : null,
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
    this.musicXml,
    this.force = false,
  });

  final SongScore score;
  final String? musicXml;
  final bool force;
}
