import '../../../core/progression/character_training.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../core/utils/dice_utils.dart';
import '../../../shared/widgets/formula_roll_sheet.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/item.dart';
import '../../../shared/widgets/dice_roller_modal.dart';
import '../../combat/combat_tracker_screen.dart';
import 'gameplay_state_editor.dart';
import 'session/health_panel.dart';
import 'session/condition_chips.dart';
import 'session/rest_sheet.dart';
import 'session/value_editors.dart';
import 'session/expressive_hold_surface.dart';
import 'abilities/abilities_section_header.dart';
import 'abilities/abilities_section_surface.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../core/ui/card_sheet_route.dart';
import '../../inventory/inventory_sheets.dart';

class OverviewTab extends StatefulWidget {
  final Character character;
  final VoidCallback? onCharacterUpdated;

  const OverviewTab({
    super.key,
    required this.character,
    this.onCharacterUpdated,
  });

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  bool _resting = false;
  // One origin per equipped weapon, stable across rebuilds.
  final _attackOrigins = <String, GlobalKey<CardSheetOriginState>>{};
  Character get character => widget.character;
  void _updated() {
    if (!mounted) return;
    setState(() {});
    widget.onCharacterUpdated?.call();
  }

  String _getDamageTypeLabel(AppLocalizations l10n, String type) {
    switch (type.toLowerCase()) {
      case 'slashing':
        return l10n.damageTypeSlashing;
      case 'piercing':
        return l10n.damageTypePiercing;
      case 'bludgeoning':
        return l10n.damageTypeBludgeoning;
      case 'acid':
        return l10n.damageTypeAcid;
      case 'cold':
        return l10n.damageTypeCold;
      case 'fire':
        return l10n.damageTypeFire;
      case 'force':
        return l10n.damageTypeForce;
      case 'lightning':
        return l10n.damageTypeLightning;
      case 'necrotic':
        return l10n.damageTypeNecrotic;
      case 'poison':
        return l10n.damageTypePoison;
      case 'psychic':
        return l10n.damageTypePsychic;
      case 'radiant':
        return l10n.damageTypeRadiant;
      case 'thunder':
        return l10n.damageTypeThunder;
      default:
        return l10n.damageTypePhysical;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // COMBAT DASHBOARD
        AbilitiesSectionSurface(
          quiet: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AbilitiesSectionHeader(
                title: l10n.sheetVitals,
                icon: Icons.shield_outlined,
                trailing: IconButton(
                  tooltip: l10n.sheetEditCharacter,
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () async {
                    if (await showGameplayStateEditor(context, character)) {
                      _updated();
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (character.activeConditions.isNotEmpty ||
                  character.exhaustionLevel > 0) ...[
                SheetConditionChips(character: character, onChanged: _updated),
                const SizedBox(height: 16),
              ],
              SheetHealthPanel(character: character, onChanged: _updated),
              const SizedBox(height: 16),

              LayoutBuilder(builder: (context, constraints) {
                final large = MediaQuery.textScalerOf(context).scale(1) > 1.2;
                final columns = constraints.maxWidth >= 320 && !large
                    ? 4
                    : constraints.maxWidth >= 240
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                Widget cell(Widget child) =>
                    SizedBox(width: width, child: child);
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  cell(_buildStatCard(
                      context,
                      l10n.armorClassAC,
                      '${character.armorClass}',
                      Icons.shield_outlined,
                      colorScheme.secondary, onHold: () async {
                    if (await showArmorValueEditor(context, character)) {
                      _updated();
                    }
                  })),
                  cell(_buildStatCard(
                      context,
                      l10n.initiativeINIT,
                      character.formatModifier(character.initiativeBonus),
                      Icons.bolt_rounded,
                      colorScheme.tertiary,
                      onTap: () => showDiceRoller(context,
                          title: l10n.rollInitiative,
                          modifier: character.initiativeBonus))),
                  cell(_buildStatCard(
                      context,
                      l10n.speedSPEED,
                      '${character.speed}',
                      Icons.directions_run_rounded,
                      colorScheme.primary)),
                  cell(_buildStatCard(
                      context,
                      l10n.proficiencyPROF,
                      '+${character.proficiencyBonus}',
                      Icons.school_outlined,
                      colorScheme.onSurfaceVariant)),
                ]);
              }),

              const SizedBox(height: 24),

              // 3. Attacks
              Text(
                  '${l10n.weaponsAttacks}${CharacterTraining.attacks(character) > 1 ? ' · ${CharacterTraining.attacks(character)}' : ''}',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -.4)),
              const SizedBox(height: 12),
              _buildAttacksList(context, l10n),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SheetRestActions(
          busy: _resting,
          onShortRest: () => _showRestDialog(context, short: true),
          onLongRest: () => _showRestDialog(context, short: false),
        ),

        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CombatTrackerScreen(character: character),
              ),
            );
            _updated();
          },
          icon: const Icon(Icons.sports_martial_arts),
          label: Text(l10n.startCombat),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value,
      IconData icon, Color color,
      {VoidCallback? onTap, VoidCallback? onHold}) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExpressiveHoldSurface(
      semanticLabel: '$label $value',
      hint:
          onHold == null ? null : AppLocalizations.of(context)!.sheetHoldToEdit,
      onTap: onTap,
      onHold: onHold,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: companionDecoration(context,
            quiet: true,
            color: colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lgPlus))),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 20, color: color),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: colorScheme.onSurface)),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttacksList(BuildContext context, AppLocalizations l10n) {
    final weapons = character.inventory
        .where((i) => i.isEquipped && i.type == ItemType.weapon)
        .toList();
    final locale = Localizations.localeOf(context).languageCode;

    if (weapons.isEmpty) {
      final strMod = character.abilityScores.strengthModifier;
      final hitBonus = strMod + character.proficiencyBonus;
      final damage = 1 + strMod;
      return _buildAttackCard(context, l10n.unarmedStrike, hitBonus, '$damage',
          l10n.damageTypeBludgeoning,
          icon: Icons.back_hand);
    }

    return Column(
      children: weapons.map((weapon) {
        final strMod = character.abilityScores.strengthModifier;
        final dexMod = character.abilityScores.dexterityModifier;
        final bool isRanged = weapon.weaponProperties?.range != null;
        final bool isFinesse =
            weapon.weaponProperties?.weaponTags.contains('finesse') ?? false;
        final mod =
            (isRanged || (isFinesse && dexMod > strMod)) ? dexMod : strMod;

        final trained = CharacterTraining.weapon(character, weapon);
        final hitBonus =
            mod + (trained == false ? 0 : character.proficiencyBonus);
        final damageDice = weapon.weaponProperties?.damageDice ?? '1d4';

        final rawDamageType =
            weapon.weaponProperties?.damageType.name ?? 'physical';
        final damageType = _getDamageTypeLabel(l10n, rawDamageType);

        final damageModStr =
            mod != 0 ? (mod > 0 ? ' + $mod' : ' - ${mod.abs()}') : '';

        return _buildAttackCard(context, weapon.getName(locale), hitBonus,
            '$damageDice$damageModStr', damageType,
            item: weapon);
      }).toList(),
    );
  }

  Widget _buildAttackCard(BuildContext context, String name, int hitBonus,
      String damage, String type,
      {IconData icon = Icons.sports_martial_arts, Item? item}) {
    final c = Theme.of(context).colorScheme;
    Widget content() =>
        _attackContent(context, name, hitBonus, damage, type, icon: icon);
    if (item == null) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CompanionSurface(
              contour: CompanionContour.facet,
              color: c.surface,
              padding: const EdgeInsets.all(16),
              child: content()));
    }
    final origin = _attackOrigins.putIfAbsent(
        item.instanceId ?? '${item.id}#${character.inventory.indexOf(item)}',
        () => GlobalKey<CardSheetOriginState>());
    // The card grows into the item's sheet; the attack buttons keep working.
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CardSheetOrigin(
            key: origin,
            child: CompanionSurface(
                contour: CompanionContour.facet,
                color: c.surface,
                padding: const EdgeInsets.all(16),
                onTap: () => showCardSheet<bool>(context,
                    origin: origin,
                    originColor: c.surface,
                    faceBuilder: (_) => Padding(
                        padding: const EdgeInsets.all(16), child: content()),
                    builder: (_) => ownedInventoryItemSheet(character, item,
                        onChanged: _updated)).then((_) => _updated()),
                child: content())));
  }

  Widget _attackContent(BuildContext context, String name, int hitBonus,
      String damage, String type,
      {required IconData icon}) {
    final t = Theme.of(context), c = t.colorScheme;
    final l = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(icon, size: 22, color: c.secondary),
        const SizedBox(width: 10),
        Expanded(
            child: Text(name,
                style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: -.35))),
        const SizedBox(width: 12),
        FilledButton.tonal(
            onPressed: () => showDiceRoller(context,
                title: '${l.hit} ($name)', modifier: hitBonus),
            child: Text(character.formatModifier(hitBonus),
                style: t.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
          onPressed: () => showFormulaRoller(context,
              title: '${l.damage} · $name', formula: damage),
          icon: const Icon(Icons.casino_outlined, size: 20),
          label: Text('${DiceUtils.formatDice(damage, context)} · $type',
              textAlign: TextAlign.center)),
    ]);
  }

  Future<void> _showRestDialog(BuildContext context,
      {required bool short}) async {
    if (_resting) return;
    setState(() => _resting = true);
    try {
      final l10n = AppLocalizations.of(context)!;
      final changed = await showRestSheet(context, character, short: short);
      if (changed) {
        _updated();
        if (context.mounted) {
          AppSnackBar.success(context, l10n.restedSuccess);
        }
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _resting = false);
    }
  }
}
