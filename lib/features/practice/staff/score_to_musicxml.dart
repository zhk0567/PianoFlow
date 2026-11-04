import '../../../shared/models/song.dart';

/// Build MusicXML from [SongScore] for Verovio practice engraving.
///
/// This is the practice-page source of truth so staff, waterfall, and guide
/// audio share the same note onsets. Packaged MusicXML assets are for import /
/// audit only — they are not loaded into the practice WebView.
///
/// Always emits a non-empty `<type>` (and `<dot/>` when needed). Verovio only
/// calls SetDur when type is present; duration alone → stemless noteheads.
String songScoreToMusicXml(SongScore score, {Hand hand = Hand.both}) {
  final notes = score.notesForHand(hand);
  // Higher divisions reduce MIDI/JSON onset quantization drift vs waterfall.
  const divisions = 16; // quarter = 16
  final fifths = score.keySignature;
  final beats = score.timeNum;
  final beatType = score.timeDen;
  final bpm = score.bpm;

  final buf = StringBuffer();
  buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buf.writeln(
    '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" '
    '"http://www.musicxml.org/dtds/partwise.dtd">',
  );
  buf.writeln('<score-partwise version="3.1">');
  buf.writeln('<work><work-title>${_esc(score.title)}</work-title></work>');
  buf.writeln(
    '<part-list><score-part id="P1">'
    '<part-name print-object="no">Piano</part-name>'
    '</score-part></part-list>',
  );
  buf.writeln('<part id="P1">');

  final bpmMeasure = score.beatsPerMeasure;
  final endBeat = score.durationBeats <= 0 ? bpmMeasure : score.durationBeats;
  final measureCount = (endBeat / bpmMeasure).ceil().clamp(1, 512);

  final byMeasure = <int, List<ScoreNote>>{};
  for (final n in notes) {
    final mi = (n.start / bpmMeasure).floor().clamp(0, measureCount - 1);
    byMeasure.putIfAbsent(mi, () => []).add(n);
  }

  for (var mi = 0; mi < measureCount; mi++) {
    final mStart = mi * bpmMeasure;
    buf.writeln('<measure number="${mi + 1}">');
    if (mi == 0) {
      buf.writeln('<attributes>');
      buf.writeln('<divisions>$divisions</divisions>');
      buf.writeln('<key><fifths>$fifths</fifths></key>');
      buf.writeln(
        '<time><beats>$beats</beats><beat-type>$beatType</beat-type></time>',
      );
      buf.writeln('<staves>2</staves>');
      buf.writeln('<clef number="1"><sign>G</sign><line>2</line></clef>');
      buf.writeln('<clef number="2"><sign>F</sign><line>4</line></clef>');
      buf.writeln('</attributes>');
      buf.writeln(
        '<direction placement="above"><direction-type>'
        '<metronome><beat-unit>quarter</beat-unit><per-minute>$bpm</per-minute></metronome>'
        '</direction-type><sound tempo="$bpm"/></direction>',
      );
    }

    final mNotes = [...(byMeasure[mi] ?? const <ScoreNote>[])]
      ..sort((a, b) => a.start.compareTo(b.start));

    _writeStaffVoice(
      buf,
      mNotes.where((n) => n.hand != Hand.left).toList(),
      staff: 1,
      measureStart: mStart,
      measureBeats: bpmMeasure,
      divisions: divisions,
    );
    final measureDivs = (bpmMeasure * divisions).round();
    buf.writeln('<backup><duration>$measureDivs</duration></backup>');
    _writeStaffVoice(
      buf,
      mNotes.where((n) => n.hand == Hand.left).toList(),
      staff: 2,
      measureStart: mStart,
      measureBeats: bpmMeasure,
      divisions: divisions,
    );

    buf.writeln('</measure>');
  }

  buf.writeln('</part></score-partwise>');
  return buf.toString();
}

const _typeQuarters = <(String, double)>[
  ('whole', 4.0),
  ('half', 2.0),
  ('quarter', 1.0),
  ('eighth', 0.5),
  ('16th', 0.25),
  ('32nd', 0.125),
  ('64th', 0.0625),
];

