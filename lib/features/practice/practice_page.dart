import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/breakpoint_latch.dart';
import '../library/library_repository.dart';
import '../library/recent_practice_dwell.dart';
import '../library/user_library_store.dart';
import 'keyboard_geometry.dart';
import 'practice_clock.dart';
import 'practice_constants.dart';
import 'practice_stage_theme.dart';
import 'practice_engine.dart';
import 'practice_stats_store.dart';
import 'verovio_runtime.dart';
import 'verovio_web_host_factory.dart';
import 'widgets/falling_notes_lane.dart';
import 'widgets/hit_feedback_overlay.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/practice_controls.dart';
import 'widgets/practice_settlement_sheet.dart';
import 'widgets/practice_visual_fx_overlay.dart';
import 'widgets/full_score_browse.dart';
import 'widgets/verovio_staff_lane.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({
    super.key,
    required this.songId,
    this.examMode = false,
    this.examRecord = false,
    this.examHand,
  });

  final String songId;

  /// Entered from /exam lobby.
  final bool examMode;
  final bool examRecord;
  final Hand? examHand;

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  final _recentPromote = RecentPracticePromote();

  void _armRecentPromote() {
    _recentPromote.arm(() {
      if (!mounted) return;
      final id = widget.songId;
      pianoFlowLog('Library', 'recent promote after 5min open: $id');
      ref.read(userLibraryProvider.notifier).touchRecent(id);
    });
  }

  @override
  void initState() {
    super.initState();
    _armRecentPromote();
  }

  @override
  void didUpdateWidget(PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) _armRecentPromote();
  }

  @override
  void dispose() {
    _recentPromote.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByIdProvider(widget.songId));

    return songAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) {
        pianoFlowLog('Practice', 'song lookup failed (${widget.songId}): $e');
        return const Scaffold(
          body: Center(
            child: Text('无法打开练习：曲目信息加载失败（详情见控制台 [PianoFlow/Practice]）'),
          ),
        );
      },
      data: (summary) {
        if (summary == null) {
          pianoFlowLog('Practice', 'song not in catalog: ${widget.songId}');
          return const Scaffold(body: Center(child: Text('曲目不存在')));
        }
        final scoreAsync = ref.watch(scoreProvider(summary));
        return scoreAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) {
            pianoFlowLog('Practice', 'score open failed (${summary.id}): $e');
            return const Scaffold(
              body: Center(
                child: Text('无法打开练习：乐谱加载失败（详情见控制台 [PianoFlow/Library]）'),
              ),
            );
          },
          data: (score) => _PracticeScaffold(
            summary: summary,
            score: score,
            examMode: widget.examMode,
            examRecord: widget.examRecord,
            examHand: widget.examHand,
          ),
        );
      },
    );
  }
}

class _PracticeScaffold extends ConsumerStatefulWidget {
  const _PracticeScaffold({
    required this.summary,
    required this.score,
    this.examMode = false,
    this.examRecord = false,
    this.examHand,
  });

  final SongSummary summary;
  final SongScore score;
  final bool examMode;
  final bool examRecord;
  final Hand? examHand;

  @override
  ConsumerState<_PracticeScaffold> createState() => _PracticeScaffoldState();
}

class _PracticeScaffoldState extends ConsumerState<_PracticeScaffold> {
  /// Tall when height ≥ exit-compact; compact again only below [compactScreenHeight].
  final _tallLatch = BreakpointLatch(
    enter: PracticeConstants.compactScreenHeight + 40,
    exit: PracticeConstants.compactScreenHeight,
    value: true,
  );

