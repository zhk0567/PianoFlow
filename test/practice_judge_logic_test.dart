import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_constants.dart';
import 'package:piano_flow/features/practice/practice_judge_logic.dart';
import 'package:piano_flow/features/practice/practice_settlement_copy.dart';

void main() {
  group('PracticeJudgeLogic.gradeFromDelta', () {
    test('perfect within judgePerfectBeats', () {
      expect(PracticeJudgeLogic.gradeFromDelta(0), HitGrade.perfect);
      expect(
        PracticeJudgeLogic.gradeFromDelta(PracticeConstants.judgePerfectBeats),
        HitGrade.perfect,
      );
      expect(
        PracticeJudgeLogic.gradeFromDelta(-PracticeConstants.judgePerfectBeats),
        HitGrade.perfect,
      );
    });

    test('good between perfect and early window', () {
      final mid = (PracticeConstants.judgePerfectBeats +
              PracticeConstants.waitEarlyHitBeats) /
          2;
      expect(PracticeJudgeLogic.gradeFromDelta(mid), HitGrade.good);
      expect(PracticeJudgeLogic.gradeFromDelta(-mid), HitGrade.good);
      expect(
        PracticeJudgeLogic.gradeFromDelta(
          PracticeConstants.waitEarlyHitBeats,
        ),
        HitGrade.good,
      );
    });

    test('just outside perfect is good', () {
      expect(
        PracticeJudgeLogic.gradeFromDelta(
          PracticeConstants.judgePerfectBeats + 0.001,
        ),
        HitGrade.good,
      );
    });
  });

  group('PracticeJudgeLogic.accuracy / score100', () {
    test('empty session is zero', () {
      expect(
        PracticeJudgeLogic.accuracy(perfects: 0, goods: 0, misses: 0),
        0,
      );
      expect(
        PracticeJudgeLogic.score100(perfects: 0, goods: 0, misses: 0),
        0,
      );
    });

    test('all perfect', () {
      expect(
        PracticeJudgeLogic.accuracy(perfects: 5, goods: 0, misses: 0),
        1,
      );
      expect(
        PracticeJudgeLogic.score100(perfects: 5, goods: 0, misses: 0),
        100,
      );
    });

    test('mixed', () {
      expect(
        PracticeJudgeLogic.accuracy(perfects: 1, goods: 1, misses: 2),
        0.5,
      );
      expect(
        PracticeJudgeLogic.score100(perfects: 2, goods: 0, misses: 2),
        50,
      );
    });
  });

  group('PracticeSettlementCopy', () {
    test('all perfect title', () {
      expect(
        PracticeSettlementCopy.title(
          perfects: 3,
          goods: 0,
          misses: 0,
          maxCombo: 3,
        ),
        '神仙手指',
      );
    });

    test('low accuracy title', () {
      expect(
        PracticeSettlementCopy.title(
          perfects: 0,
          goods: 1,
          misses: 5,
          maxCombo: 1,
        ),
        '慢练更香',
      );
    });
  });
}
