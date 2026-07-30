import 'package:flutter_test/flutter_test.dart';

import 'package:piano_flow/features/practice/keyboard_geometry.dart';
import 'package:piano_flow/features/practice/practice_constants.dart';

void main() {
  group('KeyboardGeometry', () {
    test('maps white and black keys to centers within width', () {
      final geo = KeyboardGeometry(
        width: 750,
        startMidi: 48,
        whiteKeyCount: 15,
      );

      expect(geo.whiteWidth, 50);
      expect(geo.containsMidi(48), isTrue);
      expect(geo.containsMidi(47), isFalse);

      final c3 = geo.midiToCenterX(48);
      expect(c3, isNotNull);
      expect(c3!, closeTo(25, 0.01));

      final cs = geo.midiToCenterX(49);
      expect(cs, isNotNull);
      expect(cs! > c3, isTrue);
      expect(cs < geo.midiToCenterX(50)!, isTrue);
    });

    test('equality depends on layout params', () {
      final a = KeyboardGeometry(width: 100, startMidi: 48, whiteKeyCount: 15);
      final b = KeyboardGeometry(width: 100, startMidi: 48, whiteKeyCount: 15);
      final c = KeyboardGeometry(width: 200, startMidi: 48, whiteKeyCount: 15);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('distributes residual so white keys fill integer width', () {
      // 100 / 15 → base 6, rem 10 → 10×7 + 5×6 = 100 (no right gap)
      final geo = KeyboardGeometry(
        width: 100,
        startMidi: 48,
        whiteKeyCount: 15,
      );
      expect(geo.whiteWidth, 6);
      var sum = 0.0;
      for (var i = 0; i < geo.whiteKeyCount; i++) {
        sum += geo.whiteKeyWidth(i);
      }
      expect(sum, 100);
      expect(geo.whiteKeyWidth(0), 7);
      expect(geo.whiteKeyWidth(9), 7);
      expect(geo.whiteKeyWidth(10), 6);
      expect(geo.whiteKeyLeft(geo.whiteKeyCount - 1) + geo.whiteKeyWidth(geo.whiteKeyCount - 1), 100);
    });

    test('stable floors width then fills exactly', () {
      final geo = KeyboardGeometry.stable(
        width: 100.9,
        startMidi: PracticeConstants.startMidi,
        whiteKeyCount: PracticeConstants.whiteKeyCount,
      );
      expect(geo.width, 100);
      var sum = 0.0;
      for (var i = 0; i < geo.whiteKeyCount; i++) {
        sum += geo.whiteKeyWidth(i);
      }
      expect(sum, 100);
    });

    test('standard 88-key spans A0 to C8', () {
      final geo = KeyboardGeometry(
        width: 1040,
        startMidi: 21,
        whiteKeyCount: 52,
      );
      expect(geo.whiteMidis.first, 21);
      expect(geo.lastMidi, 108);
      expect(geo.whiteMidis, hasLength(52));
      expect(geo.blackMidis, hasLength(36));
      expect(geo.containsMidi(21), isTrue);
      expect(geo.containsMidi(108), isTrue);
      expect(geo.containsMidi(20), isFalse);
      expect(geo.containsMidi(109), isFalse);
      expect(geo.midiToCenterX(21), isNotNull);
      expect(geo.midiToCenterX(108), isNotNull);
      // Residual fill: 1040 / 52 = 20 exactly
      expect(geo.whiteWidth, 20);
      var sum = 0.0;
      for (var i = 0; i < geo.whiteKeyCount; i++) {
        sum += geo.whiteKeyWidth(i);
      }
      expect(sum, 1040);
    });

    test('midiKeyLabel uses naturals and flat accidentals', () {
      expect(KeyboardGeometry.midiKeyLabel(60), 'C');
      expect(KeyboardGeometry.midiKeyLabel(61), 'Db');
      expect(KeyboardGeometry.midiKeyLabel(62), 'D');
      expect(KeyboardGeometry.midiKeyLabel(63), 'Eb');
      expect(KeyboardGeometry.midiKeyLabel(64), 'E');
      expect(KeyboardGeometry.midiKeyLabel(65), 'F');
      expect(KeyboardGeometry.midiKeyLabel(66), 'Gb');
      expect(KeyboardGeometry.midiKeyLabel(67), 'G');
      expect(KeyboardGeometry.midiKeyLabel(68), 'Ab');
      expect(KeyboardGeometry.midiKeyLabel(69), 'A');
      expect(KeyboardGeometry.midiKeyLabel(70), 'Bb');
      expect(KeyboardGeometry.midiKeyLabel(71), 'B');
    });

    test('midiWhiteKeyLabel / midiPitchLabel always include octave', () {
      expect(KeyboardGeometry.midiWhiteKeyLabel(60), 'C4');
      expect(KeyboardGeometry.midiWhiteKeyLabel(62), 'D4');
      expect(KeyboardGeometry.midiWhiteKeyLabel(48), 'C3');
      expect(KeyboardGeometry.midiWhiteKeyLabel(71), 'B4');
      expect(KeyboardGeometry.midiWhiteKeyLabel(21), 'A0');
      expect(KeyboardGeometry.midiPitchLabel(68), 'Ab4');
      expect(KeyboardGeometry.midiPitchLabel(61), 'Db4');
    });

    test('midiOctave follows scientific pitch notation', () {
      expect(KeyboardGeometry.midiOctave(60), 4);
      expect(KeyboardGeometry.midiOctave(21), 0);
    });
  });

  group('Staff step mapping', () {
    test('B4 is middle line; E4 bottom; F5 top', () {
      expect(_staffStep(71), 0);
      expect(_staffStep(64), -4);
      expect(_staffStep(77), 4);
      expect(_staffStep(60), -6);
    });
  });
}

double _staffStep(int midi) {
  const stepOfPc = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
  final pc = midi % 12;
  final octave = midi ~/ 12;
  final stepFromC0 = octave * 7 + stepOfPc[pc];
  const b4FromC0 = 41;
  return (stepFromC0 - b4FromC0).toDouble();
}
