enum Hand { left, right, both }

extension HandX on Hand {
  String get label => switch (this) {
        Hand.left => '左手',
        Hand.right => '右手',
        Hand.both => '双手',
      };
}

/// Catalog score engraving quality for Verovio display.
///
/// - [formal]: authored / textbook MusicXML under `assets/scores/musicxml/`
/// - [simplified]: JSON→MusicXML 简编（可读、跟进度，但非正式排版）
enum ScoreKind { formal, simplified }

class SongSummary {
  const SongSummary({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.difficulty,
    required this.bpm,
    required this.asset,
    required this.description,
    this.durationHint,
    this.scoreKind = ScoreKind.simplified,
  });

  final String id;
  final String title;
  final String artist;
  final String genre;
  final int difficulty;
  final int bpm;
  final String asset;
  final String description;
  final int? durationHint;
  final ScoreKind scoreKind;

  factory SongSummary.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['scoreKind'] as String?;
    return SongSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      genre: json['genre'] as String,
      difficulty: json['difficulty'] as int,
      bpm: json['bpm'] as int,
      asset: json['asset'] as String,
      description: json['description'] as String? ?? '',
      durationHint: json['durationHint'] as int?,
      scoreKind: kindRaw == 'formal' ? ScoreKind.formal : ScoreKind.simplified,
    );
  }

  bool get isSimplifiedScore => scoreKind == ScoreKind.simplified;

  String get scoreKindLabel =>
      scoreKind == ScoreKind.formal ? '正式谱' : '简编谱';

  String get difficultyLabel => switch (difficulty) {
        1 => '入门',
        2 => '初级',
        3 => '中级',
        4 => '高级',
        _ => '自定义',
      };

  String formatDuration({double? durationBeats}) {
    if (durationHint != null) {
      final m = durationHint! ~/ 60;
      final s = durationHint! % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    if (durationBeats != null && bpm > 0) {
      final sec = (durationBeats * 60 / bpm).round();
      return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    return '--:--';
  }
}

class ScoreNote {
  const ScoreNote({
    required this.midi,
    required this.start,
    required this.duration,
    required this.hand,
  });

  final int midi;
  final double start;
  final double duration;
  final Hand hand;

  double get end => start + duration;

  factory ScoreNote.fromJson(Map<String, dynamic> json) {
    final handRaw = json['hand'] as String? ?? 'right';
    return ScoreNote(
      midi: json['midi'] as int,
      start: (json['start'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      hand: handRaw == 'left' ? Hand.left : Hand.right,
    );
  }

  Map<String, dynamic> toJson() => {
        'midi': midi,
        'start': start,
        'duration': duration,
        'hand': hand == Hand.left ? 'left' : 'right',
      };
}

class SongScore {
  const SongScore({
    required this.id,
    required this.title,
    required this.bpm,
    required this.notes,
    this.timeNum = 4,
    this.timeDen = 4,
    this.keySignature = 0,
  });

  final String id;
  final String title;
  final int bpm;
  final List<ScoreNote> notes;

  /// Time signature numerator / denominator (e.g. 4/4).
  final int timeNum;
  final int timeDen;

  /// Key signature: positive = sharps count, negative = flats count.
  final int keySignature;

  double get beatsPerMeasure => timeNum * (4.0 / timeDen);

  factory SongScore.fromJson(Map<String, dynamic> json) {
    final notes = (json['notes'] as List<dynamic>)
        .map((e) => ScoreNote.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    var timeNum = 4;
    var timeDen = 4;
    final ts = json['timeSignature'];
    if (ts is Map) {
      timeNum = (ts['num'] as num?)?.toInt() ?? 4;
      timeDen = (ts['den'] as num?)?.toInt() ?? 4;
    }

    return SongScore(
      id: json['id'] as String,
      title: json['title'] as String,
      bpm: json['bpm'] as int,
      notes: notes,
      timeNum: timeNum,
      timeDen: timeDen,
      keySignature: (json['keySignature'] as num?)?.toInt() ?? 0,
    );
  }

  double get durationBeats {
    if (notes.isEmpty) return 0;
    return notes.map((n) => n.end).reduce((a, b) => a > b ? a : b);
  }

  List<ScoreNote> notesForHand(Hand hand) {
    if (hand == Hand.both) return notes;
    return notes.where((n) => n.hand == hand).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SongScore && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
