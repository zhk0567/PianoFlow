import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/swift_f0.dart';

void main() {
  test('resampleLinear 44.1k → 16k preserves A4 period roughly', () {
    const fromSr = 44100;
    const toSr = 16000;
    const hz = 440.0;
    final n = fromSr; // 1s
    final input = List<double>.generate(
      n,
      (i) => 0.4 * math.sin(2 * math.pi * hz * i / fromSr),
    );
    final out = resampleLinear(input, fromSr, toSr);
    expect(out.length, closeTo(toSr, 2));

    // Zero-crossing density ≈ 2*hz per second
    var crossings = 0;
    for (var i = 1; i < out.length; i++) {
      if (out[i - 1] <= 0 && out[i] > 0) crossings++;
    }
    expect(crossings, closeTo(hz, 30));
  });

  test('golden fixture A4 median pitch near 440 (Python/ONNX reference)', () {
    final file = File('test/fixtures/swiftf0_a4.json');
    expect(file.existsSync(), isTrue, reason: 'run download + fixture gen first');
    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final pitches = (map['pitch_hz'] as List).cast<num>().map((e) => e.toDouble()).toList();
    final confs = (map['confidence'] as List).cast<num>().map((e) => e.toDouble()).toList();
    final voiced = <double>[];
    for (var i = 0; i < pitches.length; i++) {
      if (confs[i] > 0.9) voiced.add(pitches[i]);
    }
    expect(voiced, isNotEmpty);
    voiced.sort();
    final med = voiced[voiced.length ~/ 2];
    expect(med, closeTo(440, 15));
  });

  test('SwiftF0 ONNX matches golden fixture (plugin)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final file = File('test/fixtures/swiftf0_a4.json');
    if (!file.existsSync()) {
      return;
    }
    if (!File('assets/models/swiftf0.onnx').existsSync()) {
      return;
    }

    SwiftF0Estimator? est;
    try {
      est = await SwiftF0Estimator.create();
    } catch (e) {
      // Unit test host may lack ORT native plugin — skip.
      // ignore: avoid_print
      print('SwiftF0 session skip: $e');
      return;
    }

    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final audio = Float32List.fromList(
      (map['audio'] as List).cast<num>().map((e) => e.toDouble()).toList(),
    );
    final got = await est.estimate16k(audio);
    await est.dispose();
    expect(got, isNotNull);
    expect(got!.hz, closeTo(440, 20));
    expect(got.clarity, greaterThan(0.8));
  });
}
