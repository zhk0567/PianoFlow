import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/library/user_import_store.dart';
import 'package:piano_flow/features/workshop/workshop_musicxml_import.dart';
import 'package:piano_flow/shared/models/song.dart';

SongSummary _s({
  required String id,
  ScoreKind kind = ScoreKind.formal,
}) {
  return SongSummary(
    id: id,
    title: id,
    artist: 'a',
    genre: 'Classical',
    difficulty: 2,
    bpm: 100,
    asset: kind == ScoreKind.userImport ? 'user:$id' : 'assets/scores/$id.json',
    description: '',
    scoreKind: kind,
  );
}

void main() {
  test('merge appends user-only and overrides same id', () {
    final bundled = [
      _s(id: 'a'),
      _s(id: 'b'),
    ];
    final user = [
      _s(id: 'b', kind: ScoreKind.userImport),
      _s(id: 'c', kind: ScoreKind.userImport),
    ];
    final merged = UserCatalogMerge.merge(bundled: bundled, user: user);
    expect(merged.map((s) => s.id).toList(), ['a', 'b', 'c']);
    expect(merged[1].scoreKind, ScoreKind.userImport);
    expect(merged[2].id, 'c');
  });

  test('parseCatalogJson reads userImport', () {
    const raw = '''
    {"songs":[{
      "id":"user_demo",
      "title":"Demo",
      "artist":"自导入",
      "genre":"Classical",
      "difficulty":3,
      "bpm":90,
      "asset":"user:user_demo",
      "description":"x",
      "scoreKind":"userImport"
    }]}
    ''';
    final songs = UserCatalogMerge.parseCatalogJson(raw);
    expect(songs.single.isUserImport, isTrue);
    expect(songs.single.scoreKindLabel, '自导入');
  });

  test('WorkshopMusicXmlImporter slug', () {
    expect(
      WorkshopMusicXmlImporter.slugFromPath(r'F:\scores\Moonlight Sonata.musicxml'),
      'user_moonlight_sonata',
    );
  });
}
