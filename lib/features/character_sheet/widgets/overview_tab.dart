import '../../../core/progression/character_training.dart';
import '../../../core/utils/dice_utils.dart';
import '../../../shared/widgets/formula_roll_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'session/armor_class_sheet.dart';
import 'session/expressive_hold_surface.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../core/models/condition.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/ui/condition_presentation.dart';
import '../../../core/utils/item_utils.dart';
import '../../../core/ui/card_sheet_route.dart';
import '../../inventory/inventory_sheets.dart';

/// Overview, as in the accepted wave 1 prototype: health, the likely next
/// step, the quick numbers, conditions, weapons, rest and combat.
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

  Future<void> _editState() async {
    if (await showGameplayStateEditor(context, character)) _updated();
  }

  Future<void> _pickConditions() async {
    final result = await showConditionPicker(context, character);
    if (result == ConditionPickerResult.allParameters && mounted) {
      await _editState();
    } else if (result == ConditionPickerResult.changed) {
      _updated();
    }
  }

  Future<void> _armorClass() async {
    if (await showArmorClassBreakdown(context, character)) _updated();
  }

  void _rollInitiative() => showDiceRoller(context,
      title: AppLocalizations.of(context)!.rollInitiative,
      modifier: character.initiativeBonus);

  Future<void> _startCombat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CombatTrackerScreen(character: character),
      ),
    );
    _updated();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final attacks = CharacterTraining.attacks(character);
    final weapons = character.inventory
        .where((i) => i.isEquipped && i.type == ItemType.weapon)
        .toList();
    final now = _nowCard(context, l10n);
    final inset = SheetPageInset.of(context);
    Widget gap(Widget child) =>
        Padding(padding: const EdgeInsets.only(bottom: 14), child: child);

    return ListView(
      // The page scrolls on under the floating island.
      clipBehavior: Clip.none,
      padding: EdgeInsets.fromLTRB(16, inset + 6, 16, 110),
      children: [
        gap(SheetHealthPanel(character: character, onChanged: _updated)),
        if (now != null) gap(now),
        gap(_QuickStats(
          armorClass: '${character.armorClass}',
          initiative: character.formatModifier(character.initiativeBonus),
          speed: '${character.speed}',
          proficiency: '+${character.proficiencyBonus}',
          onArmorClass: _armorClass,
          onInitiative: _rollInitiative,
        )),
        gap(SectionHeading(l10n.overviewConditions)),
        gap(SheetConditionChips(
          character: character,
          onChanged: _updated,
          onAdd: _pickConditions,
        )),
        gap(SectionHeading(l10n.overviewWeapons,
            count: attacks > 1
                ? l10n.overviewAttacksPerAction(attacks)
                : '${weapons.isEmpty ? 1 : weapons.length}')),
        _buildAttacksList(context, l10n, weapons),
        gap(SectionHeading(l10n.rest)),
        gap(SheetRestActions(
          busy: _resting,
          onShortRest: () => _showRestDialog(context, short: true),
          onLongRest: () => _showRestDialog(context, short: false),
        )),
        _CombatButton(label: l10n.startCombat, onPressed: _startCombat),
      ],
    );
  }

  /// The most likely next step for the hero as they are right now.
  Widget? _nowCard(BuildContext context, AppLocalizations l10n) {
    if (character.currentHp <= 0) return null;
    final locale = Localizations.localeOf(context).languageCode;
    final conditions = character.activeConditions.toSet();
    if (conditions.isNotEmpty) {
      final first = conditions.first;
      return _NowCard(
        icon: Icon(ConditionPresentation.icon(first), size: 20),
        title: ConditionPresentation.label(l10n, first),
        note: first.getDescription(locale),
      );
    }
    if (character.maxHp > 0 && character.currentHp * 2 <= character.maxHp) {
      final dice = character.hitDice.fold<int>(0, (a, b) => a + b);
      return _NowCard(
        icon: const LineIcon('cup', size: 20),
        title: l10n.nowLowHpTitle,
        note: l10n.nowLowHpNote(dice),
        action: l10n.nowRestAction,
        onAction:
            _resting ? null : () => _showRestDialog(context, short: true),
      );
    }
    return _NowCard(
      icon: const LineIcon('bolt', size: 20),
      title: l10n.nowReadyTitle,
      note: l10n
          .nowReadyNote(character.formatModifier(character.initiativeBonus)),
      action: l10n.nowRollAction,
      onAction: _rollInitiative,
    );
  }

  Widget _buildAttacksList(
      BuildContext context, AppLocalizations l10n, List<Item> weapons) {
    final locale = Localizations.localeOf(context).languageCode;

    if (weapons.isEmpty) {
      final strMod = character.abilityScores.strengthModifier;
      final hitBonus = strMod + character.proficiencyBonus;
      final damage = 1 + strMod;
      return _buildAttackCard(context, l10n.unarmedStrike, hitBonus, '$damage',
          'bludgeoning', l10n.damageTypeBludgeoning,
          kind: l10n.weaponKindMelee);
    }

    return Column(
      children: weapons.map((weapon) {
        final strMod = character.abilityScores.strengthModifier;
        final dexMod = character.abilityScores.dexterityModifier;
        final tags = weapon.weaponProperties?.weaponTags ?? const <String>[];
        final bool isRanged = weapon.weaponProperties?.range != null;
        final bool isFinesse = tags.contains('finesse');
        final thrown = tags.contains('thrown');
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
        final range = weapon.weaponProperties?.range;
        final longRange = weapon.weaponProperties?.longRange;

        return _buildAttackCard(context, weapon.getName(locale), hitBonus,
            '$damageDice$damageModStr', rawDamageType, damageType,
            kind: thrown
                ? l10n.weaponKindThrown
                : isRanged
                    ? l10n.weaponKindRanged
                    : l10n.weaponKindMelee,
            ranged: isRanged && !thrown,
            tags: [
              for (final tag in tags)
                if (!const {'simple', 'martial'}.contains(tag.toLowerCase()))
                  ItemUtils.getLocalizedTag(l10n, tag).toLowerCase(),
              if (range != null)
                '$range${longRange == null ? '' : '/$longRange'} ${locale == 'ru' ? 'фт' : 'ft'}',
            ],
            item: weapon);
      }).toList(),
    );
  }

  Widget _buildAttackCard(BuildContext context, String name, int hitBonus,
      String damage, String rawType, String type,
      {required String kind,
      bool ranged = false,
      List<String> tags = const [],
      Item? item}) {
    final c = Theme.of(context).colorScheme;
    final accents = AppAccents.of(context);
    final tone = accents.at(ranged ? 4 : 1);
    final locale = Localizations.localeOf(context).languageCode;
    Widget content() => _WeaponFace(
          name: name,
          kind: kind,
          tone: tone,
          attack: character.formatModifier(hitBonus),
          damage: DiceUtils.formatDice(damage, context).replaceAll(' ', ''),
          damageType: locale == 'ru' ? type.toLowerCase() : type,
          damageTone: accents.at(_damageTone(rawType)),
          tags: tags,
          onAttack: () => showDiceRoller(context,
              title: '${AppLocalizations.of(context)!.hit} ($name)',
              modifier: hitBonus),
          onDamage: () => showFormulaRoller(context,
              title: '${AppLocalizations.of(context)!.damage} · $name',
              formula: damage),
        );
    Widget surface({VoidCallback? onTap}) => Pressable(
          onTap: onTap,
          scale: .99,
          child: _WeaponSurface(tone: tone, child: content()),
        );
    if (item == null) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 10), child: surface());
    }
    final origin = _attackOrigins.putIfAbsent(
        item.instanceId ?? '${item.id}#${character.inventory.indexOf(item)}',
        () => GlobalKey<CardSheetOriginState>());
    // The card grows into the item's sheet; its two roll zones keep working.
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CardSheetOrigin(
            key: origin,
            child: surface(
                onTap: () => showCardSheet<bool>(context,
                    origin: origin,
                    originColor: c.surfaceContainerLow,
                    originBorderRadius: _WeaponSurface.radius,
                    faceBuilder: (_) =>
                        _WeaponSurface(tone: tone, child: content()),
                    builder: (_) => ownedInventoryItemSheet(character, item,
                        onChanged: _updated)).then((_) => _updated()))));
  }

  static int _damageTone(String type) => switch (type.toLowerCase()) {
        'slashing' => 1,
        'piercing' => 4,
        'bludgeoning' => 5,
        _ => 2,
      };

  Future<void> _showRestDialog(BuildContext context,
      {required bool short}) async {
    if (_resting) return;
    setState(() => _resting = true);
    try {
      final l10n = AppLocalizations.of(context)!;
      final changed = await showRestSheet(context, character, short: short);
      if (changed) {
        HapticFeedback.lightImpact();
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

/// The prototype's `.now`: a calm card with the most likely next step.
class _NowCard extends StatelessWidget {
  const _NowCard(
      {required this.icon,
      required this.title,
      required this.note,
      this.action,
      this.onAction});
  final Widget icon;
  final String title, note;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final button = ToneButton(
        label: action ?? '', onPressed: onAction, height: 38, fontSize: 13);
    final card = Container(
      key: const ValueKey('overview-now'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: c.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: c.tertiary.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(AppRadii.md)),
          child: IconTheme(
              data: IconThemeData(color: c.tertiary, size: 20),
              child: Center(child: icon)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: t.textTheme.titleSmall?.copyWith(
                    fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.3)),
            Text(note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodySmall
                    ?.copyWith(fontSize: 13, color: c.onSurfaceVariant)),
          ]),
        ),
        if (action != null && !large) ...[
          const SizedBox(width: 10),
          button,
        ],
      ]),
    );
    if (action == null || !large) return card;
    // Large text: the action moves under the hint instead of squeezing it.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      card,
      const SizedBox(height: 6),
      button,
    ]);
  }
}

