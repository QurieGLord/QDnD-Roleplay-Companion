import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../core/models/character.dart';
import '../../../core/progression/multiclass_rules.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/page_kit.dart';
import '../../character_creation/prologue.dart' show abilityName, showClassInfo;
import '../../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import '../widgets/advancement_climb.dart';
import '../widgets/advancement_layout.dart';
import '../widgets/class_advancement_picker.dart';
import '../../../shared/widgets/content_variant_picker.dart' show contentSourceName;

/// «В какой класс?» — the first step of a level (wave 6 prototype, `cls`):
/// continue a class the hero has, or open a new one. Every new class says
/// what it asks for and what the hero has; one the hero cannot take yet is
/// set aside, and a tap on it asks whether the GM allows an exception.
class ClassChoiceStep extends StatelessWidget {
  const ClassChoiceStep(
      {super.key,
      required this.hero,
      required this.selectedId,
      required this.onChoose,
      required this.onNext});
  final Character hero;

  /// The class this level goes to now.
  final String selectedId;
  final ValueChanged<AdvancementTarget> onChoose;
  final VoidCallback onNext;

  /// «Ловкость 13 ✓ (15)», «Сила или Ловкость 13 · у героя 11».
  static List<(String, bool)> requirements(
      AppLocalizations l, Tr tr, Character hero, String classId) {
    final rule = MulticlassRules.prerequisites[classId];
    if (rule == null) return const [];
    final scores = hero.abilityScores.toJson();
    return [
      for (final group in rule)
        () {
          final best = group
              .map((a) => scores[a] as int)
              .reduce((a, b) => a > b ? a : b);
          final ok = best >= 13;
          final names = group.map((a) => abilityName(l, a)).join(tr.t(' или ', ' or '));
          return (
            ok
                ? '$names 13 ✓ ($best)'
                : tr.t('$names 13 · у героя $best', '$names 13 · hero has $best'),
            ok
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr(context);
    final l = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final locale = tr.ru ? 'ru' : 'en';
    final options = advancementClassOptions(hero, locale);
    final own = options.where((o) => o.owned).toList();
    final fresh = options.where((o) => !o.owned).toList();
    // Taking a new class also asks the classes the hero already has.
    final ownUnmet = [
      for (final o in own)
        for (final r in requirements(l, tr, hero, o.data.id))
          if (!r.$2) '${o.data.getName(locale)}: ${r.$1}'
    ];
    Future<void> choose(AdvancementClassOption option) async {
      final target = await resolveAdvancementClass(context, hero, option);
      if (target != null) onChoose(target);
    }

    Widget card(AdvancementClassOption o, int i) {
      final cls = o.data;
      final accent = classAccent(context, cls.id);
      final reqs = o.owned ? const <(String, bool)>[] : requirements(l, tr, hero, cls.id);
      final unmet = !o.owned && (reqs.any((r) => !r.$2) || ownUnmet.isNotEmpty);
      final subtitle = o.unavailable
          ? tr.t('Правила класса нужно восстановить', 'The class rules need recovery')
          : o.owned
              ? tr.t('Продолжить свой класс · уровень ${o.entry!.level} → ${o.entry!.level + 1}',
                  'Continue your class · level ${o.entry!.level} → ${o.entry!.level + 1}')
              : reqs.isEmpty
                  ? tr.t('Новый класс · книга не указывает требований',
                      'New class · the book states no prerequisites')
                  : unmet
                      ? tr.t('Нужно: ', 'Needs: ') +
                          [
                            for (final r in reqs)
                              if (!r.$2) r.$1,
                            ...ownUnmet,
                          ].join(' · ')
                      : tr.t('Новый класс · ', 'New class · ') +
                          reqs.map((r) => r.$1).join(' · ');
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PageEntrance(
          index: i,
          child: AdvancementPick(
            key: ValueKey('advancement-class-${cls.id}'),
            selected: cls.id == selectedId,
            blocked: unmet || o.unavailable,
            // The display face has no arrow: the jump reads in the line below.
            title: o.owned
                ? tr.t('${cls.getName(locale)} · ${o.entry!.level + 1}-й уровень',
                    '${cls.getName(locale)} · level ${o.entry!.level + 1}')
                : tr.t('${cls.getName(locale)} · 1-й уровень',
                    '${cls.getName(locale)} · level 1'),
            subtitle: subtitle,
            icon: classSigil(cls.id),
            accent: accent,
            chips: [
              '${tr.t('к', 'd')}${cls.hitDie}',
              if (cls.primaryAbilities.isNotEmpty)
                cls.primaryAbilities.map((a) => abilityName(l, a)).join(', '),
            ],
            source: !o.owned && cls.sourceId != null
                ? contentSourceName(context, cls.sourceId)
                : null,
            onTap: cls.id == selectedId ? null : () => choose(o),
            onInfo: () => showClassInfo(context, cls),
          ),
        ),
      );
    }

    return Column(children: [
      AdvancementStepList(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, 20 + AdvancementDockScope.inset(context)),
          children: [
            AdvancementHeading(
                title: tr.t('В какой класс?', 'Which class?'),
                subtitle: tr.t(
                    'Продолжить свой класс или открыть новый. Удержание карточки — полное описание класса.',
                    'Continue your class or open a new one. Hold a card for the whole class.')),
            _Group(tr.t('Ваш класс', 'Your class'),
                own.length > 1 ? tr.t('${own.length} класса', '${own.length} classes') : null),
            for (final (i, o) in own.indexed) card(o, i),
            _Group(tr.t('Новый класс', 'A new class'), tr.t('мультикласс', 'multiclass')),
            for (final (i, o) in fresh.indexed) card(o, own.length + i),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LineIcon('info', size: 17, color: c.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      tr.t(
                          'Требования мультикласса проверяются по характеристикам героя — и для нового класса, и для ваших. Начальные спасброски и снаряжение второй раз не выдаются. Исключение может разрешить мастер.',
                          'Multiclass prerequisites are checked against the hero’s scores — for the new class and for yours. Starting saving throws and equipment are not granted again. The GM may allow an exception.'),
                      style: TextStyle(
                          fontSize: 13, height: 1.4, color: c.onSurfaceVariant)),
                ),
              ]),
            ),
          ]),
      AdvancementFooter(
          label: l.continueLabel,
          onPressed: () {
            HapticFeedback.selectionClick();
            onNext();
          }),
    ]);
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.note);
  final String title;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
        ),
        if (note != null)
          Text(note!, style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
      ]),
    );
  }
}
