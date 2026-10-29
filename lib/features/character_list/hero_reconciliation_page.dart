import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content/content_catalog.dart';
import '../../core/content/hero_reconciliation.dart';
import '../../core/models/character.dart';
import '../../core/models/class_data.dart';
import '../../core/models/spell.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/page_kit.dart';
import '../../shared/widgets/content_variant_picker.dart';
import '../character_level_up/widgets/advancement_climb.dart'
    show AdvancementPick, advancementGist;
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import '../journal/journal_kit.dart';
import 'hero_transfer.dart' show HeroBadge;

/// «Сверка с библиотеками» — C03, right after an FC5 hero is brought in.
/// Only the entries the libraries know in several differing versions are
/// listed; each already refers to its lead, a tap lists the versions. Leaving
/// without «Принять» keeps the leads, which are saved already.
Future<void> showHeroReconciliation(
        BuildContext context, Character hero, List<HeroAmbiguity> found) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HeroReconciliationPage(hero: hero, found: found)));

class HeroReconciliationPage extends StatefulWidget {
  const HeroReconciliationPage(
      {super.key, required this.hero, required this.found, this.write});
  final Character hero;
  final List<HeroAmbiguity> found;

  /// Where the choices are saved (the store by default; tests pass their own).
  final Future<void> Function(Character)? write;
  @override
  State<HeroReconciliationPage> createState() => _HeroReconciliationPageState();
}

class _HeroReconciliationPageState extends State<HeroReconciliationPage> {
  final _picks = <HeroAmbiguity, ContentRecord>{};
  bool _busy = false;

  ContentRecord _shown(HeroAmbiguity a) => _picks[a] ?? a.chosen;

