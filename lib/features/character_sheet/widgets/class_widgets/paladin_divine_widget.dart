import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import '../../../../l10n/app_localizations.dart';

class PaladinDivineWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature layOnHands;
  final CharacterFeature? divineSense;
  final CharacterFeature? channelDivinityResource;
  final List<CharacterFeature> channelDivinitySpells;
  final VoidCallback? onChanged;

  const PaladinDivineWidget({
    super.key,
    required this.character,
    required this.layOnHands,
    this.divineSense,
    this.channelDivinityResource,
    this.channelDivinitySpells = const [],
    this.onChanged,
  });

  @override
  State<PaladinDivineWidget> createState() => _PaladinDivineWidgetState();
}

class _PaladinDivineWidgetState extends State<PaladinDivineWidget> {
  bool _isChannelActive = false;

  String _getLocalizedSubclass(AppLocalizations l10n, String? subclass) {
    if (subclass == null) return l10n.sacredOath;
    final lower = subclass.toLowerCase();
    if (lower.contains('devotion')) return l10n.oathDevotion;
    if (lower.contains('ancients')) return l10n.oathAncients;
    if (lower.contains('vengeance')) return l10n.oathVengeance;
    if (lower.contains('conquest')) return l10n.oathConquest;
    if (lower.contains('redemption')) return l10n.oathRedemption;
    return subclass;
  }

