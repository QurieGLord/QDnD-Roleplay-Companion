import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/content/content_reference_repair.dart';
import '../../core/content/library_policy.dart';
import '../../core/models/compendium_source.dart';
import '../../core/services/character_data_service.dart';
import '../../core/services/item_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/page_kit.dart';
import '../journal/journal_kit.dart';
import 'library_import.dart';
import 'library_shelf.dart';

/// The libraries as a shelf (wave 5, variant A «Полка»): totals on top, a
/// spine per source on a plank from edge to edge — a ZIP stands as a set of
/// its modules — and the touched book slides up while its card opens below.
class LibraryManagerScreen extends StatefulWidget {
  const LibraryManagerScreen({super.key});

  @override
  State<LibraryManagerScreen> createState() => _LibraryManagerScreenState();
}

class _LibraryManagerScreenState extends State<LibraryManagerScreen> {
  final _scroll = ScrollController();
  bool _titled = false;
  String? _selected;

  /// The book that has just been put on the shelf drops into its place.
  String? _dropped;

  @override
  void initState() {
    super.initState();
    LibraryPolicy.revision.addListener(_policyChanged);
    _scroll.addListener(() {
      final titled = _scroll.offset > 64;
      if (titled != _titled) setState(() => _titled = titled);
    });
  }

  void _policyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LibraryPolicy.revision.removeListener(_policyChanged);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final id = await importLibrary(context);
    if (!mounted || id == null) return;
    setState(() {
      _selected = id;
      _dropped = id;
    });
    final s = Tr(context);
    AppSnackBar.success(context, s.t('Книга на полке', 'The book is on the shelf'));
  }

  Future<void> _reload() async {
    await ItemService.reload();
    await SpellService.reload();
    await ContentReferenceRepair.repairStoredCharacters();
    await CharacterDataService.reload();
  }

  Future<void> _removeBook(ShelfBook book) async {
    final s = Tr(context);
    setState(() => _selected = null);
    try {
      await StorageService.deleteSources(book.parts.map((p) => p.id));
      await _reload();
      if (!mounted) return;
      AppSnackBar.success(context,
          s.t('«${book.name}» убрана с полки', '«${book.name}» is off the shelf'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, s.t('Не удалось убрать: $e', 'Could not remove it: $e'));
    }
  }

  Future<void> _removeModule(CompendiumSource module) async {
    final s = Tr(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('Убрать модуль?', 'Remove the module?')),
        content: Text(s.t(
            '«${module.moduleName ?? module.name}» и всё, что он принёс, уйдут из библиотек.',
            '«${module.moduleName ?? module.name}» and all it brought will leave the libraries.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('Отмена', 'Cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                  foregroundColor: AppAccents.of(context).at(0)),
              child: Text(s.t('Убрать', 'Remove'))),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    HapticFeedback.mediumImpact();
    try {
      await StorageService.deleteSource(module.id);
      await _reload();
      if (!mounted) return;
      AppSnackBar.success(context, s.t('Модуль убран', 'Module removed'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, s.t('Не удалось убрать: $e', 'Could not remove it: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    final top = MediaQuery.paddingOf(context).top;
    Widget page(List<ShelfBook> books) {
      final selected = books.where((b) => b.id == _selected).firstOrNull;
      return SingleChildScrollView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(0, top + 80, 0, 60),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PageMasthead(
                cap: s.t('Контент стола', 'Table content'),
                title: s.t('Библиотеки', 'Libraries'),
                subtitle: s.t(
                    'Книги правил, заклинания и свои находки стола — из файлов XML и архивов ZIP.',
                    'Rulebooks, spells and your table\'s own finds — from XML files and ZIP archives.')),
          ),
          const SizedBox(height: 14),
          ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PageGrid3(children: [
                for (final k in ShelfKind.values)
                  PageCount(
                      value: books
                          .where((b) => b.enabled)
                          .fold(0, (n, b) => n + b.count(k)),
                      label: k.label(s),
                      accent: AppAccents.of(context).at(k.index),
                      from: 0),
              ]),
            ),
            const SizedBox(height: 8),
            _Shelf(
              books: books,
              selected: _selected,
              dropped: _dropped,
              onPick: (id) {
                HapticFeedback.lightImpact();
                setState(() => _selected = _selected == id ? null : id);
              },
              onImport: _import,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, const Duration(milliseconds: 420)),
                switchInCurve: AppMotion.snappyCurve,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) => Transform.translate(
                        offset: Offset(0, 16 * (1 - animation.value)),
                        child: child),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current]),
                child: selected == null
                    ? Padding(
                        key: const ValueKey('hint'),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: PageNote(
                            s.t(
                                'Коснитесь корешка — книга выдвинется, а здесь появится её содержимое.',
                                'Touch a spine — the book slides out and its contents show here.'),
                            icon: 'book',
                            size: 13.5),
                      )
                    : _BookCard(
                        key: ValueKey(selected.id),
                        book: selected,
                        onRemove: () => _removeBook(selected),
                        onRemoveModule: _removeModule,
                      ),
              ),
            ),
          ],
        ]),
      );
    }

    Widget body;
    try {
      body = ValueListenableBuilder<Box<CompendiumSource>>(
        valueListenable: StorageService.getSourcesListenable(),
        builder: (context, box, _) => page(shelfBooks(box.values)),
      );
    } catch (_) {
      body = page(const []);
    }
    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(children: [
        body,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: JournalTopBar(
            titled: _titled,
            title: s.t('Библиотеки', 'Libraries'),
            leading: JournalRound(
                icon: 'back',
                label: s.t('Назад', 'Back'),
                onTap: () => Navigator.of(context).maybePop()),
            actions: [
              JournalRound(
                  icon: 'plus',
                  label: s.t('Импорт', 'Import'),
                  onTap: _import),
            ],
          ),
        ),
      ]),
    );
  }
}

