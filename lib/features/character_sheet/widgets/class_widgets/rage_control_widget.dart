import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';

class RageControlWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature rageFeature;
  final VoidCallback? onChanged;

  const RageControlWidget({
    super.key,
    required this.character,
    required this.rageFeature,
    this.onChanged,
  });

  @override
  State<RageControlWidget> createState() => _RageControlWidgetState();
}

class _RageControlWidgetState extends State<RageControlWidget> {
  bool _isRaging = false;
  bool _isReckless = false;

  void _showFeatureDetails(CharacterFeature feature, IconData icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(
        feature: feature,
        // no backgroundColor here, just let it use theme surface
      ),
    );
  }

  void _showSubclassLore(BuildContext context) async {
    final subclassId = widget.character.subclass ?? '';
    if (subclassId.isEmpty) return;

    try {
      final subclassData = await CharacterDataService.getSubclass(
        widget.character.characterClass,
        subclassId,
      );

      if (subclassData == null || !context.mounted) return;

      final locale = Localizations.localeOf(context).languageCode;
      final name = subclassData.getName(locale);
      final desc = subclassData.getDescription(locale);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 24),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.terrain,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        desc,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('Error loading subclass lore: $e');
    }
  }

  int _getRageDamage(int level) {
    if (level >= 16) return 4;
    if (level >= 9) return 3;
    return 2;
  }

  int _getMaxRage(int level) {
    if (level >= 20) return 99; // Unlimited
    if (level >= 17) return 6;
    if (level >= 12) return 5;
    if (level >= 6) return 4;
    if (level >= 3) return 3;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    final pool = widget.rageFeature.resourcePool;
    if (pool != null && pool.currentUses == 0) {
      final correctMax = _getMaxRage(widget.character.level);
      if (pool.maxUses != correctMax && correctMax < 99) {
        pool.maxUses = correctMax;
      }
      pool.restoreFull();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.character.save();
      });
    }
  }

  void _toggleRage(bool value) {
    final l10n = AppLocalizations.of(context)!;
    final pool = widget.rageFeature.resourcePool;
    // NUCLEAR OPTION: Safety check
    if (pool == null) return;

    final level = widget.character.level;
    final maxRage = _getMaxRage(level);
    final isUnlimited = maxRage >= 99;

    final locale = Localizations.localeOf(context).languageCode;
    final usedText = locale == 'ru' ? 'использована!' : 'used!';
    final unlimText = locale == 'ru' ? '(Бесконечно)' : '(Unlimited)';

    if (value) {
      // Trying to enter rage
      if (pool.currentUses > 0 || isUnlimited) {
        setState(() {
          _isRaging = true;
          if (!isUnlimited) {
            pool.use(1);
          }
          widget.character.save();
          widget.onChanged?.call();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUnlimited
                ? '${l10n.rage} $usedText $unlimText'
                : '${l10n.rage} $usedText (-1)'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale == 'ru'
                ? 'Нет зарядов Ярости!'
                : 'No Rage charges left!'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Ending rage
      setState(() {
        _isRaging = false;
        _isReckless = false; // Turn off reckless upon dropping rage
      });
    }
  }

  void _executeQuickAction(
      CharacterFeature feature, int maxUses, String locale) {
    HapticFeedback.heavyImpact();
    // Doesn't cost anything for now, Frenzy just happens.
    final usedText = locale == 'ru' ? 'использовано!' : 'used!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${feature.getName(locale)} $usedText'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildActionTile(CharacterFeature? feature, IconData fallBackIcon,
      String locale, ThemeData theme) {
    if (feature == null) return const SizedBox.shrink();
    final cleanName =
        feature.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), '');

    IconData icon = fallBackIcon;
    final nid = (feature.id ?? '').toLowerCase();
    final nname = (feature.nameEn ?? '').toLowerCase();
    if (nid.contains('frenzy') || nname.contains('frenzy'))
      icon = Icons.mood_bad;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showFeatureDetails(feature, icon),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(icon, color: theme.colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cleanName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 36,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _executeQuickAction(feature, 0, locale),
                      child: const Icon(Icons.flash_on, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.rageFeature.resourcePool;
    // NUCLEAR OPTION: Crash Prevention
    if (pool == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final level = widget.character.level;
    final rageDamage = _getRageDamage(level);
    final maxRage = _getMaxRage(level);
    final isUnlimited = maxRage >= 99;

    final activeColor = colorScheme.error;
    final cardColor = _isRaging
        ? activeColor.withOpacity(0.15)
        : colorScheme.surfaceContainerHighest;
    final borderColor = _isRaging
        ? activeColor.withOpacity(0.5)
        : colorScheme.outline.withOpacity(0.3);
    final textColor = _isRaging ? activeColor : colorScheme.onSurface;
    final String locale = Localizations.localeOf(context).languageCode;

    // Localize subclass name
    String subclassDisplayName = widget.character.subclass ?? '';
    final classData =
        CharacterDataService.getClassById(widget.character.characterClass);
    if (classData != null && subclassDisplayName.isNotEmpty) {
      final nid = subclassDisplayName.toLowerCase().trim();
      final targetSubclass = classData.subclasses
          .where((s) =>
              s.id == nid || s.name.values.any((v) => v.toLowerCase() == nid))
          .firstOrNull;
      if (targetSubclass != null) {
        subclassDisplayName = targetSubclass.getName(locale);
      }
    }

    // Find Reckless Attack
    final recklessFeature = widget.character.features
        .where((f) => (f.id ?? '').toLowerCase().contains('reckless'))
        .firstOrNull;

    // Find Frenzy
    final frenzyFeature = widget.character.features
        .where((f) => (f.id ?? '').toLowerCase().contains('frenzy'))
        .firstOrNull;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subclass Block
            if ((widget.character.subclass ?? '').isNotEmpty) ...[
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.outline.withOpacity(0.2)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showSubclassLore(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.terrain,
                                size: 18, color: colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locale == 'ru'
                                      ? 'Первобытный Путь'
                                      : 'Primal Path',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  subclassDisplayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: colorScheme.onSurfaceVariant
                                  .withOpacity(0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Rage Dashboard
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: borderColor, width: _isRaging ? 2 : 1),
                boxShadow: _isRaging
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Header Row: Icon, Title, Switch
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isRaging
                                ? activeColor
                                : colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.whatshot,
                            color: _isRaging
                                ? colorScheme.onError
                                : colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.rage.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      letterSpacing: 1.0,
                                    ),
                              ),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                      color: _isRaging
                                          ? activeColor
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                child: Text(_isRaging
                                    ? l10n.raging.toUpperCase()
                                    : l10n.rageInactive.toUpperCase()),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isRaging,
                          onChanged: _toggleRage,
                          activeThumbColor: activeColor,
                          activeTrackColor: activeColor.withOpacity(0.4),
                          inactiveThumbColor: colorScheme.outline,
                          inactiveTrackColor:
                              colorScheme.surfaceContainerHighest,
                          trackOutlineColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.transparent
                                  : colorScheme.outlineVariant),
                          thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                              (states) => states.contains(WidgetState.selected)
                                  ? const Icon(Icons.whatshot,
                                      size: 16, color: Colors.white)
                                  : null),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Divider(height: 1, color: borderColor.withOpacity(0.5)),
                    const SizedBox(height: 16),

                    // Stats Row: Usages & Damage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rage Charges (Flames)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.resources.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isRaging
                                      ? colorScheme.error
                                      : colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              isUnlimited
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: Icon(Icons.all_inclusive,
                                          color: _isRaging
                                              ? activeColor
                                              : colorScheme.primary,
                                          size: 28),
                                    )
                                  : Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: List.generate(maxRage, (index) {
                                        final isActive =
                                            index < pool.currentUses;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isActive) {
                                                pool.use(
                                                    pool.currentUses - index);
                                              } else {
                                                pool.restore(index -
                                                    pool.currentUses +
                                                    1);
                                              }
                                              widget.character.save();
                                            });
                                            HapticFeedback.lightImpact();
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? (_isRaging
                                                      ? activeColor
                                                          .withOpacity(0.2)
                                                      : colorScheme.primary
                                                          .withOpacity(0.1))
                                                  : Colors.transparent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isActive
                                                    ? (_isRaging
                                                        ? activeColor
                                                        : colorScheme.primary)
                                                    : colorScheme.outline
                                                        .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Icon(
                                                Icons.local_fire_department,
                                                size: 20,
                                                color: isActive
                                                    ? (_isRaging
                                                        ? activeColor
                                                        : colorScheme.primary)
                                                    : colorScheme.outline
                                                        .withOpacity(0.3)),
                                          ),
                                        );
                                      }),
                                    ),
                            ],
                          ),
                        ),

                        // Rage Damage Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isRaging
                                ? activeColor
                                : colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isRaging
                                ? [
                                    BoxShadow(
                                        color: activeColor.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2))
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isRaging) ...[
                                Icon(Icons.check_circle,
                                    size: 14, color: colorScheme.onError),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '+$rageDamage',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _isRaging
                                      ? colorScheme.onError
                                      : colorScheme.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                locale == 'ru' ? 'УРОН' : 'DMG',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isRaging
                                      ? colorScheme.onError.withOpacity(0.8)
                                      : colorScheme.onSecondaryContainer
                                          .withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Quick Actions (Frenzy)
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart,
              alignment: Alignment.topCenter,
              child: (_isRaging && frenzyFeature != null)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8.0, left: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.flash_on,
                                  size: 16, color: colorScheme.error),
                              const SizedBox(width: 6),
                              Text(
                                locale == 'ru' ? 'В Ярости' : 'While Raging',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildActionTile(frenzyFeature, Icons.mood_bad, locale,
                            Theme.of(context)),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),

            // Reckless Attack
            if (recklessFeature != null) ...[
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: _isReckless
                      ? colorScheme.errorContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _isReckless
                          ? colorScheme.error.withOpacity(0.5)
                          : colorScheme.outline.withOpacity(0.3)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onLongPress: () => _showFeatureDetails(
                        recklessFeature, Icons.warning_amber),
                    onTap: () {
                      setState(() {
                        _isReckless = !_isReckless;
                      });
                      if (_isReckless) HapticFeedback.heavyImpact();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: _isReckless
                                ? colorScheme.onErrorContainer
                                : colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recklessFeature.getName(locale) ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isReckless
                                        ? colorScheme.onErrorContainer
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                if (_isReckless)
                                  Text(
                                    locale == 'ru'
                                        ? 'Преимущество на атаки, но враги бьют с преимуществом'
                                        : 'Advantage on attacks, but enemies have advantage against you',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onErrorContainer
                                          .withOpacity(0.8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isReckless,
                            onChanged: (v) {
                              setState(() {
                                _isReckless = v;
                              });
                              if (v) HapticFeedback.heavyImpact();
                            },
                            activeColor: colorScheme.onErrorContainer,
                            activeTrackColor:
                                colorScheme.onErrorContainer.withOpacity(0.3),
                            inactiveThumbColor: colorScheme.outline,
                            inactiveTrackColor:
                                colorScheme.surfaceContainerHighest,
                            trackOutlineColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.transparent;
                              }
                              return colorScheme.outline;
                            }),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
