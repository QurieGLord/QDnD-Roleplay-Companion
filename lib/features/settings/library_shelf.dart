import 'dart:math' as math;

import '../../core/content/library_policy.dart';
import '../../core/models/compendium_source.dart';
import '../../core/services/character_data_service.dart';
import '../../core/services/item_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/ui/page_kit.dart';

/// The six kinds of content a library brings, in the prototype's order and
/// accents (a0–a5).
enum ShelfKind { items, spells, races, classes, backgrounds, feats }

extension ShelfKindLook on ShelfKind {
  String get icon => switch (this) {
        ShelfKind.items => 'bag',
        ShelfKind.spells => 'magic',
        ShelfKind.races => 'person',
        ShelfKind.classes => 'shield',
        ShelfKind.backgrounds => 'book',
        ShelfKind.feats => 'star',
      };

  String label(Tr s) => switch (this) {
        ShelfKind.items => s.t('Предметы', 'Items'),
        ShelfKind.spells => s.t('Заклинания', 'Spells'),
        ShelfKind.races => s.t('Расы', 'Races'),
        ShelfKind.classes => s.t('Классы', 'Classes'),
        ShelfKind.backgrounds => s.t('Предыстории', 'Backgrounds'),
        ShelfKind.feats => s.t('Черты', 'Feats'),
      };

  int of(CompendiumSource s) => switch (this) {
        ShelfKind.items => s.itemCount,
        ShelfKind.spells => s.spellCount,
        ShelfKind.races => s.raceCount,
        ShelfKind.classes => s.classCount,
        ShelfKind.backgrounds => s.backgroundCount,
        ShelfKind.feats => s.featCount,
      };
}

/// A book on the shelf: one XML source, or every module of one ZIP.
class ShelfBook {
  ShelfBook(this.id, this.name, this.parts, {required this.zip})
      : builtIn = false,
        _counts = null;

  /// The SRD 2014 book that ships with the app.
  ShelfBook.builtIn(List<int> counts)
      : id = builtInId,
        name = 'SRD 2014',
        parts = const [],
        zip = false,
        builtIn = true,
        _counts = counts;

  static const builtInId = 'builtin:srd2014';

  final String id, name;
  final List<CompendiumSource> parts;
  final bool zip, builtIn;
  final List<int>? _counts;

  /// A built-in book can be put away but never removed.
  bool get enabled => !builtIn || LibraryPolicy.srdEnabled;

  /// Its colour on the shelf, given by its place in the import order.
  int accent = 0;

  DateTime get importedAt => parts.isEmpty
      ? DateTime(2000)
      : parts.map((p) => p.importedAt).reduce((a, b) => a.isAfter(b) ? a : b);

  int count(ShelfKind kind) => _counts != null
      ? _counts[kind.index]
      : parts.fold(0, (n, p) => n + kind.of(p));
  int get total => ShelfKind.values.fold(0, (n, k) => n + count(k));

  /// Spine width from the size of the book, on a log scale.
  double get spineWidth =>
      26 + math.min(34, (math.log(total + 1) / math.ln10 * 10).roundToDouble());
}

int sourceTotal(CompendiumSource s) =>
    ShelfKind.values.fold(0, (n, k) => n + k.of(s));

/// The built-in book's six counts, read from the loaded catalogues.
List<int> builtInCounts() {
  int safe(int Function() f) {
    try {
      return f();
    } catch (_) {
      return 0;
    }
  }

  return [
    safe(() => ItemService.builtInItems().length),
    safe(() => SpellService.builtInSpells().length),
    safe(() => CharacterDataService.builtInRaces().length),
    safe(CharacterDataService.builtInClassCount),
    safe(() => CharacterDataService.builtInBackgrounds().length),
    0,
  ];
}

/// The built-in book first, then the player's books, oldest first.
List<ShelfBook> shelfBooks(Iterable<CompendiumSource> sources,
    {bool builtIn = true}) {
  final byId = <String, ShelfBook>{};
  for (final s in sources) {
    final archive = s.archiveId;
    if (archive != null && archive.isNotEmpty) {
      byId
          .putIfAbsent(
              'zip:$archive',
              () => ShelfBook('zip:$archive', s.archiveName ?? s.name, [],
                  zip: true))
          .parts
          .add(s);
    } else {
      byId[s.id] = ShelfBook(s.id, s.name, [s], zip: false);
    }
  }
  final books = byId.values.toList()
    ..sort((a, b) => a.importedAt.compareTo(b.importedAt));
  for (var i = 0; i < books.length; i++) {
    books[i].accent = (i + 1) % 6;
    books[i].parts.sort(
        (a, b) => (a.moduleName ?? a.name).compareTo(b.moduleName ?? b.name));
  }
  return [if (builtIn) ShelfBook.builtIn(builtInCounts()), ...books];
}

/// «3 источника · 12 480 записей».
String shelfSummary(Tr s, List<ShelfBook> books) {
  if (books.isEmpty) return s.t('Пока пусто', 'Empty for now');
  final n = books.where((b) => b.enabled).fold(0, (t, b) => t + b.total);
  final sources = s.plural(books.length,
      const ['источник', 'источника', 'источников'], const ['source', 'sources']);
  final entries = s.plural(
      n, const ['запись', 'записи', 'записей'], const ['entry', 'entries']);
  return '$sources · $entries';
}
