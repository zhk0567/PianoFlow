import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';
import '../practice/keyboard_geometry.dart';
import '../practice/pitch_service.dart';
import '../practice/practice_constants.dart';
import '../practice/widgets/piano_keyboard.dart';

String _engineLabel(PitchEngineKind e) {
  switch (e) {
    case PitchEngineKind.basicPitch:
      return 'Basic Pitch（多音）';
    case PitchEngineKind.swiftf0:
      return 'SwiftF0（单音）';
    case PitchEngineKind.yin:
      return 'YIN（单音）';
  }
}

/// Mic pitch recognition lab: play audio nearby and watch keys light up.
class PitchTestPage extends ConsumerStatefulWidget {
  const PitchTestPage({super.key});

  @override
  ConsumerState<PitchTestPage> createState() => _PitchTestPageState();
}

class _PitchTestPageState extends ConsumerState<PitchTestPage> {
  StreamSubscription<PitchFrame>? _frameSub;
  StreamSubscription<int>? _noteSub;
  PitchFrame? _frame;
  final Set<int> _lit = {};
  final Map<int, Timer> _clearTimers = {};
  String? _status;
  bool _listening = false;
  int _noteHits = 0;

  static const _startMidi = PracticeConstants.startMidi;
  static const _whiteKeys = PracticeConstants.whiteKeyCount;

  @override
  void dispose() {
    _frameSub?.cancel();
    _noteSub?.cancel();
    for (final t in _clearTimers.values) {
      t.cancel();
    }
    if (_listening) {
      unawaited(ref.read(pitchServiceProvider).stop());
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    final pitch = ref.read(pitchServiceProvider);
    if (_listening) {
      await pitch.stop();
      _frameSub?.cancel();
      _noteSub?.cancel();
      setState(() {
        _listening = false;
        _frame = null;
        _lit.clear();
        _status = '已停止';
      });
      return;
    }

    setState(() => _status = '正在打开麦克风…');
    await pitch.start();
    if (!mounted) return;
    if (pitch.lastError != null) {
      setState(() {
        _listening = false;
        _status = pitch.lastError;
      });
      return;
    }

    _frameSub = pitch.frameStream.listen((f) {
      if (!mounted) return;
      setState(() => _frame = f);
    });
    _noteSub = pitch.noteOnStream.listen(_onDetected);

    setState(() {
      _listening = true;
      _noteHits = 0;
      _status =
          '监听中 · ${_engineLabel(pitch.engine)} — 支持同时多键';
    });
  }

  void _onDetected(int midi) {
    _clearTimers[midi]?.cancel();
    setState(() {
      _lit.add(midi);
      _noteHits++;
    });
    _clearTimers[midi] = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _lit.remove(midi));
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final keyboardH = screen.height < 700 ? 128.0 : 152.0;
    final frame = _frame;
    final gateLin = PitchService.rmsGate;

    return Scaffold(
      appBar: AppBar(title: const Text('音高识别测试')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '主引擎 Basic Pitch（多音 ONNX）；失败时回退 SwiftF0 / YIN。'
                '可同时弹多个键；先确认音量条过黄线。',
                style: AppTheme.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '输入音量',
                      style: AppTheme.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LevelMeter(
                      rms: frame?.rms ?? 0,
                      peak: frame?.peak ?? 0,
                      gate: gateLin,
                      listening: _listening,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      frame == null
                          ? (_listening ? '等待音频块…' : '未开始')
                          : 'RMS ${frame.rmsDb.toStringAsFixed(1)} dB'
                              ' · peak ${(frame.peak * 100).toStringAsFixed(0)}%'
                              ' · ${frame.aboveGate ? "已过门限" : "低于门限（不识音）"}',
                      style: AppTheme.body(
                        fontSize: 12,
                        color: frame?.aboveGate == true
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      frame?.label ?? '—',
                      textAlign: TextAlign.center,
                      style: AppTheme.display(
                        fontSize: frame != null && frame.midis.length > 3
                            ? 28
                            : 42,
                        color: frame?.confirmed == true
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      !_listening
                          ? '等待开始'
                          : frame == null
                              ? '等待音频块…'
                              : !frame.aboveGate
                                  ? '等待声音'
                                  : frame.confirmed
                                      ? '${frame.midis.length} 音'
                                          ' · ${_engineLabel(frame.engine)}'
                                          '${frame.clarity != null ? " · 置信 ${(frame.clarity! * 100).round()}%" : ""}'
                                      : '锁定中…',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '$_status'
                        '${_listening ? " · 命中 $_noteHits" : ""}',
                        textAlign: TextAlign.center,
                        style: AppTheme.body(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _toggle,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                label: Text(_listening ? '停止识别' : '开始识别'),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final geo = KeyboardGeometry(
                      width: constraints.maxWidth,
                      startMidi: _startMidi,
                      whiteKeyCount: _whiteKeys,
                    );
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: keyboardH,
                        width: constraints.maxWidth,
                        child: PianoKeyboard(
                          geometry: geo,
                          highlighted: {
                            for (final m in {...?frame?.midis, ..._lit})
                              m: Hand.right,
                          },
                          pressed: {
                            ...?frame?.midis,
                            ..._lit,
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '88 键标准音域：A0–C8（MIDI 21–108）',
                textAlign: TextAlign.center,
                style: AppTheme.body(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({
    required this.rms,
    required this.peak,
    required this.gate,
    required this.listening,
  });

  final double rms;
  final double peak;
  final double gate;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    // Visual scale: map rms 0..0.25 → full bar (typical speech/music mic levels)
    const visualMax = 0.25;
    final rmsT = (rms / visualMax).clamp(0.0, 1.0);
    final peakT = (peak / visualMax).clamp(0.0, 1.0);
    final gateT = (gate / visualMax).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 28,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              // RMS fill
              FractionallySizedBox(
                widthFactor: listening ? rmsT : 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.rightHand.withValues(alpha: 0.85),
                        AppColors.accent,
                        if (rmsT > 0.85) AppColors.danger,
                      ],
                    ),
                  ),
                ),
              ),
              // Peak tick
              if (listening && peakT > 0.02)
                Positioned(
                  left: (w * peakT - 1).clamp(0.0, w - 2),
                  top: 2,
                  bottom: 2,
                  child: Container(width: 2, color: Colors.white70),
                ),
              // Gate threshold line
              Positioned(
                left: (w * gateT - 1).clamp(0.0, w - 2),
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: AppColors.accent.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
