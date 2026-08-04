import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_constants.dart';
import 'package:piano_flow/features/practice/practice_loop_logic.dart';

void main() {
  group('withStartLeadIn', () {
    test('parks near beat 0 into negative pre-roll', () {
      expect(
        PracticeLoopLogic.withStartLeadIn(0),
        PracticeConstants.playbackStartParkBeats,
      );
      expect(
        PracticeLoopLogic.withStartLeadIn(0.04),
        PracticeConstants.playbackStartParkBeats,
      );
    });

    test('keeps mid-piece and existing pre-roll', () {
      expect(PracticeLoopLogic.withStartLeadIn(2), 2);
      expect(PracticeLoopLogic.withStartLeadIn(-0.5), -0.5);
    });
  });

  group('wrapIfPastEnd', () {
    test('null while still inside the loop', () {
      expect(
        PracticeLoopLogic.wrapIfPastEnd(
          next: 3.9,
          loopStart: 0,
          loopEnd: 4,
        ),
        isNull,
      );
    });

    test('wraps to lead-in when loopStart is piece beginning', () {
      expect(
        PracticeLoopLogic.wrapIfPastEnd(
          next: 4.0,
          loopStart: 0,
          loopEnd: 4,
        ),
        PracticeConstants.playbackStartParkBeats,
      );
      expect(
        PracticeLoopLogic.wrapIfPastEnd(
          next: 4.05,
          loopStart: 0,
          loopEnd: 4,
        ),
        PracticeConstants.playbackStartParkBeats,
      );
    });

    test('wraps to mid-piece loopStart without lead-in', () {
      expect(
        PracticeLoopLogic.wrapIfPastEnd(
          next: 8.1,
          loopStart: 2,
          loopEnd: 8,
        ),
        2.0,
      );
    });
  });

  group('metronomeBeatIndexForPosition', () {
    test('floors playhead; clamps negative pre-roll to 0', () {
      expect(PracticeLoopLogic.metronomeBeatIndexForPosition(3.9), 3);
      expect(PracticeLoopLogic.metronomeBeatIndexForPosition(4.0), 4);
      expect(
        PracticeLoopLogic.metronomeBeatIndexForPosition(
          PracticeConstants.playbackStartParkBeats,
        ),
        0,
      );
    });

    test('loop wrap to start resets metro index vs continuing past end', () {
      const loopEnd = 4.0;
      // Without wrap alignment, a continuing counter would stay at 4+.
      expect(PracticeLoopLogic.metronomeBeatIndexForPosition(loopEnd), 4);
      final wrapped = PracticeLoopLogic.wrapIfPastEnd(
        next: loopEnd,
        loopStart: 0,
        loopEnd: loopEnd,
      )!;
      expect(
        PracticeLoopLogic.metronomeBeatIndexForPosition(wrapped),
        0,
      );
    });
  });

  group('shouldRealignMetronome', () {
    test('playing + metro + speed change → realign', () {
      expect(
        PracticeLoopLogic.shouldRealignMetronome(
          isPlaying: true,
          metronomeEnabled: true,
          speedChanged: true,
          metronomeJustEnabled: false,
        ),
        isTrue,
      );
    });

    test('playing + turning metro on → realign', () {
      expect(
        PracticeLoopLogic.shouldRealignMetronome(
          isPlaying: true,
          metronomeEnabled: true,
          speedChanged: false,
          metronomeJustEnabled: true,
        ),
        isTrue,
      );
    });

    test('paused or metro off skips realign', () {
      expect(
        PracticeLoopLogic.shouldRealignMetronome(
          isPlaying: false,
          metronomeEnabled: true,
          speedChanged: true,
          metronomeJustEnabled: false,
        ),
        isFalse,
      );
      expect(
        PracticeLoopLogic.shouldRealignMetronome(
          isPlaying: true,
          metronomeEnabled: false,
          speedChanged: true,
          metronomeJustEnabled: false,
        ),
        isFalse,
      );
    });

    test('unchanged speed with metro already on skips', () {
      expect(
        PracticeLoopLogic.shouldRealignMetronome(
          isPlaying: true,
          metronomeEnabled: true,
          speedChanged: false,
          metronomeJustEnabled: false,
        ),
        isFalse,
      );
    });
  });
}
