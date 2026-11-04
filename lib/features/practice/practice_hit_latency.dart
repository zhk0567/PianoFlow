/// Follow-mode lab metrics: capture→hit latency + miss / block / leak counters.
///
/// Used by [practice_engine] for logs and a future debug strip.
/// Does **not** retune quiet/hop/echoSuppress — observation only.
abstract final class PracticeHitLatency {
  static const maxSamples = 256;

  static final List<int> _samplesAll = [];
  static final List<int> _samplesGuideOn = [];
  static final List<int> _samplesGuideOff = [];

  static int hits = 0;
  static int hitsGuideOn = 0;
  static int hitsGuideOff = 0;
  static int misses = 0;
  static int latchBlocks = 0;
  static int softMatches = 0;
  /// Chord left freeze line still incomplete (漏推进启发式).
  static int leaks = 0;
  /// Frame-path advances while guideAudio on (示范路径推进，便于对照误推).
  static int frameHitsGuideOn = 0;
  /// AttackLatch released via onset re-strike (连击).
  static int onsetReleases = 0;
  /// Soft-cue speaker bleed blocked by CueBleedGuard.
  static int cueBleeds = 0;

  static void reset() {
    _samplesAll.clear();
    _samplesGuideOn.clear();
    _samplesGuideOff.clear();
    hits = 0;
    hitsGuideOn = 0;
    hitsGuideOff = 0;
    misses = 0;
    latchBlocks = 0;
    softMatches = 0;
    leaks = 0;
    frameHitsGuideOn = 0;
    onsetReleases = 0;
    cueBleeds = 0;
  }

  static List<int> get samplesMs => List.unmodifiable(_samplesAll);

  /// Record capture→判定 ms. Returns clamped value for logging.
  static int record(
    int elapsedMs, {
    bool guideOn = false,
    String path = 'noteOn',
  }) {
    final v = elapsedMs < 0 ? 0 : elapsedMs;
    _push(_samplesAll, v);
    if (guideOn) {
      _push(_samplesGuideOn, v);
      hitsGuideOn++;
      if (path == 'frame') frameHitsGuideOn++;
    } else {
      _push(_samplesGuideOff, v);
      hitsGuideOff++;
    }
    hits++;
    return v;
  }

  static void noteMiss() => misses++;

  static void noteLatchBlock() => latchBlocks++;

  static void noteSoftMatch() => softMatches++;

  static void noteLeak() => leaks++;

  static void noteOnsetRelease() => onsetReleases++;

  static void noteCueBleed() => cueBleeds++;

  static void _push(List<int> list, int v) {
    list.add(v);
    while (list.length > maxSamples) {
      list.removeAt(0);
    }
  }

  static double? get averageMs => _avg(_samplesAll);

  static double? get averageGuideOnMs => _avg(_samplesGuideOn);

  static double? get averageGuideOffMs => _avg(_samplesGuideOff);

  static int? percentileMs(num p, {bool? guideOn}) {
    final src = guideOn == null
        ? _samplesAll
        : (guideOn ? _samplesGuideOn : _samplesGuideOff);
    return _percentile(src, p);
  }

  static int? get p50Ms => percentileMs(50);

  static int? get p95Ms => percentileMs(95);

  static int? get p50GuideOnMs => percentileMs(50, guideOn: true);

  static int? get p95GuideOnMs => percentileMs(95, guideOn: true);

  static int? get p50GuideOffMs => percentileMs(50, guideOn: false);

  static int? get p95GuideOffMs => percentileMs(95, guideOn: false);

  /// Miss rate among hit+miss decisions (0–1), or null if none.
  static double? get missRate {
    final n = hits + misses;
    if (n == 0) return null;
    return misses / n;
  }

  static double? _avg(List<int> list) {
    if (list.isEmpty) return null;
    final sum = list.fold<int>(0, (a, b) => a + b);
    return sum / list.length;
  }

  static int? _percentile(List<int> list, num p) {
    if (list.isEmpty) return null;
    final sorted = [...list]..sort();
    final rank = (p.clamp(0, 100) / 100) * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    final t = rank - lo;
    return (sorted[lo] * (1 - t) + sorted[hi] * t).round();
  }

  /// One-line summary for logs / debug UI.
  static String snapshotLine() {
    final p50 = p50Ms;
    final p95 = p95Ms;
    final miss = missRate;
    final buf = StringBuffer('metrics');
    buf.write(' hits=$hits');
    buf.write(' miss=$misses');
    if (miss != null) {
      buf.write(' missRate=${(miss * 100).toStringAsFixed(1)}%');
    }
    buf.write(' latchBlock=$latchBlocks');
    buf.write(' softMatch=$softMatches');
    buf.write(' leak=$leaks');
    buf.write(' onsetRel=$onsetReleases');
    buf.write(' cueBleed=$cueBleeds');
    buf.write(' frameGuide=$frameHitsGuideOn');
    if (p50 != null) buf.write(' p50=${p50}ms');
    if (p95 != null) buf.write(' p95=${p95}ms');
    final g50 = p50GuideOnMs;
    final g95 = p95GuideOnMs;
    final o50 = p50GuideOffMs;
    final o95 = p95GuideOffMs;
    if (g50 != null) buf.write(' guideOn p50=${g50}ms');
    if (g95 != null) buf.write(' p95=${g95}ms');
    if (o50 != null) buf.write(' guideOff p50=${o50}ms');
    if (o95 != null) buf.write(' p95=${o95}ms');
    buf.write(' n=${_samplesAll.length}');
    return buf.toString();
  }

  static Map<String, Object?> snapshot() => {
        'hits': hits,
        'hitsGuideOn': hitsGuideOn,
        'hitsGuideOff': hitsGuideOff,
        'misses': misses,
        'missRate': missRate,
        'latchBlocks': latchBlocks,
        'softMatches': softMatches,
        'leaks': leaks,
        'onsetReleases': onsetReleases,
        'cueBleeds': cueBleeds,
        'frameHitsGuideOn': frameHitsGuideOn,
        'p50Ms': p50Ms,
        'p95Ms': p95Ms,
        'p50GuideOnMs': p50GuideOnMs,
        'p95GuideOnMs': p95GuideOnMs,
        'p50GuideOffMs': p50GuideOffMs,
        'p95GuideOffMs': p95GuideOffMs,
        'avgMs': averageMs,
        'sampleCount': _samplesAll.length,
      };
}
