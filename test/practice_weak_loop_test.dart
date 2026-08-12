import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_weak_loop.dart';

void main() {
  test('empty misses → null', () {
    expect(
      PracticeWeakLoopLogic.suggest(missBeats: const [], durationBeats: 16),
      isNull,
    );
  });

  test('single miss pads into a short loop', () {
    final r = PracticeWeakLoopLogic.suggest(
      missBeats: const [4.0],
      durationBeats: 16,
    );
    expect(r, isNotNull);
    expect(r!.start, lessThan(4.0));
    expect(r.end, greaterThan(4.0));
    expect(r.end - r.start, greaterThanOrEqualTo(1.0));
  });

  test('cluster prefers densest miss region', () {
    final r = PracticeWeakLoopLogic.suggest(
      missBeats: const [1.0, 8.0, 8.5, 9.0, 9.2, 15.0],
      durationBeats: 20,
    );
    expect(r, isNotNull);
    expect(r!.start, lessThan(8.0));
    expect(r.end, greaterThan(9.0));
    expect(r.start, greaterThan(2.0)); // not pulled to beat 1
  });

  test('label mentions 薄弱', () {
    expect(
      PracticeWeakLoopLogic.labelZh((start: 2, end: 5)),
      contains('薄弱'),
    );
  });
}
