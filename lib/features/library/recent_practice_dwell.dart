import 'dart:async';

/// 练习页打开后的墙钟停留（含暂停）满此时长，才把曲目写入最近练习。
const recentPracticeMinDwell = Duration(minutes: 5);

/// 满 [minDwell] 回调一次。提前 [cancel] 则不回调；已回调过的不会撤销。
class RecentPracticePromote {
  RecentPracticePromote({this.minDwell = recentPracticeMinDwell});

  final Duration minDwell;
  Timer? _timer;
  var committed = false;

  /// 开始计时。再次调用会清掉上一次未完成的计时，重新算满 5 分钟。
  void arm(void Function() onCommit) {
    _timer?.cancel();
    committed = false;
    _timer = Timer(minDwell, () {
      _timer = null;
      if (committed) return;
      committed = true;
      onCommit();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
