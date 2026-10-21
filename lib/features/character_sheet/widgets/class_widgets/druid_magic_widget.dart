import '../../../../shared/widgets/wild_shape_editor.dart';
import '../../../../core/services/class_session_actions_service.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/magic/casting_constraints.dart';
import '../../../../core/services/magic_resource_actions_service.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/services/feature_service.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/models/spell_slots_table.dart';
import 'shared/class_tools_layout_builder.dart';

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
  bool _shapeBusy = false;
  // --- Wild Shape Logic ---

  void _handleWildShape() {
    if (_shapeBusy) return;
    if (widget.character.isWildShaped) {
      _revertWildShape();
    } else {
      // Level 20 Archdruid: Unlimited Wild Shape
      final canTransform = CastingConstraints.coreDruid(widget.character, 20) ||
          widget.character.wildShapeCharges > 0;

      if (canTransform) {
        _showTransformModal();
      } else {
        HapticFeedback.heavyImpact();
        AppSnackBar.warning(
          context,
          AppLocalizations.of(context)!.noWildShapeCharges,
        );
      }
    }
  }

  Future<void> _revertWildShape() async {
    if (_shapeBusy) return;
    setState(() => _shapeBusy = true);
    try {
      await ClassSessionActionsService.wildShape(widget.character, false);
      if (mounted) {
        HapticFeedback.mediumImpact();
        widget.onStateChanged();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Не удалось завершить облик.'
                : 'Could not end Wild Shape.');
      }
    } finally {
      if (mounted) setState(() => _shapeBusy = false);
    }
  }

  Future<void> _showTransformModal() =>
      showWildShapeEditor(context, onSubmit: _confirmTransformation);

  Future<bool> _confirmTransformation(int hp, String name) async {
    if (_shapeBusy) return false;
    setState(() => _shapeBusy = true);
    try {
      final changed = await ClassSessionActionsService.wildShape(
          widget.character, true,
          hp: hp, name: name);
      if (mounted && changed) {
        HapticFeedback.heavyImpact();
        widget.onStateChanged();
      }
      return changed;
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Не удалось принять облик. Проверь состояние и остаток использований.'
                : 'Could not transform. Check your conditions and remaining uses.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _shapeBusy = false);
    }
  }

  // --- Natural Recovery Logic ---

  bool get _hasNaturalRecovery {
    final owner = CharacterClassContext(widget.character, 'druid');
    return owner.level >= 2 &&
        widget.character.features.any((f) =>
            owner.canUseFeature(f) &&
            f.id.replaceAll('_', '-') == 'natural-recovery');
  }

  void _showNaturalRecoveryModal() {
    final maxRecoveryLevels = (widget.character.classLevel('druid') / 2).ceil();
    // Track selected slots to recover locally in the modal
    final Map<int, int> selectedSlots = {}; // Level -> Count

    // Fail-safe: Use SpellSlotsTable for max slots
    final tableSlots =
        SpellSlotsTable.getSlots(widget.character.classLevel('druid'), 'full');
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
                  // REPLACING ListView with a simple Column loop for guaranteed safety
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

                            // Skip if max slots is 0 (slot level not unlocked or invalid data)
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

  Future<void> _confirmNaturalRecovery(Map<int, int> slotsToRecover) async {
    try {
      await MagicResourceActionsService.recover(
          widget.character, slotsToRecover,
          classId: 'druid');
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

    // Use a natural green/tertiary color for Druid theming
    final druidColor = theme.colorScheme.tertiary;

    final owner = CharacterClassContext(widget.character, 'druid');
    final language = widget.character.features
        .where((f) => owner.canUseFeature(f) && f.id == 'druidic')
        .firstOrNull;
    return ClassPanelFrame(
        character: widget.character,
        classId: 'druid',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: [
            if (owner.level == 1 && language != null)
              ClassPrimaryControl(
                  classId: 'druid',
                  title: language
                      .getName(Localizations.localeOf(context).languageCode),
                  onDetails: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => FeatureDetailsSheet(feature: language)),
                  child: Text(
                      Localizations.localeOf(context).languageCode == 'ru'
                          ? 'Тайный язык друидов: общение и скрытые послания.'
                          : 'The secret language of druids: conversation and hidden messages.',
                      style: theme.textTheme.bodyLarge)),
            // 1. Druid Circle Block
            if (owner.hasAcquiredSubclass)
              _buildDruidCircleBlock(context, theme, l10n, druidColor),

            // Wild Shape begins at this class’s second level.
            _buildWildShapeBlock(context, theme, l10n, druidColor),

            // 3. Natural Recovery Block (Conditional)
            if (_hasNaturalRecovery)
              _buildNaturalRecoveryBlock(context, theme, l10n, druidColor),
          ],
        ));
  }

  Widget _buildDruidCircleBlock(BuildContext context, ThemeData theme,
          AppLocalizations l10n, Color accentColor) =>
      ClassSubclassLink(character: widget.character, classId: 'druid');

  Widget _buildWildShapeBlock(BuildContext context, ThemeData theme,
      AppLocalizations l10n, Color accentColor) {
    final level = widget.character.classLevel('druid');
    final transformed = widget.character.isWildShaped;
    final owner = CharacterClassContext(widget.character, 'druid');
    final ownedShape = widget.character.features
        .where((f) =>
            owner.canUseFeature(f) &&
            (f.id.toLowerCase().replaceAll('_', '-').contains('wild-shape') ||
                f.nameEn.toLowerCase().contains('wild shape')))
        .firstOrNull;
    if (level < 2) return const SizedBox.shrink();
    final unlimited = CastingConstraints.coreDruid(widget.character, 20);
    final circle = CharacterClassContext(widget.character, 'druid')
        .subclass
        ?.toLowerCase();
    final moon = circle == 'moon' || circle == 'circle-of-the-moon';
    final maxCR = moon
        ? '${level < 6 ? 1 : level ~/ 3}'
        : level < 4
            ? '1/4'
            : level < 8
                ? '1/2'
                : '1';
    final restrictions = level < 4
        ? l10n.noFlyingSwimming
        : level < 8
            ? l10n.noFlying
            : l10n.noRestrictions;
    return ClassPrimaryControl(
        classId: 'druid',
        title: l10n.wildShape,
        trailing: unlimited
            ? const Icon(Icons.all_inclusive_rounded, size: 28)
            : null,
        onDetails: ownedShape == null
            ? null
            : () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => FeatureDetailsSheet(feature: ownedShape)),
        current: unlimited ? null : widget.character.wildShapeCharges,
        maximum: unlimited ? null : 2,
        active: transformed,
        footer: l10n.shortRest,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClassFacts(facts: [
            (label: l10n.maxCR, value: maxCR),
            (
              label: l10n.wildShapeDuration,
              value:
                  '${level ~/ 2} ${Localizations.localeOf(context).languageCode == 'ru' ? 'ч.' : 'h'}'
            ),
          ]),
          const SizedBox(height: 12),
          Text(restrictions,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (transformed) ...[
            const SizedBox(height: 16),
            _buildBeastProfileCard(context, theme, l10n, accentColor),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
              onPressed: transformed ||
                      unlimited ||
                      widget.character.wildShapeCharges > 0
                  ? _handleWildShape
                  : null,
              icon: Icon(transformed
                  ? Icons.keyboard_return_rounded
                  : Icons.swap_horiz_rounded),
              label: Text(transformed ? l10n.revertForm : l10n.transform)),
        ]));
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            // Fetch Natural Recovery Feature to display description
            final charFeature = widget.character.features.firstWhere(
                (f) =>
                    f.nameEn.toLowerCase().contains('natural recovery') ||
                    f.nameRu
                        .toLowerCase()
                        .contains('естественное восстановление'),
                orElse: () =>
                    FeatureService.getFeatureById('natural-recovery') ??
                    CharacterFeature(
                        id: 'dummy',
                        nameEn: 'Natural Recovery',
                        nameRu: 'Естественное восстановление',
                        descriptionEn:
                            'You can regain some of your magical energy by sitting in meditation and communing with nature...',
                        descriptionRu:
                            'Вы можете восстановить часть своей магической энергии, медитируя и общаясь с природой...',
                        type: FeatureType.passive,
                        minLevel: 2));

            final description = charFeature
                .getDescription(Localizations.localeOf(context).languageCode);

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
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
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
                          Icon(Icons.spa, color: accentColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.naturalRecovery,
                              style: theme.textTheme.headlineSmall?.copyWith(
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
                            : l10n.noFeaturesAtLevel1,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
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
          ),
        ),
      ),
    );
  }

  Widget _buildBeastProfileCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    final currentHp = widget.character.beastCurrentHp ?? 0;
    final maxHp = widget.character.beastMaxHp ?? 1;
    final ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    child: Icon(Icons.pets, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.character.beastName?.isNotEmpty == true
                          ? widget.character.beastName!
                          : l10n.wildShape,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 2: HP Bar
              InkWell(
                onTap: () {
                  _showBeastHpOverrideDialog(context, currentHp);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            l10n.beastHP,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$currentHp / $maxHp',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          curve:
                              Curves.easeInOutCubicEmphasized, // M3 Expressive
                          tween: Tween<double>(begin: ratio, end: ratio),
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 12,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              color: Color.lerp(
                                  theme.colorScheme.error, accentColor, value),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Row 3: Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _showHpModifierDialog(context, true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Icon(Icons.water_drop,
                          color: theme.colorScheme.error),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _showHpModifierDialog(context, false),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Icon(Icons.eco, color: accentColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHpModifierDialog(BuildContext context, bool isDamage) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDamage ? l10n.takeDamage : l10n.heal),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: isDamage ? l10n.damageAmount : l10n.healAmount,
          ),
          autofocus: false,
          onSubmitted: (val) {
            _applyHpModifier(val, isDamage);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              _applyHpModifier(controller.text, isDamage);
              Navigator.pop(context);
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _applyHpModifier(String value, bool isDamage) async {
    final amount = int.tryParse(value);
    if (amount == null || amount <= 0) return;
    try {
      await GameplayActionsService.changeHealth(widget.character, amount,
          healing: !isDamage);
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() => widget.onStateChanged());
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Не удалось сохранить ОЗ.'
                : 'Could not save HP.');
      }
    }
  }

  void _showBeastHpOverrideDialog(BuildContext context, int currentHp) {
    final controller = TextEditingController(text: currentHp.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.beastHP),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          autofocus: false,
          onSubmitted: (val) {
            _updateBeastHp(val);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              _updateBeastHp(controller.text);
              Navigator.pop(context);
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBeastHp(String value) async {
    final hp = int.tryParse(value);
    if (hp == null || hp < 0) return;
    try {
      await ClassSessionActionsService.beastHealth(widget.character, hp);
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() => widget.onStateChanged());
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Не удалось сохранить ОЗ зверя.'
                : 'Could not save beast HP.');
      }
    }
  }
}
