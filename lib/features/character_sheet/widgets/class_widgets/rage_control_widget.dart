import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import 'shared/class_tools_layout_builder.dart';

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

class _RageControlWidgetState extends State<RageControlWidget>
    with TickerProviderStateMixin {
  bool _isRaging = false;
  bool _isReckless = false;
  bool _isFrenzied = false;

  late AnimationController _frenzyPulseController;
  late Animation<double> _frenzyGlowAnimation;

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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.terrain,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
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
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.6),
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
    _isRaging = widget.character.isRaging;

    _frenzyPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _frenzyGlowAnimation = Tween<double>(begin: 2.0, end: 8.0).animate(
      CurvedAnimation(parent: _frenzyPulseController, curve: Curves.easeInOut),
    );

    final pool = widget.rageFeature.resourcePool;
    if (pool != null) {
      final correctMax = _getMaxRage(widget.character.level);
      final previousMax = pool.maxUses;
      final wasOutdated = pool.maxUses != correctMax;
      if (wasOutdated) {
        pool.maxUses = correctMax;
      }
      if (wasOutdated && pool.currentUses == previousMax) {
        pool.currentUses = correctMax;
      }
      if (pool.currentUses > pool.maxUses) {
        pool.currentUses = pool.maxUses;
      }
      if (wasOutdated && pool.currentUses == 0) {
        pool.restoreFull();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.character.save();
      });
    }
  }

  @override
  void dispose() {
    _frenzyPulseController.dispose();
    super.dispose();
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
          widget.character.isRaging = true;
          if (!isUnlimited) {
            pool.use(1);
          }
          widget.character.save();
          widget.onChanged?.call();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUnlimited
                  ? '${l10n.rage} $usedText $unlimText'
                  : '${l10n.rage} $usedText (-1)',
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale == 'ru' ? 'Нет зарядов Ярости!' : 'No Rage charges left!',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Clear short-lived rage helpers when rage ends.
      final wasFrenzied = _isFrenzied;
      setState(() {
        _isRaging = false;
        _isReckless = false;
        _isFrenzied = false;
        widget.character.isRaging = false;
      });
      _frenzyPulseController.stop();
      _frenzyPulseController.reverse();

      // Exhaustion penalty for Berserker Frenzy (PHB p.49)
      if (wasFrenzied) {
        widget.character.exhaustionLevel++;
        widget.character.save();
        widget.onChanged?.call();

        if (context.mounted) {
          final isRu = Localizations.localeOf(context).languageCode == 'ru';
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(
                Icons.local_fire_department,
                color: Colors.deepOrange,
                size: 32,
              ),
              title: Text(isRu ? 'Откат Бешенства' : 'Frenzy Exhaustion'),
              content: Text(
                isRu
                    ? 'Ярость спала, оставляя вас без сил.\nВы получаете 1 степень истощения (итого: ${widget.character.exhaustionLevel}).'
                    : 'As the rage subsides, exhaustion sets in.\nYou gain 1 level of exhaustion (total: ${widget.character.exhaustionLevel}).',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isRu ? 'Понятно' : 'Understood'),
                ),
              ],
            ),
          );
        }
      }
    }
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
        ? activeColor.withValues(alpha: 0.15)
        : colorScheme.surfaceContainerHighest;
    final borderColor = _isRaging
        ? activeColor.withValues(alpha: 0.5)
        : colorScheme.outline.withValues(alpha: 0.3);
    final textColor = _isRaging ? activeColor : colorScheme.onSurface;
    final String locale = Localizations.localeOf(context).languageCode;

    // Localize subclass name
    String subclassDisplayName = widget.character.subclass ?? '';
    final classData = CharacterDataService.getClassById(
      widget.character.characterClass,
    );
    if (classData != null && subclassDisplayName.isNotEmpty) {
      final nid = subclassDisplayName.toLowerCase().trim();
      final targetSubclass = classData.subclasses
          .where(
            (s) =>
                s.id == nid || s.name.values.any((v) => v.toLowerCase() == nid),
          )
          .firstOrNull;
      if (targetSubclass != null) {
        subclassDisplayName = targetSubclass.getName(locale);
      }
    }

    // Find Reckless Attack
    final recklessFeature = widget.character.features
        .where((f) => (f.id).toLowerCase().contains('reckless'))
        .firstOrNull;

    // Find Frenzy
    final frenzyFeature = widget.character.features
        .where((f) => (f.id).toLowerCase().contains('frenzy'))
        .firstOrNull;

    final recklessHelperText = _isReckless
        ? (locale == 'ru'
            ? 'Преимущество на атаки Силой до конца хода; враги атакуют вас с преимуществом до следующего хода.'
            : 'Advantage on Strength-based attacks until end of turn; enemies have advantage against you until your next turn.')
        : (locale == 'ru'
            ? 'Не требует Ярости. Используйте для первой рукопашной атаки Силой в свой ход.'
            : 'Does not require Rage. Use it for your first Strength-based melee attack on your turn.');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline, width: 1.5),
      ),
      child: ClassToolsLayoutBuilder(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Subclass Block
          if ((widget.character.subclass ?? '').isNotEmpty)
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showSubclassLore(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.terrain,
                            size: 18,
                            color: colorScheme.primary,
                          ),
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
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Rage Dashboard
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: _isRaging ? 2 : 1),
              boxShadow: _isRaging
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
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
                              child: Text(
                                _isRaging
                                    ? l10n.raging.toUpperCase()
                                    : l10n.rageInactive.toUpperCase(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isRaging,
                        onChanged: _toggleRage,
                        activeThumbColor: activeColor,
                        activeTrackColor: activeColor.withValues(alpha: 0.4),
                        inactiveThumbColor: colorScheme.outline,
                        inactiveTrackColor: colorScheme.surfaceContainerHighest,
                        trackOutlineColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.transparent
                              : colorScheme.outlineVariant,
                        ),
                        thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                          (states) => states.contains(WidgetState.selected)
                              ? const Icon(
                                  Icons.whatshot,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
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
                                      horizontal: 4.0,
                                    ),
                                    child: Icon(
                                      Icons.all_inclusive,
                                      color: _isRaging
                                          ? activeColor
                                          : colorScheme.primary,
                                      size: 28,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: List.generate(maxRage, (index) {
                                      final isActive = index < pool.currentUses;
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (isActive) {
                                              pool.use(
                                                pool.currentUses - index,
                                              );
                                            } else {
                                              pool.restore(
                                                index - pool.currentUses + 1,
                                              );
                                            }
                                            widget.character.save();
                                          });
                                          HapticFeedback.lightImpact();
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? (_isRaging
                                                    ? activeColor.withValues(
                                                        alpha: 0.2,
                                                      )
                                                    : colorScheme.primary
                                                        .withValues(
                                                        alpha: 0.1,
                                                      ))
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isActive
                                                  ? (_isRaging
                                                      ? activeColor
                                                      : colorScheme.primary)
                                                  : colorScheme.outline
                                                      .withValues(alpha: 0.3),
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
                                                    .withValues(alpha: 0.3),
                                          ),
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
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _isRaging
                              ? activeColor
                              : colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isRaging
                              ? [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isRaging) ...[
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: colorScheme.onError,
                              ),
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
                                    ? colorScheme.onError.withValues(alpha: 0.8)
                                    : colorScheme.onSecondaryContainer
                                        .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Frenzy Panel (only visible while raging) ──
                  if (frenzyFeature != null)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubicEmphasized,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: _isRaging
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: AnimatedBuilder(
                                  animation: _frenzyGlowAnimation,
                                  builder: (context, child) {
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeInOut,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        // Card background pulses red when frenzied
                                        color: _isFrenzied
                                            ? colorScheme.errorContainer
                                                .withValues(alpha: 0.45)
                                            : colorScheme.surface.withValues(
                                                alpha: 0.88,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _isFrenzied
                                              ? activeColor
                                              : activeColor.withValues(
                                                  alpha: 0.25,
                                                ),
                                          width: _isFrenzied ? 1.5 : 1,
                                        ),
                                        boxShadow: _isFrenzied
                                            ? [
                                                BoxShadow(
                                                  color: activeColor.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  blurRadius:
                                                      _frenzyGlowAnimation
                                                          .value,
                                                  spreadRadius:
                                                      _frenzyGlowAnimation
                                                              .value /
                                                          3,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onLongPress: () => _showFeatureDetails(
                                      frenzyFeature,
                                      Icons.mood_bad,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          // Animated icon chip
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _isFrenzied
                                                  ? activeColor
                                                  : activeColor.withValues(
                                                      alpha: 0.12,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              // Distinct icons for inactive / active
                                              _isFrenzied
                                                  ? Icons.mood_bad
                                                  : Icons
                                                      .sentiment_dissatisfied,
                                              size: 20,
                                              color: _isFrenzied
                                                  ? colorScheme.onError
                                                  : activeColor,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Name + static hint (no dynamic text → no layout shift)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  frenzyFeature
                                                      .getName(locale)
                                                      .replaceAll(
                                                        RegExp(r'\s*\(.*?\)'),
                                                        '',
                                                      ),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: _isFrenzied
                                                        ? colorScheme
                                                            .onErrorContainer
                                                        : colorScheme.onSurface,
                                                  ),
                                                ),
                                                Text(
                                                  locale == 'ru'
                                                      ? '+1 атака бонусным действием'
                                                      : '+1 bonus action attack',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _isFrenzied
                                                        ? colorScheme
                                                            .onErrorContainer
                                                            .withValues(
                                                            alpha: 0.75,
                                                          )
                                                        : colorScheme
                                                            .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Fixed-size toggle button — no layout jump
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: _isFrenzied
                                                ? IconButton.filled(
                                                    style: IconButton.styleFrom(
                                                      backgroundColor:
                                                          activeColor,
                                                      foregroundColor:
                                                          colorScheme.onError,
                                                      disabledBackgroundColor:
                                                          activeColor
                                                              .withValues(
                                                        alpha: 0.5,
                                                      ),
                                                      disabledForegroundColor:
                                                          colorScheme.onError
                                                              .withValues(
                                                        alpha: 0.8,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          10,
                                                        ),
                                                      ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons
                                                          .local_fire_department,
                                                      size: 20,
                                                    ),
                                                    onPressed:
                                                        null, // Frenzy cannot be manually toggled off
                                                  )
                                                : IconButton.outlined(
                                                    style: IconButton.styleFrom(
                                                      foregroundColor:
                                                          activeColor,
                                                      side: BorderSide(
                                                        color: activeColor
                                                            .withValues(
                                                          alpha: 0.5,
                                                        ),
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          10,
                                                        ),
                                                      ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons
                                                          .local_fire_department_outlined,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      setState(
                                                        () =>
                                                            _isFrenzied = true,
                                                      );
                                                      _frenzyPulseController
                                                          .repeat(
                                                        reverse: true,
                                                      );
                                                      HapticFeedback
                                                          .heavyImpact();
                                                    },
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Frenzy is nested inside the Rage card (AnimatedSize above)

          // Reckless Attack
          if (recklessFeature != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: _isReckless
                    ? colorScheme.errorContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isReckless
                      ? colorScheme.error.withValues(alpha: 0.5)
                      : colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onLongPress: () =>
                      _showFeatureDetails(recklessFeature, Icons.warning_amber),
                  onTap: () {
                    setState(() {
                      _isReckless = !_isReckless;
                    });
                    if (_isReckless) HapticFeedback.heavyImpact();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                                recklessFeature.getName(locale),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isReckless
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                recklessHelperText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _isReckless
                                      ? colorScheme.onErrorContainer
                                          .withValues(alpha: 0.8)
                                      : colorScheme.onSurfaceVariant,
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
                          activeThumbColor: colorScheme.onErrorContainer,
                          activeTrackColor: colorScheme.onErrorContainer
                              .withValues(alpha: 0.3),
                          inactiveThumbColor: colorScheme.outline,
                          inactiveTrackColor:
                              colorScheme.surfaceContainerHighest,
                          trackOutlineColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.transparent;
                            }
                            return colorScheme.outline;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
