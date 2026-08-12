import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_constants.dart';
import 'package:piano_flow/features/practice/practice_loop_logic.dart';
import 'package:piano_flow/features/practice/verovio_transport_sync.dart';

void main() {
  group('shouldSkipPush', () {
    test('skips tiny position + rate noise while play steady', () {
      expect(
        VerovioTransportSync.shouldSkipPush(
          posDelta: 0.005,
          playChanged: false,
          rateDelta: 0.0,
        ),
        isTrue,
      );
      expect(
        VerovioTransportSync.shouldSkipPush(
          posDelta: VerovioTransportSync.posMinDelta,
          playChanged: false,
          rateDelta: VerovioTransportSync.rateMinDelta,
        ),
        isTrue,
      );
    });

    test('does not skip on play/pause or meaningful move/rate', () {
      expect(
        VerovioTransportSync.shouldSkipPush(
          posDelta: 0,
          playChanged: true,
          rateDelta: 0,
        ),
        isFalse,
      );
      expect(
        VerovioTransportSync.shouldSkipPush(
          posDelta: 0.02,
          playChanged: false,
          rateDelta: 0,
        ),
        isFalse,
      );
      expect(
        VerovioTransportSync.shouldSkipPush(
          posDelta: 0,
          playChanged: false,
          rateDelta: 0.05,
        ),
        isFalse,
      );
    });
  });

  group('shouldSnapSeek', () {
    test('boundary: equal 0.35 eases; above snaps', () {
      expect(
        VerovioTransportSync.shouldSnapSeek(VerovioTransportSync.seekSnapBeats),
        isFalse,
      );
      expect(
        VerovioTransportSync.shouldSnapSeek(
          VerovioTransportSync.seekSnapBeats + 1e-9,
        ),
        isTrue,
      );
      expect(VerovioTransportSync.shouldSnapSeek(0.34), isFalse);
      expect(VerovioTransportSync.shouldSnapSeek(1.0), isTrue);
    });

    test('normal tick advance does not snap', () {
      // ~16ms tick at 120 BPM ≈ 0.032 beats — well under seek threshold.
      const tickBeats = 120 / 60 * (16 / 1000);
      expect(tickBeats, lessThan(VerovioTransportSync.seekSnapBeats));
      expect(VerovioTransportSync.shouldSnapSeek(tickBeats), isFalse);
    });

    test('loop wrap to lead-in snaps (matches seek)', () {
      const loopEnd = 4.0;
      final wrapped = PracticeLoopLogic.wrapIfPastEnd(
        next: loopEnd,
        loopStart: 0,
        loopEnd: loopEnd,
      )!;
      expect(wrapped, PracticeConstants.playbackStartParkBeats);
      final delta = VerovioTransportSync.positionDelta(loopEnd, wrapped);
      expect(delta, greaterThan(VerovioTransportSync.seekSnapBeats));
      expect(VerovioTransportSync.shouldSnapSeek(delta), isTrue);
    });

    test('mid-piece loop wrap snaps', () {
      final wrapped = PracticeLoopLogic.wrapIfPastEnd(
        next: 8.05,
        loopStart: 2,
        loopEnd: 8,
      )!;
      final delta = VerovioTransportSync.positionDelta(8.05, wrapped);
      expect(VerovioTransportSync.shouldSnapSeek(delta), isTrue);
    });

    test('small scrub under threshold eases', () {
      final delta = VerovioTransportSync.positionDelta(3.0, 3.2);
      expect(delta, closeTo(0.2, 1e-9));
      expect(VerovioTransportSync.shouldSnapSeek(delta), isFalse);
    });
  });

  group('shouldDeferResize', () {
    test('defers while score/resize push holds the bridge', () {
      expect(VerovioTransportSync.shouldDeferResize(pushing: true), isTrue);
      expect(VerovioTransportSync.shouldDeferResize(pushing: false), isFalse);
    });
  });

  group('shouldSnapForRateZeroCrossing', () {
    test('snaps when freeze starts or ends', () {
      expect(
        VerovioTransportSync.shouldSnapForRateZeroCrossing(
          previousRate: 2.0,
          currentRate: 0,
        ),
        isTrue,
      );
      expect(
        VerovioTransportSync.shouldSnapForRateZeroCrossing(
          previousRate: 0,
          currentRate: 2.0,
        ),
        isTrue,
      );
      expect(
        VerovioTransportSync.shouldSnapForRateZeroCrossing(
          previousRate: 2.0,
          currentRate: 2.1,
        ),
        isFalse,
      );
      expect(
        VerovioTransportSync.shouldSnapForRateZeroCrossing(
          previousRate: 0,
          currentRate: 0,
        ),
        isFalse,
      );
    });
  });
}
