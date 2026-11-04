/// Shared midi ↔ X mapping for falling notes and the on-screen piano.
class KeyboardGeometry {
  KeyboardGeometry({
    required this.width,
    required this.startMidi,
    required this.whiteKeyCount,
  })  : assert(width > 0),
        assert(whiteKeyCount > 0) {
    final whites = <int>[];
    var midi = startMidi;
    while (whites.length < whiteKeyCount) {
      if (!isBlack(midi)) whites.add(midi);
      midi++;
    }
    whiteMidis = List.unmodifiable(whites);

    // Integer-pixel columns: base width + distribute residual so N keys
    // exactly fill [0, totalPx) — no right-side gap, no fractional overflow.
    final totalPx = width < 1 ? 1.0 : width.floorToDouble();
    final n = whiteKeyCount;
    final base = (totalPx / n).floorToDouble().clamp(1.0, totalPx);
    final rem = (totalPx - base * n).round().clamp(0, n);

    final widths = List<double>.generate(
      n,
      (i) => i < rem ? base + 1.0 : base,
    );
    final lefts = List<double>.filled(n, 0);
    var x = 0.0;
    for (var i = 0; i < n; i++) {
      lefts[i] = x;
      x += widths[i];
    }
    _whiteWidths = List.unmodifiable(widths);
    _whiteLefts = List.unmodifiable(lefts);

    // Nominal width (narrower column) — used for black key / bar sizing.
    whiteWidth = base;
    blackWidth = whiteWidth * 0.62;
    lastMidi = whiteMidis.last;

    final blacks = <int>[];
    for (var m = whiteMidis.first; m <= lastMidi; m++) {
      if (isBlack(m)) blacks.add(m);
    }
    blackMidis = List.unmodifiable(blacks);
  }

  /// Integer-pixel width — avoids sub-pixel geometry thrash during window drag.
  factory KeyboardGeometry.stable({
    required double width,
    required int startMidi,
    required int whiteKeyCount,
  }) {
    final w = width < 1 ? 1.0 : width.floorToDouble();
    return KeyboardGeometry(
      width: w,
      startMidi: startMidi,
      whiteKeyCount: whiteKeyCount,
    );
  }

  final double width;
  final int startMidi;
  final int whiteKeyCount;

  late final List<int> whiteMidis;
  late final List<int> blackMidis;
  late final List<double> _whiteWidths;
  late final List<double> _whiteLefts;

  /// Nominal (base) white-key width in px; some keys may be +1 via residual.
  late final double whiteWidth;
  late final double blackWidth;
  late final int lastMidi;

  double whiteKeyWidth(int index) => _whiteWidths[index];

  double whiteKeyLeft(int index) => _whiteLefts[index];

  static bool isBlack(int midi) {
    const blacks = {1, 3, 6, 8, 10};
    return blacks.contains(midi % 12);
  }

  /// Pitch-class label for on-key marking.
  /// Sharps on black keys — matches practice「请弹：C#2」status labels.
  static String midiKeyLabel(int midi) {
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    return names[midi % 12];
  }

  /// Scientific octave number for [midi] (MIDI 60 → 4).
  static int midiOctave(int midi) => (midi ~/ 12) - 1;

  /// Pitch label with octave (C4, Ab3, …) for lit-key overlays.
  static String midiPitchLabel(int midi) =>
      '${midiKeyLabel(midi)}${midiOctave(midi)}';

  /// White-key mark with octave (C3, E4, …).
  static String midiWhiteKeyLabel(int midi) => midiPitchLabel(midi);

  bool containsMidi(int midi) {
    return midi >= whiteMidis.first && midi <= lastMidi;
  }

  /// Horizontal center of the key for [midi], or null if out of range.
  double? midiToCenterX(int midi) {
    if (!containsMidi(midi)) return null;
    if (isBlack(midi)) {
      final left = blackKeyLeft(midi);
      if (left == null) return null;
      return left + blackWidth / 2;
    }
    final i = whiteMidis.indexOf(midi);
    if (i < 0) return null;
    return whiteKeyLeft(i) + whiteKeyWidth(i) / 2;
  }

  /// True when [midi]'s bar center matches the piano key center (Flowkey X-align).
  bool centersAlign(int midi, {double epsilon = 0.01}) {
    final c = midiToCenterX(midi);
    if (c == null) return false;
    if (isBlack(midi)) {
      final left = blackKeyLeft(midi)!;
      return (c - (left + blackWidth / 2)).abs() <= epsilon;
    }
    final i = whiteMidis.indexOf(midi);
    final expected = whiteKeyLeft(i) + whiteKeyWidth(i) / 2;
    return (c - expected).abs() <= epsilon;
  }

  /// Left edge of a black key, matching [PianoKeyboard] placement.
  double? blackKeyLeft(int midi) {
    if (!isBlack(midi) || !containsMidi(midi)) return null;
    final leftWhiteIndex = whiteMidis.indexWhere((w) => w > midi) - 1;
    if (leftWhiteIndex < 0) return null;
    return whiteKeyLeft(leftWhiteIndex + 1) - blackWidth / 2;
  }

  double noteBarWidth(int midi) {
    if (isBlack(midi)) return blackWidth * 0.78;
    final i = whiteMidis.indexOf(midi);
    if (i < 0) return whiteWidth * 0.62;
    return whiteKeyWidth(i) * 0.62;
  }

  @override
  bool operator ==(Object other) {
    return other is KeyboardGeometry &&
        other.width == width &&
        other.startMidi == startMidi &&
        other.whiteKeyCount == whiteKeyCount;
  }

  @override
  int get hashCode => Object.hash(width, startMidi, whiteKeyCount);
}
