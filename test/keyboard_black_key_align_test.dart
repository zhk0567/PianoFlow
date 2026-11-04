import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/keyboard_geometry.dart';
import 'package:piano_flow/features/practice/practice_constants.dart';

void main() {
  test('C#2 bar center sits on C/D gap, not C2 white center', () {
    final geo = KeyboardGeometry.stable(
      width: 1200,
      startMidi: PracticeConstants.startMidi,
      whiteKeyCount: PracticeConstants.whiteKeyCount,
    );

    const c2 = 36;
    const cs2 = 37;
    const d2 = 38;

    expect(KeyboardGeometry.isBlack(cs2), isTrue);
    expect(KeyboardGeometry.midiPitchLabel(cs2), 'C#2');

    final cCenter = geo.midiToCenterX(c2)!;
    final csCenter = geo.midiToCenterX(cs2)!;
    final dCenter = geo.midiToCenterX(d2)!;
    final dLeft = geo.whiteKeyLeft(geo.whiteMidis.indexOf(d2));
    final blackLeft = geo.blackKeyLeft(cs2)!;

    // Black key centered on the C–D boundary (D's left edge).
    expect(csCenter, closeTo(dLeft, 0.01));
    expect(csCenter, closeTo(blackLeft + geo.blackWidth / 2, 0.01));

    // Must not collapse onto the white C2 center (user-reported bug).
    expect((csCenter - cCenter).abs(), greaterThan(geo.whiteWidth * 0.35));
    expect(csCenter, greaterThan(cCenter));
    expect(csCenter, lessThan(dCenter));
  });

  test('all black midis A0–C8 have finite centers between neighbors', () {
    final geo = KeyboardGeometry.stable(
      width: 1280,
      startMidi: PracticeConstants.startMidi,
      whiteKeyCount: PracticeConstants.whiteKeyCount,
    );
    expect(geo.blackMidis, isNotEmpty);
    for (final m in geo.blackMidis) {
      final c = geo.midiToCenterX(m);
      expect(c, isNotNull, reason: 'midi $m');
      expect(geo.blackKeyLeft(m), isNotNull, reason: 'left $m');
      expect(geo.centersAlign(m), isTrue, reason: 'align $m');
      expect(c! > 0 && c < geo.width, isTrue);
    }
  });
}
