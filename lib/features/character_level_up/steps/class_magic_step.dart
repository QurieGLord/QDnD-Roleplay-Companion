import 'package:flutter/material.dart';
import '../../../core/models/spell.dart';
import '../../../core/progression/spell_learning_plan.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../../spell_almanac/spell_almanac_strings.dart';
import '../widgets/advancement_layout.dart';
import '../widgets/advancement_climb.dart';
import '../widgets/advancement_spells.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/ui/expressive_kit.dart';
import '../../../core/ui/page_kit.dart';

class ClassMagicStep extends StatelessWidget {
  const ClassMagicStep(
      {super.key,
      required this.plan,
      required this.selected,
      required this.onChanged,
      required this.onNext,
      this.replaceOld,
      this.replaceNew,
      required this.onReplace,
      this.manualCounts,
      required this.onManualCounts});
  final SpellLearningPlan plan;
  final Map<String, List<String>> selected;
  final ValueChanged<Map<String, List<String>>> onChanged;
  final VoidCallback onNext;
  final String? replaceOld, replaceNew;
  final void Function(String?, String?) onReplace;
  final Map<String, int>? manualCounts;
  final ValueChanged<Map<String, int>> onManualCounts;
  String _name(SpellLearningKind kind, AlmanacStrings s) => switch (kind) {
        SpellLearningKind.normal => s.t('Новые заклинания', 'New spells'),
        SpellLearningKind.cantrip => s.t('Новые заговоры', 'New cantrips'),
        SpellLearningKind.secret => s.t('Тайны магии', 'Magical Secrets'),
        SpellLearningKind.arcanum =>
          s.t('Таинственный арканум', 'Mystic Arcanum'),
        SpellLearningKind.masteryOne =>
          s.t('Мастерство · первый круг', 'Mastery · first circle'),
        SpellLearningKind.masteryTwo =>
          s.t('Мастерство · второй круг', 'Mastery · second circle'),
        SpellLearningKind.signature =>
          s.t('Фирменные заклинания', 'Signature Spells'),
        SpellLearningKind.ritualBook =>
          s.t('Книга ритуалов', 'Book of rituals'),
        SpellLearningKind.tome =>
          s.t('Заговоры Договора гримуара', 'Pact of the Tome cantrips'),
        SpellLearningKind.unrestricted =>
          s.t('Заклинание любой школы', 'Spell from any school')
      };
  // Every option in a sheet of spell rows; «Готово» applies the picks.
  Future<void> _pick(BuildContext context, SpellLearningChoice choice) async {
    final result = await showSpellChooser(context,
        title: _name(choice.kind, AlmanacStrings(context)),
        spells: choice.options,
        selected: {...?selected[choice.key]},
        limit: choice.count,
        school: (spell) => spellLine(context, spell));
    if (result != null) onChanged({...selected, choice.key: result.toList()});
  }

