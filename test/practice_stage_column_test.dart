import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_constants.dart';

void main() {
  test('特效开：谱区贴刻线高度，多余高度给瀑布', () {
    final lanes = PracticeConstants.stageColumn(
      stageHeight: 700,
      compact: false,
      showFalling: true,
      staffInk: 210,
    );
    expect(lanes.staff, 210);
    expect(lanes.keyboard, PracticeConstants.keyboardHComfort);
    expect(lanes.falling, greaterThan(200));
    expect(
      lanes.falling +
          lanes.keyboard +
          lanes.staff +
          PracticeConstants.stageLaneGap,
      closeTo(700, 0.01),
    );
  });

  test('特效关：键盘与谱区约各一半', () {
    final lanes = PracticeConstants.stageColumn(
      stageHeight: 700,
      compact: false,
      showFalling: false,
      staffInk: 210,
    );
    expect(lanes.falling, 0);
    final room = 700 - PracticeConstants.stageLaneGap;
    expect(lanes.staff, closeTo(room * 0.5, 0.01));
    expect(lanes.keyboard, closeTo(room * 0.5, 0.01));
    expect(
      lanes.keyboard + lanes.staff + PracticeConstants.stageLaneGap,
      closeTo(700, 0.01),
    );
  });

  test('特效关：矮窗口仍保住键盘底线', () {
    final lanes = PracticeConstants.stageColumn(
      stageHeight: 220,
      compact: true,
      showFalling: false,
      staffInk: 200,
    );
    expect(lanes.falling, 0);
    expect(lanes.keyboard, greaterThanOrEqualTo(88));
    expect(
      lanes.keyboard + lanes.staff + PracticeConstants.stageLaneGap,
      closeTo(220, 0.01),
    );
  });

  test('未回报刻线高度时用一行回退，而不是 310 的空井', () {
    final lanes = PracticeConstants.stageColumn(
      stageHeight: 800,
      compact: false,
      showFalling: true,
    );
    expect(lanes.staff, PracticeConstants.staffInkFallbackComfort);
    expect(lanes.staff, lessThan(280));
    expect(lanes.falling, greaterThan(lanes.staff));
  });
}
