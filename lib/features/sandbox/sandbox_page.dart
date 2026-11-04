import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';
import '../practice/keyboard_geometry.dart';
import '../practice/practice_constants.dart';
import '../practice/score_audio_player.dart';
import '../practice/widgets/piano_keyboard.dart';
import '../practice/widgets/visual_metronome.dart';

/// Standalone metronome + tap-to-play 88-key sandbox (not the practice layout).
class SandboxPage extends ConsumerStatefulWidget {
  const SandboxPage({super.key});

  @override
  ConsumerState<SandboxPage> createState() => _SandboxPageState();
}

class _SandboxPageState extends ConsumerState<SandboxPage> {
  double _bpm = 100;
  bool _metroOn = false;
  final Set<int> _pressed = {};
  bool _audioReady = false;
  String? _hint;

  ScoreAudioPlayer get _audio => ref.read(scoreAudioProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_ensureAudio);
  }

  @override
  void dispose() {
    // Stop metronome when leaving; do not dispose shared ScoreAudioPlayer.
    try {
      final audio = ref.read(scoreAudioProvider);
      audio.setMetronome(false);
      audio.setTransportPlaying(false);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _ensureAudio() async {
    try {
      await _audio.ensureReady();
      // Wake WASAPI before first key — same hitch practice page avoids.
      await _audio.ensureDeviceWarm();
      if (!mounted) return;
      setState(() {
        _audioReady = true;
        _hint = null;
      });
      // Bind samples in background; do not block UI. Center first, then rest.
      unawaited(_prefetchAuditionKeys());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hint = '音色初始化失败（详见控制台 [PianoFlow/Audio]）';
      });
    }
  }

  /// Lazy-bind is the main audition lag: first press paid setSource (~100–500ms).
  Future<void> _prefetchAuditionKeys() async {
    final center = <int>[
      for (var m = 48; m <= 72; m++) m,
    ];
    final rest = <int>[
      for (var m = PracticeConstants.midiMin; m <= PracticeConstants.midiMax; m++)
        if (m < 48 || m > 72) m,
    ];
    await _audio.prefetchMidis(center);
    if (!mounted) return;
    await _audio.prefetchMidis(rest);
  }

  void _setMetro(bool on) {
    setState(() => _metroOn = on);
    _audio.setMetronomeBpm(_bpm);
    _audio.setMetronome(on);
    _audio.setTransportPlaying(on);
  }

  void _setBpm(double v) {
    setState(() => _bpm = v);
    _audio.setMetronomeBpm(v);
  }

  void _tapKey(int midi) {
    // Fire audio first — do not await ensureReady on the tap path.
    if (!_audioReady) unawaited(_ensureAudio());
    _audio.playOneShot(midi, hand: Hand.both);
    setState(() => _pressed.add(midi));
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _pressed.remove(midi));
    });
  }

  /// Hit-test white keys (black keys map to nearest white for sandbox simplicity).
  int? _midiAt(KeyboardGeometry geo, Offset local, double height) {
    final x = local.dx;
    // Prefer black keys in upper 55% of keyboard height.
    if (local.dy < height * 0.55) {
      for (final m in geo.blackMidis) {
        final left = geo.blackKeyLeft(m);
        if (left == null) continue;
        if (x >= left && x <= left + geo.blackWidth) return m;
      }
    }
    for (var i = 0; i < geo.whiteMidis.length; i++) {
      final left = geo.whiteKeyLeft(i);
      final w = geo.whiteKeyWidth(i);
      if (x >= left && x < left + w) return geo.whiteMidis[i];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '节拍器与试音',
          style: AppTheme.body(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '节拍器',
                          style: AppTheme.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_bpm.round()} BPM',
                          style: AppTheme.body(
                            fontSize: 14,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _metroOn,
                          onChanged: _audioReady ? _setMetro : null,
                        ),
                      ],
                    ),
                    Slider(
                      value: _bpm.clamp(
                        PracticeConstants.metroBpmMin,
                        PracticeConstants.metroBpmMax,
                      ),
                      min: PracticeConstants.metroBpmMin,
                      max: PracticeConstants.metroBpmMax,
                      onChanged: _audioReady ? _setBpm : null,
                    ),
                    if (_metroOn)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: VisualMetronomeDot(
                            enabled: _metroOn,
                            isPlaying: _metroOn,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_hint != null) ...[
                const SizedBox(height: 10),
                Text(
                  _hint!,
                  style: AppTheme.body(fontSize: 13, color: AppColors.accent),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '试音键盘（点按发声，不跟谱）',
                style: AppTheme.body(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final geo = KeyboardGeometry.stable(
                      width: constraints.maxWidth,
                      startMidi: PracticeConstants.startMidi,
                      whiteKeyCount: PracticeConstants.whiteKeyCount,
                    );
                    final keyH =
                        (constraints.maxHeight * 0.55).clamp(120.0, 220.0);
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: keyH,
                        width: geo.width,
                        // Listener = pointer-down（比 GestureDetector.onTapDown 更跟手）。
                        // Builder 用键盘区域自己的 RenderBox 做命中，避免用到 Expanded 坐标。
                        child: Builder(
                          builder: (keyCtx) {
                            return Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (event) {
                                final box =
                                    keyCtx.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                final local =
                                    box.globalToLocal(event.position);
                                final midi = _midiAt(geo, local, keyH);
                                if (midi != null) _tapKey(midi);
                              },
                              child: PianoKeyboard(
                                geometry: geo,
                                highlighted: const {},
                                pressed: _pressed,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
