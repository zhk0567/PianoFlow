import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/song.dart';
import '../../../shared/piano_flow_log.dart';
import '../../../shared/theme/app_theme.dart';
import '../verovio_runtime.dart';
import '../verovio_web_host_factory.dart';

/// Full-score browse: Verovio pages stacked vertically; scroll only (no pager).
///
/// Practice staff lane must not be mounted while this is visible (singleton host).
class FullScoreBrowse extends StatefulWidget {
  const FullScoreBrowse({
    super.key,
    required this.summary,
    required this.score,
    required this.onClose,
  });

  final SongSummary summary;
  final SongScore score;
  final VoidCallback onClose;

  @override
  State<FullScoreBrowse> createState() => _FullScoreBrowseState();
}

class _FullScoreBrowseState extends State<FullScoreBrowse> {
  final _runtime = VerovioRuntime.instance;
  final _focus = FocusNode(debugLabel: 'fullScoreBrowse');

  bool _loading = true;
  String? _error;
  Size _viewport = const Size(800, 600);
  int _scheduledHash = 0;

  @override
  void initState() {
    super.initState();
    if (!verovioPlatformSupported) {
      _loading = false;
      _error = '完整曲谱目前仅支持 Windows / Android';
      return;
    }
    _runtime.host.addListener(_onHost);
    unawaited(_load());
  }

  @override
  void dispose() {
    _runtime.host.removeListener(_onHost);
    _focus.dispose();
    super.dispose();
  }

  void _onHost() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _runtime.ensureReady();
      if (!mounted) return;
      await _runtime.beginScoreSwitch(reason: 'full-score ${widget.score.id}');
      // Same MusicXML as practice staff (SongScore→XML) so engraving matches.
      final xml = await _runtime.resolveMusicXml(widget.score, Hand.both);
      if (!mounted) return;
      await _runtime.pushScore(
        score: widget.score,
        hand: Hand.both,
        viewport: _viewport,
        musicXml: xml,
        force: true,
        layoutMode: 'paged',
      );
      if (!mounted) return;
      setState(() => _loading = false);
      pianoFlowLog('Verovio', 'full-score ready id=${widget.score.id}');
    } catch (e, st) {
      pianoFlowLog('Verovio', 'full-score load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '无法打开完整曲谱（详情见控制台 [PianoFlow/Verovio]）';
      });
    }
  }

  void _onViewport(Size box) {
    if (box.width < 40 || box.height < 40) return;
    if ((box.width - _viewport.width).abs() < 8 &&
        (box.height - _viewport.height).abs() < 8) {
      return;
    }
    _viewport = box;
    if (!_runtime.scoreLoaded || _runtime.layoutMode != 'paged') return;
    unawaited(() async {
      try {
        await _runtime.pushResize(box, layoutMode: 'paged');
      } catch (e, st) {
        pianoFlowLog('Verovio', 'full-score resize failed: $e\n$st');
      }
    }());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    // Leave wheel / drag scroll to the WebView; no discrete page keys.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: const Color(0xFFFFFBF5),
        child: Column(
          children: [
            _TopBar(
              title: widget.summary.title,
              kindLabel: widget.summary.scoreKindLabelDetail,
              onClose: widget.onClose,
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTheme.body(color: const Color(0xFF664422)),
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final box = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            final hash = Object.hash(
                              box.width.round(),
                              box.height.round(),
                            );
                            if (_scheduledHash != hash) {
                              _scheduledHash = hash;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _onViewport(box);
                              });
                            }
                            if (!verovioPlatformSupported) {
                              return const SizedBox.expand();
                            }
                            return _runtime.host.buildView(
                              key: const ValueKey('full-score-verovio'),
                            );
                          },
                        ),
                        if (_loading)
                          const ColoredBox(
                            color: Color(0xCCFFFBF5),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.kindLabel,
    required this.onClose,
  });

  final String title;
  final String kindLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '返回练习',
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '完整曲谱 · $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$kindLabel · 上下滚动浏览',
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
