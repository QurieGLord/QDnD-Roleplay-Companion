import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/models/character.dart';
import '../../../../../core/models/spell.dart';
import '../../../../../core/utils/spell_utils.dart';
import '../abilities_shell_tokens.dart';
import '../abilities_tap_feedback.dart';

class AbilitiesSpellListItem extends StatelessWidget {
  const AbilitiesSpellListItem({
    super.key,
    required this.spell,
    required this.character,
    required this.locale,
    required this.isPrepared,
    required this.isSpontaneous,
    required this.canCast,
    required this.onOpenDetails,
    required this.onCastSpell,
    required this.onTogglePreparation,
  });

  final Spell spell;
  final Character character;
  final String locale;
  final bool isPrepared;
  final bool isSpontaneous;
  final bool canCast;
  final VoidCallback onOpenDetails;
  final VoidCallback onCastSpell;
  final VoidCallback onTogglePreparation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AbilitiesTapFeedback(
      onTap: onOpenDetails,
      borderRadius: BorderRadius.circular(AbilitiesShellTokens.itemRadius),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSpontaneous)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AbilitiesTapFeedback(
                  onTap: onTogglePreparation,
                  borderRadius: BorderRadius.circular(14),
                  color: isPrepared
                      ? colorScheme.tertiaryContainer
                      : colorScheme.surfaceContainerHighest,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      isPrepared ? Icons.star : Icons.star_border,
                      size: 18,
                      color: isPrepared
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.outline,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spell.getName(locale),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SpellUtils.getLocalizedSchool(l10n, spell.school),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: canCast ? onCastSpell : null,
              tooltip: l10n.castSpell,
              icon: const Icon(Icons.auto_fix_high),
            ),
          ],
        ),
      ),
    );
  }
}
