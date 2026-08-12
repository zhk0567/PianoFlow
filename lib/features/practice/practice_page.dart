import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/breakpoint_latch.dart';
import '../library/library_repository.dart';
import '../library/user_library_store.dart';
import 'keyboard_geometry.dart';
import 'practice_constants.dart';
import 'practice_engine.dart';
import 'practice_stats_store.dart';
import 'practice_weak_loop.dart';
import 'verovio_runtime.dart';
import 'widgets/falling_notes_lane.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/practice_controls.dart';
import 'widgets/practice_settlement_sheet.dart';
import 'widgets/verovio_staff_lane.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key, required this.songId});

  final String songId;

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
          data: (score) => _PracticeScaffold(summary: summary, score: score),
        );
      },
    );
  }
}

class _PracticeScaffold extends ConsumerStatefulWidget {
  const _PracticeScaffold({required this.summary, required this.score});

  final SongSummary summary;
  final SongScore score;

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

  @override
  void initState() {
    super.initState();
    // Prefetch MusicXML as soon as practice opens (was on song-detail preview).
    if (Platform.isWindows) {
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

    return PopScope(
      canPop: !snap.hasSessionActivity,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_showSettlement(leaveAfter: true));
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
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
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (s.mode.isPractice && snap.hasSessionActivity)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Text(
                              '命中 ${snap.sessionHits}',
                              style: AppTheme.body(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
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
                          color: fav
                              ? AppColors.accent
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
                                    color: AppColors.accent,
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
                        final usable = constraints.maxHeight -
                            keyboardH -
                            fkGap -
                            gap;
                        final lanes = PracticeConstants.splitStageLanes(
                          usableHeight: usable,
                          compact: compact,
                        );
                        final ppb =
                            PracticeConstants.pixelsPerBeatForHeight(
                          lanes.falling,
                        );

                        return Column(
                          children: [
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
                                          loopEnabled: s.loopEnabled,
                                          loopStart: s.loopStart,
                                          loopEnd: s.loopEnd,
                                          visualFxEnabled:
                                              s.visualFxEnabled,
                                          ghostHits: snap.ghostHits,
                                          showGhost: s.showGhost,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (fkGap > 0) SizedBox(height: fkGap),
                            SizedBox(
                              height: keyboardH,
                              width: geo.width,
                              child: RepaintBoundary(
                                child: ListenableBuilder(
                                  listenable: ctrl.clock,
                                  builder: (context, _) {
                                    return PianoKeyboard(
                                      geometry: geo,
                                      highlighted:
                                          snap.highlightByHandAt(
                                        ctrl.clock.positionBeats,
                                      ),
                                      pressed: s.mode.isAutoPlay
                                          ? const {}
                                          : snap.pressedMidi,
                                    );
                                  },
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
    );
  }
}
