import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/services/spellcasting_service.dart';

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
      SpellcastingService.getSpellcastingType(widget.character.characterClass) == 'pact_magic';

  @override
  Widget build(BuildContext context) {
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

  Widget _buildIconsMode(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final maxSlots = widget.character.maxSpellSlots;
    final currentSlots = widget.character.spellSlots;

    List<Widget> rows = [];

    // If Pact Magic, usually all slots are at one specific level, 
    // but the data model might store them in the standard array.
    // We iterate through all levels to be safe.
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
                    // Logic: Slots are consumed. 
                    // If current = 3, max = 4. Indices 0, 1, 2 are "Available". Index 3 is "Used".
                    // Wait, usually currentSlots stores "Remaining".
                    // Example: Max 4, Current 3. 
                    // We want to show 3 filled icons, 1 empty.
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
                              ? (_isPactMagic ? Colors.purple : colorScheme.primary)
                              : colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isAvailable 
                                ? (_isPactMagic ? Colors.purple : colorScheme.primary)
                                : colorScheme.outline,
                            width: 2,
                          ),
                          boxShadow: isAvailable ? [
                            BoxShadow(
                              color: (_isPactMagic ? Colors.purple : colorScheme.primary).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ] : [],
                        ),
                        child: Icon(
                          _isPactMagic ? Icons.auto_awesome : Icons.bolt,
                          size: 20,
                          color: isAvailable ? colorScheme.onPrimary : colorScheme.onSurfaceVariant.withOpacity(0.5),
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
                 color: isEmpty ? colorScheme.onSurfaceVariant : colorScheme.onPrimaryContainer,
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
          backgroundColor: isEmpty ? colorScheme.errorContainer.withOpacity(0.2) : null,
          side: isEmpty ? BorderSide(color: colorScheme.error.withOpacity(0.5)) : null,
          onPressed: () {
            // Tap to Use
            if (current > 0) {
              widget.character.useSpellSlot(level);
              widget.onChanged();
              
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.spellCastLevelSuccess(l10n.levelSlot(level), level)),
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
          tooltip: '${l10n.levelSlot(level)}: Tap to Use, Long Press to Restore',
        ),
      );
    }

    // Wrap allows chips to flow naturally
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Hidden InkWell for Long Press restore logic if needed on individual chips,
        // but ActionChip doesn't natively support onLongPress easily without wrapping.
        // Let's replace ActionChip with a custom InkWell container if we need reliable LongPress.
        // Actually, let's wrap the ActionChip in a GestureDetector to capture LongPress.
        // Note: ActionChip swallows gestures. 
        // Better approach: Use RawChip or FilterChip, or just a custom container.
        
        // Let's stick to standard UI: Tap to Open Dialog? Or just +/-?
        // User requested "Clickable chips". 
        // To support "Restore", I'll add a helper method to build the chip with GestureDetector.
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.noSlotsAvailable), backgroundColor: colorScheme.error)
                    );
                 }
              },
              onLongPress: () {
                if (current < max) {
                   widget.character.restoreSpellSlot(level);
                   widget.onChanged();
                   ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Restored Level $level Slot"))
                    );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: isEmpty ? colorScheme.errorContainer : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isEmpty ? colorScheme.error : colorScheme.primary,
                    width: 1
                  )
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Text('$level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$current / $max',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEmpty ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
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
