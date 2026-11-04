import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_fx_onsets.dart';
import 'package:piano_flow/features/practice/practice_stage_theme.dart';
import 'package:piano_flow/shared/models/song.dart';
import 'package:piano_flow/shared/theme/app_theme.dart';

ScoreNote _n(int midi, double start, Hand hand) {
  return ScoreNote(midi: midi, start: start, duration: 1, hand: hand);
}

void main() {
  test('同拍和弦每个音高各算一次发声', () {
    final notes = [
      _n(60, 1, Hand.right),
      _n(64, 1, Hand.right),
      _n(67, 1, Hand.left),
    ];
    final got = soundingOnsetsCrossing(notes: notes, prev: 0.9, pos: 1.05);
    expect(got.map((e) => e.midi).toList(), [60, 64, 67]);
  });

  test('同一 MIDI 同拍双手齐奏只算一声', () {
    final notes = [_n(60, 1, Hand.left), _n(60, 1, Hand.right)];
    final got = soundingOnsetsCrossing(notes: notes, prev: 0.9, pos: 1.05);
    expect(got, hasLength(1));
    expect(got.single.midi, 60);
  });

  test('同一音高稍后再次经过击打线仍算发声', () {
    final notes = [_n(60, 1, Hand.right), _n(60, 1.25, Hand.right)];
    final first = soundingOnsetsCrossing(notes: notes, prev: 0.9, pos: 1.05);
    final second = soundingOnsetsCrossing(notes: notes, prev: 1.05, pos: 1.3);
    expect(first.single.start, 1);
    expect(second.single.start, 1.25);
  });

  test('已经过线的音不会在下一窗重放', () {
    final notes = [_n(60, 1, Hand.right)];
    final got = soundingOnsetsCrossing(notes: notes, prev: 1, pos: 1.2);
    expect(got, isEmpty);
  });

  test('装饰舞台留在暖纸家族，关闭特效仍是日常纸色', () {
    const fx = PracticeStageTheme.decorated;
    const plain = PracticeStageTheme.standard;
    expect(plain.pageBg, AppColors.background);
    expect(plain.panelBg, AppColors.surface);
    expect(plain.accent, AppColors.accent);
    expect(fx.pageBg, const Color(0xFFE3D6C4));
    expect(fx.accent, AppColors.accent);
    expect(fx.textPrimary, AppColors.textPrimary);
    expect(fx.auroraWarm, AppColors.accentWarm);
    expect(fx.auroraCool, AppColors.rightHand);
    expect(fx.pageBg, isNot(const Color(0xFF020B18)));
    expect(fx.accent, isNot(const Color(0xFFFFD078)));
    expect(
      PracticeStageTheme.of(visualFxEnabled: false).pageBg,
      AppColors.background,
    );
    expect(PracticeStageTheme.of(visualFxEnabled: true).pageBg, fx.pageBg);
  });

  test('等待态是左右手颜色变浅，不是第三种颜色', () {
    final left = PracticeStageTheme.waitingFillForHand(Hand.left);
    final right = PracticeStageTheme.waitingFillForHand(Hand.right);
    expect(left, isNot(AppColors.keyWait));
    expect(right, isNot(AppColors.keyWait));
    expect(left, isNot(right));
    expect(left, Color.lerp(AppColors.leftHand, Colors.white, 0.28));
    expect(right, Color.lerp(AppColors.rightHand, Colors.white, 0.28));
  });
}