  @override
  void initState() {
    super.initState();
    if (widget.channelDivinityResource?.resourcePool != null) {
      _isChannelActive =
          widget.channelDivinityResource!.resourcePool!.currentUses > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // --- PALETTE MAPPING ---
    final orangeAccent = colorScheme.primary;
    final beigeAccent = colorScheme.secondary;
    final onBeige = colorScheme.onSecondary;

    // Explicit background for inner blocks to visually separate them
    final blockBg = colorScheme.surfaceContainerHighest;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outline, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- BLOCK 0: SUBCLASS (OATH) ---
            if (widget.character.subclass != null) ...[
              _buildSubclassBlock(context, colorScheme, orangeAccent),
              const SizedBox(height: 12),
            ],

            // --- BLOCK 1: LAY ON HANDS ---
            _buildBlockContainer(
              color: blockBg,
              onTap: () => _showDetails(widget.layOnHands),
              // Padding inside the block for content
              padding: const EdgeInsets.all(12),
              child: _buildLayOnHandsContent(
                  context, colorScheme, orangeAccent, beigeAccent, onBeige),
            ),

            const SizedBox(height: 12),

            // --- BLOCK 2: DIVINE SENSE ---
            if (widget.divineSense != null) ...[
              _buildBlockContainer(
                color: blockBg,
                onTap: () => _showDetails(widget.divineSense!),
                padding: const EdgeInsets.all(12),
                child: _buildDivineSenseContent(
                    context, colorScheme, orangeAccent, beigeAccent, onBeige),
              ),
              const SizedBox(height: 12),
            ],

            // --- BLOCK 3: CHANNEL DIVINITY ---
            if (widget.channelDivinityResource != null) ...[
              // Special container logic for the "Full Width Header"
              Container(
                decoration: BoxDecoration(
                  color: blockBg,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                ),
                // CRITICAL: AntiAlias clip ensures the header's top corners match the container's
                clipBehavior: Clip.antiAlias,
                child: _buildChannelDivinityContent(
                    context, colorScheme, beigeAccent, onBeige, orangeAccent),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  /// Helper to create the visual "tiles"
  Widget _buildBlockContainer({
    required Color color,
    required Widget child,
    required EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. LAY ON HANDS CONTENT
  // ===========================================================================
  Widget _buildLayOnHandsContent(BuildContext context, ColorScheme colorScheme,
      Color barColor, Color btnColor, Color onBtnColor) {
    final pool = widget.layOnHands.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final calculatedMax = widget.character.level * 5;
    final max = calculatedMax > 0
        ? calculatedMax
        : (pool.maxUses > 0 ? pool.maxUses : 5);
    final current = pool.currentUses.clamp(0, max);
    final progress = max > 0 ? current / max : 0.0;

    final locale = Localizations.localeOf(context).languageCode;
    final featureName = widget.layOnHands.getName(locale).toUpperCase();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.favorite, color: barColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  featureName,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurfaceVariant),
                ),
              ),
              Icon(Icons.info_outline,
                  size: 16, color: colorScheme.outline.withValues(alpha: 0.5)),
            ],
          ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$current / $max',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface),
          ),
        ),

        const SizedBox(height: 6),

        // Progress Bar
        GestureDetector(
          onTap: () => _showCustomHealDialog(context, pool, max),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutQuart,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 14,
                  backgroundColor: colorScheme.surfaceDim,
                  valueColor: AlwaysStoppedAnimation(barColor),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildTonalBtn(
                context,
                "-1",
                () => _modifyPool(pool, -1, maxOverride: max),
                current >= 1,
                btnColor,
                onBtnColor),
            const SizedBox(width: 8),
            _buildTonalBtn(
                context,
                "-5",
                () => _modifyPool(pool, -5, maxOverride: max),
                current >= 5,
                btnColor,
                onBtnColor),
            const SizedBox(width: 8),
            _buildTonalBtn(
                context,
                "-10",
                () => _modifyPool(pool, -10, maxOverride: max),
                current >= 10,
                btnColor,
                onBtnColor),
            const SizedBox(width: 8),
            // Undo/Reset
            IconButton.filledTonal(
              onPressed: () =>
                  _modifyPool(pool, max - current, maxOverride: max),
              icon: const Icon(Icons.refresh, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceDim,
                foregroundColor: colorScheme.onSurfaceVariant,
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTonalBtn(BuildContext context, String label, VoidCallback onTap,
      bool enabled, Color bg, Color fg) {
    return SizedBox(
      height: 32,
      child: FilledButton(
        onPressed: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: Theme.of(context).colorScheme.surfaceDim,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  // ===========================================================================
  // 2. DIVINE SENSE CONTENT
  // ===========================================================================
  Widget _buildDivineSenseContent(BuildContext context, ColorScheme colorScheme,
      Color dotColor, Color buttonColor, Color onButtonColor) {
    final pool = widget.divineSense?.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context).languageCode;
    final featureName =
        widget.divineSense?.getName(locale).toUpperCase() ?? 'DIVINE SENSE';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.visibility, color: dotColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  featureName,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurfaceVariant),
                ),
              ),
              Icon(Icons.info_outline,
                  size: 16, color: colorScheme.outline.withValues(alpha: 0.5)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Charges
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(pool.maxUses, (index) {
                  final isActive = index < pool.currentUses;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      // Toggle logic: click active dot to spend, click inactive to restore
                      if (isActive) {
                        _modifyPool(pool, -1);
                      } else {
                        _modifyPool(pool, 1);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? dotColor : Colors.transparent,
                        border: Border.all(
                          color: isActive
                              ? dotColor
                              : colorScheme.outline.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Sensor Button
            _DivineSenseSensorButton(
              hasCharges: pool.currentUses > 0,
              backgroundColor: buttonColor,
              iconColor: onButtonColor,
              disabledColor: colorScheme.surfaceDim,
              onTap: () {
                if (pool.currentUses > 0) {
                  _modifyPool(pool, -1);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(locale == 'ru'
                        ? 'Божественное чувство использовано'
                        : 'Divine Sense used'),
                    backgroundColor: dotColor,
                    duration: const Duration(milliseconds: 800),
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        locale == 'ru' ? 'Нет зарядов!' : 'No charges left!'),
                    backgroundColor: colorScheme.error,
                    duration: const Duration(milliseconds: 800),
                  ));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. CHANNEL DIVINITY CONTENT (Fixed Header Width)
  // ===========================================================================
  Widget _buildChannelDivinityContent(
      BuildContext context,
      ColorScheme colorScheme,
      Color activeBg,
      Color activeContent,
      Color iconColor) {
    final pool = widget.channelDivinityResource?.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context).languageCode;
    final featureName =
        widget.channelDivinityResource?.getName(locale).toUpperCase() ??
            'CHANNEL DIVINITY';

    final isActive = _isChannelActive;

    // Header Colors
    final pillColor = isActive ? activeBg : colorScheme.surfaceDim;
    final pillContentColor =
        isActive ? activeContent : colorScheme.onSurfaceVariant;
    final shieldIconColor = isActive ? activeContent : iconColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HEADER: Merged "Cap"
        // Uses Material to handle InkWell splash properly over colored bg
        Material(
          color: pillColor,
          // No rounded corners here on Material itself because the Parent clips it.
          // BUT, we can add bottom radius to create the separation effect from the list.
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: InkWell(
            onTap: () => _showDetails(widget.channelDivinityResource!),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.shield, color: shieldIconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      featureName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: pillContentColor,
                      ),
                    ),
                  ),
                  Icon(Icons.info_outline,
                      size: 16, color: pillContentColor.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  // Switch
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: isActive,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isChannelActive = val;
                          pool.currentUses = val ? 1 : 0;
                          widget.character.save();
                          widget.onChanged?.call();
                        });
                      },
                      activeThumbColor: colorScheme.onSecondary,
                      activeTrackColor:
                          colorScheme.onSecondary.withValues(alpha: 0.15),
                      inactiveThumbColor:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      inactiveTrackColor: Colors.transparent,
                      trackOutlineColor:
                          WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return colorScheme.onSecondary;
                        }
                        return colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Spells List
        // Note: Padding is added HERE, not on the container, to push content in
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isActive ? 1.0 : 0.5,
          child: IgnorePointer(
            ignoring: !isActive,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: widget.channelDivinitySpells.map((f) {
                  return _buildSpellTile(context, f, colorScheme, activeBg,
                      activeContent, locale, pool);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpellTile(
      BuildContext context,
      CharacterFeature feature,
      ColorScheme colorScheme,
      Color buttonBg,
      Color buttonContent,
      String locale,
      ResourcePool pool) {
    final name = feature.getName(locale);
    final icon = _getSmartIcon(name, feature.iconName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetails(feature),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface),
                  ),
                ),
                // Compact Action Button (Icon Only)
                SizedBox(
                  width: 48,
                  height: 36,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _useChannelDivinity(pool, name);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: buttonContent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.auto_fix_high, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Logic Helpers ---

  void _showDetails(CharacterFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(feature: feature),
    );
  }

  void _showCustomHealDialog(BuildContext context, ResourcePool pool, int max) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Custom Heal Amount"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: "HP to spend"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                _modifyPool(pool, -amount, maxOverride: max);
              }
              Navigator.pop(context);
            },
            child: const Text("Heal"),
          ),
        ],
      ),
    );
  }

