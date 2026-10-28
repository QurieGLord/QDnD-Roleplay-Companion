import 'content_catalog.dart';
import 'library_policy.dart';

/// C04 · one entry of a choice list: a concept of the catalogue, however many
/// books carry it. Exact copies are one card with their books; differing
/// versions are chosen explicitly (see showContentVariantPicker).
class ShelfChoice<T> {
  const ShelfChoice(this.family, this.lead);
  final ContentFamily<T> family;

  /// The record the card shows until one of the family is chosen.
  final T lead;

  bool get hasVersions => family.variants.length > 1;
  bool get manyBooks => family.sources.length > 1;

  /// Whether the record [id] of [sourceId] is one of this concept's; a
  /// choice made before a reload is a new object with the same identity.
  bool holds(String? id, String? sourceId) =>
      id != null &&
      family.records.any((r) => r.id == id && r.sourceId == sourceId);
}

/// Groups a shelf list (already settled by [LibraryPolicy]) into concepts, in
/// the order the shelf lists them. The lead follows the overlap setting: the
/// built-in record when the base book wins, the library's otherwise.
List<ShelfChoice<T>> shelfChoices<T>(
    List<T> listed, ContentRecord<T> Function(T) record) {
  final key = Object.hashAll([
    T,
    LibraryPolicy.overlap,
    for (final e in listed) identityHashCode(e),
  ]);
  final cached = _cache[T];
  if (cached != null && cached.$1 == key) {
    return cached.$2 as List<ShelfChoice<T>>;
  }
  List<ShelfChoice<T>> choices;
  try {
    final order = {for (final (i, e) in listed.indexed) identityHashCode(e): i};
    final mineFirst = LibraryPolicy.overlap == LibraryOverlap.mine;
    final families = ContentCatalog<T>(listed.map(record)).families;
    choices = [
      for (final family in families)
        ShelfChoice(family, (family.records.toList()
              ..sort((a, b) {
                if ((a.sourceId == null) != (b.sourceId == null)) {
                  return (a.sourceId == null) != mineFirst ? -1 : 1;
                }
                return order[identityHashCode(a.entity)]!
                    .compareTo(order[identityHashCode(b.entity)]!);
              }))
            .first
            .entity)
    ]..sort((a, b) => _firstIndex(a, order).compareTo(_firstIndex(b, order)));
  } catch (_) {
    // A broken index never empties the list: one card per record, as before.
    choices = [
      for (final e in listed)
        ShelfChoice(ContentFamily<T>([record(e)]), e)
    ];
  }
  _cache[T] = (key, choices);
  return choices;
}

int _firstIndex<T>(ShelfChoice<T> choice, Map<int, int> order) => choice
    .family.records
    .map((r) => order[identityHashCode(r.entity)]!)
    .reduce((a, b) => a < b ? a : b);

final _cache = <Type, (int, List<ShelfChoice>)>{};
