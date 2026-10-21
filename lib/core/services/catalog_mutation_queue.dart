import 'dart:async';

/// Serializes source installation/deletion; failures never poison the queue.
class CatalogMutationQueue {
  static Future<void>? _previous;
  static Future<T> run<T>(Future<T> Function() action) async {
    final before = _previous;
    final done = Completer<void>();
    _previous = done.future;
    if (before != null) await before;
    try {
      return await action();
    } finally {
      done.complete();
      if (identical(_previous, done.future)) _previous = null;
    }
  }
}
