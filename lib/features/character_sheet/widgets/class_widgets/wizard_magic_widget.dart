import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/models/spell_slots_table.dart';

class WizardMagicWidget extends StatefulWidget {
  final Character character;
  final VoidCallback onStateChanged;

  const WizardMagicWidget({
    super.key,
    required this.character,
    required this.onStateChanged,
  });

  @override
  State<WizardMagicWidget> createState() => _WizardMagicWidgetState();
}

class _WizardMagicWidgetState extends State<WizardMagicWidget> {
  // --- Arcane Recovery Logic ---

  String _getLocalizedTradition(AppLocalizations l10n, String? subclass) {
    if (subclass == null) return l10n.arcaneTradition;
    final lower = subclass.toLowerCase();
    if (lower.contains('evocation')) return l10n.traditionEvocation;
    if (lower.contains('abjuration')) return l10n.traditionAbjuration;
    if (lower.contains('conjuration')) return l10n.traditionConjuration;
    if (lower.contains('divination')) return l10n.traditionDivination;
    if (lower.contains('enchantment')) return l10n.traditionEnchantment;
    if (lower.contains('illusion')) return l10n.traditionIllusion;
    if (lower.contains('necromancy')) return l10n.traditionNecromancy;
    if (lower.contains('transmutation')) return l10n.traditionTransmutation;
    return subclass;
  }

  bool get _hasArcaneRecovery {
    // 1. Feature check (Name or ID)
    final hasFeature = widget.character.features.any((f) {
      final nameEn = (f.nameEn ?? '').toLowerCase();
      final nameRu = (f.nameRu ?? '').toLowerCase();
      final id = (f.id ?? '').toLowerCase().replaceAll('-', '_');
      return nameEn.contains('arcane recovery') ||
          nameRu.contains('арканное восстановление') ||
          id.contains('arcane_recovery');
    });

    if (hasFeature) return true;

    // 2. Fallback: Level 1+ Wizard (It's a base class feature at lvl 1)
    return widget.character.level >= 1 &&
        widget.character.characterClass.toLowerCase() == 'wizard';
  }