/// The plank books stand on.
class _Plank extends StatelessWidget {
  const _Plank();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.surfaceContainerHigh, c.surfaceContainer]),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .7),
              blurRadius: 20,
              spreadRadius: -10,
              offset: const Offset(0, 10)),
        ],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf(
      {required this.books,
      required this.selected,
      required this.dropped,
      required this.onPick,
      required this.onImport});
  final List<ShelfBook> books;
  final String? selected, dropped;
  final ValueChanged<String> onPick;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 40),
        child: Stack(clipBehavior: Clip.none, children: [
          const Positioned(left: -20, right: -20, bottom: 0, child: _Plank()),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 210),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < books.length; i++) ...[
                      _BookSpines(
                        key: ValueKey(books[i].id),
                        book: books[i],
                        index: i,
                        selected: books[i].id == selected,
                        drop: books[i].id == dropped,
                        onTap: () => onPick(books[i].id),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Semantics(
                      button: true,
                      label: s.t('Импорт', 'Import'),
                      child: Pressable(
                        scale: .95,
                        haptic: true,
                        onTap: onImport,
                        child: JournalDashed(
                          radius: 8,
                          child: SizedBox(
                            width: 44,
                            height: 150,
                            child: Center(
                                child: LineIcon('plus',
                                    color: c.onSurfaceVariant)),
                          ),
                        ),
                      ),
                    ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One book on the shelf. Touched, it slides up on a spring; a new one
/// drops into its place from above.
class _BookSpines extends StatefulWidget {
  const _BookSpines(
      {super.key,
      required this.book,
      required this.index,
      required this.selected,
      required this.drop,
      required this.onTap});
  final ShelfBook book;
  final int index;
  final bool selected, drop;
  final VoidCallback onTap;
  @override
  State<_BookSpines> createState() => _BookSpinesState();
}

class _BookSpinesState extends State<_BookSpines>
    with TickerProviderStateMixin {
  late final _lift = AnimationController.unbounded(
      vsync: this, value: widget.selected ? -22 : 0);
  late final _fall = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      value: widget.drop ? 0 : 1);

  @override
  void initState() {
    super.initState();
    if (widget.drop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _fall.value = 1;
          return;
        }
        _fall.animateWith(SpringSimulation(AppMotion.bouncy, 0, 1, 0));
        // Brings the new book into view along the shelf only.
        final box = context.findRenderObject();
        if (box != null) {
          Scrollable.of(context).position.ensureVisible(box,
              alignment: 1,
              duration: AppMotion.long,
              curve: AppMotion.standard);
        }
      });
    }
  }

  @override
  void didUpdateWidget(_BookSpines old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      final to = widget.selected ? -22.0 : 0.0;
      if (MediaQuery.disableAnimationsOf(context)) {
        _lift.value = to;
      } else {
        _lift.animateWith(
            SpringSimulation(AppMotion.snappy, _lift.value, to, _lift.velocity));
      }
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final a = book.builtIn
        ? Theme.of(context).colorScheme.primary
        : AppAccents.of(context).at(book.accent);
    final parts = book.zip ? book.parts : [null];
    final w = book.spineWidth;
    final h = 150.0 + ((widget.index * 37) % 4) * 12;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: book.name,
      child: Pressable(
        scale: .98,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_lift, _fall]),
          builder: (context, child) {
            final f = _fall.value;
            return Transform.translate(
              offset: Offset(0, _lift.value - 140 * (1 - f)),
              child: Transform.rotate(
                angle: -8 * math.pi / 180 * (1 - f),
                // A book put away stands dim on the shelf.
                child: AnimatedOpacity(
                  duration: AppMotion.of(context, AppMotion.medium),
                  opacity: book.enabled ? 1 : .38,
                  child: Opacity(opacity: f.clamp(0.0, 1.0), child: child),
                ),
              ),
            );
          },
          child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var k = 0; k < parts.length; k++) ...[
                  if (k > 0) const SizedBox(width: 2),
                  _Spine(
                    title: book.zip
                        ? (parts[k]!.moduleName ?? parts[k]!.name)
                        : book.name.replaceAll(RegExp(r'\.xml$'), ''),
                    accent: a,
                    width: parts.length > 1 ? math.max(22, w - 8 - k * 4) : w,
                    height: h - k * 14,
                    lifted: widget.selected,
                    badge: book.builtIn
                        ? 'star'
                        : (book.zip && k == 0 ? 'zip' : null),
                  ),
                ],
              ]),
        ),
      ),
    );
  }
}