  void _modifyPool(ResourcePool pool, int amount, {int? maxOverride}) {
    HapticFeedback.lightImpact();
    setState(() {
      final effectiveMax = maxOverride ?? pool.maxUses;
      final newCurrent = (pool.currentUses + amount).clamp(0, effectiveMax);
      pool.currentUses = newCurrent;
      if (maxOverride != null && pool.maxUses != maxOverride) {
        pool.maxUses = maxOverride;
      }
      widget.character.save();
      widget.onChanged?.call();
    });
  }

  void _useChannelDivinity(ResourcePool pool, String featureName) {
    if (pool.currentUses > 0) {
      setState(() {
        pool.use(1);
        _isChannelActive = false;
        widget.character.save();
        widget.onChanged?.call();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$featureName used!'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  IconData _getSmartIcon(String name, String? iconName) {
    final lower = name.toLowerCase();
    if (lower.contains('weapon') || lower.contains('оружие')) {
      return Icons.colorize;
    }
    if (lower.contains('turn') || lower.contains('изгнание')) {
      return Icons.security;
    }
    if (lower.contains('heal') || lower.contains('исцел')) {
      return Icons.local_hospital;
    }
    if (lower.contains('hammer') || lower.contains('молот')) return Icons.gavel;
    return Icons.auto_awesome;
  }

  Widget _buildSubclassBlock(
      BuildContext context, ColorScheme colorScheme, Color accentColor) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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

            final description =
                subclassData?.getDescription(locale) ?? l10n.noFeaturesAtLevel1;
            final subclassDisplay =
                _getLocalizedSubclass(l10n, widget.character.subclass);

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
                          color: colorScheme.surface,
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
                                  color: colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(children: [
                              Icon(Icons.gavel, color: accentColor, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  subclassDisplay,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ));
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.gavel, color: accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sacredOath,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        _getLocalizedSubclass(l10n, widget.character.subclass),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Internal Widget: Divine Sense Pulse Button ---

class _DivineSenseSensorButton extends StatefulWidget {
  final bool hasCharges;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final Color disabledColor;

  const _DivineSenseSensorButton({
    required this.hasCharges,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    required this.disabledColor,
  });

  @override
  State<_DivineSenseSensorButton> createState() =>
      _DivineSenseSensorButtonState();
}

class _DivineSenseSensorButtonState extends State<_DivineSenseSensorButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _controller.forward(from: 0.0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.hasCharges
                ? widget.backgroundColor
                : widget.disabledColor,
            boxShadow: widget.hasCharges
                ? [
                    BoxShadow(
                        color: widget.backgroundColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1)
                  ]
                : [],
          ),
          child: Icon(Icons.remove_red_eye,
              size: 28,
              color: widget.hasCharges ? widget.iconColor : Colors.white38),
        ),
      ),
    );
  }
}