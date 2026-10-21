import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/utils/dice_expression.dart';

class _LowestRoll implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  test('Damage rolls every die and the modifier, including Cyrillic notation',
      () {
    expect(
        DiceExpression.tryParse('2к6 + 1d4 + 3')!.roll(_LowestRoll()).total, 6);
    expect(DiceExpression.tryParse('2d6 - 2')!.roll(_LowestRoll()).total, 0);
    expect(DiceExpression.tryParse('4')!.roll(_LowestRoll()).total, 4);
    expect(DiceExpression.tryParse('d8 + 3')!.roll(_LowestRoll()).rolls, [1]);
  });
  test('Unknown or excessive formulas do not fall back to a different die', () {
    for (final text in [
      '',
      '2d6fire',
      '1d6/2',
      'd0',
      '0d6',
      '999d6',
      '1d9999',
      '1d6+1d6x',
      '1d6 1d8'
    ]) {
      expect(DiceExpression.tryParse(text), isNull, reason: text);
    }
  });
}
