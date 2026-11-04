import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/note_voice_pump.dart';

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  test('一帧入队只启动第一个任务，其余等让出之后', () async {
    final order = <String>[];
    final hold = Completer<void>();
    final yieldGate = Completer<void>();
    final pump = NoteVoicePump(
      yieldTurn: () async {
        order.add('yield');
        await yieldGate.future;
      },
    );
    pump.enqueue(() async {
      order.add('a');
      await hold.future;
    });
    pump.enqueue(() async {
      order.add('b');
    });
    pump.enqueue(() async {
      order.add('c');
    });

    expect(order, ['a']);
    expect(pump.pending, 2);

    hold.complete();
    await _turn();
    expect(order, ['a', 'yield']);

    yieldGate.complete();
    await pump.whenIdle;
    expect(order, ['a', 'yield', 'b', 'yield', 'c']);
  });

  test('clearPending 丢掉还没开始的任务', () async {
    final started = <int>[];
    final hold = Completer<void>();
    final pump = NoteVoicePump(yieldTurn: () async {});
    pump.enqueue(() async {
      started.add(1);
      await hold.future;
    });
    pump.enqueue(() async {
      started.add(2);
    });
    expect(started, [1]);
    expect(pump.pending, 1);
    pump.clearPending();
    expect(pump.pending, 0);
    hold.complete();
    await _turn();
    await _turn();
    expect(started, [1]);
    expect(pump.isRunning, isFalse);
  });

  test('front 任务插到队首，暂停停止优先于后续发音', () async {
    final order = <int>[];
    final hold = Completer<void>();
    final yieldGate = Completer<void>();
    final pump = NoteVoicePump(
      yieldTurn: () async {
        await yieldGate.future;
      },
    );
    pump.enqueue(() async {
      order.add(1);
      await hold.future;
    });
    pump.enqueue(() async {
      order.add(2);
    });
    expect(pump.enqueue(() async => order.add(9), front: true), isTrue);
    hold.complete();
    yieldGate.complete();
    await pump.whenIdle;
    expect(order, [1, 9, 2]);
  });

  test('队列满时丢掉普通任务，front 停止仍入队', () async {
    final pump = NoteVoicePump(maxPending: 1, yieldTurn: () async {});
    final hold = Completer<void>();
    expect(
      pump.enqueue(() async {
        await hold.future;
      }),
      isTrue,
    );
    expect(pump.enqueue(() async {}), isTrue);
    expect(pump.pending, 1);
    expect(pump.enqueue(() async {}), isFalse);
    expect(pump.enqueue(() async {}, front: true), isTrue);
    expect(pump.pending, 2);
    hold.complete();
    await pump.whenIdle;
  });

  test('任务抛错后泵继续，whenIdle 仍完成', () async {
    final pump = NoteVoicePump(yieldTurn: () async {});
    var second = false;
    pump.enqueue(() async {
      throw StateError('boom');
    });
    pump.enqueue(() async {
      second = true;
    });
    await pump.whenIdle;
    expect(second, isTrue);
    expect(pump.isRunning, isFalse);
  });
}