/// The four quick numbers. Armour class rolls out its breakdown on a tap or
/// a hold; initiative rolls on a tap.
class _QuickStats extends StatelessWidget {
  const _QuickStats({
    required this.armorClass,
    required this.initiative,
    required this.speed,
    required this.proficiency,
    required this.onArmorClass,
    required this.onInitiative,
  });
  final String armorClass, initiative, speed, proficiency;
  final VoidCallback onArmorClass, onInitiative;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final tiles = [
      ExpressiveHoldSurface(
        semanticLabel: '${l10n.armorClass} $armorClass',
        hint: l10n.acBreakdownSubtitle,
        onTap: onArmorClass,
        onHold: onArmorClass,
        child: _QuickTile(
            icon: 'shield',
            value: armorClass,
            label: l10n.armorClassAC,
            shieldTint: true),
      ),
      Pressable(
          onTap: onInitiative,
          semanticLabel: '${l10n.rollInitiative} $initiative',
          child: ExcludeSemantics(
              child: _QuickTile(
                  icon: 'bolt',
                  value: initiative,
                  label: l10n.initiativeINIT))),
      _QuickTile(icon: 'run', value: speed, label: l10n.quickSpeed),
      _QuickTile(icon: 'medal', value: proficiency, label: l10n.quickProf),
    ];
    return LayoutBuilder(builder: (context, box) {
      final columns = large || box.maxWidth < 300 ? 2 : 4;
      final w = (box.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final tile in tiles) SizedBox(width: w, child: tile),
      ]);
    });
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile(
      {required this.icon,
      required this.value,
      required this.label,
      this.shieldTint = false});
  final String icon, value, label;
  final bool shieldTint;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        LineIcon(icon, size: 18, color: c.secondary),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            style: AppType.numeric(t.textTheme.headlineSmall).copyWith(
                fontSize: 24, fontWeight: FontWeight.w600, height: 1.1)),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: .66,
                color: c.onSurfaceVariant)),
      ]),
    );
    return Container(
      decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
      child: shieldTint
          // The armour tile carries a faint shield shape inside it.
          ? Stack(children: [
              Positioned.fill(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: c.secondary.withValues(alpha: .09),
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                              bottomLeft: Radius.circular(22),
                              bottomRight: Radius.circular(22)))),
                ),
              ),
              Center(child: body),
            ])
          : Center(child: body),
    );
  }
}

