import '../../../core/progression/character_training.dart';
import '../../../core/magic/magic_slots.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/qdnd_bundle_codec.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/progression/feature_evolution.dart';
import '../../../core/progression/proficiency_identity.dart';
import '../widgets/advancement_layout.dart';
import '../widgets/advancement_climb.dart';
import '../widgets/advancement_spells.dart';
import '../../../core/ui/companion_kit.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class SummaryStep extends StatelessWidget {
  final Character character;
  final int nextLevel;
  final int hpIncrease;
  final List<CharacterFeature> newFeatures;
  final VoidCallback onConfirm;
  final Character Function()? previewBuilder;
  final bool saving;
  final String? error;
  final String? unavailableMessage;
  final Color? accent;

  const SummaryStep(
      {super.key,
      required this.character,
      required this.nextLevel,
      required this.hpIncrease,
      required this.newFeatures,
      required this.onConfirm,
      this.previewBuilder,
      this.saving = false,
      this.error,
      this.unavailableMessage,
      this.accent});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final colors = Theme.of(context).colorScheme;
    final tone = accent ?? colors.primary;
    Character? next;
    try {
      next = previewBuilder?.call() ??
          (QdndBundleCodec.cloneCharacter(character)
            ..level = nextLevel
            ..maxHp = character.maxHp + hpIncrease);
    } catch (_) {
      /* Keep the page readable; an incomplete preview cannot commit. */
    }
    final proposed = next;
    final beforePools = {
      for (final feature in character.features)
        if (feature.resourcePool != null)
          FeatureEvolution.key(feature): feature.resourcePool!
    };
    final beforeIds = character.features.map((f) => f.id).toSet();
    final added = proposed?.features
            .where((f) =>
                !beforeIds.contains(f.id) &&
                (!f.id.contains('ability-score-improvement') ||
                    f.options?.isNotEmpty == true))
            .toList() ??
        [];
    return Column(children: [
      AdvancementStepList(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 24 + AdvancementDockScope.inset(context)),
              children: [
            AdvancementHeading(
              title: l10n.advancementReviewTitle,
              subtitle: l10n.advancementReviewHint,
            ),
            if (proposed == null)
              _message(
                  context,
                  ru
                      ? unavailableMessage ??
                          'Не удалось собрать итог. Вернись к выбору способностей и проверь подключённые источники.'
                      : unavailableMessage ??
                          'The preview is incomplete. Review your choices and installed sources.')
            else ...[
              _section(context, ru ? 'Изменения листа' : 'Sheet changes', [
                _row(
                    context,
                    icon: 'up',
                    ru ? 'Уровень героя' : 'Hero level',
                    '${character.level}',
                    '${proposed.level}'),
                _row(
                    context,
                    icon: 'heart',
                    ru ? 'ОЗ' : 'HP',
                    '${character.currentHp}/${character.maxHp}',
                    '${proposed.currentHp}/${proposed.maxHp}',
                    key: const ValueKey('progression-summary-health')),
                _row(
                    context,
                    icon: 'star',
                    l10n.proficiencyBonusLabel,
                    _bonus(character.proficiencyBonus),
                    _bonus(proposed.proficiencyBonus),
                    key: const ValueKey('progression-summary-proficiency')),
                _row(
                    context,
                    icon: 'dice',
                    ru ? 'Кости хитов' : 'Hit Dice',
                    '${character.hitDice.fold<int>(0, (a, b) => a + b)}/${character.maxHitDice}',
                    '${proposed.hitDice.fold<int>(0, (a, b) => a + b)}/${proposed.maxHitDice}'),
              ]),
              if (proposed.abilityScores.toJson().toString() !=
                  character.abilityScores.toJson().toString())
                _section(context, l10n.abilityScoresTitle, [
                  for (final entry in proposed.abilityScores.toJson().entries)
                    if (entry.value !=
                        character.abilityScores.toJson()[entry.key])
                      _row(
                          context,
                          icon: 'stats',
                          _ability(l10n, entry.key),
                          '${character.abilityScores.toJson()[entry.key]}',
                          '${entry.value}')
                ]),
              for (final training in [
                (
                  l10n.skills,
                  character.proficientSkills,
                  proposed.proficientSkills
                ),
                (l10n.expertise, character.expertSkills, proposed.expertSkills)
              ])
                if (training.$3.any((skill) =>
                    !ProficiencyIdentity.contains(training.$2, skill)))
                  _section(context, training.$1, [
                    for (final skill in training.$3.where((skill) =>
                        !ProficiencyIdentity.contains(training.$2, skill)))
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(_skill(l10n, skill),
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface)))
                  ]),
              if (added.isNotEmpty)
                _group(context, l10n.classFeatures, '${added.length}', [
                  for (final feature in added)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AdvancementGain(
                        icon: advancementFeatureGlyph(feature.iconName),
                        title: feature.getName(ru ? 'ru' : 'en'),
                        text: advancementGist(
                            feature.getDescription(ru ? 'ru' : 'en'),
                            max: 90),
                        accent: tone,
                        small: true,
                        onTap: () => showAdvancementInfo(
                            context,
                            AdvancementInfo(
                                kicker: l10n.classFeatures,
                                title: feature.getName(ru ? 'ru' : 'en'),
                                icon: advancementFeatureGlyph(feature.iconName),
                                accent: tone,
                                text: feature
                                    .getDescription(ru ? 'ru' : 'en'))),
                      ),
                    ),
                ]),
              if (proposed.knownSpells
                  .any((id) => !character.knownSpells.contains(id)))
                _group(
                    context, ru ? 'Изученные заклинания' : 'Learned spells', null, [
                  for (final id in proposed.knownSpells
                      .where((id) => !character.knownSpells.contains(id)))
                    Padding(
                        key: ValueKey('progression-learned-$id'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Builder(builder: (context) {
                          final spell = SpellService.getSpellById(id);
                          return AdvancementGain(
                              icon: 'magic',
                              title: spell?.getName(ru ? 'ru' : 'en') ??
                                  (ru
                                      ? 'Заклинание из источника'
                                      : 'Spell from an installed source'),
                              text: spell == null ? '' : spellLine(context, spell),
                              accent: tone,
                              small: true,
                              onTap: spell == null
                                  ? null
                                  : () => showSpellDetails(context, spell));
                        })),
                ]),
              if (proposed.features.any((f) =>
                  f.resourcePool != null &&
                  (beforePools[FeatureEvolution.key(f)]?.currentUses !=
                          f.resourcePool!.currentUses ||
                      beforePools[FeatureEvolution.key(f)]?.maxUses !=
                          f.resourcePool!.maxUses)))
                _section(context, ru ? 'Ресурсы' : 'Resources', [
                  for (final feature in proposed.features)
                    if (feature.resourcePool != null &&
                        (beforePools[FeatureEvolution.key(feature)]
                                    ?.currentUses !=
                                feature.resourcePool!.currentUses ||
                            beforePools[FeatureEvolution.key(feature)]
                                    ?.maxUses !=
                                feature.resourcePool!.maxUses))
                      _row(
                          context,
                          feature.getName(ru ? 'ru' : 'en'),
                          '${beforePools[FeatureEvolution.key(feature)]?.currentUses ?? 0}/${beforePools[FeatureEvolution.key(feature)]?.maxUses ?? 0}',
                          '${feature.resourcePool!.currentUses}/${feature.resourcePool!.maxUses}',
                          key: ValueKey('progression-resource-${feature.id}')),
                ]),
              if (MagicSlots.read(proposed).pact != null)
                _section(context, ru ? 'Магия договора' : 'Pact Magic', [
                  _row(
                      context,
                      ru ? 'Круг / остаток' : 'Circle / remaining',
                      MagicSlots.read(character).pact == null
                          ? '—'
                          : '${MagicSlots.read(character).pact!.circle} · ${MagicSlots.read(character).pact!.current}/${MagicSlots.read(character).pact!.maximum}',
                      '${MagicSlots.read(proposed).pact!.circle} · ${MagicSlots.read(proposed).pact!.current}/${MagicSlots.read(proposed).pact!.maximum}'),
                ]),
              for (final entry in proposed.classes)
                if (entry.entryProficiencies.isNotEmpty &&
                    !character.classes.any((c) => c.id == entry.id))
                  _section(
                      context, ru ? 'Новые владения' : 'New proficiencies', [
                    for (final value in entry.entryProficiencies)
                      Text(CharacterTraining.label(value, ru ? 'ru' : 'en')),
                  ]),
              // Only circles whose slots this level changes; a hero without
              // shared slots (Pact Magic alone) shows nothing here.
              if (_slotRows(character, proposed).isNotEmpty)
                _section(context, ru ? 'Ячейки заклинаний' : 'Spell slots', [
                  for (final i in _slotRows(character, proposed))
                    _row(context, icon: 'magic',
                        ru ? '${i + 1}-й круг' : 'Circle ${i + 1}',
                        _slot(character, i), _slot(proposed, i)),
                ]),
            ],
            if (proposed != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LineIcon('info', size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        ru
                            ? 'Журнал, имущество и текущие ОЗ не меняются, потраченные ячейки не восстанавливаются. Повышение запишется в историю — его можно откатить.'
                            : 'The journal, belongings and current HP stay as they are; spent slots are not restored. The level-up goes into the history and can be rolled back.',
                        style: TextStyle(
                            fontSize: 13, height: 1.4, color: colors.onSurfaceVariant)),
                  ),
                ]),
              ),
            if (error != null) _message(context, error!),
          ]),
      AdvancementFooter(
        label:
            saving ? (ru ? 'Сохраняем…' : 'Saving…') : (l10n.advancementApply),
        busy: saving,
        onPressed: proposed == null ? null : onConfirm,
      ),
    ]);
  }

  static String _skill(AppLocalizations l, String value) =>
      switch (ProficiencyIdentity.normalize(value)) {
        'acrobatics' => l.skillAcrobatics,
        'animal-handling' => l.skillAnimalHandling,
        'arcana' => l.skillArcana,
        'athletics' => l.skillAthletics,
        'deception' => l.skillDeception,
        'history' => l.skillHistory,
        'insight' => l.skillInsight,
        'intimidation' => l.skillIntimidation,
        'investigation' => l.skillInvestigation,
        'medicine' => l.skillMedicine,
        'nature' => l.skillNature,
        'perception' => l.skillPerception,
        'performance' => l.skillPerformance,
        'persuasion' => l.skillPersuasion,
        'religion' => l.skillReligion,
        'sleight-of-hand' => l.skillSleightOfHand,
        'stealth' => l.skillStealth,
        'survival' => l.skillSurvival,
        _ => value
      };
  static String _bonus(int value) => value >= 0 ? '+$value' : '$value';
  static List<int> _slotRows(Character before, Character after) => [
        for (var i = 0; i < after.maxSpellSlots.length; i++)
          if (after.maxSpellSlots[i] > 0 && _slot(before, i) != _slot(after, i))
            i
      ];
  static String _slot(Character c, int i) =>
      '${i < c.spellSlots.length ? c.spellSlots[i] : 0}/${i < c.maxSpellSlots.length ? c.maxSpellSlots[i] : 0}';
  static String _ability(AppLocalizations l10n, String key) => switch (key) {
        'strength' => l10n.abilityStr,
        'dexterity' => l10n.abilityDex,
        'constitution' => l10n.abilityCon,
        'intelligence' => l10n.abilityInt,
        'wisdom' => l10n.abilityWis,
        'charisma' => l10n.abilityCha,
        _ => key
      };
  Widget _message(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text,
          style: TextStyle(color: Theme.of(context).colorScheme.error)));
  /// A titled group (`.grp6`) over a card of changes (`.sum6`).
  Widget _section(BuildContext context, String title, List<Widget> children) =>
      _group(context, title, null, [
        Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children)),
      ]);

  Widget _group(BuildContext context, String title, String? note,
      List<Widget> children) {
    final c = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: c.onSurface)),
                  ),
                  if (note != null)
                    Text(note,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: c.onSurfaceVariant)),
                ]),
          ),
          ...children,
        ]));
  }

  /// A change row (`.drow`): glyph, what, the old value, an arrow and the
  /// new value in the accent.
  Widget _row(
      BuildContext context, String label, String oldValue, String newValue,
      {Key? key, String? icon}) {
    final c = Theme.of(context).colorScheme;
    final tone = accent ?? c.primary;
    final unchanged = oldValue == newValue;
    final values = Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (!unchanged) ...[
            Text(oldValue,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceVariant)),
            LineIcon('forward', size: 14, color: c.onSurfaceVariant),
          ],
          Text(newValue,
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: unchanged ? c.onSurface : Color.lerp(c.onSurface, tone, .8))),
        ]);
    final name = Text(label,
        style: TextStyle(
            fontSize: 14, height: 1.2, fontWeight: FontWeight.w500, color: c.onSurface));
    return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: LayoutBuilder(builder: (context, size) {
          if (MediaQuery.textScalerOf(context).scale(1) > 1.25 ||
              size.maxWidth < 300) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [name, const SizedBox(height: 6), values]);
          }
          return Row(children: [
            if (icon != null) ...[
              LineIcon(icon, size: 18, color: c.onSurfaceVariant),
              const SizedBox(width: 10),
            ],
            Expanded(child: name),
            const SizedBox(width: 16),
            values
          ]);
        }));
  }
}
