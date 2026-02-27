import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/spellcasting_service.dart';
import '../../../core/models/spell_slots_table.dart';

class SpellSlotsWidget extends StatefulWidget {
  final Character character;
  final VoidCallback onChanged;

  const SpellSlotsWidget({
    super.key,
    required this.character,
    required this.onChanged,
  });

  @override
  State<SpellSlotsWidget> createState() => _SpellSlotsWidgetState();
}

class _SpellSlotsWidgetState extends State<SpellSlotsWidget> {
  bool get _isPactMagic =>
      SpellcastingService.getSpellcastingType(
          widget.character.characterClass) ==
      'pact_magic';

  @override
  Widget build(BuildContext context) {
    if (_isPactMagic) {
      return _buildWarlockPactMagic(context);
    }

    final maxSlots = widget.character.maxSpellSlots;
    // Count how many slot levels actually have slots > 0
    final activeSlotLevels = maxSlots.where((count) => count > 0).length;

    // Determine mode
    // Conditions:
    // 1. Pact Magic (Warlock) -> Always Icons
    // 2. Low level / Half-casters (<= 3 slot levels) -> Icons
    // 3. High level full casters (>= 4 slot levels) -> Compact
    final bool useCompactMode = !_isPactMagic && activeSlotLevels >= 4;

    if (useCompactMode) {
      return _buildCompactMode(context);
    } else {
      return _buildIconsMode(context);
    }
  }

  // ===========================================================================
  // WARLOCK PACT MAGIC UI
  // ===========================================================================

