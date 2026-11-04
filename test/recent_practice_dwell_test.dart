import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/library/recent_practice_dwell.dart';

void main() {
  test('满 5 分钟才写入一次最近练习', () {
    fakeAsync((async) {
      var commits = 0;
      final dwell = RecentPracticePromote();
      dwell.arm(() => commits++);
      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(commits, 0);
      expect(dwell.committed, isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(commits, 1);
      expect(dwell.committed, isTrue);
      async.elapse(const Duration(minutes: 10));
      expect(commits, 1);
      dwell.cancel();
    });
  });

  test('未满 5 分钟离开不写入', () {
    fakeAsync((async) {
      var commits = 0;
      final dwell = RecentPracticePromote();
      dwell.arm(() => commits++);
      async.elapse(const Duration(minutes: 2));
      dwell.cancel();
      async.elapse(const Duration(minutes: 10));
      expect(commits, 0);
      expect(dwell.committed, isFalse);
    });
  });

  test('换一首会重新计满 5 分钟', () {
    fakeAsync((async) {
      var commits = 0;
      final dwell = RecentPracticePromote();
      dwell.arm(() => commits++);
      async.elapse(const Duration(minutes: 4));
      dwell.arm(() => commits++);
      async.elapse(const Duration(minutes: 4));
      expect(commits, 0);
      async.elapse(const Duration(minutes: 1));
      expect(commits, 1);
      dwell.cancel();
    });
  });
}
