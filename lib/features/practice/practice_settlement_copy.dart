import 'practice_judge_logic.dart';

/// Short Chinese titles for the end-of-run settlement sheet.
abstract final class PracticeSettlementCopy {
  static String title({
    required int perfects,
    required int goods,
    required int misses,
    required int maxCombo,
    int songSessions = 0,
    DateTime? now,
  }) {
    final hidden = _hiddenTitle(
      perfects: perfects,
      goods: goods,
      misses: misses,
      maxCombo: maxCombo,
      songSessions: songSessions,
      now: now ?? DateTime.now(),
    );
    if (hidden != null) return hidden;

    final total = perfects + goods + misses;
    if (total <= 0) return '练了一下';
    if (misses == 0 && goods == 0 && perfects > 0) {
      return '神仙手指';
    }
    final score = PracticeJudgeLogic.score100(
      perfects: perfects,
      goods: goods,
      misses: misses,
    );
    if (score >= 90) return _pick(const ['行云流水', '几乎贴谱', '今晚状态很好'], perfects);
    if (score >= 75) return _pick(const ['手感在线', '越弹越顺', '节奏站稳了'], goods);
    if (score >= 55) return _pick(const ['再来一把', '手还记得', '热乎着'], maxCombo);
    if (maxCombo >= 8) return '连击可观，稳一点更好';
    return _pick(const ['慢练更香', '从容一点更美', '再贴一寸'], songSessions);
  }

  static String subtitle({
    required int perfects,
    required int goods,
    required int misses,
  }) {
    final hits = perfects + goods;
    if (hits <= 0 && misses <= 0) return '先弹几下再看看手感';
    // Positive framing only — never mention misses in copy.
    if (perfects > 0 && goods == 0) {
      return '本局 $perfects 次完美命中';
    }
    return '本局命中 $hits 次 · 完美 $perfects';
  }

  /// Rare situational line — null most of the time.
  static String? _hiddenTitle({
    required int perfects,
    required int goods,
    required int misses,
    required int maxCombo,
    required int songSessions,
    required DateTime now,
  }) {
    final total = perfects + goods + misses;
    if (total <= 0) return null;

    // Deterministic low-probability based on session shape (not pure RNG spam).
    final seed = perfects * 17 + goods * 13 + maxCombo * 7 + songSessions * 3;
    final roll = seed % 100;

    if (now.hour >= 23 || now.hour < 5) {
      if (roll < 28) return '夜深人静，琴声刚好';
    }
    if (songSessions >= 3 && roll < 18) {
      return '你好像很在乎这首';
    }
    if (maxCombo >= 12 && roll < 22) {
      return '连击像一条河';
    }
    if (misses == 0 && perfects >= 8 && roll < 25) {
      return '这一遍，值得记住';
    }
    if (roll == 7) return '偶遇一句：继续就好';
    return null;
  }

  static String _pick(List<String> pool, int salt) {
    if (pool.isEmpty) return '再来一把';
    return pool[salt.abs() % pool.length];
  }
}
