import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/services/magic_resource_actions_service.dart';
import '../../../../core/magic/magic_slots.dart';
import '../../../../core/ui/companion_surface.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import 'shared/class_tools_layout_builder.dart';

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

  bool get _hasArcaneRecovery {
    // 1. Feature check (Name or ID)
    final hasFeature = widget.character.features.any((f) {
      final nameEn = (f.nameEn).toLowerCase();
      final nameRu = (f.nameRu).toLowerCase();
      final id = (f.id).toLowerCase().replaceAll('-', '_');
      return nameEn.contains('arcane recovery') ||
          nameRu.contains('арканное восстановление') ||
          id.contains('arcane_recovery');
    });

    if (hasFeature) return widget.character.classLevel('wizard') >= 1;

    // 2. Fallback: Level 1+ Wizard (It's a base class feature at lvl 1)
    return widget.character.classLevel('wizard') >= 1 &&
        'wizard'.toLowerCase() == 'wizard';
  }

  void _showArcaneRecoveryModal() {
    final maxRecoveryLevels =
        (widget.character.classLevel('wizard') / 2).ceil();
    // Track selected slots to recover locally in the modal
    final Map<int, int> selectedSlots = {}; // Level -> Count

    final maxSpellSlots = MagicSlots.read(widget.character).maximum;

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
                      ? (currentRecoveryTotal / maxRecoveryLevels).clamp(
                          0.0,
                          1.0,
                        )
                      : 0,
                  color: currentRecoveryTotal > maxRecoveryLevels
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Text(
                  '$currentRecoveryTotal / $maxRecoveryLevels ${Localizations.localeOf(context).languageCode == 'ru' ? 'ур. использовано' : 'levels used'}',
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
                        Builder(
                          builder: (context) {
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

                            if (missing <= 0 && selected == 0) {
                              return const SizedBox.shrink();
                            }

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
                                borderRadius: BorderRadius.circular(20),
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
                                        fontSize: 16,
                                      ),
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
                          },
                        ),
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

  Future<void> _confirmArcaneRecovery(Map<int, int> slotsToRecover) async {
    try {
      await MagicResourceActionsService.recover(
          widget.character, slotsToRecover,
          classId: 'wizard');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {});
      widget.onStateChanged();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Не удалось восстановить ячейки.'
                : 'Could not recover slots.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Wizard specific color (Blue/Indigo)
    final wizardColor = theme.colorScheme.primary;

    return ClassPanelFrame(
        character: widget.character,
        classId: 'wizard',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: [
            // 1. Arcane Tradition Block
            if (CharacterClassContext(widget.character, 'wizard').subclass !=
                null)
              _buildArcaneTraditionBlock(context, theme, l10n, wizardColor),

            // 2. Arcane Recovery Block (Feature Driven)
            if (_hasArcaneRecovery)
              _buildArcaneRecoveryBlock(context, theme, l10n, wizardColor),
          ],
        ));
  }

  Widget _buildArcaneTraditionBlock(BuildContext context, ThemeData theme,
          AppLocalizations l10n, Color accentColor) =>
      ClassSubclassLink(character: widget.character, classId: 'wizard');

  Widget _buildArcaneRecoveryBlock(BuildContext context, ThemeData theme,
      AppLocalizations l10n, Color accentColor) {
    final used = widget.character.arcaneRecoveryUsed;
    final budget = (widget.character.classLevel('wizard') / 2).ceil();
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return ClassPrimaryControl(
        classId: 'wizard',
        title: l10n.arcaneRecovery,
        tone: theme.colorScheme.secondaryContainer,
        footer: ru
            ? 'Во время короткого отдыха · раз в день'
            : 'During a short rest · once per day',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: companionDecoration(context,
                    raised: true,
                    color: theme.colorScheme.surface,
                    shape:
                        const CompanionShape(contour: CompanionContour.fold)),
                child: Text('$budget',
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(width: 16),
            Expanded(
                child: Text(
                    ru
                        ? 'Сумма кругов для восстановления'
                        : 'Combined spell levels to recover',
                    style: theme.textTheme.bodyLarge)),
          ]),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
              onPressed: used ? null : _showArcaneRecoveryModal,
              icon: Icon(used ? Icons.check_rounded : Icons.restore_rounded),
              label: Text(used ? l10n.used : l10n.recoverSpellSlots)),
        ]));
  }
}