  void _showArcaneRecoveryModal() {
    final maxRecoveryLevels = (widget.character.level / 2).ceil();
    // Track selected slots to recover locally in the modal
    final Map<int, int> selectedSlots = {}; // Level -> Count

    // Fail-safe: Use SpellSlotsTable for max slots
    final tableSlots = SpellSlotsTable.getSlots(widget.character.level, 'full');
    final maxSpellSlots =
        tableSlots.isNotEmpty ? tableSlots : widget.character.maxSpellSlots;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          int currentRecoveryTotal = 0;
          selectedSlots.forEach((level, count) {
            currentRecoveryTotal += level * count;
          });

          // Check if there are any slots to recover
          bool hasRecoverableSlots = false;
          for (int i = 0; i < 5; i++) {
            // Levels 1-5 only
            if (i < widget.character.spellSlots.length &&
                i < maxSpellSlots.length) {
              if (widget.character.spellSlots[i] < maxSpellSlots[i]) {
                hasRecoverableSlots = true;
                break;
              }
            }
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_fix_high,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.arcaneRecovery,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!
                      .selectSlotsToRecover(maxRecoveryLevels),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: maxRecoveryLevels > 0
                      ? currentRecoveryTotal / maxRecoveryLevels
                      : 0,
                  color: currentRecoveryTotal > maxRecoveryLevels
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Text(
                  '$currentRecoveryTotal / $maxRecoveryLevels levels used',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: currentRecoveryTotal > maxRecoveryLevels
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Empty State Check
                if (!hasRecoverableSlots)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.allSpellSlotsFull,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < 5; i++)
                        Builder(builder: (context) {
                          // Safety Checks: Ensure we don't go out of bounds
                          if (i >= widget.character.spellSlots.length ||
                              i >= maxSpellSlots.length) {
                            return const SizedBox.shrink();
                          }

                          final level = i + 1;
                          final max = maxSpellSlots[i];
                          final current = widget.character.spellSlots[i];

                          // Skip if max slots is 0
                          if (max <= 0) return const SizedBox.shrink();

                          // Logic: Show if missing slots OR if selected > 0
                          final missing = max - current;
                          final selected = selectedSlots[level] ?? 0;

                          if (missing <= 0 && selected == 0)
                            return const SizedBox.shrink();

                          // Check if adding one more of this level would exceed the cap
                          final canAdd = selected < missing &&
                              (currentRecoveryTotal + level) <=
                                  maxRecoveryLevels;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(AppLocalizations.of(context)!
                                  .levelSlot(level)),
                              subtitle: Text(
                                  '${AppLocalizations.of(context)!.currentSpellSlots}: $current / $max'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: selected > 0
                                        ? () {
                                            setModalState(() {
                                              selectedSlots[level] =
                                                  selected - 1;
                                            });
                                          }
                                        : null,
                                  ),
                                  Text(
                                    '$selected',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: canAdd
                                        ? () {
                                            setModalState(() {
                                              selectedSlots[level] =
                                                  selected + 1;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (hasRecoverableSlots &&
                          currentRecoveryTotal > 0 &&
                          currentRecoveryTotal <= maxRecoveryLevels)
                      ? () {
                          _confirmArcaneRecovery(selectedSlots);
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text(AppLocalizations.of(context)!.recoverSpellSlots),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmArcaneRecovery(Map<int, int> slotsToRecover) {
    HapticFeedback.mediumImpact();
    setState(() {
      slotsToRecover.forEach((level, count) {
        for (int i = 0; i < count; i++) {
          widget.character.restoreSpellSlot(level);
        }
      });
      widget.character.arcaneRecoveryUsed = true;
      widget.character.save();
      widget.onStateChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Wizard specific color (Blue/Indigo)
    final wizardColor = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Arcane Tradition Block
            if (widget.character.subclass != null) ...[
              _buildArcaneTraditionBlock(context, theme, l10n, wizardColor),
              const SizedBox(height: 12),
            ],

            // 2. Arcane Recovery Block (Feature Driven)
            if (_hasArcaneRecovery)
              _buildArcaneRecoveryBlock(context, theme, l10n, wizardColor),
          ],
        ),
      ),
    );
  }

  Widget _buildArcaneTraditionBlock(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();

            // Fetch lore
            final classData = CharacterDataService.getClassById(
                widget.character.characterClass);
            SubclassData? subclassData;

            if (classData != null && widget.character.subclass != null) {
              try {
                subclassData = classData.subclasses.firstWhere((s) {
                  return s.name.values
                          .any((val) => val == widget.character.subclass) ||
                      s.id ==
                          widget.character.subclass!
                              .toLowerCase()
                              .replaceAll(' ', '_');
                });
              } catch (_) {}
            }

            final locale = Localizations.localeOf(context).languageCode;
            final description =
                subclassData?.getDescription(locale) ?? l10n.noFeaturesAtLevel1;

            String subclassDisplay =
                _getLocalizedTradition(l10n, widget.character.subclass);

            showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => DraggableScrollableSheet(
                      initialChildSize: 0.6,
                      minChildSize: 0.4,
                      maxChildSize: 0.9,
                      expand: false,
                      builder: (context, scrollController) => Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(children: [
                              Icon(Icons.auto_stories,
                                  color: accentColor, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  subclassDisplay,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              description,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.auto_stories, color: accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.arcaneTradition,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _getLocalizedTradition(l10n, widget.character.subclass),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArcaneRecoveryBlock(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    final isUsed = widget.character.arcaneRecoveryUsed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_fix_high,
                color: isUsed ? theme.colorScheme.outline : accentColor,
                size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.arcaneRecovery,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  isUsed ? l10n.used : l10n.recoverSpellSlots,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isUsed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: isUsed ? null : _showArcaneRecoveryModal,
            icon: Icon(isUsed ? Icons.check : Icons.refresh),
            tooltip: isUsed ? l10n.used : l10n.recoverSpellSlots,
            style: isUsed
                ? IconButton.styleFrom(
                    disabledBackgroundColor: theme.colorScheme.surfaceDim,
                    disabledForegroundColor: theme.colorScheme.outline,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
