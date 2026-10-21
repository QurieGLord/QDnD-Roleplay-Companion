import '../../../core/content/content_catalog.dart';
import '../../../core/progression/character_class_rules.dart';
import '../../../core/services/fc5_content_identity_service.dart';
import '../../../shared/widgets/content_variant_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/models/class_data.dart';
import '../../../core/progression/multiclass_rules.dart';
import '../../../core/services/character_data_service.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../core/ui/sheet_drag_region.dart';
import '../../../l10n/app_localizations.dart';
import '../../spell_almanac/spell_almanac_strings.dart';

class AdvancementTarget {
  const AdvancementTarget(this.data, {this.tableRuling = false});
  final ClassData data;
  final bool tableRuling;
}

Future<AdvancementTarget?> chooseAdvancementClass(
        BuildContext context, Character hero) =>
    showResponsiveSheet<AdvancementTarget>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ClassPicker(hero: hero));

class _ClassPicker extends StatelessWidget {
  const _ClassPicker({required this.hero});
  final Character hero;
  Future<void> _select(
      BuildContext context, ClassData data, bool existing) async {
    final unmet = MulticlassRules.unmet(hero, data.id),
        s = AlmanacStrings(context);
    if (!{'unknown', '2014'}.contains(data.rulesEdition)) {
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(s.t('Редакция правил', 'Rules edition')),
                  content: Text(s.t(
                      'Этот срез поддерживает развитие по правилам 2014. Герой не изменён.',
                      'This slice supports 2014 advancement. The character has not changed.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(s.t('Закрыть', 'Close')))
                  ]));
      return;
    }
    final known = data.rulesEdition == '2014';
    if (!existing && (!known || unmet.isNotEmpty)) {
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(s.t(
                      'Требования мультикласса', 'Multiclass prerequisites')),
                  content: Text(!known
                      ? s.t(
                          'Для этой книги нужны явные правила развития. Продолжить с ручной проверкой?',
                          'This book needs explicit progression rules. Continue with a rules review?')
                      : s.t(
                          'Характеристики не соответствуют требованиям классов: ${unmet.map((id) => CharacterDataService.getClassById(id)?.getName('ru') ?? id).join(', ')}. Мастер разрешил исключение?',
                          'Ability scores do not meet these class prerequisites: ${unmet.join(', ')}. Has your GM allowed an exception?')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(s.t('Назад', 'Back'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(s.t('Решение мастера', 'GM ruling')))
                  ]));
      if (ok != true || !context.mounted) return;
      Navigator.pop(context, AdvancementTarget(data, tableRuling: true));
      return;
    }
    Navigator.pop(context, AdvancementTarget(data));
  }

  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context),
        t = Theme.of(context).textTheme,
        c = Theme.of(context).colorScheme,
        l = AppLocalizations.of(context)!;
    final families = ContentCatalog(CharacterDataService.getAllClasses()
            .map(ContentRecords.characterClass))
        .families;
    final familyById = <String, ContentFamily<ClassData>>{};
    final ownedById = <String, String>{};
    final unavailable = <String>{};
    final classes = <ClassData>[];
    for (final family in families) {
      final owned = hero.classes
          .where((entry) =>
              family.records.any((r) => r.id == entry.id) ||
              family.aliases.contains(ContentRecord.normalize(
                  FC5ContentIdentityService.canonicalClassId(entry.name))))
          .firstOrNull;
      ClassData chosen;
      if (owned != null) {
        try {
          chosen = CharacterClassRules.resolve(owned).data;
        } catch (_) {
          chosen = family.records.first.entity;
          unavailable.add(chosen.id);
        }
      } else {
        final records = family.records.toList()
          ..sort((a, b) {
            if ((a.sourceId == null) != (b.sourceId == null)) {
              return a.sourceId == null ? -1 : 1;
            }
            return a.id.compareTo(b.id);
          });
        chosen = records.first.entity;
      }
      classes.add(chosen);
      familyById[chosen.id] = family;
      if (owned != null) ownedById[chosen.id] = owned.id;
    }
    classes.sort((a, b) {
      final ae = hero.classes.any((v) => v.id == a.id),
          be = hero.classes.any((v) => v.id == b.id);
      if (ae != be) return ae ? -1 : 1;
      return a
          .getName(s.ru ? 'ru' : 'en')
          .compareTo(b.getName(s.ru ? 'ru' : 'en'));
    });
    return DraggableScrollableSheet(
        initialChildSize: .85,
        minChildSize: .45,
        maxChildSize: .96,
        expand: false,
        builder: (context, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  SheetDragRegion(
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.t('Новый уровень', 'A new level'),
                                    style: t.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text(
                                    s.t('Продолжи развивать свой класс или выбери новое направление.',
                                        'Advance a class you already have, or choose a new direction.'),
                                    style: t.bodyMedium)
                              ]))),
                  for (final data in classes)
                    Builder(builder: (context) {
                      final entry = hero.classes
                          .where((e) => e.id == (ownedById[data.id] ?? data.id))
                          .firstOrNull;
                      final unmet = MulticlassRules.unmet(hero, data.id);
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CompanionSurface(
                              raised: entry != null,
                              quiet: entry == null,
                              contour: entry != null
                                  ? CompanionContour.focus
                                  : CompanionContour.soft,
                              onTap: () async {
                                if (unavailable.contains(data.id)) {
                                  await showDialog<void>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                              title: Text(s.t(
                                                  'Правила класса недоступны',
                                                  'Class rules unavailable')),
                                              content: Text(s.t(
                                                  'Сохранённые правила этого класса требуют восстановления. Подключи нужную книгу; текущие решения героя сохранены.',
                                                  'The saved rules for this class need recovery. Connect its book; your character’s choices are preserved.')),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: Text(s.t(
                                                        'Закрыть', 'Close')))
                                              ]));
                                  return;
                                }
                                final family = familyById[data.id]!;
                                var choice = data;
                                if (entry == null &&
                                    family.variants.length > 1) {
                                  final selected = await showContentVariantPicker<
                                          ClassData>(context, family,
                                      title: data.getName(s.ru ? 'ru' : 'en'),
                                      summary: (v) =>
                                          '${s.t('Правила', 'Rules')}: ${v.rulesEdition == 'unknown' ? s.t('редакция не указана', 'edition not stated') : v.rulesEdition} · ${s.t('кость хитов', 'Hit Die')} d${v.hitDie}',
                                      description: (v) =>
                                          v.getDescription(s.ru ? 'ru' : 'en'));
                                  if (selected == null || !context.mounted) {
                                    return;
                                  }
                                  choice = selected;
                                }
                                await _select(context, choice, entry != null);
                              },
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(data.getName(s.ru ? 'ru' : 'en'),
                                          style: t.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 5),
                                      Text(
                                          entry != null
                                              ? '${s.t('Уровень класса', 'Class level')} ${entry.level} → ${entry.level + 1}'
                                              : s.t('Новый класс · уровень 1',
                                                  'New class · level 1'),
                                          style: t.bodyMedium
                                              ?.copyWith(color: c.secondary)),
                                      if (entry == null &&
                                          familyById[data.id]!.records.length >
                                              1)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5),
                                            child: Text(
                                                contentFamilySummary(context,
                                                    familyById[data.id]!),
                                                style: t.labelSmall?.copyWith(
                                                    color:
                                                        c.onSurfaceVariant))),
                                      if (entry == null &&
                                          familyById[data.id]!.records.length ==
                                              1 &&
                                          data.sourceId != null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5),
                                            child: Text(
                                                contentSourceName(
                                                    context, data.sourceId),
                                                style: t.labelSmall?.copyWith(
                                                    color:
                                                        c.onSurfaceVariant))),
                                      if (entry == null && unmet.isNotEmpty)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5),
                                            child: Text(
                                                s.t('Нужны характеристики от 13',
                                                    'Requires ability scores of 13 or higher'),
                                                style: t.bodySmall?.copyWith(
                                                    color:
                                                        c.onSurfaceVariant))),
                                      if (entry == null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5),
                                            child: Text(
                                                '${s.t('Кость хитов', 'Hit Die')}: d${data.hitDie}',
                                                style: t.labelSmall)),
                                    ])),
                                const SizedBox(width: 10),
                                Icon(
                                    entry != null
                                        ? Icons.arrow_forward_rounded
                                        : Icons.add_rounded,
                                    color: c.secondary)
                              ])));
                    }),
                  Text(l.advancementRulesTitle, style: t.labelMedium),
                  const SizedBox(height: 6),
                  Text(
                      s.t('Начальные спасброски и снаряжение повторно не выдаются.',
                          'Starting saving throws and equipment are not granted again.'),
                      style: t.bodySmall),
                ]));
  }
}
