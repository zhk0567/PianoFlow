import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/basic_pitch.dart';
import 'package:piano_flow/features/practice/swift_f0.dart';

void main() {
  test('BP hop resample is much smaller than full 2s window', () {
    const hop441 = 1323;
    const window441 = 11025;
    final hop = List<double>.filled(hop441, 0.1);
    final full = List<double>.filled(window441, 0.1);
    final hop22 = resampleLinear(hop, 44100, BasicPitchEstimator.sampleRate);
    final full22 = resampleLinear(full, 44100, BasicPitchEstimator.sampleRate);
    expect(hop22.length, lessThan(full22.length ~/ 4));
    expect(hop22.length, closeTo(hop441 / 2, 2));
  });

  test('22k ring unwrap is chronological after wrap', () {
    const cap = 8;
    final ring = Float64List(cap);
    var write = 0;
    var filled = 0;
    void append(List<double> s) {
      for (final v in s) {
        ring[write] = v;
        write = (write + 1) % cap;
        if (filled < cap) filled++;
      }
    }

    Float32List linear() {
      if (filled < cap) {
        return Float32List.fromList(ring.sublist(0, filled));
      }
      final out = Float32List(cap);
      final head = cap - write;
      for (var i = 0; i < head; i++) {
        out[i] = ring[write + i];
      }
      for (var i = 0; i < write; i++) {
        out[head + i] = ring[i];
      }
      return out;
    }

    append([1, 2, 3, 4, 5, 6]);
    expect(linear().toList(), [1, 2, 3, 4, 5, 6]);
    append([7, 8, 9, 10]);
    expect(linear().toList(), [3, 4, 5, 6, 7, 8, 9, 10]);
  });
}