/// The prototype's `.wcard2` background: the weapon kind's tone washing in
/// from one corner with a soft light at the top right.
class _WeaponSurface extends StatelessWidget {
  const _WeaponSurface({required this.tone, required this.child});

  static const radius = BorderRadius.only(
      topLeft: Radius.circular(AppRadii.xl),
      topRight: Radius.circular(AppRadii.xl),
      bottomRight: Radius.circular(AppRadii.xl),
      bottomLeft: Radius.circular(AppRadii.lg));
  final Color tone;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: const Alignment(-1, -.6),
              end: const Alignment(1, .6),
              colors: [
                Color.alphaBlend(
                    tone.withValues(alpha: .12), c.surfaceContainerLow),
                c.surfaceContainerLow,
              ],
              stops: const [0, .6]),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                      center: const Alignment(1.1, -1.1),
                      radius: .9,
                      colors: [
                        tone.withValues(alpha: .22 * .7),
                        tone.withValues(alpha: 0)
                      ]),
                ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ]),
      ),
    );
  }
}

/// A weapon at a glance: two clear zones, the attack (a d20 facet) and the
/// damage (its type's colour); the rest of the card opens the item.
class _WeaponFace extends StatelessWidget {
  const _WeaponFace({
    required this.name,
    required this.kind,
    required this.tone,
    required this.attack,
    required this.damage,
    required this.damageType,
    required this.damageTone,
    required this.tags,
    required this.onAttack,
    required this.onDamage,
  });
  final String name, kind, attack, damage, damageType;
  final Color tone, damageTone;
  final List<String> tags;
  final VoidCallback onAttack, onDamage;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    Widget pill(
            {required Key key,
            required Widget lead,
            required String label,
            required String value,
            required String semantics,
            required VoidCallback onTap}) =>
        Pressable(
          key: key,
          onTap: onTap,
          semanticLabel: semantics,
          child: ExcludeSemantics(
            child: Container(
              // The lead sits on the weapon icon's axis (42 wide) and the
              // text starts on the weapon name's line.
              padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
              decoration: BoxDecoration(
                  color: c.onSurface.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                SizedBox(width: 42, child: Center(child: lead)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .44,
                                color: c.onSurfaceVariant)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(value,
                              style: AppType.numeric(t.textTheme.titleLarge)
                                  .copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      height: 1.1)),
                        ),
                      ]),
                ),
              ]),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: Color.alphaBlend(
                  tone.withValues(alpha: .18), c.surfaceContainer),
              borderRadius: BorderRadius.circular(13)),
          child: Center(child: LineIcon('sword', size: 22, color: tone)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleMedium?.copyWith(
                    fontFamily: AppType.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.18,
                    height: 1.2)),
            const SizedBox(height: 2),
            Text(kind,
                style: t.textTheme.bodySmall
                    ?.copyWith(fontSize: 12.5, color: c.onSurfaceVariant)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 10,
            child: pill(
                key: const ValueKey('weapon-attack'),
                lead: SizedBox.square(
                    dimension: 30,
                    child: CustomPaint(painter: _FacetPainter(c.primary))),
                label: l10n.weaponAttack,
                value: attack,
                semantics: '${l10n.weaponAttack} $attack',
                onTap: onAttack),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 13,
            child: pill(
                key: const ValueKey('weapon-damage'),
                lead: _DamageType(color: damageTone),
                label: l10n.weaponDamageOf(damageType),
                value: damage,
                semantics: '${l10n.damage} $damage $damageType',
                onTap: onDamage),
          ),
        ]),
      ),
      if (tags.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final tag in tags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                  shape: StadiumBorder(
                      side: BorderSide(
                          color: c.onSurface.withValues(alpha: .14),
                          width: 1.2))),
              child: Text(tag,
                  style: t.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.onSurfaceVariant)),
            ),
        ]),
      ],
    ]);
  }
}

