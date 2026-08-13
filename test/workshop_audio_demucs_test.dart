import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/workshop/workshop_audio_import.dart';
import 'package:piano_flow/features/workshop/workshop_tools.dart';

void main() {
  test('audio honesty mentions optional demucs', () {
    expect(WorkshopAudioImporter.honestyDescription, contains('Demucs'));
    expect(WorkshopAudioImporter.honestyDescription, contains('非正式'));
  });

  test('importAudio tool subtitle mentions demucs path', () {
    final audio = WorkshopTool.byId(WorkshopToolId.importAudio)!;
    expect(audio.subtitle, contains('Demucs'));
    expect(audio.available, isTrue);
  });
}
