import 'dart:math' as math;

/// Progression grants only a positive increase of a resource's normal capacity.
/// Consumption and table-granted excess survive; growth never implies rest.
class ResourceGrowth {
  static int remaining(
      {required int current,
      required int oldMaximum,
      required int newMaximum}) {
    if (current < 0 || oldMaximum < 0 || newMaximum < 0) {
      throw ArgumentError('Resource values must be nonnegative.');
    }
    return current + math.max(0, newMaximum - oldMaximum);
  }
}
