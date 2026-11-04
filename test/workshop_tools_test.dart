import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:piano_flow/features/library/user_import_store.dart';
import 'package:piano_flow/features/workshop/workshop_import_common.dart';
import 'package:piano_flow/features/workshop/workshop_pdf_guide.dart';
import 'package:piano_flow/features/workshop/workshop_tools.dart';
import 'package:piano_flow/shared/models/song.dart';

void main() {
  test('WorkshopTool catalog: MusicXML / MIDI / Audio / PDF / edit available', () {
    final xml = WorkshopTool.byId(WorkshopToolId.importMusicXml);
    final midi = WorkshopTool.byId(WorkshopToolId.importMidi);
    final audio = WorkshopTool.byId(WorkshopToolId.importAudio);
    final pdf = WorkshopTool.byId(WorkshopToolId.pdfToScore);
    final edit = WorkshopTool.byId(WorkshopToolId.editScore);
    final other = WorkshopTool.byId(WorkshopToolId.importOther);

    expect(xml, isNotNull);
    expect(xml!.available, isTrue);
    expect(midi!.available, isTrue);
    expect(midi.badge, '可用');
    expect(audio!.available, isTrue);
    expect(audio.badge, '可用');
    expect(audio.subtitle, contains('Demucs'));
    expect(audio.subtitle, contains('进练习'));
    expect(pdf!.available, isTrue);
    expect(pdf.badge, '可用');
    expect(pdf.subtitle, contains('一键'));
    expect(edit!.available, isTrue);
    expect(edit.badge, '可用');
    expect(edit.subtitle, contains('自导入'));
    expect(other!.available, isTrue);
    expect(other.badge, '指引');
    expect(WorkshopTool.all.length, greaterThanOrEqualTo(6));
  });

  test('slugFromPath normalizes and prefixes user_', () {
    expect(
      WorkshopImportCommon.slugFromPath(r'C:\Scores\My Piece!!.musicxml'),
      'user_my_piece',
    );
    expect(
      WorkshopImportCommon.slugFromPath('already.mid', prefix: 'user_midi_'),
      'user_midi_already',
    );
    expect(
      WorkshopImportCommon.slugFromPath('@@@.xml'),
      'user_import',
    );
  });

  test('UserCatalogMerge keeps bundled order and appends user-only', () {
    const a = SongSummary(
      id: 'a',
      title: 'A',
      artist: 'x',
      genre: 'Classical',
      difficulty: 1,
      bpm: 60,
      asset: 'assets/scores/a.json',
      description: '',
      scoreKind: ScoreKind.formal,
    );
    const b = SongSummary(
      id: 'b',
      title: 'B',
      artist: 'x',
      genre: 'Classical',
      difficulty: 1,
      bpm: 60,
      asset: 'assets/scores/b.json',
      description: '',
      scoreKind: ScoreKind.omrDraft,
    );
    const u = SongSummary(
      id: 'user_x',
      title: 'U',
      artist: 'me',
      genre: 'Pop',
      difficulty: 2,
      bpm: 90,
      asset: r'C:\tmp\user_x.json',
      description: '',
      scoreKind: ScoreKind.userImport,
    );
    const overrideB = SongSummary(
      id: 'b',
      title: 'B-user',
      artist: 'me',
      genre: 'Pop',
      difficulty: 2,
      bpm: 90,
      asset: r'C:\tmp\b.json',
      description: '',
      scoreKind: ScoreKind.userImport,
    );
    final merged = UserCatalogMerge.merge(
      bundled: const [a, b],
      user: const [overrideB, u],
    );
    expect(merged.map((s) => s.id).toList(), ['a', 'b', 'user_x']);
    expect(merged[1].title, 'B-user');
    expect(merged[1].scoreKind, ScoreKind.userImport);
  });

  test('SongSummary toJson round-trip keeps userImport', () {
    const s = SongSummary(
      id: 'user_demo',
      title: 'Demo',
      artist: '自导入',
      genre: 'Pop',
      difficulty: 2,
      bpm: 100,
      asset: r'C:\tmp\user_demo.json',
      description: 'test',
      durationHint: 30,
      scoreKind: ScoreKind.userImport,
    );
    final again = SongSummary.fromJson(s.toJson());
    expect(again.id, s.id);
    expect(again.title, s.title);
    expect(again.bpm, 100);
    expect(again.scoreKind, ScoreKind.userImport);
    expect(again.isUserImport, isTrue);
    expect(again.isFormalScore, isFalse);
  });

  test('UserCatalogMerge encode/parse preserves userImport entries', () {
    const u = SongSummary(
      id: 'user_y',
      title: 'Y',
      artist: 'me',
      genre: 'Pop',
      difficulty: 2,
      bpm: 88,
      asset: r'C:\tmp\user_y.json',
      description: 'd',
      scoreKind: ScoreKind.userImport,
    );
    final raw = UserCatalogMerge.encodeCatalog(const [u]);
    final parsed = UserCatalogMerge.parseCatalogJson(raw);
    expect(parsed.length, 1);
    expect(parsed.single.scoreKind, ScoreKind.userImport);
    expect(parsed.single.title, 'Y');
  });

  test('findOmrMusicXml prefers corrected then omr_draft', () async {
    final tmp = await Directory.systemTemp.createTemp('pf_omr_scan_');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    final work = Directory(
      p.join(
        tmp.path,
        'third_party',
        'scores_musicxml',
        '_omr_work',
        'user_pdf_demo',
      ),
    );
    await work.create(recursive: true);
    final outDir = Directory(p.join(work.path, 'audiveris_out'));
    await outDir.create(recursive: true);

    await File(p.join(outDir.path, 'raw.xml')).writeAsString('<score/>');
    await File(p.join(work.path, 'omr_draft.musicxml'))
        .writeAsString('<score/>');
    await File(p.join(work.path, 'corrected.musicxml'))
        .writeAsString('<score/>');

    final found = await WorkshopPdfGuide.findOmrMusicXml(
      scoreIdHint: 'user_pdf_demo',
      repoRoot: tmp.path,
    );
    expect(found.length, greaterThanOrEqualTo(3));
    expect(found.first.label.toLowerCase(), contains('corrected'));
    expect(found.first.preferred, isTrue);
  });

  test('PDF chinese steps are non-empty', () {
    expect(WorkshopPdfGuide.chineseSteps.length, greaterThanOrEqualTo(4));
    expect(
      WorkshopPdfGuide.chineseSteps.any((s) => s.contains('自导入')),
      isTrue,
    );
  });

  test('encodeCatalog never emits formal for userImport song', () {
    const u = SongSummary(
      id: 'user_z',
      title: 'Z',
      artist: 'me',
      genre: 'Pop',
      difficulty: 1,
      bpm: 60,
      asset: 'z.json',
      description: '',
      scoreKind: ScoreKind.userImport,
    );
    final map = jsonDecode(UserCatalogMerge.encodeCatalog(const [u]))
        as Map<String, dynamic>;
    final song = (map['songs'] as List).single as Map<String, dynamic>;
    expect(song['scoreKind'], 'userImport');
    expect(song['scoreKind'], isNot('formal'));
  });

  test('SongScore toJson round-trip preserves notes for note editor', () {
    final score = SongScore(
      id: 'user_demo',
      title: 'Demo',
      bpm: 100,
      timeNum: 3,
      timeDen: 4,
      keySignature: -1,
      notes: const [
        ScoreNote(midi: 60, start: 0, duration: 1, hand: Hand.right),
        ScoreNote(midi: 48, start: 1, duration: 0.5, hand: Hand.left),
      ],
    );
    final again = SongScore.fromJson(score.toJson());
    expect(again.id, 'user_demo');
    expect(again.timeNum, 3);
    expect(again.timeDen, 4);
    expect(again.keySignature, -1);
    expect(again.notes.length, 2);
    expect(again.notes[0].midi, 60);
    expect(again.notes[1].hand, Hand.left);
    expect(again.notes[1].duration, 0.5);
  });

  test('saveUserNotes rejects missing id', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final store = UserImportStore();
    await expectLater(
      store.saveUserNotes(
        id: 'definitely_missing_user_score_xyz',
        notes: const [
          ScoreNote(midi: 60, start: 0, duration: 1, hand: Hand.right),
        ],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('找不到自导入'),
        ),
      ),
    );
  });

  test('saveUserNotes writes JSON and MusicXML under user dir', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tmp = await Directory.systemTemp.createTemp('pf_user_notes_');
    final previous = PathProviderPlatform.instance;
    addTearDown(() async {
      PathProviderPlatform.instance = previous;
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    PathProviderPlatform.instance = _FakeDocsPathProvider(tmp.path);

    final root = Directory(p.join(tmp.path, UserImportPaths.folderName));
    await Directory(p.join(root.path, 'musicxml')).create(recursive: true);

    const id = 'user_note_edit_demo';
    final summary = SongSummary(
      id: id,
      title: 'NoteEdit',
      artist: '自导入',
      genre: 'Pop',
      difficulty: 1,
      bpm: 90,
      asset: p.join(root.path, '$id.json'),
      description: 'test',
      scoreKind: ScoreKind.userImport,
    );
    await File(p.join(root.path, UserImportPaths.catalogFileName)).writeAsString(
      UserCatalogMerge.encodeCatalog([summary]),
    );

    final score = SongScore(
      id: id,
      title: 'NoteEdit',
      bpm: 90,
      notes: const [
        ScoreNote(midi: 60, start: 0, duration: 1, hand: Hand.right),
        ScoreNote(midi: 48, start: 0, duration: 2, hand: Hand.left),
      ],
    );
    await File(p.join(root.path, '$id.json')).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(score.toJson())}\n',
    );

    final store = UserImportStore();
    final saved = await store.saveUserNotes(
      id: id,
      notes: const [
        ScoreNote(midi: 62, start: 0, duration: 1, hand: Hand.right),
        ScoreNote(midi: 50, start: 1, duration: 1, hand: Hand.left),
      ],
    );
    expect(saved.notes.length, 2);
    expect(saved.notes.first.midi, 62);

    final jsonAgain = SongScore.fromJson(
      jsonDecode(await File(p.join(root.path, '$id.json')).readAsString())
          as Map<String, dynamic>,
    );
    expect(jsonAgain.notes.map((n) => n.midi).toList(), [62, 50]);

    final xml = await File(p.join(root.path, 'musicxml', '$id.musicxml'))
        .readAsString();
    expect(xml.contains('score-partwise'), isTrue);
    expect(xml.contains('NoteEdit'), isTrue);
  });
}

class _FakeDocsPathProvider extends PathProviderPlatform {
  _FakeDocsPathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}