/// The damage type's mark: a rounded square in its colour with a diamond.
class _DamageType extends StatelessWidget {
  const _DamageType({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: color.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: .7), width: 2)),
        child: Center(
          child: Transform.rotate(
            angle: .785398,
            child: Container(
              width: 8.8,
              height: 8.8,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ),
      );
}

/// A d20 seen face-on: a hexagon with its central triangle.
class _FacetPainter extends CustomPainter {
  const _FacetPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w / 100, y * h / 100);
    final hex = Path()
      ..addPolygon(
          [p(50, 6), p(88, 28), p(88, 72), p(50, 94), p(12, 72), p(12, 28)],
          true);
    canvas.drawPath(hex, Paint()..color = color.withValues(alpha: .2));
    canvas.drawPath(
        hex,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .05
          ..strokeJoin = StrokeJoin.round);
    final facets = Paint()
      ..color = color.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .035
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        Path()..addPolygon([p(50, 6), p(30, 60), p(70, 60), p(50, 6)], false),
        facets);
    canvas.drawPath(
        Path()
          ..addPolygon(
              [p(12, 28), p(30, 60), p(50, 94), p(70, 60), p(88, 28)], false),
        facets);
  }

  @override
  bool shouldRepaint(_FacetPainter old) => old.color != color;
}

/// The prototype's `.combat`: a 58 high capsule in a primary wash.
class _CombatButton extends StatelessWidget {
  const _CombatButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    return Pressable(
      key: const ValueKey('overview-start-combat'),
      onTap: onPressed,
      scale: .98,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: Color.alphaBlend(
                  c.primary.withValues(alpha: .22), c.surfaceContainerLow)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            LineIcon('swords', size: 22, color: c.onSurface),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: t.textTheme.titleSmall
                      ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}
