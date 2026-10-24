import 'package:flutter/material.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';

import '../../../../core/magic/spellbook_state.dart';
import '../../../../core/models/character.dart';
import '../../../../core/progression/class_spellcasting_profile.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/spell_service.dart';
import '../../../../core/services/spellbook_actions_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/spell_preparation_rules_sheet.dart';
import '../class_widgets/instrument/instrument_kit.dart';

/// The spellcasting facts of each class (prototype `.src`): ability
/// modifier, save DC and attack, then how many spells are prepared or
/// known. Several casting classes stack, each under its coloured name.
class SpellSourceSummary extends StatefulWidget {
  const SpellSourceSummary(
      {super.key, required this.hero, required this.onPrepare});
  final Character hero;
  final VoidCallback onPrepare;
  @override
  State<SpellSourceSummary> createState() => _SpellSourceSummaryState();
}

class _SpellSourceSummaryState extends State<SpellSourceSummary> {
  @override
  Widget build(BuildContext context) {
    final profiles = <ClassSpellcastingProfile>[];
    for (final entry in widget.hero.classes) {
      try {
        final p = ClassSpellcastingProfile.resolve(widget.hero, entry.id);
        if (p != null) profiles.add(p);
      } catch (_) {}
    }
    if (profiles.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final p in profiles) ...[
        if (p != profiles.first) const SizedBox(height: 10),
        _source(context, p, several: profiles.length > 1),
      ],
    ]);
  }

  Widget _source(BuildContext context, ClassSpellcastingProfile profile, {required bool several}) {
    final l = AppLocalizations.of(context)!;
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final c = Theme.of(context).colorScheme;
    final owner = CharacterClassContext(widget.hero, profile.classId);
    final source = 'class:${profile.classId}';
    final limit = SpellbookActionsService.preparationLimit(widget.hero, source);
    final count = SpellbookActionsService.preparedCount(widget.hero, source);
    String ability(String value) => switch (value) {
          'intelligence' => l.abilityIntAbbr,
          'wisdom' => l.abilityWisAbbr,
          'charisma' => l.abilityChaAbbr,
          'strength' => l.abilityStrAbbr,
          'dexterity' => l.abilityDexAbbr,
          'constitution' => l.abilityConAbbr,
          _ => value
        };
    String signed(int n) => n >= 0 ? '+$n' : '$n';
    Widget fact(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(color: c.onSurface.withValues(alpha: .05), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppType.body, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .55, height: 1, color: c.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontFamily: AppType.display, fontSize: 22, fontWeight: FontWeight.w600, height: 1.15, fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
        );
    var known = 0, cantrips = 0;
    try {
      final state = SpellbookState.read(widget.hero.spellbookData);
      final ids = {...state.ids(source, 'known'), if (widget.hero.classes.length == 1) ...state.unassignedKnown(widget.hero)};
      for (final id in ids) {
        final s = SpellService.getSpellById(id);
        if (s == null) continue;
        s.level == 0 ? cantrips++ : known++;
      }
    } catch (_) {}
    final muted = TextStyle(fontFamily: AppType.body, fontSize: 13, color: c.onSurfaceVariant);
    final strong = TextStyle(fontFamily: AppType.display, fontWeight: FontWeight.w600, color: c.onSurface);
    final custom = owner.definition?.sourceId != null || profile.preparation == null;
    return Container(
      key: ValueKey('spell-source-${profile.classId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (several) ...[
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: classAccent(context, profile.classId))),
            const SizedBox(width: 8),
            Text('${owner.name(locale)} ${profile.classLevel}', style: const TextStyle(fontFamily: AppType.body, fontSize: 14, fontWeight: FontWeight.w600, height: 1.2)),
          ]),
          const SizedBox(height: 10),
        ],
        Row(children: [
          fact(ability(profile.ability), signed(profile.modifier)),
          const SizedBox(width: 10),
          fact(ru ? 'Сл спаса' : 'Save DC', '${profile.saveDC}'),
          const SizedBox(width: 10),
          fact(ru ? 'Атака' : 'Attack', signed(profile.attackBonus)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text.rich(
              limit != null
                  ? TextSpan(children: [
                      TextSpan(text: ru ? 'Подготовлено ' : 'Prepared '),
                      TextSpan(text: '$count / $limit', style: strong),
                    ])
                  : TextSpan(children: [
                      TextSpan(text: ru ? 'Известно ' : 'Known '),
                      TextSpan(text: '$known', style: strong),
                      TextSpan(text: ru ? ' · заговоров ' : ' · cantrips '),
                      TextSpan(text: '$cantrips', style: strong),
                    ]),
              style: muted,
            ),
          ),
          if (custom)
            Pressable(
              onTap: () async {
                final saved = await showSpellPreparationRulesSheet(context, widget.hero, profile.classId);
                if (saved == true && mounted) setState(() {});
              },
              semanticLabel: ru ? 'Правила магии' : 'Magic rules',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(ru ? 'Правила магии' : 'Magic rules',
                    style: TextStyle(fontFamily: AppType.body, fontSize: 13, fontWeight: FontWeight.w600, color: c.secondary)),
              ),
            ),
        ]),
      ]),
    );
  }

}
