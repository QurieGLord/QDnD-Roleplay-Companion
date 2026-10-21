import 'dart:math';

/// Bounded dice sums for item damage. Unsupported syntax never becomes a d20.
class DiceExpression {
  DiceExpression._(this.terms);
  final List<({int sign, int count, int sides, int constant})> terms;
  static DiceExpression? tryParse(String input) {
    final text =
        input.replaceAll(RegExp(r'\s+'), '').toLowerCase().replaceAll('к', 'd');
    if (text.isEmpty || text.length > 256) return null;
    final pattern = RegExp(r'([+-]?)(?:(\d*)d(\d+)|(\d+))');
    final terms = <({int sign, int count, int sides, int constant})>[];
    var offset = 0, dice = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start != offset || (offset > 0 && match[1]!.isEmpty)) {
        return null;
      }
      final sign = match[1] == '-' ? -1 : 1;
      final constant = int.tryParse(match[4] ?? '0');
      final count = match[3] == null
          ? 0
          : int.tryParse(match[2]!.isEmpty ? '1' : match[2]!);
      final sides = int.tryParse(match[3] ?? '0');
      if (constant == null ||
          count == null ||
          sides == null ||
          constant > 100000 ||
          (match[3] != null &&
              (count < 1 || count > 100 || sides < 2 || sides > 1000))) {
        return null;
      }
      dice += count;
      if (dice > 100) return null;
      terms.add((sign: sign, count: count, sides: sides, constant: constant));
      offset = match.end;
    }
    return offset == text.length
        ? DiceExpression._(List.unmodifiable(terms))
        : null;
  }

  ({int total, List<int> rolls}) roll(Random random) {
    final rolls = <int>[];
    var total = 0;
    for (final term in terms) {
      total += term.sign * term.constant;
      for (var n = 0; n < term.count; n++) {
        final roll = random.nextInt(term.sides) + 1;
        rolls.add(term.sign * roll);
        total += term.sign * roll;
      }
    }
    return (total: total, rolls: List.unmodifiable(rolls));
  }
}