class _Spine extends StatelessWidget {
  const _Spine(
      {required this.title,
      required this.accent,
      required this.width,
      required this.height,
      required this.lifted,
      this.badge});
  final String title;
  final Color accent;
  final double width, height;
  final bool lifted;

  /// A mark at the top corner: a ZIP's set, the built-in book's star.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final calm = AppCalm.of(context);
    final ink = pageMix(Colors.black, .1, c.surface);
    Widget band() => FractionallySizedBox(
          widthFactor: .7,
          child: Container(
              height: 3,
              decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(2))),
        );
    return Stack(clipBehavior: Clip.none, children: [
      AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 300)),
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6), bottom: Radius.circular(3)),
          gradient: calm.on
              ? null
              : LinearGradient(stops: const [
                  0,
                  .4,
                  1
                ], colors: [
                  pageMix(accent, .62, c.surfaceContainer),
                  accent,
                  pageMix(Colors.black, .24, accent),
                ]),
          color: calm.on ? pageMix(accent, .8, c.surfaceContainer) : null,
          border: Border.all(color: Colors.black.withValues(alpha: .18)),
          boxShadow: [
            lifted && !calm.on
                ? BoxShadow(
                    color: accent,
                    blurRadius: 30,
                    spreadRadius: -12,
                    offset: const Offset(0, 18))
                : BoxShadow(
                    color: Colors.black.withValues(alpha: .7),
                    blurRadius: 12,
                    spreadRadius: -8,
                    offset: const Offset(0, 6)),
          ],
        ),
        child: Column(children: [
          band(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 12.5,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: ink)),
              ),
            ),
          ),
          band(),
        ]),
      ),
      if (badge != null)
        Positioned(
          top: -12,
          right: -8,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface,
                border: Border.all(color: accent, width: 2)),
            child: LineIcon(badge!, size: 14, color: accent),
          ),
        ),
    ]);
  }
}

/// The opened book: its seal, what kind of book it is and when it came,
/// its six counts, the modules of a ZIP, and the hold to take it down.
class _BookCard extends StatelessWidget {
  const _BookCard(
      {super.key,
      required this.book,
      required this.onRemove,
      required this.onRemoveModule});
  final ShelfBook book;
  final VoidCallback onRemove;
  final ValueChanged<CompendiumSource> onRemoveModule;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final acc = book.builtIn ? c.primary : a.at(book.accent);
    final s = Tr(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    final at = book.importedAt;
    final date = DateUtils.isSameDay(at, now)
        ? s.t('сегодня', 'today')
        : DateFormat.yMMMd(locale).format(at);
    final kind = book.zip
        ? 'ZIP · ${s.plural(book.parts.length, const ['модуль', 'модуля', 'модулей'], const ['module', 'modules'])}'
        : 'XML';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(30)),
      child: Stack(children: [
        Positioned(
          right: -100,
          top: -130,
          child: Container(
            width: 300,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(stops: const [
                0,
                .66
              ], colors: [
                acc.withValues(alpha: .3 * AppCalm.of(context).glow),
                acc.withValues(alpha: 0)
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              PageSeal(book.builtIn ? 'star' : (book.zip ? 'zip' : 'file'),
                  accent: acc, size: PageSealSize.lg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PageCap(
                      book.builtIn
                          ? s.t('Встроенная · SRD 5.1', 'Built in · SRD 5.1')
                          : '$kind · $date',
                      accent: acc),
                  const SizedBox(height: 4),
                  Text(
                      book.builtIn
                          ? s.t('Базовые правила 2014', 'Core rules 2014')
                          : book.name,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 26,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.65,
                          color: c.onSurface)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            PageGrid3(children: [
              for (final k in ShelfKind.values)
                PageCount(
                    value: book.count(k),
                    label: k.label(s),
                    accent: a.at(k.index),
                    icon: k.icon,
                    size: 20,
                    tint: .12,
                    base: c.surfaceContainer,
                    dimZero: true,
                    from: 0),
            ]),
            if (book.zip) ...[
              const SizedBox(height: 14),
              for (final m in book.parts) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  decoration: BoxDecoration(
                      color: c.onSurface.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Expanded(
                      child: PageTitle(
                          m.moduleName ?? m.name,
                          '${m.modulePath ?? m.name} · '
                          '${s.plural(sourceTotal(m), const ['запись', 'записи', 'записей'], const ['entry', 'entries'])}'),
                    ),
                    JournalRound(
                        icon: 'trash',
                        label: s.t('Убрать модуль', 'Remove the module'),
                        size: 36,
                        onTap: () => onRemoveModule(m)),
                  ]),
                ),
                const SizedBox(height: 6),
              ],
            ],
            const SizedBox(height: 14),
            if (book.builtIn)
              const _BuiltInControls()
            else
              PageHold(
                  label: s.t('Удерживайте, чтобы убрать с полки',
                      'Hold to take it off the shelf'),
                  onDone: onRemove),
          ]),
        ),
      ]),
    );
  }
}

