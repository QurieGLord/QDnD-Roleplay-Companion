import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/features/character_level_up/widgets/advancement_selection.dart';

void main() {
  test(
      'Replacement follows selection order, including after deselection and reselection',
      () {
    var picks = <String>{'a', 'b'};
    picks = toggleAdvancementSelection(picks, 'c', 2);
    expect(picks.toList(), ['b', 'c']);
    picks = toggleAdvancementSelection(picks, 'b', 2);
    expect(picks.toList(), ['c']);
    picks = toggleAdvancementSelection(picks, 'b', 2);
    picks = toggleAdvancementSelection(picks, 'd', 2);
    expect(picks.toList(), ['b', 'd']);
  });
  test('One-place replacement and a zero-place group never overfill', () {
    final original = {'a'};
    expect(toggleAdvancementSelection(original, 'b', 1), {'b'});
    expect(original, {'a'});
    expect(toggleAdvancementSelection(<String>{}, 'b', 0), isEmpty);
  });
}