  /// Captures Space for play/pause on Windows / Flutter Web desktop.
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'practiceSpace');

  bool _settlementShowing = false;
  bool _examBootstrapped = false;

  /// Full-score paged browse overlay (owns shared Verovio WebView).
  bool _fullScoreOpen = false;

  /// Cropped grand-staff height from the viewer. Null until the first engrave.
  double? _staffInk;

  void _onStaffInk(double height) {
    final next = height.clamp(140.0, 400.0);
    if (_staffInk != null && (next - _staffInk!).abs() < 4) return;
    setState(() => _staffInk = next);
  }

  @override
  void initState() {
    super.initState();
    // Prefetch MusicXML as soon as practice opens (was on song-detail preview).
    if (verovioPlatformSupported) {
      VerovioRuntime.instance.prewarm();
      unawaited(VerovioRuntime.instance.prefetchMusicXml(widget.score));
    }
    if (widget.summary.isOmrDraft) {
      pianoFlowLog(
        'Practice',
        'omrDraft ${widget.summary.id}: ${SongSummary.omrHonestyNotice}',
      );
    }
    if (widget.examMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyExamEntry());
    }
  }

  @override
  void dispose() {
    _shortcutFocus.dispose();
    super.dispose();
  }

  /// True when Space should toggle transport (no modal / no text field).
  bool _spaceCanTogglePlay() {
    if (_fullScoreOpen) return false;
    if (_settlementShowing) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary != _shortcutFocus) {
      final w = primary.context?.widget;
      if (w is EditableText) return false;
      if (primary.context != null) {
        final editable = primary.context!
            .findAncestorWidgetOfExactType<EditableText>();
        if (editable != null) return false;
      }
    }
    return true;
  }

  KeyEventResult _onShortcutKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (!_spaceCanTogglePlay()) return KeyEventResult.ignored;
    ref.read(practiceProvider(widget.score).notifier).togglePlay();
    return KeyEventResult.handled;
  }

  void _applyExamEntry() {
    if (!mounted || _examBootstrapped) return;
    _examBootstrapped = true;
    final ctrl = ref.read(practiceProvider(widget.score).notifier);
    final cur = ref.read(practiceProvider(widget.score)).settings;
    ctrl.updateSettings(
      cur.copyWith(
        mode: PracticeMode.exam,
        guideAudio: false,
        loopEnabled: false,
        examRecordAudio: widget.examRecord,
        hand: widget.examHand ?? cur.hand,
        showGhost: false,
      ),
    );
    pianoFlowLog(
      'Practice',
      'exam entry id=${widget.score.id} record=${widget.examRecord} '
          'hand=${widget.examHand?.name ?? 'default'}',
    );
  }

  Future<void> _showSettlement({required bool leaveAfter}) async {
    if (_settlementShowing || !mounted) return;
    final score = widget.score;
    final snap = ref.read(practiceProvider(score));
    final ctrl = ref.read(practiceProvider(score).notifier);
    if (!snap.hasSessionActivity) {
      if (leaveAfter && mounted) Navigator.of(context).pop();
      return;
    }
    // 平时练习：只落库，不弹「慢练更香」结算；考试仍走结算 sheet。
    if (!snap.settings.mode.isExam) {
      ctrl.clearSettlementReady();
      await ctrl.flushStatsIfNeeded();
      if (leaveAfter && mounted) Navigator.of(context).pop();
      return;
    }
    _settlementShowing = true;
    final sessions =
        ref.read(practiceStatsProvider).bySong[widget.summary.id]?.sessions ??
        0;
    ctrl.clearSettlementReady();
    var choseLeave = false;
    var choseRetry = false;
    try {
      await showPracticeSettlementSheet(
        context: context,
        snap: snap,
        songSessions: sessions,
        examRecordingPath: ctrl.lastExamRecordingPath,
        // 日常结算已去掉；考试 sheet 亦不提供「练薄弱段」。
        weakLoopLabel: null,
        onWeakLoop: null,
        onRetry: () {
          choseRetry = true;
          unawaited(() async {
            await ctrl.flushStatsIfNeeded();
            ctrl.resetSessionAndRestart();
          }());
        },
        onLeave: () async {
          choseLeave = true;
          await ctrl.flushStatsIfNeeded();
          if (mounted) Navigator.of(context).pop();
        },
      );
      if (!choseLeave && !choseRetry && leaveAfter && mounted) {
        await ctrl.flushStatsIfNeeded();
        if (mounted) Navigator.of(context).pop();
      }
    } finally {
      _settlementShowing = false;
      if (mounted) _shortcutFocus.requestFocus();
    }
  }

  void _openPracticeSettings(
    BuildContext context, {
    required void Function(PracticeSettings) onSettings,
  }) {
    unawaited(() async {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return Theme(
            data: AppTheme.light(),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: StatefulBuilder(
                  builder: (context, setLocal) {
                    final s = ref.read(practiceProvider(widget.score)).settings;
                    final stage = PracticeStageTheme.of(
                      visualFxEnabled: s.visualFxEnabled,
                    );
                    Widget labeledSlider({
                      required String label,
                      required String valueText,
                      required double value,
                      required double min,
                      required double max,
                      required ValueChanged<double> onChanged,
                    }) {
                      return Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              label,
                              style: AppTheme.body(
                                fontSize: 13,
                                color: stage.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              valueText,
                              style: AppTheme.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: stage.accent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7,
                                ),
                              ),
                              child: Slider(
                                value: value,
                                min: min,
                                max: max,
                                onChanged: (v) {
                                  onChanged(v);
                                  setLocal(() {});
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '练习设置',
                          style: AppTheme.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        labeledSlider(
                          label: '速度',
                          valueText: '${(s.speed * 100).round()}%',
                          value: s.speed,
                          min: PracticeConstants.speedMin,
                          max: PracticeConstants.speedMaxUi,
                          onChanged: (v) {
                            final cur = ref
                                .read(practiceProvider(widget.score))
                                .settings;
                            onSettings(cur.copyWith(speed: v));
                          },
                        ),
                        labeledSlider(
                          label: '音量',
                          valueText: '${(s.volume * 100).round()}%',
                          value: s.volume.clamp(
                            PracticeConstants.volumeMin,
                            PracticeConstants.volumeMax,
                          ),
                          min: PracticeConstants.volumeMin,
                          max: PracticeConstants.volumeMax,
                          onChanged: (v) {
                            final cur = ref
                                .read(practiceProvider(widget.score))
                                .settings;
                            onSettings(cur.copyWith(volume: v));
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
      if (mounted) _shortcutFocus.requestFocus();
    }());
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final score = widget.score;
    final snap = ref.watch(practiceProvider(score));
    final ctrl = ref.read(practiceProvider(score).notifier);
    final fav = ref.watch(userLibraryProvider).favorites.contains(summary.id);
    final s = snap.settings;
    final stage = PracticeStageTheme.of(visualFxEnabled: s.visualFxEnabled);
    final screen = MediaQuery.sizeOf(context);
    final tall = _tallLatch.update(screen.height);
    final compact = !tall;

    if (snap.settlementReady && !_settlementShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_showSettlement(leaveAfter: false));
      });
    }

    final baseTheme = Theme.of(context);
    if (_fullScoreOpen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() => _fullScoreOpen = false);
        },
        child: Theme(
          data: stage.applyTo(baseTheme),
          child: Scaffold(
            backgroundColor: const Color(0xFFFFFBF5),
            body: SafeArea(
              child: FullScoreBrowse(
                summary: summary,
                score: score,
                onClose: () {
                  if (mounted) setState(() => _fullScoreOpen = false);
                },
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !snap.hasSessionActivity,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_showSettlement(leaveAfter: true));
      },
      child: Theme(
        data: stage.applyTo(baseTheme),
        child: Focus(
          focusNode: _shortcutFocus,
          autofocus: true,
          onKeyEvent: _onShortcutKey,
          child: Scaffold(
            backgroundColor: stage.pageBg,
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: stage.panelBg,
                      border: Border(
                        bottom: BorderSide(color: stage.panelBorder, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (snap.isPlaying) {
                              ref
                                  .read(practiceProvider(score).notifier)
                                  .pause();
                            }
                            if (snap.hasSessionActivity) {
                              unawaited(_showSettlement(leaveAfter: true));
                            } else {
                              Navigator.of(context).maybePop();
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.title,
                                style: AppTheme.body(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: stage.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${summary.bpm} BPM · '
                                '${s.mode.labelZh}'
                                ' · ${summary.scoreKindLabelDetail}',
                                style: AppTheme.body(
                                  fontSize: 12,
                                  color: summary.isOmrDraft
                                      ? stage.accent
                                      : stage.textSecondary,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 平时练习不展示「命中 N」；结算/考试汇总仍保留。
                        if (verovioPlatformSupported)
                          IconButton(
                            tooltip: '完整曲谱',
                            onPressed: () {
                              final c = ref.read(
                                practiceProvider(score).notifier,
                              );
                              if (snap.isPlaying) c.pause();
                              setState(() => _fullScoreOpen = true);
                            },
                            icon: Icon(
                              Icons.menu_book_rounded,
                              color: stage.textSecondary,
                            ),
                          ),
                        IconButton(
                          tooltip: '设置',
                          onPressed: () => _openPracticeSettings(
                            context,
                            onSettings: ctrl.updateSettings,
                          ),
                          icon: Icon(
                            Icons.settings_rounded,
                            color: stage.textSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: fav ? '取消收藏' : '收藏',
                          onPressed: () => ref
                              .read(userLibraryProvider.notifier)
                              .toggleFavorite(summary.id),
                          icon: Icon(
                            fav
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: fav ? stage.accent : stage.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final banner =
                          snap.statusHint ?? summary.practiceHonestyBanner;
                      return SizedBox(
                        height: 22,
                        child: banner == null
                            ? null
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  0,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    banner,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.body(
                                      fontSize: 12,
                                      color: stage.accent,
                                    ),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final geo = KeyboardGeometry.stable(
                            width: constraints.maxWidth,
                            startMidi: PracticeConstants.startMidi,
                            whiteKeyCount: PracticeConstants.whiteKeyCount,
                          );
                          const gap = PracticeConstants.stageLaneGap;
                          // 瀑布=装饰特效。开：谱贴刻线，多出来的高度给瀑布。
                          // 关：键盘与谱区约各一半（避免巨型琴键）。
                          final showFalling = s.visualFxEnabled;
                          final lanes = PracticeConstants.stageColumn(
                            stageHeight: constraints.maxHeight,
                            compact: compact,
                            showFalling: showFalling,
                            staffInk: _staffInk,
                          );
                          final fallingH = lanes.falling;
                          final keyboardH = lanes.keyboard;
                          final staffH = lanes.staff;
                          final ppb = showFalling
                              ? PracticeConstants.pixelsPerBeatForHeight(
                                  fallingH,
                                )
                              : 1.0;

                          return Column(
                            children: [
                              if (showFalling && fallingH > 0)
                                SizedBox(
                                  height: fallingH,
                                  width: geo.width,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      RepaintBoundary(
                                        child: ListenableBuilder(
                                          listenable: ctrl.clock,
                                          builder: (context, _) {
                                            return FallingNotesLane(
                                              geometry: geo,
                                              notes: snap.filteredNotes,
                                              positionBeats:
                                                  ctrl.clock.positionBeats,
                                              pixelsPerBeat: ppb,
                                              waitingFor: snap.waitingFor,
                                              visualFxEnabled: true,
                                              ghostHits: snap.ghostHits,
                                              showGhost: s.showGhost,
                                            );
                                          },
                                        ),
                                      ),
                                      RepaintBoundary(
                                        child: PracticeVisualFxOverlay(
                                          enabled: true,
                                          geometry: geo,
                                          hits: snap.sessionHitLog,
                                          notes: snap.filteredNotes,
                                          clock: ctrl.clock,
                                          autoplayVisual: s.mode.isAutoPlay,
                                          hitLineYFraction: fallingH > 1
                                              ? (fallingH -
                                                        PracticeConstants
                                                            .fallingHitLineInset) /
                                                    fallingH
                                              : 0.98,
                                        ),
                                      ),
                                      RepaintBoundary(
                                        child: HitFeedbackOverlay(
                                          grade: snap.lastGrade,
                                          nonce: snap.feedbackNonce,
                                          enhanced: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(
                                height: keyboardH,
                                width: geo.width,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: stage.panelBg,
                                    border: Border(
                                      top: BorderSide(
                                        color: stage.panelBorder.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      RepaintBoundary(
                                        child: _HighlightGatedKeyboard(
                                          clock: ctrl.clock,
                                          geometry: geo,
                                          highlightAt: snap.highlightByHandAt,
                                          waitingFor: s.mode.isPractice
                                              ? snap.waitingFor
                                              : const {},
                                          // Wait mode: only light presses that hit an
                                          // owed pitch. Neighbor-bin / ambient mic
                                          // noise must not paint keys in gaps or idle
                                          // (waiting empty → no pressed lights).
                                          pressed: s.mode.isAutoPlay
                                              ? const {}
                                              : (s.mode.isPractice
                                                    ? snap.pressedMidi
                                                        .intersection(
                                                        snap.waitingFor,
                                                      )
                                                    : snap.pressedMidi),
                                          visualFxEnabled: s.visualFxEnabled,
                                        ),
                                      ),
                                      if (!showFalling)
                                        RepaintBoundary(
                                          child: HitFeedbackOverlay(
                                            grade: snap.lastGrade,
                                            nonce: snap.feedbackNonce,
                                            enhanced: false,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: gap),
                              SizedBox(
                                height: staffH,
                                child: RepaintBoundary(
                                  child: VerovioStaffLane(
                                    score: score,
                                    clock: ctrl.clock,
                                    durationBeats: snap.durationBeats,
                                    allowsSeek: s.mode.allowsSeek,
                                    onSeek: ctrl.seek,
                                    onInkHeight: _onStaffInk,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  PracticeControls(
                    snap: snap,
                    positionListenable: ctrl.clock,
                    onPlay: ctrl.togglePlay,
                    onRestart: ctrl.restart,
                    onSettings: ctrl.updateSettings,
                    onSeek: ctrl.seek,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rebuilds the piano only when highlight / press sets change (not every clock tick).
class _HighlightGatedKeyboard extends StatefulWidget {
  const _HighlightGatedKeyboard({
    required this.clock,
    required this.geometry,
    required this.highlightAt,
    required this.waitingFor,
    required this.pressed,
    required this.visualFxEnabled,
  });

  final PracticeClock clock;
  final KeyboardGeometry geometry;
  final Map<int, Hand> Function(double pos) highlightAt;
  final Set<int> waitingFor;
  final Set<int> pressed;
  final bool visualFxEnabled;

  @override
  State<_HighlightGatedKeyboard> createState() =>
      _HighlightGatedKeyboardState();
}

class _HighlightGatedKeyboardState extends State<_HighlightGatedKeyboard> {
  late Map<int, Hand> _highlighted;

  @override
  void initState() {
    super.initState();
    _highlighted = widget.highlightAt(widget.clock.positionBeats);
    widget.clock.addListener(_onClock);
  }

  @override
  void didUpdateWidget(covariant _HighlightGatedKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock) {
      oldWidget.clock.removeListener(_onClock);
      widget.clock.addListener(_onClock);
    }
    if (oldWidget.pressed != widget.pressed ||
        oldWidget.waitingFor != widget.waitingFor ||
        oldWidget.highlightAt != widget.highlightAt) {
      _highlighted = widget.highlightAt(widget.clock.positionBeats);
    }
  }

  void _onClock() {
    final next = widget.highlightAt(widget.clock.positionBeats);
    if (_mapsEqual(_highlighted, next)) return;
    setState(() => _highlighted = next);
  }

  static bool _mapsEqual(Map<int, Hand> a, Map<int, Hand> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  void dispose() {
    widget.clock.removeListener(_onClock);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PianoKeyboard(
      geometry: widget.geometry,
      highlighted: _highlighted,
      waitingFor: widget.waitingFor,
      pressed: widget.pressed,
      visualFxEnabled: widget.visualFxEnabled,
    );
  }
}
