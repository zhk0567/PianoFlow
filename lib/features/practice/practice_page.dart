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
import 'verovio_runtime.dart';
import 'widgets/falling_notes_lane.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/practice_controls.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
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
                  if (s.mode.isPractice &&
                      (snap.sessionHits > 0 || snap.sessionMisses > 0))
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
                          snap.sessionMisses > 0
                              ? '命中 ${snap.sessionHits} · 失误 ${snap.sessionMisses}'
                              : '命中 ${snap.sessionHits}',
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
                      fav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: fav ? AppColors.accent : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Fixed slot: runtime errors take priority; else OMR honesty banner.
            // Keeps height stable so stage does not reflow when hints appear.
            Builder(
              builder: (context) {
                final banner =
                    snap.statusHint ?? summary.practiceHonestyBanner;
                return SizedBox(
                  height: 22,
                  child: banner == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                    const fkGap = PracticeConstants.stageFallingKeyboardGap;
                    final usable = constraints.maxHeight -
                        keyboardH -
                        fkGap -
                        gap;
                    final lanes = PracticeConstants.splitStageLanes(
                      usableHeight: usable,
                      compact: compact,
                    );
                    final ppb = PracticeConstants.pixelsPerBeatForHeight(
                      lanes.falling,
                    );

                    // Lock waterfall + keyboard to floored geo.width so bars
                    // center on keys even when the parent has a fractional px.
                    return Column(
                      children: [
                        SizedBox(
                          height: lanes.falling,
                          width: geo.width,
                          child: FallingNotesLane(
                            geometry: geo,
                            notes: snap.filteredNotes,
                            positionBeats: snap.positionBeats,
                            pixelsPerBeat: ppb,
                            waitingFor: snap.waitingFor,
                            loopEnabled: s.loopEnabled,
                            loopStart: s.loopStart,
                            loopEnd: s.loopEnd,
                          ),
                        ),
                        if (fkGap > 0) SizedBox(height: fkGap),
                        SizedBox(
                          height: keyboardH,
                          width: geo.width,
                          child: PianoKeyboard(
                            geometry: geo,
                            highlighted: snap.highlightByHand,
                            // 自动播放不依赖 mic，不显示按下高亮（避免回声误亮）。
                            pressed: s.mode.isAutoPlay
                                ? const {}
                                : snap.pressedMidi,
                          ),
                        ),
                        SizedBox(height: gap),
                        SizedBox(
                          height: lanes.staff,
                          child: VerovioStaffLane(
                            score: score,
                            positionBeats: snap.positionBeats,
                            hand: s.hand,
                            isPlaying: snap.isPlaying,
                            // Wait free-advance (gaps/early window) must drive
                            // staff rate; freeze only at wait onset hold.
                            beatsPerSec: snap.staffBeatsPerSec,
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
              onPlay: ctrl.togglePlay,
              onRestart: ctrl.restart,
              onSettings: ctrl.updateSettings,
              onSeek: ctrl.seek,
            ),
          ],
        ),
      ),
    );
  }
}
