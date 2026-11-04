import 'dart:async';

/// Serializes async one-shot work (Windows `audioplayers` seek / resume / stop).
///
/// A dense chord used to post every note's method-channel call before the
/// event loop could deliver a click, so pause / back / route pop never ran.
/// Only one job runs at a time, and the pump yields between jobs.
class NoteVoicePump {
  NoteVoicePump({
    Future<void> Function()? yieldTurn,
    this.maxPending = 16,
  }) : _yieldTurn = yieldTurn ?? (() => Future<void>.delayed(Duration.zero));

  /// Queued note attacks beyond this are dropped. Stop jobs use [front] and
  /// are not capped, so pause can still cut sound when the queue is full.
  final int maxPending;

  final Future<void> Function() _yieldTurn;
  final List<_NoteVoiceJob> _queue = [];
  final List<Completer<void>> _idleWaiters = [];
  bool _running = false;

  int get pending => _queue.length;
  bool get isRunning => _running;

  /// Returns false when a non-priority job was dropped.
  bool enqueue(Future<void> Function() job, {bool front = false}) {
    if (!front && _queue.length >= maxPending) return false;
    final item = _NoteVoiceJob(job);
    if (front) {
      _queue.insert(0, item);
    } else {
      _queue.add(item);
    }
    if (!_running) {
      _running = true;
      unawaited(_drain());
    }
    return true;
  }

  /// Drops not-yet-started jobs. The in-flight job is left to finish; callers
  /// bump their voice epoch so it no-ops before the next platform call.
  void clearPending() {
    _queue.clear();
  }

  Future<void> get whenIdle {
    if (!_running && _queue.isEmpty) return Future<void>.value();
    final waiter = Completer<void>();
    _idleWaiters.add(waiter);
    return waiter.future;
  }

  Future<void> _drain() async {
    try {
      while (_queue.isNotEmpty) {
        final item = _queue.removeAt(0);
        try {
          await item.job();
        } catch (_) {
          // Jobs log their own failures. A throw must not wedge the pump,
          // or later stop() calls never reach the platform.
        }
        if (_queue.isEmpty) break;
        await _yieldTurn();
      }
    } finally {
      _running = false;
      if (_queue.isNotEmpty) {
        _running = true;
        unawaited(_drain());
      } else {
        _releaseIdle();
      }
    }
  }

  void _releaseIdle() {
    if (_running || _queue.isNotEmpty) return;
    final waiters = List<Completer<void>>.of(_idleWaiters);
    _idleWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }
}

class _NoteVoiceJob {
  _NoteVoiceJob(this.job);
  final Future<void> Function() job;
}
