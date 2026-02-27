import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../core/models/class_data.dart';

class ClericMagicWidget extends StatefulWidget {
  final Character character;
  final VoidCallback onStateChanged;

  const ClericMagicWidget({
    super.key,
    required this.character,
    required this.onStateChanged,
  });

  @override
  State<ClericMagicWidget> createState() => _ClericMagicWidgetState();
}

class _ClericMagicWidgetState extends State<ClericMagicWidget> {
  String _getLocalizedSubclass(AppLocalizations l10n, String? subclass) {
    if (subclass == null) return l10n.divineDomain;
    final lower = subclass.toLowerCase();
    if (lower.contains('life')) return l10n.domainLife;
    if (lower.contains('light')) return l10n.domainLight;
    if (lower.contains('knowledge')) return l10n.domainKnowledge;
    if (lower.contains('nature')) return l10n.domainNature;
    if (lower.contains('tempest')) return l10n.domainTempest;
    if (lower.contains('trickery')) return l10n.domainTrickery;
    if (lower.contains('war')) return l10n.domainWar;
    if (lower.contains('death')) return l10n.domainDeath;
    return subclass;
  }

  void _showCDRules() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.channelDivinity.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.channelDivinityRules,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTurnUndeadRules() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final level = widget.character.level;

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Row(
                children: [
                  Icon(Icons.security, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (level >= 5 ? l10n.destroyUndead : l10n.turnUndead)
                          .toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                l10n.turnUndeadRules,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              if (level >= 5) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.destroyUndeadRules,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDIRules() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Row(
                children: [
                  Icon(Icons.brightness_high,
                      color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.divineIntervention.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.divineInterventionRules,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final clericColor = theme.colorScheme.primary;
    final maxCharges = widget.character.getMaxChannelDivinityCharges();

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
            // 1. Divine Domain Block
            if (widget.character.subclass != null) ...[
              _buildDomainBlock(context, theme, l10n, clericColor),
            ],

            // 2. Channel Divinity Block (Includes Turn Undead)
            if (maxCharges > 0) ...[
              const SizedBox(height: 12),
              _buildChannelDivinityBlock(
                  context, theme, l10n, clericColor, maxCharges),
            ],

            // 3. Divine Intervention Block
            if (widget.character.level >= 10) ...[
              const SizedBox(height: 12),
              _buildDivineInterventionBlock(context, theme, l10n, clericColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDomainBlock(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
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

            final description =
                subclassData?.getDescription(locale) ?? l10n.noFeaturesAtLevel1;

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
                              Icon(Icons.brightness_7,
                                  color: accentColor, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _getLocalizedSubclass(
                                      l10n, widget.character.subclass),
                                  style: theme.textTheme.headlineSmall
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
                Icon(Icons.brightness_7, color: accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.divineDomain,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _getLocalizedSubclass(l10n, widget.character.subclass),
                        style: theme.textTheme.titleMedium?.copyWith(
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

  Widget _buildChannelDivinityBlock(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
    int maxCharges,
  ) {
    final colorScheme = theme.colorScheme;
    final currentCharges = widget.character.channelDivinityCharges;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            InkWell(
              onTap: _showCDRules,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: accentColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.channelDivinity,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '$currentCharges / $maxCharges',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: currentCharges == 0
                            ? colorScheme.error
                            : accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.info_outline,
                        size: 16, color: colorScheme.outline),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),

            // Star Resource Pool
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxCharges, (index) {
                  final isActive = index < currentCharges;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          if (isActive) {
                            widget.character.channelDivinityCharges--;
                          } else {
                            widget.character.channelDivinityCharges++;
                          }
                          widget.character.save();
                          widget.onStateChanged();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? accentColor.withOpacity(0.15)
                              : colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? accentColor
                                : colorScheme.outline.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.star,
                          color: isActive
                              ? accentColor
                              : colorScheme.outline.withOpacity(0.3),
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Nested Ability Tiles
            if (widget.character.level >= 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildTurnUndeadTile(context, theme, l10n, accentColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnUndeadTile(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    final colorScheme = theme.colorScheme;
    final level = widget.character.level;
    final currentCharges = widget.character.channelDivinityCharges;

    String name = l10n.turnUndead;
    String? crText;

    if (level >= 5) {
      name = l10n.destroyUndead;
      String cr = "1/2";
      if (level >= 17) {
        cr = "4";
      } else if (level >= 14) {
        cr = "3";
      } else if (level >= 11) {
        cr = "2";
      } else if (level >= 8) {
        cr = "1";
      }
      crText = "${l10n.maxCR}: $cr";
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _showTurnUndeadRules,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.security, size: 20, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (crText != null)
                      Text(
                        crText,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.auto_fix_high),
                onPressed: currentCharges > 0
                    ? () {
                        HapticFeedback.heavyImpact();
                        setState(() {
                          widget.character.channelDivinityCharges--;
                          widget.character.save();
                          widget.onStateChanged();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.usedChannelDivinity),
                            backgroundColor: colorScheme.secondary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : null,
                color: accentColor,
                tooltip: l10n.useAction,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivineInterventionBlock(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    Color accentColor,
  ) {
    final colorScheme = theme.colorScheme;
    final isUsed = widget.character.divineInterventionUsed;
    final level = widget.character.level;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: _showDIRules,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.brightness_high, color: accentColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.divineIntervention,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Icon(Icons.info_outline,
                        size: 16, color: colorScheme.outline),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: isUsed
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            widget.character.divineInterventionUsed = false;
                            widget.character.save();
                            widget.onStateChanged();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.resetCooldown),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.secondary,
                          side: BorderSide(color: colorScheme.secondary),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _handleInterventionRoll(
                            context, level, l10n, colorScheme),
                        icon: const Icon(Icons.casino),
                        label: Text(l10n.callUponDeity.toUpperCase()),
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleInterventionRoll(BuildContext context, int level,
      AppLocalizations l10n, ColorScheme colorScheme) {
    HapticFeedback.heavyImpact();
    final roll = Random().nextInt(100) + 1;
    final isSuccess = level >= 20 || roll <= level;

    if (isSuccess) {
      setState(() {
        widget.character.divineInterventionUsed = true;
        widget.character.save();
        widget.onStateChanged();
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Icon Header
              Icon(
                isSuccess ? Icons.wb_sunny : Icons.nights_stay,
                size: 64,
                color: isSuccess ? colorScheme.secondary : colorScheme.outline,
              ),
              const SizedBox(height: 16),

              // 2. Status Title
              Text(
                (isSuccess
                        ? l10n.interventionSuccess
                        : l10n.interventionFailure)
                    .toUpperCase(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isSuccess
                          ? colorScheme.secondary
                          : colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 24),

              // 3. GIANT ROLL NUMBER
              Text(
                '$roll',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 80,
                      color: isSuccess
                          ? colorScheme.secondary
                          : colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n
                    .interventionRollResult(roll)
                    .split(':')
                    .first
                    .toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2,
                      color: colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 32),

              // 4. Thematic Message
              Text(
                isSuccess
                    ? (Localizations.localeOf(context).languageCode == 'ru'
                        ? "Ваша мольба услышана!"
                        : "Your prayer was heard!")
                    : (Localizations.localeOf(context).languageCode == 'ru'
                        ? "Тишина в ответ..."
                        : "Only silence follows..."),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),

              // 5. Action Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: isSuccess
                        ? colorScheme.secondary
                        : colorScheme.secondaryContainer,
                    foregroundColor: isSuccess
                        ? colorScheme.onSecondary
                        : colorScheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    (Localizations.localeOf(context).languageCode == 'ru'
                            ? "ПРИНЯТЬ ВОЛЮ БОГОВ"
                            : "ACCEPT DIVINE WILL")
                        .toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
