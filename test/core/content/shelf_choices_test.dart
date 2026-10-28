import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/shelf_choices.dart';

class _Entry {
  _Entry(this.id, this.sourceId, this.names, [this.text = '']);
  final String id;
  final String? sourceId;
  final List<String> names;
  final String text;
}

ContentRecord<_Entry> _record(_Entry e) => ContentRecord(
    kind: ContentKind.race,
    id: e.id,
    sourceId: e.sourceId,
    entity: e,
    names: e.names,
    definition: {'names': e.names, 'text': e.text});

void main() {
  test('exact copies are one concept; differing versions stay explicit', () {
    final dwarf = _Entry('dwarf', null, ['Dwarf', 'Дварф']);
    final dwarfCopy = _Entry('dwarf', 'phb', ['Dwarf', 'Дварф']);
    final elf = _Entry('elf', 'phb', ['Elf', 'Эльф'], 'one');
    final elfOther = _Entry('elf-x', 'xge', ['Эльф'], 'two');
    final orc = _Entry('orc', 'vgm', ['Orc']);
    final choices =
        shelfChoices([dwarf, elf, dwarfCopy, orc, elfOther], _record);
    expect(choices, hasLength(3));
    // The shelf order holds; the built-in record leads its family.
    expect(choices.map((c) => c.lead.id), ['dwarf', 'elf', 'orc']);
    expect(choices.first.lead, same(dwarf));
    expect(choices.first.manyBooks, isTrue);
    expect(choices.first.hasVersions, isFalse);
    expect(choices[1].hasVersions, isTrue);
    expect(choices[1].holds('elf-x', 'xge'), isTrue);
    expect(choices[1].holds('elf-x', null), isFalse);
    expect(choices[2].manyBooks, isFalse);
  });

  test('the same shelf is grouped once', () {
    final list = [
      _Entry('a', null, ['A']),
      _Entry('a', 'book', ['A'])
    ];
    expect(identical(shelfChoices(list, _record), shelfChoices(list, _record)),
        isTrue);
  });
}
