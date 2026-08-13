import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/workshop/workshop_pdf_guide.dart';

void main() {
  test('pollAttempts covers timeout window', () {
    expect(
      WorkshopPdfGuide.pollAttempts(
        timeout: const Duration(seconds: 9),
        interval: const Duration(seconds: 3),
      ),
      3,
    );
    expect(
      WorkshopPdfGuide.pollAttempts(
        timeout: const Duration(milliseconds: 1),
        interval: const Duration(seconds: 3),
      ),
      1,
    );
  });

  test('pollOmrUntilFound returns when scan succeeds', () async {
    var calls = 0;
    final found = await WorkshopPdfGuide.pollOmrUntilFound(
      scoreIdHint: 'user_pdf_test',
      timeout: const Duration(seconds: 9),
      interval: const Duration(milliseconds: 1),
      delay: (_) async {},
      scanOnce: () async {
        calls++;
        if (calls < 3) return const [];
        return const [
          WorkshopOmrCandidate(
            path: r'C:\tmp\omr_draft.musicxml',
            label: 'omr_draft.musicxml',
            preferred: true,
          ),
        ];
      },
    );
    expect(found, hasLength(1));
    expect(calls, 3);
  });

  test('pollOmrUntilFound times out empty', () async {
    var calls = 0;
    final found = await WorkshopPdfGuide.pollOmrUntilFound(
      scoreIdHint: 'user_pdf_test',
      timeout: const Duration(milliseconds: 5),
      interval: const Duration(milliseconds: 1),
      delay: (_) async {},
      scanOnce: () async {
        calls++;
        return const [];
      },
    );
    expect(found, isEmpty);
    expect(calls, greaterThanOrEqualTo(1));
  });
}
