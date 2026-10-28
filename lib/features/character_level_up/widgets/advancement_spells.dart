import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/spell.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/search/journal_search.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/ui/expressive_kit.dart';
import '../../../core/ui/page_kit.dart';
import '../../../core/ui/sheet_drag_region.dart';
import '../../../shared/widgets/spell_details_sheet.dart';
import 'advancement_climb.dart';

/// Spells in the wave 6 language (`.spl` of the prototype): a circle badge,
/// the name and school, the «i» and a tick that squares when chosen. A long
/// press or the «i» opens the spell's own sheet.

/// A spell's school in the reader's language.
String spellSchool(AppLocalizations l, String school) =>
    switch (school.toLowerCase()) {
      'abjuration' => l.schoolAbjuration,
      'conjuration' => l.schoolConjuration,
      'divination' => l.schoolDivination,
      'enchantment' => l.schoolEnchantment,
      'evocation' => l.schoolEvocation,
      'illusion' => l.schoolIllusion,
      'necromancy' => l.schoolNecromancy,
      'transmutation' => l.schoolTransmutation,
      _ => school,
    };

/// «Заговор · Воплощение», «1-й круг · Ограждение».
String spellLine(BuildContext context, Spell spell) {
  final tr = Tr(context);
  final circle = spell.level == 0
      ? tr.t('Заговор', 'Cantrip')
      : tr.t('${spell.level}-й круг', 'Circle ${spell.level}');
  return '$circle · ${spellSchool(AppLocalizations.of(context)!, spell.school)}';
}

/// The accent of magic choices (a5 of the prototype).
Color spellAccent(BuildContext context) => AppAccents.of(context).at(5);

void showSpellDetails(BuildContext context, Spell spell) =>
    showResponsiveSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SpellDetailsSheet(spell: spell));

class AdvancementSpellRow extends StatelessWidget {
  const AdvancementSpellRow(
      {super.key,
      required this.spell,
      required this.selected,
      required this.onTap,
      this.subtitle,
      this.dim = false,
      this.accent});
  final Spell spell;
  final bool selected, dim;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tr = Tr(context);
    final a = accent ?? spellAccent(context);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final row = AnimatedContainer(
      duration: dur,
      curve: AppMotion.snappyCurve,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(selected ? 14 : 18),
        color: selected ? pageMix(a, .12, c.surfaceContainerLow) : c.surfaceContainerLow,
        border: Border.all(
            color: selected ? a.withValues(alpha: .5) : Colors.transparent,
            width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: pageMix(a, .18, c.surfaceContainer),
              borderRadius: BorderRadius.circular(10)),
          child: Text(spell.level == 0 ? tr.t('з', 'c') : '${spell.level}',
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: a)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(spell.getName(tr.ru ? 'ru' : 'en'),
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        AdvancementInfoButton(onTap: () => showSpellDetails(context, spell)),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: dur,
          curve: AppMotion.snappyCurve,
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? a : Colors.transparent,
            borderRadius: BorderRadius.circular(selected ? 7 : 12),
            border: Border.all(
                color: selected ? Colors.transparent : c.outline, width: 2),
          ),
          child: AnimatedScale(
            duration: dur,
            curve: AppMotion.snappyCurve,
            scale: selected ? 1 : 0,
            child: Icon(Icons.check_rounded, size: 15, color: c.surface),
          ),
        ),
      ]),
    );
    return AdvancementHold(
      accent: a,
      radius: selected ? 14 : 18,
      onHold: () => showSpellDetails(context, spell),
      child: Semantics(
        selected: selected,
        button: true,
        child: Pressable(
          onTap: dim || onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          scale: .985,
          child: AnimatedOpacity(
              duration: AppMotion.of(context, AppMotion.medium),
              opacity: dim ? .4 : 1,
              child: SelectPulse(on: selected, child: row)),
        ),
      ),
    );
  }
}

/// A group of spells to pick from: a title with the count as a pill, the
/// first few rows, and every spell — searchable, by circle — in a sheet.
class AdvancementSpellList extends StatelessWidget {
  const AdvancementSpellList(
      {super.key,
      required this.title,
      required this.spells,
      required this.selected,
      required this.limit,
      required this.onToggle,
      this.note,
      this.school,
      this.shown = 6});
  final String title;
  final String? note;
  final List<Spell> spells;
  final Set<String> selected;