  Future<String?> _single(BuildContext context, String title,
      List<Spell> spells, String? initial) async {
    final result = await showSpellChooser(context,
        title: title,
        spells: spells,
        selected: {if (initial != null) initial},
        limit: 1,
        school: (spell) => spellLine(context, spell));
    return result == null ? initial : result.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context),
        l = AppLocalizations.of(context)!,
        t = Theme.of(context).textTheme,
        c = Theme.of(context).colorScheme;
    bool ready = !plan.needsManualCounts;
    String? issue;
    try {
      plan.validate(selected, replaceOld: replaceOld, replaceNew: replaceNew);
    } catch (_) {
      ready = false;
      issue = s.t(
          'Заверши выборы магии. Одно заклинание нельзя выбрать дважды.',
          'Finish the spell choices. A spell cannot fill two learning choices.');
    }
    return Column(children: [
      AdvancementStepList(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, 20 + AdvancementDockScope.inset(context)),
              children: [
        AdvancementHeading(
            title: s.t('Магия класса', 'Class spellcasting'),
            subtitle: s.t(
                'Изучение относится к уровню этого класса. Общие ячейки не открывают новые круги.',
                'Learning follows this class level. Shared slots do not unlock higher spell circles.')),
        if (plan.needsManualCounts || manualCounts != null)
          CompanionSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(s.t('Выборы по твоей книге', 'Choices from your book'),
                    style: t.titleMedium),
                const SizedBox(height: 8),
                Text(s.t(
                    'В книге нет полной таблицы изучения. Укажи положенный прирост; эти значения применятся только к этому повышению.',
                    'This book has no complete learning table. Enter the choices granted for this advancement.')),
                const SizedBox(height: 12),
                for (final field in [
                  ('normal', s.t('Новые заклинания', 'New spells')),
                  ('cantrip', s.t('Новые заговоры', 'New cantrips'))
                ])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                          initialValue: '${manualCounts?[field.$1] ?? 0}',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: field.$2),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n >= 0 && n <= 100) {
                              onManualCounts({
                                ...?manualCounts,
                                field.$1: n,
                                'confirmed': 0
                              });
                            }
                          })),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.t('Выбирать из всего Альманаха',
                        'Choose from the entire Almanac')),
                    value: manualCounts?['all'] == 1,
                    onChanged: (v) => onManualCounts({
                          ...?manualCounts,
                          'all': v == true ? 1 : 0,
                          'confirmed': 0
                        })),
                FilledButton.tonal(
                    onPressed: () => onManualCounts({
                          'normal': manualCounts?['normal'] ?? 0,
                          'cantrip': manualCounts?['cantrip'] ?? 0,
                          'all': manualCounts?['all'] ?? 0,
                          'confirmed': 1
                        }),
                    child: Text(
                        s.t('Применить выборы книги', 'Use these choices'))),
              ])),
        for (final choice in plan.choices)
          Builder(builder: (context) {
            // The count of the prototype (`.mbar`): how many are picked of
            // how many this level teaches; the picked ones as capsules.
            final magic = AppAccents.of(context).at(5);
            final picked = [
              for (final id in selected[choice.key] ?? const <String>[])
                choice.options
                        .where((v) => v.id == id)
                        .firstOrNull
                        ?.getName(s.ru ? 'ru' : 'en') ??
                    id
            ];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Pressable(
                onTap: () => _pick(context, choice),
                haptic: true,
                scale: .985,
                // Once the choice is whole the card warms, squares its
                // corners and takes a thin ring.
                child: AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.snappySettle),
                  curve: AppMotion.snappyCurve,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                      color: pageMix(
                          magic,
                          picked.length >= choice.count ? .16 : .1,
                          c.surfaceContainerLow),
                      border: Border.all(
                          color: picked.length >= choice.count
                              ? magic.withValues(alpha: .5)
                              : Colors.transparent,
                          width: 1.5),
                      borderRadius: BorderRadius.circular(
                          picked.length >= choice.count ? 16 : 22)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          RollingNumber(picked.length,
                              style: TextStyle(
                                  fontFamily: AppType.display,
                                  fontSize: 28,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                  color: c.onSurface)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${s.t('из', 'of')} ${choice.count} · ${_name(choice.kind, s)}',
                                      style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: c.onSurface)),
                                  const SizedBox(height: 2),
                                  AnimatedSwitcher(
                                    duration: AppMotion.of(
                                        context, AppMotion.medium),
                                    child: Text(
                                        key: ValueKey(picked.isEmpty),
                                        picked.isEmpty
                                            ? s.t('Коснитесь, чтобы выбрать',
                                                'Tap to choose')
                                            : s.t('Коснитесь, чтобы изменить',
                                                'Tap to change'),
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: c.onSurfaceVariant)),
                                  ),
                                ]),
                          ),
                          LineIcon('forward',
                              size: 18, color: c.onSurfaceVariant),
                        ]),
                        // The picked spells arrive as capsules; the card
                        // grows to hold them.
                        SoftSize(
                          duration:
                              AppMotion.of(context, AppMotion.gentleSettle),
                          curve: AppMotion.standard,
                          alignment: Alignment.topLeft,
                          child: picked.isEmpty
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final (i, name)
                                              in picked.indexed)
                                            _Arrive(
                                                key: ValueKey(name),
                                                delay: i,
                                                child: AdvancementFact(name,
                                                    accent: magic,
                                                    icon: 'magic')),
                                        ]),
                                  ),
                                ),
                        ),
                        if (choice.allowedSchools.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                  s.t('Школы подкласса; свободных выборов другой школы: ${choice.freeSchoolChoices}.',
                                      'Subclass schools; unrestricted choices: ${choice.freeSchoolChoices}.'),
                                  style: t.bodySmall)),
                        if (choice.options.length < choice.count)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  s.t('В библиотеке недостаточно подходящих заклинаний.',
                                      'The library does not contain enough eligible spells.'),
                                  style:
                                      t.bodySmall?.copyWith(color: c.error))),
                      ]),
                ),
              ),
            );
          }),
        if (plan.replaceable.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CompanionSurface(
                  quiet: true,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t('Замена заклинания', 'Replace a spell'),
                            style: t.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                            s.t('По желанию: забудь одно известное заклинание и изучи новое из списка класса.',
                                'Optional: replace one known spell with another from your class list.'),
                            style: t.bodySmall),
                        const SizedBox(height: 10),
                        OutlinedButton(
                            onPressed: () async {
                              final id = await _single(
                                  context,
                                  s.t('Что заменить', 'Spell to replace'),
                                  plan.replaceable,
                                  replaceOld);
                              if (id != null) onReplace(id, null);
                            },
                            child: Text(replaceOld == null
                                ? s.t('Выбрать известное', 'Choose known spell')
                                : plan.replaceable
                                    .where((s) => s.id == replaceOld)
                                    .first
                                    .getName(s.ru ? 'ru' : 'en'))),
                        if (replaceOld != null)
                          OutlinedButton(
                              onPressed: () async {
                                final id = await _single(
                                    context,
                                    s.t('Новое заклинание',
                                        'Replacement spell'),
                                    plan.replacementsFor(replaceOld),
                                    replaceNew);
                                if (id != null) onReplace(replaceOld, id);
                              },
                              child: Text(replaceNew == null
                                  ? s.t('Выбрать замену', 'Choose replacement')
                                  : plan.replacementOptions
                                      .where((s) => s.id == replaceNew)
                                      .first
                                      .getName(s.ru ? 'ru' : 'en'))),
                        if (replaceOld != null)
                          TextButton(
                              onPressed: () => onReplace(null, null),
                              child: Text(s.t('Оставить как есть',
                                  'Keep the current spell'))),
                      ]))),
        if (plan.choices.isEmpty && !plan.needsManualCounts)
          Text(s.t(
              'Новых выборов заклинаний на этом уровне нет. Изменения запасов показаны в итогах.',
              'No new spell choices at this level. Pool changes appear in the review.')),
      ]),
      AdvancementFooter(
          label: l.next, onPressed: ready ? onNext : null, hint: issue)
    ]);
  }
}

/// A capsule that rises into place, a moment after its neighbours.
class _Arrive extends StatelessWidget {
  const _Arrive({super.key, required this.delay, required this.child});
  final int delay;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final total = 420 + delay * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
      duration: AppMotion.of(context, Duration(milliseconds: total)),
      curve: Interval(delay * 60 / total, 1, curve: AppMotion.snappyCurve),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: Transform.scale(scale: .7 + .3 * t, child: child)),
      ),
      child: child,
    );
  }
}
