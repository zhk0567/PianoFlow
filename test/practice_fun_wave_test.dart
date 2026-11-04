import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_exam_eval.dart';
import 'package:piano_flow/features/practice/practice_judge_logic.dart';
import 'package:piano_flow/features/practice/practice_models.dart';
import 'package:piano_flow/features/practice/practice_settlement_copy.dart';
import 'package:piano_flow/features/practice/verovio_transport_sync.dart';
import 'package:piano_flow/features/practice/widgets/practice_atmosphere.dart';

void main() {
  test('seek epoch helper', () {
    expect(
      VerovioTransportSync.shouldSnapForEpoch(
        previousEpoch: 1,
        currentEpoch: 1,
      ),
      isFalse,
    );
    expect(
      VerovioTransportSync.shouldSnapForEpoch(
        previousEpoch: 1,
        currentEpoch: 2,
      ),
      isTrue,
    );
  });

  test('settlement copy never says 失误', () {
    for (var i = 0; i < 30; i++) {
      final t = PracticeSettlementCopy.title(
        perfects: i % 5,
        goods: i % 3,
        misses: i % 4,
        maxCombo: i,
        songSessions: i,
        now: DateTime(2026, 8, 5, 23, 30),
      );
      expect(t.contains('失误'), isFalse);
    }
  });

  test('exam eval positive framing', () {
    final e = PracticeExamEval.build(
      perfects: 10,
      goods: 4,
      misses: 2,
      maxCombo: 6,
      hitLog: [
        (beat: 4.0, grade: HitGrade.good),
        (beat: 8.0, grade: HitGrade.perfect),
      ],
    );
    expect(e.score100, greaterThan(50));
    expect(e.goods.join().contains('失误'), isFalse);
    expect(e.improves.join().contains('失误'), isFalse);
  });

  test('decorative visual FX default on', () {
    const s = PracticeSettings();
    expect(s.visualFxEnabled, isTrue);
    expect(s.showGhost, isFalse);
  });

  test('atmosphere resolver still available (unmounted from practice page)', () {
    expect(
      PracticeAtmosphereResolver.resolve(
        genre: 'Classical',
        songId: 'beethoven_moonlight_sonata',
      ),
      PracticeAtmosphereKind.night,
    );
  });

  test('judge perfect window', () {
    expect(PracticeJudgeLogic.gradeFromDelta(0.05), HitGrade.perfect);
    expect(PracticeJudgeLogic.gradeFromDelta(0.2), HitGrade.good);
  });
}