const _beamable = {'eighth', '16th', '32nd', '64th'};

({String name, int dots}) _durationToType(int d, int divisions) {
  final quarters = d.clamp(1, 9999) / divisions.clamp(1, 9999);
  var bestName = 'quarter';
  var bestDots = 0;
  var bestErr = 1e9;
  for (final (name, q) in _typeQuarters) {
    for (var dots = 0; dots <= 2; dots++) {
      var mult = 1.0;
      for (var i = 0; i < dots; i++) {
        mult += mathPowHalf(i + 1);
      }
      final err = (quarters - q * mult).abs();
      if (err < bestErr - 1e-9) {
        bestErr = err;
        bestName = name;
        bestDots = dots;
      }
    }
  }
  return (name: bestName, dots: bestDots);
}

double mathPowHalf(int n) {
  var v = 1.0;
  for (var i = 0; i < n; i++) {
    v *= 0.5;
  }
  return v;
}

String _typeXml(int d, int divisions) {
  final t = _durationToType(d, divisions);
  final dots = StringBuffer();
  for (var i = 0; i < t.dots; i++) {
    dots.write('<dot/>');
  }
  return '<type>${t.name}</type>$dots';
}

void _writeStaffVoice(
  StringBuffer buf,
  List<ScoreNote> notes, {
  required int staff,
  required double measureStart,
  required double measureBeats,
  required int divisions,
}) {
  if (notes.isEmpty) {
    final d = (measureBeats * divisions).round();
    buf.writeln(
      '<note><rest measure="yes"/><duration>$d</duration>'
      '<voice>$staff</voice><staff>$staff</staff></note>',
    );
    return;
  }

  // Polyphonic MIDI/JSON often stacks long held tones under a faster melody.
  // MusicXML chords share one duration, so we:
  // 1) never skip an onset (was: skip when onset <= cursor → staff ≠ waterfall)
  // 2) advance by min(shortest in group, gap to next onset, remain)
  // 3) <backup> when the next onset is earlier than the written cursor
  final events = <_StaffEvent>[];
  var cursor = 0.0;
  var i = 0;
  while (i < notes.length) {
    final n = notes[i];
    final onset = (n.start - measureStart).clamp(0.0, measureBeats);

    final group = <ScoreNote>[n];
    var j = i + 1;
    while (j < notes.length && (notes[j].start - n.start).abs() < 0.02) {
      group.add(notes[j]);
      j++;
    }

    var nextOnset = measureBeats;
    if (j < notes.length) {
      nextOnset = (notes[j].start - measureStart).clamp(0.0, measureBeats);
    }

    if (onset > cursor + 0.001) {
      final restBeats = onset - cursor;
      final d = (restBeats * divisions).round();
      // Do NOT force d>=1: sub-division gaps must not become a full 16th rest
      // (that accumulated timing drift and dropped later notes).
      if (d >= 1) {
        events.add(_StaffEvent.rest(d.clamp(1, 9999)));
        cursor += d / divisions;
      }
    } else if (onset < cursor - 0.001) {
      final back = ((cursor - onset) * divisions).round();
      if (back >= 1) {
        events.add(_StaffEvent.backup(back.clamp(1, 9999)));
        cursor = onset;
      }
    }
    // Snap writing onset to cursor after quantization.
    final writeOnset = cursor;

    final remain = measureBeats - writeOnset;
    if (remain < 0.5 / divisions) break;
    final shortest = group
        .map((g) => g.duration)
        .reduce((a, b) => a < b ? a : b);
    final rawGap = nextOnset - writeOnset;
    final gap = rawGap > 0 ? (rawGap < remain ? rawGap : remain) : remain;
    final unit = 1.0 / divisions;
    var durBeats = shortest < gap ? shortest : gap;
    if (durBeats > remain) durBeats = remain;
    if (durBeats < unit) durBeats = unit;
    var d = (durBeats * divisions).round().clamp(1, 9999);
    if (writeOnset + d / divisions > measureBeats + 0.001) {
      d = ((measureBeats - writeOnset) * divisions).round().clamp(1, 9999);
    }
    final tname = _durationToType(d, divisions).name;
    events.add(
      _StaffEvent.notes(
        d: d,
        group: group,
        typeName: tname,
        beamable: _beamable.contains(tname),
      ),
    );
    cursor = writeOnset + d / divisions;
    i = j;
    if (writeOnset >= measureBeats - 0.001) break;
  }

  if (cursor < measureBeats - 0.05) {
    final d = ((measureBeats - cursor) * divisions).round();
    if (d >= 1) events.add(_StaffEvent.rest(d.clamp(1, 9999)));
  } else if (cursor > measureBeats + 0.001) {
    final back = ((cursor - measureBeats) * divisions).round();
    if (back >= 1) events.add(_StaffEvent.backup(back.clamp(1, 9999)));
  }

  final beamVals = <int, String>{};
  var k = 0;
  while (k < events.length) {
    final ev = events[k];
    if (!ev.isNotes || !ev.beamable) {
      k++;
      continue;
    }
    final run = <int>[k];
    final t0 = ev.typeName;
    var m = k + 1;
    while (m < events.length &&
        events[m].isNotes &&
        events[m].beamable &&
        events[m].typeName == t0) {
      run.add(m);
      m++;
    }
    if (run.length >= 2) {
      beamVals[run.first] = 'begin';
      for (var bi = 1; bi < run.length - 1; bi++) {
        beamVals[run[bi]] = 'continue';
      }
      beamVals[run.last] = 'end';
    }
    k = m;
  }

  for (var idx = 0; idx < events.length; idx++) {
    final ev = events[idx];
    if (ev.isBackup) {
      buf.writeln('<backup><duration>${ev.d}</duration></backup>');
      continue;
    }
    final tx = _typeXml(ev.d, divisions);
    if (!ev.isNotes) {
      buf.writeln(
        '<note><rest/><duration>${ev.d}</duration>$tx'
        '<voice>$staff</voice><staff>$staff</staff></note>',
      );
      continue;
    }
    final bx = beamVals.containsKey(idx)
        ? '<beam number="1">${beamVals[idx]}</beam>'
        : '';
    for (var g = 0; g < ev.group!.length; g++) {
      final gn = ev.group![g];
      final pitch = _midiToPitch(gn.midi);
      final chord = g > 0 ? '<chord/>' : '';
      final beamPart = g == 0 ? bx : '';
      buf.writeln(
        '<note>$chord<pitch><step>${pitch.step}</step>'
        '${pitch.alter != 0 ? '<alter>${pitch.alter}</alter>' : ''}'
        '<octave>${pitch.octave}</octave></pitch>'
        '<duration>${ev.d}</duration>$tx<voice>$staff</voice>'
        '$beamPart<staff>$staff</staff></note>',
      );
    }
  }
}

class _StaffEvent {
  _StaffEvent.rest(this.d)
      : isNotes = false,
        isBackup = false,
        group = null,
        typeName = '',
        beamable = false;

  _StaffEvent.backup(this.d)
      : isNotes = false,
        isBackup = true,
        group = null,
        typeName = '',
        beamable = false;

  _StaffEvent.notes({
    required this.d,
    required List<ScoreNote> this.group,
    required this.typeName,
    required this.beamable,
  })  : isNotes = true,
        isBackup = false;

  final int d;
  final bool isNotes;
  final bool isBackup;
  final List<ScoreNote>? group;
  final String typeName;
  final bool beamable;
}

({String step, int alter, int octave}) _midiToPitch(int midi) {
  const steps = ['C', 'C', 'D', 'D', 'E', 'F', 'F', 'G', 'G', 'A', 'A', 'B'];
  const alters = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0];
  final pc = midi % 12;
  final octave = (midi ~/ 12) - 1;
  return (step: steps[pc], alter: alters[pc], octave: octave);
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
