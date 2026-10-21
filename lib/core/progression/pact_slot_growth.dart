import 'dart:math' as math;
import 'resource_growth.dart';

class PactSlotGrowth {
  PactSlotGrowth._(this.current, this.maximum);
  final List<int> current;
  final List<int> maximum;

  factory PactSlotGrowth.move(
      {required List<int> current,
      required List<int> maximum,
      required int oldCircle,
      required int newCircle,
      required int oldNorm,
      required int newNorm}) {
    if (oldCircle < 1 ||
        newCircle < 1 ||
        oldCircle > 9 ||
        newCircle > 9 ||
        current.length > 9 ||
        maximum.length > 9 ||
        current.any((n) => n < 0) ||
        maximum.any((n) => n < 0) ||
        oldNorm < 0 ||
        newNorm < 0) {
      throw ArgumentError('Invalid Pact slot state.');
    }
    final length =
        math.max(newCircle, math.max(current.length, maximum.length));
    int at(List<int> values, int index) =>
        index < values.length ? values[index] : 0;
    final next = [for (var i = 0; i < length; i++) at(current, i)];
    final limits = [for (var i = 0; i < length; i++) at(maximum, i)];
    final remainder = ResourceGrowth.remaining(
        current: at(current, oldCircle - 1),
        oldMaximum: oldNorm,
        newMaximum: newNorm);
    final capacity =
        at(maximum, oldCircle - 1) + math.max(0, newNorm - oldNorm).toInt();
    if (oldCircle == newCircle) {
      next[newCircle - 1] = remainder;
      limits[newCircle - 1] = capacity;
    } else {
      if (oldCircle <= length) {
        next[oldCircle - 1] = 0;
        limits[oldCircle - 1] = 0;
      }
      next[newCircle - 1] += remainder;
      limits[newCircle - 1] += capacity;
    }
    return PactSlotGrowth._(next, limits);
  }
}
