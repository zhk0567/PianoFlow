import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_pos_history.dart';

void main() {
  test('empty history returns fallback', () {
    final h = PracticePosHistory();
    expect(h.beatsAt(DateTime.now(), fallback: 3.5), 3.5);
  });

  test('interpolates between samples', () {
    final h = PracticePosHistory();
    final t0 = DateTime.utc(2026, 1, 1, 12);
    h.record(t0, 0);
    h.record(t0.add(const Duration(milliseconds: 100)), 1);
    final mid = t0.add(const Duration(milliseconds: 50));
    expect(h.beatsAt(mid, fallback: -1), closeTo(0.5, 1e-9));
  });

  test('before first returns first beats', () {
    final h = PracticePosHistory();
    final t0 = DateTime.utc(2026, 1, 1, 12);
    h.record(t0, 4);
    expect(
      h.beatsAt(t0.subtract(const Duration(milliseconds: 20)), fallback: 0),
      4,
    );
  });
}