  Widget _buildWarlockPactMagic(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    
    // STRICT FIX: Use SpellSlotsTable directly instead of character array
    final pactSlots = SpellSlotsTable.getPactSlots(widget.character.level);
    
    int pactSlotLevel = 0;
    int maxPactSlots = 0;

    // Find the highest level with > 0 slots
    for (int i = 0; i < pactSlots.length; i++) {
      if (pactSlots[i] > 0) {
        pactSlotLevel = i + 1;
        maxPactSlots = pactSlots[i];
      }
    }

    // Safe access to current slots
    int currentPactSlots = 0;
    if (pactSlotLevel > 0 && pactSlotLevel <= widget.character.spellSlots.length) {
       currentPactSlots = widget.character.spellSlots[pactSlotLevel - 1];
    } else {
       currentPactSlots = maxPactSlots; 
    }

    const warlockColor = Colors.deepPurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Row: Slot Level & Short Rest
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (l10n.localeName == 'ru' ? "МАГИЯ ДОГОВОРА" : "PACT MAGIC").toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: warlockColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "$pactSlotLevel",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (l10n.localeName == 'ru' ? "УРОВЕНЬ" : "LEVEL"),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Short Rest Button (Compact)
            TextButton.icon(
              onPressed: () => _performShortRest(context, l10n),
              icon: const Icon(Icons.fireplace_outlined, size: 18),
              label: Text((l10n.localeName == 'ru' ? "Отдых" : "Short Rest")),
              style: TextButton.styleFrom(
                foregroundColor: warlockColor,
                backgroundColor: warlockColor.withOpacity(0.1),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),

        // Slots Row (Smaller, Elegant)
        Row(
          mainAxisAlignment: MainAxisAlignment.start, // Align left or center? Center is better for limited count.
          children: List.generate(maxPactSlots, (index) {
            final isAvailable = index < currentPactSlots;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildSmallPactSlot(
                  context, isAvailable, pactSlotLevel, warlockColor),
            );
          }),
        ),

        // Mystic Arcanum (if 11+)
        if (widget.character.level >= 11) ...[
          const SizedBox(height: 24),
          _buildMysticArcanumSection(context, l10n, warlockColor),
        ],
      ],
    );
  }

  Widget _buildSmallPactSlot(
      BuildContext context, bool isAvailable, int level, Color warlockColor) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isAvailable) {
          widget.character.useSpellSlot(level);
        } else {
          widget.character.restoreSpellSlot(level);
        }
        widget.onChanged();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isAvailable
              ? warlockColor
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isAvailable ? warlockColor : colorScheme.outline.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: warlockColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Icon(
            Icons.bolt,
            size: 24,
            color: isAvailable ? Colors.white : colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildMysticArcanumSection(
      BuildContext context, AppLocalizations l10n, Color warlockColor) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Define Arcanum levels
    final levels = <int>[];
    if (widget.character.level >= 11) levels.add(6);
    if (widget.character.level >= 13) levels.add(7);
    if (widget.character.level >= 15) levels.add(8);
    if (widget.character.level >= 17) levels.add(9);

    if (levels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_fix_high, size: 16, color: colorScheme.secondary),
            const SizedBox(width: 8),
            Text(
              (l10n.localeName == 'ru' ? "ТАИНСТВЕННЫЙ АРКАНУМ" : "MYSTIC ARCANUM")
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: levels.map((level) {
            // Find or Create Feature for this level
            // We use a consistent ID format so we can find it again.
            final arcanumId = 'mystic_arcanum_${level}th';
            var feature = widget.character.features.firstWhere(
              (f) => f.id == arcanumId,
              orElse: () {
                // If not found, look for generic ones or create new
                return widget.character.features.firstWhere(
                  (f) => (f.nameEn ?? '').contains('Mystic Arcanum') && 
                         (f.nameEn ?? '').contains('${level}th'),
                  orElse: () {
                     // Create a transient feature if missing from data
                     // In a real app, we might want to add this to the character properly,
                     // but here we just need it for state tracking.
                     // BETTER: Add it to character if missing so state persists!
                     final newFeature = CharacterFeature(
                       id: arcanumId,
                       nameEn: 'Mystic Arcanum ($level${_getOrdinal(level)} level)',
                       nameRu: 'Таинственный Арканум ($level круг)',
                       descriptionEn: 'Cast a $level-level spell once without a slot.',
                       descriptionRu: 'Заклинание $level-го уровня без ячейки.',
                       type: FeatureType.resourcePool,
                       minLevel: (level - 1) * 2 + 1, // approx
                       resourcePool: ResourcePool(
                         currentUses: 1, 
                         maxUses: 1, 
                         recoveryType: RecoveryType.longRest
                       ), 
                     );
                     // We can't easily add to the list during build.
                     // We will use a "virtual" feature logic or rely on existing ones.
                     // The prompt implies "UI is dead", meaning features might exist but not work.
                     // Let's assume for safety we return this unattached feature 
                     // and handle state by finding it again in the list or adding it.
                     return newFeature;
                  }
                );
              }
            );

            // Ensure Resource Pool exists
            if (feature.resourcePool == null) {
              feature.resourcePool = ResourcePool(
                currentUses: 1, 
                maxUses: 1, 
                recoveryType: RecoveryType.longRest
              );
            }

            final pool = feature.resourcePool!;
            final isAvailable = pool.currentUses > 0;

            return GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  // Toggle state for UI feeling
                  if (isAvailable) {
                     pool.currentUses = 0;
                  } else {
                     pool.currentUses = 1;
                  }
                  
                  // Ensure feature is in character list if it was generated
                  if (!widget.character.features.contains(feature)) {
                    widget.character.features.add(feature);
                  }
                  
                  widget.character.save();
                  widget.onChanged();
                });
              },
              onLongPress: () {
                 // Reset
                 setState(() {
                   pool.currentUses = 1;
                   if (!widget.character.features.contains(feature)) {
                    widget.character.features.add(feature);
                   }
                   widget.character.save();
                   widget.onChanged();
                 });
              },
              child: _buildArcanumNode(context, level, isAvailable, warlockColor),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getOrdinal(int number) {
    if (number == 1) return 'st';
    if (number == 2) return 'nd';
    if (number == 3) return 'rd';
    return 'th';
  }

  void _showArcanumCastDialog(BuildContext context, CharacterFeature feature, int level, Color color, AppLocalizations l10n) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.localeName == 'ru' ? "Использовать Арканум?" : "Use Arcanum?"),
          content: Text(l10n.localeName == 'ru' 
             ? "Вы можете использовать это заклинание $level-го уровня один раз без траты ячейки." 
             : "You can cast this $level-th level spell once without expending a spell slot."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () {
                setState(() {
                  feature.resourcePool?.use(1);
                  widget.character.save();
                  widget.onChanged();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.localeName == 'ru' ? "Арканум использован!" : "Arcanum used!")));
              }, 
              child: Text(l10n.castSpell)
            ),
          ],
        ),
      );
  }

  void _showArcanumDetails(BuildContext context, CharacterFeature feature) {
      // Simple details for now, as linking to specific spell ID is hard without more data
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(feature.getName(Localizations.localeOf(context).languageCode)),
          content: Text(feature.getDescription(Localizations.localeOf(context).languageCode)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
        ),
      );
  }

  Widget _buildArcanumNode(
      BuildContext context, int level, bool isAvailable, Color warlockColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final romanNumerals = {6: 'VI', 7: 'VII', 8: 'VIII', 9: 'IX'};

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isAvailable ? warlockColor : colorScheme.surfaceContainerHighest.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: isAvailable ? warlockColor : colorScheme.outline.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: isAvailable 
              ? [BoxShadow(color: warlockColor.withOpacity(0.3), blurRadius: 10)] 
              : [],
          ),
          child: Center(
            child: Text(
              romanNumerals[level] ?? '$level',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isAvailable ? Colors.white : colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${level}th",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colorScheme.outline,
          ),
        ),
      ],
    );
  }

  void _performShortRest(BuildContext context, AppLocalizations l10n) {
    HapticFeedback.heavyImpact();
    setState(() {
      widget.character.shortRest();
      // Logic inside Character model should handle slots now, 
      // but we force a state refresh here.
      widget.character.save();
      widget.onChanged();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.localeName == 'ru'
            ? "Короткий отдых завершен. Ячейки восстановлены!"
            : "Short rest completed. Slots restored!"),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildIconsMode(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final maxSlots = widget.character.maxSpellSlots;
    final currentSlots = widget.character.spellSlots;

    List<Widget> rows = [];

    for (int i = 0; i < maxSlots.length; i++) {
      final level = i + 1;
      final max = maxSlots[i];
      if (max <= 0) continue;

      final current = i < currentSlots.length ? currentSlots[i] : 0;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Level Label
              SizedBox(
                width: 50,
                child: Text(
                  l10n.lvlShort(level).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),

              // Slots
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(max, (index) {
                    final isAvailable = index < current;

                    return GestureDetector(
                      onTap: () {
                        if (isAvailable) {
                          widget.character.useSpellSlot(level);
                        } else {
                          widget.character.restoreSpellSlot(level);
                        }
                        widget.onChanged();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isAvailable
                                ? colorScheme.primary
                                : colorScheme.outline,
                            width: 2,
                          ),
                          boxShadow: isAvailable
                              ? [
                                  BoxShadow(
                                    color: colorScheme.primary
                                        .withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Icon(
                          Icons.bolt,
                          size: 20,
                          color: isAvailable
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: rows,
    );
  }

  Widget _buildCompactMode(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final maxSlots = widget.character.maxSpellSlots;
    final currentSlots = widget.character.spellSlots;

    List<Widget> chips = [];

    for (int i = 0; i < maxSlots.length; i++) {
      final level = i + 1;
      final max = maxSlots[i];
      if (max <= 0) continue;

      final current = i < currentSlots.length ? currentSlots[i] : 0;
      final isFull = current == max;
      final isEmpty = current == 0;

      chips.add(
        ActionChip(
          avatar: CircleAvatar(
            backgroundColor: isEmpty
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer,
            child: Text(
              '$level',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isEmpty
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          label: Text(
            '$current / $max',
            style: TextStyle(
              fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
              color: isEmpty ? colorScheme.error : null,
            ),
          ),
          backgroundColor:
              isEmpty ? colorScheme.errorContainer.withOpacity(0.2) : null,
          side: isEmpty
              ? BorderSide(color: colorScheme.error.withOpacity(0.5))
              : null,
          onPressed: () {
            // Tap to Use
            if (current > 0) {
              widget.character.useSpellSlot(level);
              widget.onChanged();

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      l10n.spellCastLevelSuccess(l10n.levelSlot(level), level)),
                  duration: const Duration(milliseconds: 1000),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.noSlotsAvailable),
                  backgroundColor: colorScheme.error,
                  duration: const Duration(milliseconds: 1000),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          tooltip:
              '${l10n.levelSlot(level)}: Tap to Use, Long Press to Restore',
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...maxSlots.asMap().entries.where((e) => e.value > 0).map((entry) {
          final index = entry.key;
          final max = entry.value;
          final level = index + 1;
          final current = index < currentSlots.length ? currentSlots[index] : 0;
          final isEmpty = current == 0;

          return InkWell(
            onTap: () {
              if (current > 0) {
                widget.character.useSpellSlot(level);
                widget.onChanged();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.noSlotsAvailable),
                    backgroundColor: colorScheme.error));
              }
            },
            onLongPress: () {
              if (current < max) {
                widget.character.restoreSpellSlot(level);
                widget.onChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Restored Level $level Slot")));
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                  color: isEmpty
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isEmpty ? colorScheme.error : colorScheme.primary,
                      width: 1)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Text('$level',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$current / $max',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isEmpty
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