  /// How many to pick; 0 — as many as wanted.
  final int limit;
  final ValueChanged<String> onToggle;
  final String Function(Spell spell)? school;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tr = Tr(context);
    final a = spellAccent(context);
    final complete = limit > 0 && selected.length >= limit;
    final visible = [
      for (final (i, s) in spells.indexed)
        if (i < shown || selected.contains(s.id)) s
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
          ),
          AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.medium),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: complete ? a : c.onSurface.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(complete ? 10 : 16)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (complete) ...[
                Icon(Icons.check_rounded, size: 15, color: pageOnAccent(c)),
                const SizedBox(width: 4),
              ],
              RollingNumber(selected.length,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: complete ? pageOnAccent(c) : c.onSurface)),
              Text(limit > 0 ? ' / $limit' : '',
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: complete ? pageOnAccent(c) : c.onSurface)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Text(
            note ??
                (limit > 0
                    ? tr.t('Сверх лимита новый выбор сменит самый ранний. Удержание — описание.',
                        'Over the limit a new pick replaces the earliest. Hold for details.')
                    : tr.t('Выбор необязателен. Удержание — описание.',
                        'Picking is optional. Hold for details.')),
            style: TextStyle(fontSize: 13, height: 1.35, color: c.onSurfaceVariant)),
      ),
      for (final s in visible)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: AdvancementSpellRow(
            key: ValueKey('spell-${s.id}'),
            spell: s,
            selected: selected.contains(s.id),
            subtitle: school?.call(s),
            onTap: () => onToggle(s.id),
          ),
        ),
      if (spells.length > visible.length)
        Align(
          alignment: Alignment.centerLeft,
          child: Pressable(
            onTap: () async {
              final result = await showSpellChooser(context,
                  title: title,
                  spells: spells,
                  selected: selected,
                  limit: limit,
                  school: school);
              if (result == null) return;
              // Take back what was dropped first, so a new pick never pushes
              // out an old one that stays.
              for (final id in selected.difference(result)) {
                onToggle(id);
              }
              for (final id in result.difference(selected)) {
                onToggle(id);
              }
            },
            haptic: true,
            scale: .96,
            child: Container(
              height: 38,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
              decoration: BoxDecoration(
                  color: a.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(19)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                LineIcon('magic', size: 16, color: a),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(tr.t('Все заклинания · ${spells.length}', 'All spells · ${spells.length}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: c.onSurface)),
                ),
                const SizedBox(width: 4),
                LineIcon('forward', size: 14, color: c.onSurfaceVariant),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Every spell of a choice in a sheet: search, circles as capsules, rows,
/// and a confirm button held at the bottom. Picks are a draft until
/// «Готово»; the sheet then closes and returns them (null when dismissed).
Future<Set<String>?> showSpellChooser(BuildContext context,
    {required String title,
    required List<Spell> spells,
    required Set<String> selected,
    required int limit,
    String Function(Spell spell)? school}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final c = Theme.of(context).colorScheme;
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surfaceContainer,
    barrierColor: const Color(0x730A0806),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 420),
            reverseDuration: Duration(milliseconds: 220)),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
    builder: (sheet) => _SpellSheet(
        title: title,
        spells: spells,
        initial: selected,
        limit: limit,
        school: school),
  );
}

class _SpellSheet extends StatefulWidget {
  const _SpellSheet(
      {required this.title,
      required this.spells,
      required this.initial,
      required this.limit,
      this.school});
  final String title;
  final List<Spell> spells;
  final Set<String> initial;
  final int limit;
  final String Function(Spell spell)? school;
  @override
  State<_SpellSheet> createState() => _SpellSheetState();
}

class _SpellSheetState extends State<_SpellSheet> {
  late final Set<String> _picked = {...widget.initial};
  String _query = '';
  int? _circle;

  void _toggle(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else {
        // Over the limit the earliest pick gives way.
        if (widget.limit > 0 && _picked.length >= widget.limit) {
          _picked.remove(_picked.first);
        }
        _picked.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr(context);
    final c = Theme.of(context).colorScheme;
    final a = spellAccent(context);
    final locale = tr.ru ? 'ru' : 'en';
    final search = JournalSearch(_query);
    final circles = widget.spells.map((s) => s.level).toSet().toList()..sort();
    final shown = widget.spells
        .where((s) =>
            (_circle == null || s.level == _circle) &&
            search.matches([s.getName(locale), s.nameRu, s.nameEn]))
        .toList()
      ..sort((x, y) => x.level != y.level
          ? x.level.compareTo(y.level)
          : x.getName(locale).compareTo(y.getName(locale)));
    final complete = widget.limit > 0 && _picked.length >= widget.limit;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    Widget chip(String label, int? value) {
      final on = _circle == value;
      return Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _circle = value);
        },
        scale: .95,
        selected: on,
        child: AnimatedContainer(
          duration: dur,
          curve: AppMotion.snappyCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
              color: on ? c.secondary : c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(on ? 12 : 18)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? c.surface : c.onSurface)),
        ),
      );
    }

    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    // The handle and the confirm button float over the list: no strip of
    // sheet colour behind them, the rows scroll on beneath.
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Stack(children: [
        Positioned.fill(
          child: SheetTopFade(
           child: ListView(
            padding: EdgeInsets.fromLTRB(18, SheetGrab.inset, 18, 54 + 16 + 40 + bottom),
            children: [
              PageCap(widget.title, accent: a),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Text(tr.t('Все заклинания', 'All spells'),
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 26,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.52,
                          color: c.onSurface)),
                ),
                // The count rolls as spells are picked.
                RollingNumber(_picked.length,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: complete ? a : c.onSurface)),
                if (widget.limit > 0)
                  Text(' / ${widget.limit}',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: c.onSurfaceVariant)),
              ]),
              const SizedBox(height: 14),
              TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: tr.t('Найти заклинание', 'Find a spell'),
                  prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: LineIcon('search', size: 20, color: c.onSurfaceVariant)),
                  filled: true,
                  fillColor: c.surfaceContainerLow,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: a.withValues(alpha: .5))),
                ),
              ),
              if (circles.length > 1) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  chip(tr.t('Все', 'All'), null),
                  for (final circle in circles)
                    chip(
                        circle == 0
                            ? tr.t('Заговоры', 'Cantrips')
                            : tr.t('$circle-й круг', 'Circle $circle'),
                        circle),
                ]),
              ],
              const SizedBox(height: 12),
              // A new filter brings its rows in as a short wave.
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.medium),
                child: Column(
                  key: ValueKey('$_circle|$_query'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, s) in shown.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: PageEntrance(
                          index: i,
                          child: AdvancementSpellRow(
                            key: ValueKey('chooser-${s.id}'),
                            spell: s,
                            selected: _picked.contains(s.id),
                            subtitle: widget.school?.call(s),
                            onTap: () => _toggle(s.id),
                          ),
                        ),
                      ),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(tr.t('Ничего не найдено', 'Nothing found'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
        const Positioned(left: 0, right: 0, top: 0, child: SheetGrab()),
        // The confirm button stays at hand; it fills once the choice is whole.
        Positioned(
          left: 14,
          right: 14,
          bottom: 14 + bottom,
          // A glass island, as the journal's dock, holds the confirm.
          child: FloatingIsland(
           child: Pressable(
            key: const ValueKey('spell-chooser-done'),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(_picked);
            },
            scale: .97,
            child: AnimatedContainer(
              duration: dur,
              curve: AppMotion.snappyCurve,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: complete || widget.limit == 0
                      ? c.primary
                      : c.secondaryContainer,
                  borderRadius: BorderRadius.circular(complete ? 18 : 26)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    widget.limit > 0
                        ? tr.t('Готово · ${_picked.length} из ${widget.limit}',
                            'Done · ${_picked.length} of ${widget.limit}')
                        : tr.t('Готово · ${_picked.length}', 'Done · ${_picked.length}'),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: complete || widget.limit == 0
                            ? c.onPrimary
                            : c.onSecondaryContainer)),
                const SizedBox(width: 8),
                LineIcon('check',
                    size: 18,
                    color: complete || widget.limit == 0
                        ? c.onPrimary
                        : c.onSecondaryContainer),
              ]),
            ),
           ),
          ),
        ),
      ]),
    );
  }
}
