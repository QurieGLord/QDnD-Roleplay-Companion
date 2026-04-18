import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/models/character.dart';
import '../../../../../core/models/spell.dart';
import '../../../../../core/models/spell_slots_table.dart';
import '../../../../../core/services/spellcasting_service.dart';
import '../abilities_expander.dart';
import '../abilities_shell_tokens.dart';
import 'spell_list_item.dart';

class AbilitiesSpellLevelGroup extends StatelessWidget {
  const AbilitiesSpellLevelGroup({
    super.key,
    required this.character,
    required this.level,
    required this.spells,
    required this.locale,
    required this.initiallyExpanded,
    required this.onExpandedChanged,
    required this.onOpenDetails,
    required this.onCastSpell,
    required this.onTogglePreparation,
  });

  final Character character;
  final int level;
  final List<Spell> spells;
  final String locale;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<Spell> onOpenDetails;
  final ValueChanged<Spell> onCastSpell;
  final ValueChanged<Spell> onTogglePreparation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final title = level == 0 ? l10n.cantrips : l10n.levelLabel(level);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AbilitiesShellTokens.nestedRadius),
      ),
      child: AbilitiesExpander(
        initiallyExpanded: initiallyExpanded,
        onExpandedChanged: onExpandedChanged,
        borderRadius: BorderRadius.circular(AbilitiesShellTokens.nestedRadius),
        header: Padding(
          padding: AbilitiesShellTokens.nestedPadding,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                    AbilitiesShellTokens.pillRadius,
                  ),
                ),
                child: Text(
                  '${spells.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            children: [
              for (final spell in spells) ...[
                AbilitiesSpellListItem(
                  spell: spell,
                  character: character,
                  locale: locale,
                  isPrepared: _isPrepared(spell),
                  isSpontaneous: _isSpontaneous,
                  canCast: _canCast(spell),
                  onOpenDetails: () => onOpenDetails(spell),
                  onCastSpell: () => onCastSpell(spell),
                  onTogglePreparation: () => onTogglePreparation(spell),
                ),
                if (spell != spells.last)
                  const SizedBox(height: AbilitiesShellTokens.compactSpacing),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _isPactMagic =>
      SpellcastingService.getSpellcastingType(
        character.characterClass.toLowerCase(),
      ) ==
      'pact_magic';

  bool get _isSpontaneous => const [
        'sorcerer',
        'bard',
        'warlock',
        'ranger',
        'чародей',
        'бард',
        'колдун',
        'следопыт',
      ].contains(character.characterClass.toLowerCase());

  bool _isPrepared(Spell spell) {
    return _isSpontaneous || character.preparedSpells.contains(spell.id);
  }

  bool _canCast(Spell spell) {
    if (spell.level == 0) {
      return true;
    }

    if (_isPactMagic) {
      if (spell.level >= 6) {
        return true;
      }

      final pactSlots = SpellSlotsTable.getPactSlots(character.level);
      final pactSlotLevel = pactSlots.length;
      if (pactSlotLevel > 0 && pactSlotLevel <= character.spellSlots.length) {
        return character.spellSlots[pactSlotLevel - 1] > 0;
      }
      return false;
    }

    return spell.level <= character.spellSlots.length &&
        character.spellSlots[spell.level - 1] > 0;
  }
}
