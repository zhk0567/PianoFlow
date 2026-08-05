import 'package:flutter/foundation.dart';

import 'practice_judge_logic.dart';

/// Dual-column exam evaluation (正向 + 可加强，从不写「失误」).
@immutable
class ExamEvaluation {
  const ExamEvaluation({
    required this.score100,
    required this.goods,
    required this.improves,
  });

  final double score100;
  final List<String> goods;
  final List<String> improves;
}

abstract final class PracticeExamEval {
  static ExamEvaluation build({
    required int perfects,
    required int goods,
    required int misses,
    required int maxCombo,
    required List<({double beat, HitGrade grade})> hitLog,
  }) {
    final score = PracticeJudgeLogic.score100(
      perfects: perfects,
      goods: goods,
      misses: misses,
    );
    final goodLines = <String>[];
    final improveLines = <String>[];

    final total = perfects + goods + misses;
    if (total <= 0) {
      return const ExamEvaluation(
        score100: 0,
        goods: ['先完整弹完一遍再看评价'],
        improves: ['从慢速跟弹热身会更稳'],
      );
    }

    final perfectShare = perfects / total;
    if (perfectShare >= 0.7) {
      goodLines.add('完美命中占比很高，时机感在线');
    } else if (perfects >= 5) {
      goodLines.add('本场有 $perfects 次完美命中');
    }
    if (maxCombo >= 8) {
      goodLines.add('最高连击 ×$maxCombo，连贯性不错');
    } else if (maxCombo >= 4) {
      goodLines.add('连击有成形的感觉');
    }
    if (goods > 0 && perfects > goods) {
      goodLines.add('整体偏准，不错的次数也稳住了');
    }
    if (goodLines.isEmpty) {
      goodLines.add('完整走完一遍，本身就是进步');
    }

    // Find densest "good" (not perfect) cluster for constructive tip.
    final soft = hitLog.where((h) => h.grade == HitGrade.good).toList();
    if (soft.isNotEmpty) {
      soft.sort((a, b) => a.beat.compareTo(b.beat));
      final mid = soft[soft.length ~/ 2].beat;
      improveLines.add('约第 ${mid.round()} 拍附近可以再贴紧一点');
    }
    if (misses > 0 && misses >= goods) {
      improveLines.add('个别音还没对上时，放慢半档会更从容');
    } else if (goods > perfects && goods >= 3) {
      improveLines.add('「不错」偏多：试着听节拍器对齐落点');
    }
    if (maxCombo < 4 && total >= 8) {
      improveLines.add('连击偏短：把注意力放在下一音的准备上');
    }
    if (improveLines.isEmpty) {
      improveLines.add('下一遍可以挑战更高连击');
    }

    return ExamEvaluation(
      score100: score,
      goods: goodLines.take(3).toList(),
      improves: improveLines.take(3).toList(),
    );
  }
}
