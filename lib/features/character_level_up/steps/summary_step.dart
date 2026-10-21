import '../../../core/progression/character_training.dart';
import '../../../core/magic/magic_slots.dart';
import '../../../core/ui/companion_surface.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/qdnd_bundle_codec.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/progression/feature_evolution.dart';
import '../../../core/progression/proficiency_identity.dart';
import '../widgets/advancement_layout.dart';
import '../../../core/ui/sheet_drag_region.dart';

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
      this.unavailableMessage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
            AdvancementHeading(
              title: l10n.advancementReviewTitle,
              subtitle: l10n.advancementReviewHint,
              trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(18)),
                  child: Text(
                      '${character.level} → ${proposed?.level ?? nextLevel}',
                      style: theme.textTheme.titleMedium)),
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
                    ru ? 'ОЗ' : 'HP',
                    '${character.currentHp}/${character.maxHp}',
                    '${proposed.currentHp}/${proposed.maxHp}',
                    key: const ValueKey('progression-summary-health')),
                _row(
                    context,
                    l10n.proficiencyBonusLabel,
                    _bonus(character.proficiencyBonus),
                    _bonus(proposed.proficiencyBonus),
                    key: const ValueKey('progression-summary-proficiency')),
                _row(
                    context,
                    ru ? 'Кости хитов' : 'Hit Dice',
                    '${character.hitDice.fold<int>(0, (a, b) => a + b)}/${character.maxHitDice}',
                    '${proposed.hitDice.fold<int>(0, (a, b) => a + b)}/${proposed.maxHitDice}'),
                Text(
                    ru
                        ? 'Текущие ОЗ и отмеченные состояния сохраняются.'
                        : 'Current HP and marked conditions stay unchanged.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ]),
              if (proposed.abilityScores.toJson().toString() !=
                  character.abilityScores.toJson().toString())
                _section(context, l10n.abilityScoresTitle, [
                  for (final entry in proposed.abilityScores.toJson().entries)
                    if (entry.value !=
                        character.abilityScores.toJson()[entry.key])
                      _row(
                          context,
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
                              style: theme.textTheme.bodyMedium))
                  ]),
              if (added.isNotEmpty)
                _section(context, l10n.classFeatures, [
                  for (final feature in added)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.check_circle_outline_rounded,
                          color: colors.primary, size: 22),
                      title: Text(feature.getName(ru ? 'ru' : 'en'),
                          style: theme.textTheme.titleSmall),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showResponsiveSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(feature.getName(ru ? 'ru' : 'en'),
                                        style: theme.textTheme.headlineSmall),
                                    const SizedBox(height: 16),
                                    Text(
                                        feature
                                            .getDescription(ru ? 'ru' : 'en'),
                                        style: theme.textTheme.bodyLarge),
                                  ]))),
                    ),
                ]),
              if (proposed.knownSpells
                  .any((id) => !character.knownSpells.contains(id)))
                _section(
                    context, ru ? 'Изученные заклинания' : 'Learned spells', [
                  for (final id in proposed.knownSpells
                      .where((id) => !character.knownSpells.contains(id)))
                    Padding(
                        key: ValueKey('progression-learned-$id'),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            SpellService.getSpellById(id)
                                    ?.getName(ru ? 'ru' : 'en') ??
                                (ru
                                    ? 'Заклинание из источника'
                                    : 'Spell from an installed source'),
                            style: theme.textTheme.bodyMedium)),
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
              if (proposed.spellSlots.isNotEmpty)
                _section(context, ru ? 'Ячейки заклинаний' : 'Spell slots', [
                  for (var i = 0; i < proposed.spellSlots.length; i++)
                    if (proposed.spellSlots[i] > 0 ||
                        i < proposed.maxSpellSlots.length &&
                            proposed.maxSpellSlots[i] > 0)
                      _row(context, ru ? '${i + 1} круг' : 'Circle ${i + 1}',
                          _slot(character, i), _slot(proposed, i)),
                  Text(
                      ru
                          ? 'Повышение не восстанавливает потраченные ячейки.'
                          : 'Levelling does not restore spent spell slots.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant))
                ]),
            ],
            if (error != null) _message(context, error!),
          ])),
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
  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CompanionSurface(
              quiet: true,
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: -.4)),
                    const SizedBox(height: 12),
                    ...children,
                  ])));
  Widget _row(
      BuildContext context, String label, String oldValue, String newValue,
      {Key? key}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unchanged = oldValue == newValue;
    final values = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (!unchanged) ...[
            Text(oldValue,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant)),
            Icon(Icons.arrow_forward_rounded,
                size: 14, color: colors.onSurfaceVariant)
          ],
          Text(newValue,
              style: theme.textTheme.titleSmall?.copyWith(
                  color: unchanged ? colors.onSurface : colors.primary,
                  fontWeight: FontWeight.w600)),
        ]);
    return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: LayoutBuilder(builder: (context, size) {
          if (MediaQuery.textScalerOf(context).scale(1) > 1.25 ||
              size.maxWidth < 300) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  values
                ]);
          }
          return Row(children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            const SizedBox(width: 16),
            Flexible(child: values)
          ]);
        }));
  }
}
