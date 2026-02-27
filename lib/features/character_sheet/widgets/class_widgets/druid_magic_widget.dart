import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../core/services/feature_service.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/models/spell_slots_table.dart';

class DruidMagicWidget extends StatefulWidget {
  final Character character;
  final VoidCallback onStateChanged;

  const DruidMagicWidget({
    super.key,
    required this.character,
    required this.onStateChanged,
  });

  @override
  State<DruidMagicWidget> createState() => _DruidMagicWidgetState();
}

class _DruidMagicWidgetState extends State<DruidMagicWidget> {
  // --- Wild Shape Logic ---

  void _handleWildShape() {
    if (widget.character.isWildShaped) {
      _revertWildShape();
    } else {
      // Level 20 Archdruid: Unlimited Wild Shape
      final canTransform =
          widget.character.level >= 20 || widget.character.wildShapeCharges > 0;

      if (canTransform) {
        _showTransformModal();
      } else {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noWildShapeCharges),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _revertWildShape() {
    HapticFeedback.mediumImpact();
    setState(() {
      widget.character.isWildShaped = false;
      widget.character.temporaryHp = 0; // Reset temp HP on revert
      widget.character.save();
      widget.onStateChanged();
    });
  }

  void _showTransformModal() {
    final hpController = TextEditingController();
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.transform,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.beastHP,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.favorite),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.beastName,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.pets),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                final hp = int.tryParse(hpController.text);
                if (hp != null && hp > 0) {
                  _confirmTransformation(hp, nameController.text);
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.check),
              label: Text(AppLocalizations.of(context)!.confirm),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmTransformation(int hp, String name) {
    HapticFeedback.heavyImpact();
    setState(() {
      if (widget.character.level < 20) {
        widget.character.wildShapeCharges--;
      }
      widget.character.temporaryHp = hp;
      widget.character.isWildShaped = true;
      // Optional: Store beast name somewhere if needed, e.g., journal or temp field
      widget.character.save();
      widget.onStateChanged();
    });
  }

  // --- Natural Recovery Logic ---

  bool get _hasNaturalRecovery {
    // 1. Feature check (Name or ID)
    final hasFeature = widget.character.features.any((f) {
      final nameEn = (f.nameEn ?? '').toLowerCase();
      final nameRu = (f.nameRu ?? '').toLowerCase();
      final id = f.id.toLowerCase().replaceAll('-', '_');
      return nameEn.contains('natural recovery') ||
          nameRu.contains('естественное восстановление') ||
          id.contains('natural_recovery');
    });

    if (hasFeature) return true;

    // 2. Fallback: Level 2+ Land Druid
    // This covers cases where feature data might be missing or mismatched
    if (widget.character.level >= 2) {
      final subclass = (widget.character.subclass ?? '').toLowerCase();
      return subclass.contains('land') ||
          subclass.contains('земли'); // "Circle of the Land" / "Круг Земли"
    }

    return false;
  }

  void _showNaturalRecoveryModal() {
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
                    Icon(Icons.spa,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.naturalRecovery,
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
                  // REPLACING ListView with a simple Column loop for guaranteed safety
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

                          // Skip if max slots is 0 (slot level not unlocked or invalid data)
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
                          _confirmNaturalRecovery(selectedSlots);
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

  void _confirmNaturalRecovery(Map<int, int> slotsToRecover) {
    HapticFeedback.mediumImpact();
    setState(() {
      slotsToRecover.forEach((level, count) {
        for (int i = 0; i < count; i++) {
          widget.character.restoreSpellSlot(level);
        }
      });
      widget.character.naturalRecoveryUsed = true;
      widget.character.save();
      widget.onStateChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Use a natural green/tertiary color for Druid theming
    final druidColor = theme.colorScheme.tertiary;

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
            // 1. Druid Circle Block
            if (widget.character.subclass != null) ...[
              _buildDruidCircleBlock(context, theme, l10n, druidColor),
              const SizedBox(height: 12),
            ],

            // 2. Wild Shape Block (Always present)
            _buildWildShapeBlock(context, theme, l10n, druidColor),

            // 3. Natural Recovery Block (Conditional)
            if (_hasNaturalRecovery) ...[
              const SizedBox(height: 12),
              _buildNaturalRecoveryBlock(context, theme, l10n, druidColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDruidCircleBlock(
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
                  // Match against any localized name or the ID
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
            final description = subclassData?.getDescription(locale) ??
                l10n.noFeaturesAtLevel1; // Fallback text

            // Normalize Name: "Land" -> "Circle of the Land" (localized)
            String subclassDisplay =
                widget.character.subclass ?? l10n.druidCircle;
            if (subclassDisplay.toLowerCase() == 'land' ||
                subclassDisplay == 'Земля') {
              // Add more if needed
              // Use l10n if available, or just hardcode for now as I don't see a "circleOfTheLand" key.
              // Assuming "Circle of the Land" is the full name we want.
              // Actually, let's use the ClassData name if we found it.
              if (subclassData != null) {
                subclassDisplay = subclassData.getName(locale);
              } else {
                subclassDisplay =
                    locale == 'ru' ? 'Круг Земли' : 'Circle of the Land';
              }
            }

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
                              Icon(Icons.terrain, color: accentColor, size: 28),
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
                Icon(Icons.terrain, color: accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.druidCircle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        // Display logic for list item
                        (widget.character.subclass?.toLowerCase() == 'land')
                            ? (Localizations.localeOf(context).languageCode ==
                                    'ru'
                                ? 'Круг Земли'
                                : 'Circle of the Land')
                            : (widget.character.subclass ?? 'Unknown Circle'),
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

  Widget _buildWildShapeBlock(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    final level = widget.character.level;
    final maxCR = level < 4
        ? "1/4"
        : level < 8
            ? "1/2"
            : "1";
    final restrictions = level < 4
        ? l10n.noFlyingSwimming
        : level < 8
            ? l10n.noFlying
            : l10n.noRestrictions;
    final duration = (level / 2).floor();

    final isTransformed = widget.character.isWildShaped;
    final isUnlimited = level >= 20;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTransformed
            ? accentColor.withOpacity(0.15)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isTransformed
            ? Border.all(color: accentColor, width: 2)
            : Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with InkWell for Info
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                // Fetch Wild Shape Feature to display description
                // Base feature ID
                // Or better, find the one the character actually has to get correct level description if ids differ
                // But for general rules, base is fine or just localized string if we had one.
                // Let's try to find the actual feature on the character for accuracy.
                final charFeature = widget.character.features.firstWhere(
                    (f) =>
                        f.nameEn.contains('Wild Shape') == true ||
                        f.nameRu.contains('Дикий облик') == true,
                    orElse: () =>
                        FeatureService.getFeatureById(
                            'wild-shape-cr-1-2-or-below-no-flying-speed') ??
                        CharacterFeature(
                            id: 'dummy',
                            nameEn: '',
                            nameRu: '',
                            descriptionEn: '',
                            descriptionRu: '',
                            type: FeatureType.passive,
                            minLevel: 0));

                final description = charFeature.getDescription(
                    Localizations.localeOf(context).languageCode);

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
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
                          Row(
                            children: [
                              Icon(Icons.pets, color: accentColor, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.wildShape,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            description.isNotEmpty
                                ? description
                                : l10n.noFeaturesAtLevel1, // Fallback
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.wildShape,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isTransformed
                              ? accentColor
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${l10n.wildShapeMaxCR}: $maxCR • ${duration}h',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // Charges
                  isUnlimited
                      ? Icon(Icons.all_inclusive, size: 28, color: accentColor)
                      : Row(
                          children: List.generate(2, (index) {
                            final isAvailable =
                                index < widget.character.wildShapeCharges;
                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: isAvailable ? 1.0 : 0.3,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.pets,
                                  size: 28,
                                  color: isAvailable
                                      ? accentColor
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            );
                          }),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              restrictions,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _handleWildShape,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isTransformed ? theme.colorScheme.error : accentColor,
                  foregroundColor: isTransformed
                      ? theme.colorScheme.onError
                      : theme.colorScheme.onTertiary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(isTransformed ? Icons.undo : Icons.auto_awesome),
                label: Text(isTransformed ? l10n.revertForm : l10n.transform),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNaturalRecoveryBlock(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    final isUsed = widget.character.naturalRecoveryUsed;

    return Container(
      // No bottom margin for the last item
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
            child: Icon(Icons.spa,
                color: isUsed ? theme.colorScheme.outline : accentColor,
                size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.naturalRecovery,
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
            onPressed: isUsed ? null : _showNaturalRecoveryModal,
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
