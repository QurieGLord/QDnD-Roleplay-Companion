import 'package:flutter/scheduler.dart';

/// Shares pure derivations while one frame is being built.
///
/// A sheet rebuild asks the same questions many times (class rules, spell
/// sources). While the framework builds a frame, no handler can change the
/// hero, so an answer computed for one widget is valid for the rest of that
/// frame. Outside a build (actions, saves, imports, tests without a frame)
/// every call computes afresh, so nothing can go stale.
abstract final class FrameMemo {
  static final _answers = Map<Object, Map<Object, Object>>.identity();
  static bool _clearScheduled = false;

  static T shared<T extends Object>(
      Object owner, Object key, T Function() compute) {
    SchedulerBinding? binding;
    try {
      binding = SchedulerBinding.instance;
    } catch (_) {
      return compute();
    }
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      return compute();
    }
    if (!_clearScheduled) {
      _clearScheduled = true;
      binding.addPostFrameCallback((_) {
        _answers.clear();
        _clearScheduled = false;
      });
    }
    return _answers.putIfAbsent(owner, () => {}).putIfAbsent(key, compute)
        as T;
  }
}