/// The built-in book is never removed: it can be put away, and when it
/// meets the player's books on the same entry, the player picks which one
/// the app offers.
class _BuiltInControls extends StatelessWidget {
  const _BuiltInControls();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final s = Tr(context);
    final on = LibraryPolicy.srdEnabled;
    final overlap = LibraryPolicy.overlap;
    var shared = 0;
    try {
      shared = LibraryPolicy.overlapping(SpellService.builtInSpells(),
              SpellService.librarySpells(), (x) => x.nameEn) +
          LibraryPolicy.overlapping(ItemService.builtInItems(),
              ItemService.libraryItems(), (x) => x.nameEn) +
          LibraryPolicy.overlapping(CharacterDataService.builtInRaces(),
              CharacterDataService.libraryRaces(), (x) => x.name['en'] ?? x.id) +
          LibraryPolicy.overlapping(
              CharacterDataService.builtInBackgrounds(),
              CharacterDataService.libraryBackgrounds(),
              (x) => x.name['en'] ?? x.id);
    } catch (_) {}
    Widget choice(LibraryOverlap value, String icon, String title, String sub) {
      final picked = overlap == value;
      final dur = AppMotion.of(context, AppMotion.snappySettle);
      return Expanded(
        child: Semantics(
          selected: picked,
          button: true,
          child: Pressable(
            scale: .97,
            onTap: () {
              if (picked) return;
              pageTick();
              LibraryPolicy.setOverlap(value);
            },
            child: AnimatedContainer(
              duration: dur,
              curve: AppMotion.standard,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: picked
                    ? pageMix(c.secondary, .14, c.surfaceContainer)
                    : c.onSurface.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(picked ? 16 : 20),
                border: Border.all(
                    color: c.secondary.withValues(alpha: picked ? .55 : 0),
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: dur,
                  curve: AppMotion.standard,
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: picked
                          ? c.secondary
                          : c.onSurface.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(picked ? 11 : 16)),
                  child: LineIcon(icon,
                      size: 17, color: picked ? c.surface : c.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                PageTitle(title, sub, size: 14),
              ]),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageRow(
        background: c.onSurface.withValues(alpha: .04),
        leading: PageSeal('book', accent: a.at(3)),
        title: s.t('На столе', 'In play'),
        subtitle: on
            ? s.t('Книга участвует в выборе заклинаний, снаряжения, рас и предысторий',
                'The book takes part in picking spells, gear, races and backgrounds')
            : s.t('Отключена, но не удалена: герои её не теряют, вернуть можно в любой момент',
                'Put away, not removed: heroes keep it, and it can come back at any time'),
        trailing: PageSwitch(value: on),
        toggled: on,
        onTap: () {
          pageTick();
          LibraryPolicy.setSrdEnabled(!on);
        },
      ),
      PageReveal(
        open: on,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: PageTitle(
                  s.t('Совпадения с вашими книгами', 'Overlaps with your books'),
                  shared == 0
                      ? s.t('Пока ничего не совпадает', 'Nothing overlaps yet')
                      : s.t(
                          'Есть и тут, и там: ${s.plural(shared, const ['запись', 'записи', 'записей'], const ['entry', 'entries'])}',
                          'In both: ${s.plural(shared, const ['entry', 'entries'], const ['entry', 'entries'])}')),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                choice(
                    LibraryOverlap.base,
                    'star',
                    s.t('Оставлять базовые', 'Keep the built-in'),
                    s.t('Ваши книги дополняют их', 'Your books add to them')),
                const SizedBox(width: 8),
                choice(
                    LibraryOverlap.mine,
                    'layers',
                    s.t('Оставлять мои', 'Keep mine'),
                    s.t('Ваши записи заменяют базовые', 'Your entries replace them')),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}
