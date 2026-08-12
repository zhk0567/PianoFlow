import '../piano_flow_log.dart';

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
/// - [formal]: authored / textbook MusicXML（已校对或教材级）
/// - [simplified]: JSON→MusicXML 简编（可读、跟进度，但非正式排版）
/// - [omrDraft]: PDF→OMR 未逐音校对草稿（可练，但**不是**精确正式谱）
/// - [userImport]: 工坊自导入 MusicXML（永远不是 formal）
enum ScoreKind { formal, simplified, omrDraft, userImport }

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
    final known = {'formal', 'simplified', 'omrDraft', 'userImport'};
    if (kindRaw != null && !known.contains(kindRaw)) {
      pianoFlowLog(
        'Catalog',
        'unknown scoreKind "$kindRaw" for ${json['id']} → treat as simplified',
      );
    }
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
      scoreKind: switch (kindRaw) {
        'formal' => ScoreKind.formal,
        'omrDraft' => ScoreKind.omrDraft,
        'simplified' => ScoreKind.simplified,
        'userImport' => ScoreKind.userImport,
        _ => ScoreKind.simplified,
      },
    );
  }

  SongSummary copyWith({
    String? id,
    String? title,
    String? artist,
    String? genre,
    int? difficulty,
    int? bpm,
    String? asset,
    String? description,
    int? durationHint,
    ScoreKind? scoreKind,
  }) {
    return SongSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      genre: genre ?? this.genre,
      difficulty: difficulty ?? this.difficulty,
      bpm: bpm ?? this.bpm,
      asset: asset ?? this.asset,
      description: description ?? this.description,
      durationHint: durationHint ?? this.durationHint,
      scoreKind: scoreKind ?? this.scoreKind,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'genre': genre,
        'difficulty': difficulty,
        'bpm': bpm,
        'asset': asset,
        'description': description,
        if (durationHint != null) 'durationHint': durationHint,
        'scoreKind': switch (scoreKind) {
          ScoreKind.formal => 'formal',
          ScoreKind.omrDraft => 'omrDraft',
          ScoreKind.simplified => 'simplified',
          ScoreKind.userImport => 'userImport',
        },
      };

  bool get isSimplifiedScore => scoreKind == ScoreKind.simplified;

  bool get isOmrDraft => scoreKind == ScoreKind.omrDraft;

  bool get isUserImport => scoreKind == ScoreKind.userImport;

  /// True only for proofread / textbook MusicXML — never for OMR / 自导入.
  bool get isFormalScore => scoreKind == ScoreKind.formal;

  String get scoreKindLabel => switch (scoreKind) {
        ScoreKind.formal => '正式谱',
        ScoreKind.omrDraft => 'OMR草稿',
        ScoreKind.simplified => '简编谱',
        ScoreKind.userImport => '自导入',
      };

  /// Discover / practice honesty line — OMR always marked 未校对.
  String get scoreKindLabelDetail => switch (scoreKind) {
        ScoreKind.omrDraft => '$scoreKindLabel（未校对）',
        ScoreKind.userImport => '$scoreKindLabel（非正式谱）',
        _ => scoreKindLabel,
      };

  /// Shared library + practice honesty copy (never claim OMR is formal).
  static const omrHonestyNotice =
      'OMR草稿未经逐音校对，可练但不保证与原谱完全一致';

  static const userImportHonestyNotice =
      '自导入曲谱未做教材级校对，可练但不标为正式谱';

  /// Fixed practice-page banner when [isOmrDraft]/[isUserImport]; null otherwise.
  String? get practiceHonestyBanner {
    if (isOmrDraft) return omrHonestyNotice;
    if (isUserImport) return userImportHonestyNotice;
    return null;
  }

  /// Meta under「今日一首」title.
  String get homeTodayMetaLine =>
      '$artist · $scoreKindLabelDetail · $difficultyLabel · $bpm BPM';

  /// Meta under recent-practice row title.
  String get homeRecentMetaLine =>
      '$scoreKindLabelDetail · $difficultyLabel · $bpm BPM';

  /// Meta under hero primary CTA.
  String get homeHeroMetaLine =>
      '$artist · $scoreKindLabelDetail · $difficultyLabel';

  String get difficultyLabel => switch (difficulty) {
        1 => '入门',
        2 => '初级',
        3 => '中级',
        4 => '高级',
        5 => '极难',
        _ => '自定义',
      };

  /// Catalog often stores English genre codes; UI shows Chinese.
  static const genreLabelsZh = <String, String>{
    'Classical': '古典',
    'Anime': '动画',
    'Pop': '流行',
    'Game': '游戏',
  };

  String get genreLabelZh => genreLabelsZh[genre] ?? genre;

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
    final Hand hand;
    if (handRaw == 'left') {
      hand = Hand.left;
    } else if (handRaw == 'right') {
      hand = Hand.right;
    } else {
      pianoFlowLog(
        'Catalog',
        'unknown hand "$handRaw" midi=${json['midi']} → right',
      );
      hand = Hand.right;
    }
    return ScoreNote(
      midi: json['midi'] as int,
      start: (json['start'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      hand: hand,
    );
  }

  Map<String, dynamic> toJson() => {
        'midi': midi,
        'start': start,
        'duration': duration,
        'hand': hand == Hand.left ? 'left' : 'right',
      };

  ScoreNote copyWith({
    int? midi,
    double? start,
    double? duration,
    Hand? hand,
  }) {
    return ScoreNote(
      midi: midi ?? this.midi,
      start: start ?? this.start,
      duration: duration ?? this.duration,
      hand: hand ?? this.hand,
    );
  }
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'bpm': bpm,
        'timeSignature': {'num': timeNum, 'den': timeDen},
        'keySignature': keySignature,
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  SongScore copyWith({
    String? id,
    String? title,
    int? bpm,
    List<ScoreNote>? notes,
    int? timeNum,
    int? timeDen,
    int? keySignature,
  }) {
    return SongScore(
      id: id ?? this.id,
      title: title ?? this.title,
      bpm: bpm ?? this.bpm,
      notes: notes ?? this.notes,
      timeNum: timeNum ?? this.timeNum,
      timeDen: timeDen ?? this.timeDen,
      keySignature: keySignature ?? this.keySignature,
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
