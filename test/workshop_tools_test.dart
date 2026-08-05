import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/workshop/workshop_tools.dart';

void main() {
  test('workshop catalog covers PDF / edit / import entries', () {
    expect(WorkshopTool.all.length, greaterThanOrEqualTo(4));
    expect(
      WorkshopTool.all.map((t) => t.id),
      containsAll([
        WorkshopToolId.pdfToScore,
        WorkshopToolId.editScore,
        WorkshopToolId.importMusicXml,
        WorkshopToolId.importMidi,
      ]),
    );
  });

  test('parseId round-trips tool query names', () {
    expect(WorkshopTool.parseId('pdfToScore'), WorkshopToolId.pdfToScore);
    expect(WorkshopTool.parseId('nope'), isNull);
    expect(WorkshopTool.parseId(null), isNull);
  });
}
