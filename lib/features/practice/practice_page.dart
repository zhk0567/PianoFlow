import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/breakpoint_latch.dart';
import '../library/library_repository.dart';
import '../library/user_library_store.dart';
import 'keyboard_geometry.dart';
import 'practice_clock.dart';
import 'practice_constants.dart';
import 'practice_stage_theme.dart';
import 'practice_engine.dart';
import 'practice_stats_store.dart';
import 'practice_weak_loop.dart';
import 'verovio_runtime.dart';
import 'verovio_web_host_factory.dart';
import 'widgets/falling_notes_lane.dart';
import 'widgets/hit_feedback_overlay.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/practice_controls.dart';
import 'widgets/practice_settlement_sheet.dart';
import 'widgets/practice_visual_fx_overlay.dart';
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userLibraryProvider.notifier).touchRecent(widget.songId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByIdProvider(widget.songId));

    return songAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) {
            pianoFlowLog(
              'Practice',
              'score open failed (${summary.id}): $e',
            );
            return const Scaffold(
              body: Center(
                child: Text(
                  '无法打开练习：乐谱加载失败（详情见控制台 [PianoFlow/Library]）',
                ),
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

  bool _settlementShowing = false;
  bool _examBootstrapped = false;

  @override
  void initState() {
    super.initState();
    // Prefetch MusicXML as soon as practice opens (was on song-detail preview).
    if (verovioPlatformSupported) {
      VerovioRuntime.instance.prewarm();
      unawaited(
        VerovioRuntime.instance.prefetchMusicXml(widget.score),
      );
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
    if (!snap.hasSessionActivity) {
      if (leaveAfter && mounted) Navigator.of(context).pop();
      return;
    }
    _settlementShowing = true;
    final ctrl = ref.read(practiceProvider(score).notifier);
    final sessions =
        ref.read(practiceStatsProvider).bySong[widget.summary.id]?.sessions ??
            0;
    ctrl.clearSettlementReady();
    var choseLeave = false;
    var choseRetry = false;
    var choseWeak = false;
    final weak = snap.suggestedWeakLoop;
    try {
      await showPracticeSettlementSheet(
        context: context,
        snap: snap,
        songSessions: sessions,
        examRecordingPath: ctrl.lastExamRecordingPath,
        weakLoopLabel: weak == null
            ? null
            : PracticeWeakLoopLogic.labelZh(weak),
        onWeakLoop: weak == null
            ? null
            : () {
                choseWeak = true;
                unawaited(() async {
                  await ctrl.flushStatsIfNeeded();
                  ctrl.applyWeakLoopAndRestart(
                    start: weak.start,
                    end: weak.end,
                  );
                }());
              },
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
      if (!choseLeave && !choseRetry && !choseWeak && leaveAfter && mounted) {
        await ctrl.flushStatsIfNeeded();
        if (mounted) Navigator.of(context).pop();
      }
    } finally {
      _settlementShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final score = widget.score;
    final snap = ref.watch(practiceProvider(score));
    final ctrl = ref.read(practiceProvider(score).notifier);
    final fav =
        ref.watch(userLibraryProvider).favorites.contains(summary.id);
    final s = snap.settings;
    final stage = PracticeStageTheme.of(visualFxEnabled: s.visualFxEnabled);
    final screen = MediaQuery.sizeOf(context);
    final tall = _tallLatch.update(screen.height);
    final compact = !tall;
    final keyboardH = compact
        ? PracticeConstants.keyboardHCompact
        : PracticeConstants.keyboardHComfort;

    if (snap.settlementReady && !_settlementShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_showSettlement(leaveAfter: false));
      });
    }

    final baseTheme = Theme.of(context);
    return PopScope(
      canPop: !snap.hasSessionActivity,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_showSettlement(leaveAfter: true));
      },
      child: Theme(
        data: stage.applyTo(baseTheme),
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
                                    : AppColors.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Reserve width so auto↔practice does not reflow the title row.
                      SizedBox(
                        width: 92,
                        child: s.mode.isPractice && snap.hasSessionActivity
                            ? Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stage.accentSoft,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                  ),
                                  child: Text(
                                    '命中 ${snap.sessionHits}',
                                    style: AppTheme.body(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: stage.accent,
                                    ),
                                  ),
                                ),
                              )
                            : null,
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
                          color: fav
                              ? stage.accent
                              : AppColors.textSecondary,
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                        const fkGap =
                            PracticeConstants.stageFallingKeyboardGap;
                        // 瀑布=特效显示层。谱区按「不挤占」切分（boostFalling:false），
                        // 保证五线谱高度；华丽只靠绘制，不靠抢高度。
                        final showFalling = s.visualFxEnabled;
                        final usable = (constraints.maxHeight -
                                keyboardH -
                                fkGap -
                                gap)
                            .clamp(0.0, double.infinity);
                        final lanes = showFalling
                            ? PracticeConstants.splitStageLanes(
                                usableHeight: usable,
                                compact: compact,
                                boostFalling: false,
                              )
                            : (falling: 0.0, staff: usable);
                        final ppb = showFalling
                            ? PracticeConstants.pixelsPerBeatForHeight(
                                lanes.falling,
                              )
                            : 1.0;

                        return Column(
                          children: [
                            if (showFalling)
                              SizedBox(
                                height: lanes.falling,
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
                                    PracticeVisualFxOverlay(
                                      enabled: true,
                                      geometry: geo,
                                      grade: snap.lastGrade,
                                      midi: snap.lastHitMidi,
                                      nonce: snap.feedbackNonce,
                                      combo: snap.combo,
                                      notes: snap.filteredNotes,
                                      clock: ctrl.clock,
                                      autoplayVisual: s.mode.isAutoPlay,
                                      hitLineYFraction: lanes.falling > 1
                                          ? (lanes.falling -
                                                  PracticeConstants
                                                      .fallingHitLineInset) /
                                              lanes.falling
                                          : 0.98,
                                    ),
                                    if (s.mode.isPractice)
                                      HitFeedbackOverlay(
                                        grade: snap.lastGrade,
                                        nonce: snap.feedbackNonce,
                                        enhanced: true,
                                      ),
                                  ],
                                ),
                              ),
                            if (fkGap > 0) SizedBox(height: fkGap),
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
                                child: RepaintBoundary(
                                  child: _HighlightGatedKeyboard(
                                    clock: ctrl.clock,
                                    geometry: geo,
                                    highlightAt: snap.highlightByHandAt,
                                    pressed: s.mode.isAutoPlay
                                        ? const {}
                                        : snap.pressedMidi,
                                    visualFxEnabled: false,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: gap),
                            SizedBox(
                              height: lanes.staff,
                              child: RepaintBoundary(
                                child: VerovioStaffLane(
                                  score: score,
                                  clock: ctrl.clock,
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
    );
  }
}


/// Rebuilds the piano only when highlight / press sets change (not every clock tick).
class _HighlightGatedKeyboard extends StatefulWidget {
  const _HighlightGatedKeyboard({
    required this.clock,
    required this.geometry,
    required this.highlightAt,
    required this.pressed,
    required this.visualFxEnabled,
  });

  final PracticeClock clock;
  final KeyboardGeometry geometry;
  final Map<int, Hand> Function(double pos) highlightAt;
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
      pressed: widget.pressed,
      visualFxEnabled: widget.visualFxEnabled,
    );
  }
}