  Future<void> _change(HeroAmbiguity a) async {
    final tr = Tr(context);
    final locale = tr.ru ? 'ru' : 'en';
    final shown = _shown(a);
    final picked = await showContentVariantPicker<dynamic>(context, a.family,
        title: _name(shown, locale),
        summary: (v) => _summary(tr, v),
        description: (v) => v is Spell
            ? v.getDescription(locale)
            : advancementGist((v as ClassData).getDescription(locale), max: 220),
        preferredIds: {shown.id},
        preferredLabel: tr.t('Выбрано сейчас', 'Chosen now'));
    if (picked == null || !mounted) return;
    final record = a.family.records.firstWhere((r) => identical(r.entity, picked));
    HapticFeedback.selectionClick();
    setState(() {
      if (record.id == a.chosen.id && record.sourceId == a.chosen.sourceId) {
        _picks.remove(a);
      } else {
        _picks[a] = record;
      }
    });
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final tr = Tr(context);
    try {
      if (_picks.isNotEmpty) {
        await HeroReconciliation.apply(
            widget.hero, [for (final e in _picks.entries) (e.key, e.value)],
            write: widget.write);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.error(
          context,
          tr.t('Не удалось сохранить выбор — герой остался с основными версиями',
              'Could not save the choice — the hero keeps the lead versions'));
    }
  }

  static String _name(ContentRecord r, String locale) {
    final e = r.entity;
    if (e is Spell) return e.getName(locale);
    return (e as ClassData).getName(locale);
  }

  static String _summary(Tr tr, dynamic v) {
    if (v is Spell) {
      return [
        v.level == 0 ? tr.t('заговор', 'cantrip') : tr.t('${v.level}-й круг', 'level ${v.level}'),
        if (v.castingTime.isNotEmpty) v.castingTime,
        if (v.range.isNotEmpty) v.range,
      ].join(' · ');
    }
    final c = v as ClassData;
    return [
      tr.t('Правила: ', 'Rules: ') +
          (c.rulesEdition == 'unknown'
              ? tr.t('редакция не указана', 'edition not stated')
              : c.rulesEdition),
      tr.t('к${c.hitDie}', 'd${c.hitDie}'),
      tr.t('подклассов: ${c.subclasses.length}', 'subclasses: ${c.subclasses.length}'),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr(context);
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final locale = tr.ru ? 'ru' : 'en';
    final hero = widget.hero;
    final top = MediaQuery.paddingOf(context).top;
    final classes =
        widget.found.where((x) => x.kind == ContentKind.characterClass).toList();
    final spells = widget.found.where((x) => x.kind == ContentKind.spell).toList();
    final heroAccent =
        a.forClass(hero.classes.isEmpty ? hero.characterClass : hero.classes.first.id);
    var index = 0;

    Widget entry(HeroAmbiguity x) {
      final shown = _shown(x);
      final changed = _picks.containsKey(x);
      final cls = shown.entity is ClassData ? shown.entity as ClassData : null;
      final name = _name(shown, locale);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PageEntrance(
          index: index++,
          child: AdvancementPick(
            key: ValueKey('reconcile-${x.kind.name}-${x.original}'),
            selected: changed,
            title: name,
            subtitle: [
              if (ContentRecord.normalize(x.original) != ContentRecord.normalize(name))
                tr.t('в файле: «${x.original}»', 'in the file: “${x.original}”'),
              _summary(tr, shown.entity),
            ].join(' · '),
            icon: cls != null ? classSigil(cls.id) : 'spark',
            accent: cls != null ? classAccent(context, cls.id) : a.at(4),
            chips: [
              tr.plural(x.family.variants.length, const ['версия', 'версии', 'версий'],
                  const ['version', 'versions']),
              if (changed) tr.t('ваш выбор', 'your choice') else tr.t('основная', 'lead'),
            ],
            source: contentSourceName(context, shown.sourceId),
            onTap: _busy ? null : () => _change(x),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(children: [
        FloatingFooter(
          inset: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          action: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey('hero-reconcile-accept'),
              onPressed: _busy ? null : _accept,
              icon: const LineIcon('check', size: 20),
              label: Text(_picks.isEmpty
                  ? tr.t('Принять основные', 'Keep the lead versions')
                  : tr.t('Принять · ', 'Accept · ') +
                      tr.plural(_picks.length,
                          const ['изменение', 'изменения', 'изменений'],
                          const ['change', 'changes'])),
            ),
          ),
          child: ListView(
            key: const ValueKey('hero-reconcile-scroll'),
            padding: EdgeInsets.fromLTRB(
                20, top + JournalTopBar.height + 8, 20, FloatingFooter.room(context)),
            children: [
              Row(children: [
                HeroBadge(name: hero.name, accent: heroAccent, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    PageCap(tr.t('Сверка с библиотеками', 'Matching the libraries'),
                        accent: heroAccent),
                    const SizedBox(height: 4),
                    Text(hero.name,
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: c.onSurface)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Text(
                  tr.t(
                      'Эти записи есть в ваших библиотеках в нескольких версиях. Герою уже назначены основные — по настройке полки. Нажмите запись, чтобы выбрать другую версию.',
                      'Your libraries hold these in several versions. The hero already has the lead ones, as your shelf setting picks them. Tap an entry to choose another version.'),
                  style: TextStyle(fontSize: 14, height: 1.4, color: c.onSurfaceVariant)),
              const SizedBox(height: 18),
              if (classes.isNotEmpty) ...[
                PageSection(tr.t('Класс', 'Class')),
                const SizedBox(height: 10),
                for (final x in classes) entry(x),
                const SizedBox(height: 10),
              ],
              if (spells.isNotEmpty) ...[
                PageSection(tr.t('Заклинания', 'Spells')),
                const SizedBox(height: 10),
                for (final x in spells) entry(x),
              ],
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: JournalTopBar(
            titled: true,
            title: tr.t('Сверка', 'Matching'),
            leading: JournalRound(
                icon: 'x',
                label: tr.t('Закрыть', 'Close'),
                onTap: _busy ? null : () => Navigator.of(context).pop()),
          ),
        ),
      ]),
    );
  }
}
