import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';

class RogueToolsWidget extends StatefulWidget {
  final Character character;

  const RogueToolsWidget({
    super.key,
    required this.character,
  });

  @override
  State<RogueToolsWidget> createState() => _RogueToolsWidgetState();
}

class _RogueToolsWidgetState extends State<RogueToolsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  int _getSneakAttackDice(int level) {
    return (level + 1) ~/ 2;
  }

  void _rollSneakAttack(
      BuildContext context, int diceCount, CharacterFeature? feature) {
    HapticFeedback.mediumImpact();
    _rotationController.forward(from: 0.0);

    final random = Random();
    int total = 0;
    for (int i = 0; i < diceCount; i++) {
      total += random.nextInt(6) + 1;
    }

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.sneakAttackRoll(
                    total, DiceUtils.formatDice('${diceCount}d6', context)),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showStealthDialog(BuildContext context) {
    double sliderValue = 15;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            title: Text(
              l10n.stealthDifficulty,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sliderValue.toInt().toString(),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Slider(
                  value: sliderValue,
                  min: 5,
                  max: 30,
                  divisions: 25,
                  activeColor: colorScheme.primary,
                  inactiveColor: colorScheme.surfaceContainerHighest,
                  onChanged: (val) {
                    setStateDialog(() {
                      sliderValue = val;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _performStealthRoll(sliderValue.toInt(), l10n);
                },
                child: Text(l10n.rollStealthBtn),
              ),
            ],
          );
        });
      },
    );
  }

  void _performStealthRoll(int dc, AppLocalizations l10n) {
    const skillId = 'stealth';
    final mod = widget.character.abilityScores.dexterityModifier;
    final isProficient = widget.character.proficientSkills.contains(skillId);
    final isExpert = widget.character.expertSkills.contains(skillId);

    int bonus = 0;
    if (isExpert) {
      bonus = widget.character.proficiencyBonus * 2;
    } else if (isProficient) {
      bonus = widget.character.proficiencyBonus;
    }

    final totalMod = mod + bonus;
    final roll = Random().nextInt(20) + 1;
    final total = roll + totalMod;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (total >= dc) {
      setState(() => _isHidden = true);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.stealthSuccess(total, dc),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      final failPhrases = [
        l10n.stealthFail1,
        l10n.stealthFail2,
        l10n.stealthFail3,
        l10n.stealthFail4,
        l10n.stealthFail5,
        l10n.stealthFail6,
        l10n.stealthFail7,
        l10n.stealthFail8,
        l10n.stealthFail9,
        l10n.stealthFail10,
        l10n.stealthFail11,
        l10n.stealthFail12,
        l10n.stealthFail13,
        l10n.stealthFail14,
        l10n.stealthFail15,
      ];
      final reason = failPhrases[Random().nextInt(failPhrases.length)];

      setState(() => _isHidden = false);
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.stealthFailure(total, dc, reason),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _executeQuickAction(String actionName, String snackbarMsg,
      {bool triggersStealth = false}) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackbarMsg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );

    if (triggersStealth) {
      // Instead of quick action, show the DC dialog
      _showStealthDialog(context);
    }
  }

  void _showFeatureDetails(CharacterFeature feature, IconData icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(
        feature: feature,
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
                              .withValues(alpha: 0.4),
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
                            child: Icon(Icons.masks,
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

  Widget _buildActionTile({
    required CharacterFeature feature,
    required String name,
    required IconData icon,
    required IconData actionIcon,
    required ThemeData theme,
    required VoidCallback onTap,
    required VoidCallback onActionPress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
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
                      name,
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
                      onPressed: onActionPress,
                      child: Icon(actionIcon, size: 18),
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

  Widget _buildFeatureReminder({
    required CharacterFeature feature,
    required String name,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
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
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final isRu = locale == 'ru';

    final diceCount = _getSneakAttackDice(widget.character.level);
    final diceText = DiceUtils.formatDice('${diceCount}d6', context);

    // Finding relevant features correctly
    CharacterFeature? cunningActionFeature;
    CharacterFeature? uncannyDodgeFeature;
    CharacterFeature? evasionFeature;
    CharacterFeature? sneakAttackFeature;
    CharacterFeature? hideFeature;

    for (var f in widget.character.features) {
      final fid = f.id.toLowerCase();
      if (fid == 'cunning_action' ||
          fid == 'хитрое_действие' ||
          f.nameEn.toLowerCase() == 'cunning action') {
        cunningActionFeature = f;
      }
      if (fid == 'uncanny_dodge' ||
          fid == 'невероятное_уклонение' ||
          f.nameEn.toLowerCase() == 'uncanny dodge') {
        uncannyDodgeFeature = f;
      }
      if (fid == 'evasion' ||
          fid == 'увертливость' ||
          f.nameEn.toLowerCase() == 'evasion') {
        evasionFeature = f;
      }
      if (fid == 'sneak_attack' ||
          fid == 'скрытая_атака' ||
          f.nameEn.toLowerCase() == 'sneak attack') {
        sneakAttackFeature = f;
      }
      if (fid == 'hide' ||
          fid == 'засада' ||
          f.nameEn.toLowerCase() == 'hide') {
        hideFeature = f;
      }
    }

    String subclassDisplayName = widget.character.subclass ?? '';
    final classData =
        CharacterDataService.getClassById(widget.character.characterClass);
    if (classData != null && subclassDisplayName.isNotEmpty) {
      final nid = subclassDisplayName.toLowerCase().trim();
      for (var sc in classData.subclasses) {
        if (sc.id.toLowerCase().trim() == nid) {
          subclassDisplayName = sc.getName(locale);
          break;
        }
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1.5),
      ),
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Archetype Block (Каноничный)
          if (subclassDisplayName.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showSubclassLore(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.masks,
                              color: colorScheme.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRu
                                    ? 'Плутовской архетип'
                                    : 'Roguish Archetype',
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
                            color:
                                colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stealth & Sneak Attack Dashboard (M3 Expressive)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _isHidden
                        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isHidden
                          ? colorScheme.primary.withValues(alpha: 0.5)
                          : colorScheme.outline.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (hideFeature != null) {
                          _showFeatureDetails(hideFeature, Icons.dark_mode);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header part
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                          _isHidden
                                              ? Icons.nightlight_round
                                              : Icons.dark_mode,
                                          color: _isHidden
                                              ? colorScheme.primary
                                              : colorScheme.onSurface),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          isRu ? 'Засада' : 'Ambush',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    if (_isHidden) {
                                      setState(() => _isHidden = false);
                                      HapticFeedback.lightImpact();
                                    } else {
                                      _showStealthDialog(context);
                                    }
                                  },
                                  icon: Icon(_isHidden
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  label: Text(_isHidden
                                      ? (isRu ? 'Раскрыться' : 'Reveal')
                                      : (isRu ? 'Скрыться' : 'Hide')),
                                ),
                              ],
                            ),
                          ),
                          // Separated Contextual Sneak Attack Card (Like Barbarian Frenzy)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutQuart,
                            alignment: Alignment.topCenter,
                            child: _isHidden && sneakAttackFeature != null
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16, right: 16, bottom: 16),
                                    child: Container(
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainer,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: colorScheme.outline
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () => _showFeatureDetails(
                                              sneakAttackFeature!,
                                              Icons.colorize),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: colorScheme
                                                              .primary
                                                              .withValues(alpha: 0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Icon(
                                                            Icons.colorize,
                                                            size: 20,
                                                            color: colorScheme
                                                                .primary),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          sneakAttackFeature
                                                              .getName(locale),
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: colorScheme
                                                                .onSurface,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                FilledButton.icon(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        colorScheme.secondary,
                                                    foregroundColor:
                                                        colorScheme.onSecondary,
                                                  ),
                                                  onPressed: () =>
                                                      _rollSneakAttack(
                                                          context,
                                                          diceCount,
                                                          sneakAttackFeature),
                                                  icon: RotationTransition(
                                                    turns: CurvedAnimation(
                                                        parent:
                                                            _rotationController,
                                                        curve:
                                                            Curves.easeOutBack),
                                                    child: const Icon(
                                                        Icons.casino,
                                                        size: 18),
                                                  ),
                                                  label: Text(
                                                    diceText,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    width: double.infinity, height: 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Tactics and Defense Block
                if (cunningActionFeature != null ||
                    uncannyDodgeFeature != null ||
                    evasionFeature != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cunningActionFeature != null) ...[
                          Row(
                            children: [
                              Icon(Icons.keyboard_double_arrow_right,
                                  color: colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isRu
                                      ? 'Хитрое действие (Бонус)'
                                      : 'Cunning Action (Bonus)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Action: Dash
                          _buildActionTile(
                            feature: cunningActionFeature,
                            name: cunningActionFeature.getName(locale),
                            icon: Icons.directions_run,
                            actionIcon: Icons.keyboard_double_arrow_right,
                            theme: Theme.of(context),
                            onTap: () => _showFeatureDetails(
                                cunningActionFeature!, Icons.directions_run),
                            onActionPress: () => _executeQuickAction(
                                'Dash',
                                isRu
                                    ? 'Рывок (Бонусное действие)'
                                    : 'Dash (Bonus Action)'),
                          ),

                          // Action: Disengage
                          _buildActionTile(
                            feature: cunningActionFeature,
                            name: isRu
                                ? 'Отход'
                                : 'Disengage', // Forcing name to avoid redundant (Bonus action) in translated features
                            icon: Icons.turn_slight_right,
                            actionIcon: Icons.keyboard_double_arrow_right,
                            theme: Theme.of(context),
                            onTap: () => _showFeatureDetails(
                                cunningActionFeature!, Icons.turn_slight_right),
                            onActionPress: () => _executeQuickAction(
                                'Disengage',
                                isRu
                                    ? 'Отход (Бонусное действие)'
                                    : 'Disengage (Bonus Action)'),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Protective Reactions
                        if (uncannyDodgeFeature != null ||
                            evasionFeature != null) ...[
                          Text(
                            isRu ? 'Защитные Реакции' : 'Defensive Reactions',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Reaction: Dodge
                        if (uncannyDodgeFeature != null)
                          _buildFeatureReminder(
                            feature: uncannyDodgeFeature,
                            name: uncannyDodgeFeature.getName(locale),
                            icon: Icons.shield,
                            theme: Theme.of(context),
                          ),

                        // Reaction: Evasion
                        if (evasionFeature != null)
                          _buildFeatureReminder(
                            feature: evasionFeature,
                            name: evasionFeature.getName(locale),
                            icon: Icons.shield_outlined,
                            theme: Theme.of(context),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
