import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_exam_eval.dart';
import 'package:piano_flow/features/practice/practice_judge_logic.dart';
import 'package:piano_flow/features/practice/practice_settlement_copy.dart';
import 'package:piano_flow/features/practice/verovio_transport_sync.dart';
import 'package:piano_flow/features/practice/widgets/practice_atmosphere.dart';

void main() {
  group('shouldSnapForEpoch', () {
    test('snaps only when epoch advances', () {
      expect(
        VerovioTransportSync.shouldSnapForEpoch(
          previousEpoch: 0,
          currentEpoch: 0,
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
  });

  group('shouldSnapSeek intentional', () {
    test('intentional seek always snaps', () {
      expect(
        VerovioTransportSync.shouldSnapSeek(0.01, intentionalSeek: true),
        isTrue,
      );
    });
  });

  group('PracticeSettlementCopy', () {
    test('never mentions 失误', () {
      for (var i = 0; i < 40; i++) {
        final t = PracticeSettlementCopy.title(
          perfects: i % 5,
          goods: i % 3,
          misses: i % 4,
          maxCombo: i,
          songSessions: i,
          now: DateTime(2026, 8, 5, 23, 30),
        );
        final s = PracticeSettlementCopy.subtitle(
          perfects: i % 5,
          goods: i % 3,
          misses: i % 4,
        );
        expect(t.contains('失误'), isFalse);
        expect(s.contains('失误'), isFalse);
      }
    });
  });

  group('PracticeExamEval', () {
    test('builds positive eval without 失误', () {
      final e = PracticeExamEval.build(
        perfects: 10,
        goods: 4,
        misses: 2,
        maxCombo: 6,
        hitLog: [
          (beat: 4.0, grade: HitGrade.good),
          (beat: 8.0, grade: HitGrade.perfect),
          (beat: 12.0, grade: HitGrade.good),
        ],
      );
      expect(e.score100, greaterThan(50));
      expect(e.goods, isNotEmpty);
      expect(e.improves, isNotEmpty);
      expect(e.goods.join().contains('失误'), isFalse);
      expect(e.improves.join().contains('失误'), isFalse);
    });
  });

  group('PracticeAtmosphereResolver', () {
    test('maps genre / id to atmosphere', () {
      expect(
        PracticeAtmosphereResolver.resolve(
          genre: 'Classical',
          songId: 'beethoven_moonlight_sonata',
        ),
        PracticeAtmosphereKind.night,
      );
      expect(
        PracticeAtmosphereResolver.resolve(
          genre: 'Game',
          songId: 'c418_sweden',
        ),
        PracticeAtmosphereKind.mist,
      );
    });
  });
}
