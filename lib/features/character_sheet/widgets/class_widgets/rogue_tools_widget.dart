import '../../../../shared/widgets/subclass_details_sheet.dart';
import '../../../../core/ui/companion_surface.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';
import '../../../../core/services/feature_service.dart';
import '../../../../core/services/class_session_actions_service.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import 'shared/class_tools_layout_builder.dart';

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
  bool get _isHidden => widget.character.isHidden;

  bool _savingHidden = false;
  Future<bool> _setHidden(bool value) async {
    if (_savingHidden) return false;
    setState(() => _savingHidden = true);
    try {
      await ClassSessionActionsService.hidden(widget.character, value);
      return true;
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
      return false;
    } finally {
      if (mounted) setState(() => _savingHidden = false);
    }
  }

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
    AppSnackBar.success(
      context,
      l10n.sneakAttackRoll(
        total.toString(),
        DiceUtils.formatDice('${diceCount}d6', context),
      ),
      duration: const Duration(seconds: 3),
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
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
              ),
              title: Text(
                l10n.stealthDifficulty,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
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
          },
        );
      },
    );
  }

  Future<void> _performStealthRoll(int dc, AppLocalizations l10n) async {
    if (_savingHidden) return;
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

    if (total >= dc) {
      if (!await _setHidden(true) || !mounted) return;
      HapticFeedback.heavyImpact();
      AppSnackBar.success(
        context,
        l10n.stealthSuccess(total, dc),
        duration: const Duration(seconds: 2),
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

      if (!await _setHidden(false) || !mounted) return;
      HapticFeedback.vibrate();
      AppSnackBar.error(
        context,
        l10n.stealthFailure(total, dc, reason),
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _executeQuickAction(String actionName, String snackbarMsg,
      {bool triggersStealth = false}) {
    HapticFeedback.heavyImpact();
    AppSnackBar.info(
      context,
      snackbarMsg,
      duration: const Duration(seconds: 2),
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

  Future<void> _showSubclassLore(BuildContext context) async {
    await showClassSubclassDetails(context, widget.character, 'rogue');
    if (mounted) {
      setState(() {});
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
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
                          borderRadius: BorderRadius.circular(20)),
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
    );
  }

  Widget _buildFeatureReminder({
    required CharacterFeature feature,
    required String name,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final isRu = locale == 'ru';

    final diceCount = _getSneakAttackDice(widget.character.classLevel('rogue'));
    final diceText = DiceUtils.formatDice('${diceCount}d6', context);

    CharacterFeature? cunningActionFeature;
    CharacterFeature? uncannyDodgeFeature;
    CharacterFeature? evasionFeature;
    CharacterFeature? sneakAttackFeature;
    CharacterFeature? hideFeature;

    final List<CharacterFeature> cunningChildren = [];

    for (var f in widget.character.features) {
      if (!CharacterClassContext(widget.character, 'rogue').canUseFeature(f)) {
        continue;
      }
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

    if (cunningActionFeature != null) {
      final options = cunningActionFeature.options;
      if (options != null && options.isNotEmpty) {
        for (var opt in options) {
          var child =
              widget.character.features.where((f) => f.id == opt).firstOrNull;
          child ??= FeatureService.getFeatureById(opt);
          if (child != null) cunningChildren.add(child);
        }
      }

      if (cunningChildren.isEmpty) {
        // Fallback to searching by known action names if options missing
        final lookup = ['dash', 'disengage', 'hide'];
        for (var k in lookup) {
          var child = widget.character.features
              .where((f) =>
                  f.id.toLowerCase().contains(k) &&
                  f.actionEconomy == 'bonus_action')
              .firstOrNull;
          child ??= FeatureService.getFeatureById(k);
          if (child != null && !cunningChildren.any((x) => x.id == child!.id)) {
            cunningChildren.add(child);
          }
        }

        // IMPORTANT QA FIX: If cunningChildren is STILL empty, we generate proper dummy features!
        if (cunningChildren.isEmpty) {
          cunningChildren.add(CharacterFeature(
            id: 'cunning-action-dash',
            nameEn: 'Dash',
            nameRu: 'Рывок',
            descriptionEn:
                'When you take the Dash action, you gain extra movement for the current turn. The increase equals your speed, after applying any modifiers.',
            descriptionRu:
                'Если вы совершаете действие Рывок, вы получаете дополнительное перемещение в текущем ходу. Увеличение равно вашей скорости после применения всех модификаторов.',
            type: FeatureType.action,
            minLevel: 2,
            actionEconomy: 'bonus_action',
          ));
          cunningChildren.add(CharacterFeature(
            id: 'cunning-action-disengage',
            nameEn: 'Disengage',
            nameRu: 'Отход',
            descriptionEn:
                "If you take the Disengage action, your movement doesn't provoke opportunity attacks for the rest of the turn.",
            descriptionRu:
                'Если вы совершаете действие Отход, ваше перемещение не провоцирует провоцированные атаки до конца хода.',
            type: FeatureType.action,
            minLevel: 2,
            actionEconomy: 'bonus_action',
          ));
        }
      }
    }

    hideFeature ??= CharacterFeature(
      id: 'cunning-action-hide',
      nameEn: 'Hide',
      nameRu: 'Засада',
      descriptionEn:
          'When you take the Hide action, you make a Dexterity (Stealth) check in an attempt to hide, following the rules for hiding. If you succeed, you gain certain benefits.',
      descriptionRu:
          'Когда вы совершаете действие Засада, вы совершаете проверку Ловкости (Скрытность) в попытке спрятаться, следуя правилам скрытности. Если вы преуспеваете, вы получаете определенные преимущества.',
      type: FeatureType.action,
      minLevel: 2,
      actionEconomy: 'bonus_action',
    );

    String subclassDisplayName =
        CharacterClassContext(widget.character, 'rogue').subclass ?? '';
    final classData =
        CharacterClassContext(widget.character, 'rogue').definition;
    if (classData != null && subclassDisplayName.isNotEmpty) {
      final nid = subclassDisplayName.toLowerCase().trim();
      for (var sc in classData.subclasses) {
        if (sc.id.toLowerCase().trim() == nid) {
          subclassDisplayName = sc.getName(locale);
          break;
        }
      }
    }

    return ClassPanelFrame(
        character: widget.character,
        classId: 'rogue',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: [
            if (subclassDisplayName.isNotEmpty)
              ListTile(
                  dense: true,
                  minTileHeight: 40,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(subclassDisplayName,
                      style: TextStyle(color: colorScheme.secondary)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showSubclassLore(context)),
            if (sneakAttackFeature != null)
              ClassPrimaryControl(
                  classId: 'rogue',
                  title: sneakAttackFeature.getName(locale),
                  tone: colorScheme.secondaryContainer,
                  child: Row(children: [
                    Expanded(
                        child: Text(diceText,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(fontWeight: FontWeight.w700))),
                    const SizedBox(width: 12),
                    CompanionDiceControl(
                        sides: 6,
                        label: isRu ? 'Бросить $diceText' : 'Roll $diceText',
                        onPressed: () => _rollSneakAttack(
                            context, diceCount, sneakAttackFeature)),
                    IconButton(
                        tooltip:
                            AppLocalizations.of(context)!.advancementDetails,
                        onPressed: () => _showFeatureDetails(
                            sneakAttackFeature!, Icons.visibility_off_outlined),
                        icon: const Icon(Icons.info_outline_rounded)),
                  ])),
            CompanionSurface(
                contour: CompanionContour.fold,
                color: _isHidden
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerLow,
                padding: const EdgeInsets.all(16),
                quiet: !_isHidden,
                child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(isRu ? 'Скрытность' : 'Stealth',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      FilledButton.tonalIcon(
                          onPressed: _savingHidden
                              ? null
                              : () async {
                                  if (_isHidden) {
                                    if (!await _setHidden(false) || !mounted) {
                                      return;
                                    }
                                  } else {
                                    _showStealthDialog(context);
                                  }
                                },
                          icon: Icon(_isHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          label: Text(_isHidden
                              ? (isRu ? 'Раскрыться' : 'Reveal')
                              : (isRu ? 'Скрыться' : 'Hide'))),
                    ])),
            if (cunningActionFeature != null ||
                uncannyDodgeFeature != null ||
                evasionFeature != null)
              // Tactics and Defense Block
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cunningActionFeature != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          if (cunningChildren.isNotEmpty)
                            ...cunningChildren
                                .map((child) {
                                  IconData actionIcon = Icons.flash_on;
                                  if (child.id.contains('dash')) {
                                    actionIcon = Icons.directions_run;
                                  }
                                  if (child.id.contains('disengage')) {
                                    actionIcon = Icons.turn_slight_right;
                                  }
                                  if (child.id.contains('hide')) {
                                    actionIcon = Icons.visibility_off;
                                  }
                                  return _buildActionTile(
                                    feature: child,
                                    name: child.getName(locale),
                                    icon: actionIcon,
                                    actionIcon:
                                        Icons.keyboard_double_arrow_right,
                                    theme: Theme.of(context),
                                    onTap: () =>
                                        _showFeatureDetails(child, actionIcon),
                                    onActionPress: () => _executeQuickAction(
                                        child.nameEn,
                                        '${child.getName(locale)} (Бонусное действие)'),
                                  );
                                })
                                .expand((w) => [w, const SizedBox(height: 8)])
                                .toList()
                              ..removeLast(),
                        ],
                      ),
                    if (cunningActionFeature != null &&
                        (uncannyDodgeFeature != null || evasionFeature != null))
                      const SizedBox(height: 16),
                    if (uncannyDodgeFeature != null || evasionFeature != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          ...[
                            if (uncannyDodgeFeature != null)
                              _buildFeatureReminder(
                                feature: uncannyDodgeFeature,
                                name: uncannyDodgeFeature.getName(locale),
                                icon: Icons.shield,
                                theme: Theme.of(context),
                              ),
                            if (evasionFeature != null)
                              _buildFeatureReminder(
                                feature: evasionFeature,
                                name: evasionFeature.getName(locale),
                                icon: Icons.shield,
                                theme: Theme.of(context),
                              ),
                          ]
                              .expand((w) => [w, const SizedBox(height: 8)])
                              .toList()
                            ..removeLast(),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ));
  }
}
