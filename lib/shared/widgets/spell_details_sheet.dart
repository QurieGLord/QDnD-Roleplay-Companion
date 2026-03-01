import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/spell.dart';
import '../../core/models/character.dart';
import '../../core/services/spell_eligibility_service.dart';
import '../../core/utils/spell_utils.dart';

class SpellDetailsSheet extends StatelessWidget {
  final Spell spell;
  final Character? character;
  final VoidCallback? onToggleKnown;

  const SpellDetailsSheet({
    super.key,
    required this.spell,
    this.character,
    this.onToggleKnown,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    final eligibility = character != null
        ? SpellEligibilityService.checkEligibility(character!, spell)
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          SpellUtils.getSchoolColor(spell.school, colorScheme),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        spell.level == 0 ? '∞' : '${spell.level}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spell.getName(locale),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${SpellUtils.getLocalizedSchool(l10n, spell.school)}${spell.level == 0 ? ' • ${l10n.cantrips}' : ' • ${l10n.levelLabel(spell.level)}'}',
                          style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Eligibility badge
              if (eligibility != null) ...[
                const SizedBox(height: 16),
                _buildEligibilityBadge(context, eligibility, l10n),
              ],

              const SizedBox(height: 24),

              // Stats
              _buildInfoRow(l10n.castingTime,
                  SpellUtils.getLocalizedValue(l10n, spell.castingTime)),
              _buildInfoRow(
                  l10n.range, SpellUtils.getLocalizedValue(l10n, spell.range)),
              _buildInfoRow(l10n.duration,
                  SpellUtils.getLocalizedValue(l10n, spell.duration)),
              _buildInfoRow(l10n.components, spell.components.join(', ')),
              if (spell.getMaterialComponents(locale) != null)
                _buildInfoRow(
                    l10n.materials, spell.getMaterialComponents(locale)!),

              if (spell.concentration || spell.ritual)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (spell.concentration)
                        Chip(
                          label: Text(l10n.concentration),
                          avatar: const Icon(Icons.timelapse, size: 16),
                        ),
                      if (spell.ritual)
                        Chip(
                          label: Text(l10n.ritual),
                          avatar: const Icon(Icons.book, size: 16),
                        ),
                    ],
                  ),
                ),

              const Divider(height: 32),

              // Description
              Text(
                spell.getDescription(locale),
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              if (spell.getAtHigherLevels(locale) != null) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.atHigherLevels,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  spell.getAtHigherLevels(locale)!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],

              const SizedBox(height: 16),
              Text(
                '${l10n.classes}: ${spell.availableToClasses.map((c) => SpellUtils.getLocalizedClassName(context, c)).join(', ')}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),

              // Add/Remove Action
              if (character != null &&
                  onToggleKnown != null &&
                  eligibility != null &&
                  eligibility.canLearn) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      onToggleKnown!();
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      character!.knownSpells.contains(spell.id)
                          ? Icons.remove_circle_outline
                          : Icons.add_circle_outline,
                    ),
                    label: Text(
                      character!.knownSpells.contains(spell.id)
                          ? l10n.removeFromKnown
                          : l10n.addToKnown,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: character!.knownSpells.contains(spell.id)
                          ? colorScheme.error
                          : colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEligibilityBadge(BuildContext context,
      SpellEligibilityResult eligibility, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    if (eligibility.canLearn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Text(l10n.availableToLearn,
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (eligibility.canLearnAtLevel != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text(
              l10n.availableAtLevel(eligibility.canLearnAtLevel!),
              style: const TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.error),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, color: colorScheme.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                eligibility.reason,
                style: TextStyle(
                    color: colorScheme.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
