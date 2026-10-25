import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/magic/magic_slots.dart';
import '../../core/magic/spell_use.dart';
import '../../core/models/character.dart';
import '../../core/models/character_feature.dart';
import '../../core/models/combat_state.dart';
import '../../core/models/combat_turn.dart';
import '../../core/models/item.dart';
import '../../core/models/spell.dart';
import '../../core/progression/character_class_context.dart';
import '../../core/progression/character_training.dart';
import '../../core/services/combat_actions_service.dart';
import '../../core/services/feature_service.dart';
import '../../core/services/gameplay_actions_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/spell_effects.dart';
import '../character_sheet/widgets/class_panels.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';

/// Wave 3 arsenal (`docs/prototypes/wave3/src/arsenal.js`): in combat the
/// hero's spells, attacks and features sit under the turn as three doors;
/// each opens one sheet whose tabs keep one height, the turn tokens on top
/// filtering what is still possible this turn.

enum ArsenalTab { spells, attacks, feats }

/// What the hero picked in the arsenal.
sealed class ArsenalPick {
  const ArsenalPick();
}

class SpellPick extends ArsenalPick {
  const SpellPick(this.spell);
  final Spell spell;
}

class AttackPick extends ArsenalPick {
  const AttackPick(this.attack);
  final WeaponAttack attack;
}

class FeaturePick extends ArsenalPick {
  const FeaturePick(this.feature);
  final CharacterFeature feature;
}

/// A weapon as the Overview counts it: to-hit, dice, ability modifier.
class WeaponAttack {
  const WeaponAttack({
    required this.name,
    required this.hit,
    required this.count,
    required this.sides,
    required this.modifier,
    required this.type,
    required this.ranged,
    this.note,
  });
  final String name, type;
  final String? note;
  final int hit, count, sides, modifier;
  final bool ranged;
}

List<WeaponAttack> weaponAttacks(
    Character c, AppLocalizations l10n, String locale) {
  final str = c.abilityScores.strengthModifier,
      dex = c.abilityScores.dexterityModifier;
  String typeName(String raw) => switch (raw.toLowerCase()) {
        'slashing' => l10n.damageTypeSlashing,
        'piercing' => l10n.damageTypePiercing,
        'bludgeoning' => l10n.damageTypeBludgeoning,
        'fire' => l10n.damageTypeFire,
        'cold' => l10n.damageTypeCold,
        'lightning' => l10n.damageTypeLightning,
        'radiant' => l10n.damageTypeRadiant,
        'necrotic' => l10n.damageTypeNecrotic,
        'force' => l10n.damageTypeForce,
        'poison' => l10n.damageTypePoison,
        'psychic' => l10n.damageTypePsychic,
        'thunder' => l10n.damageTypeThunder,
        'acid' => l10n.damageTypeAcid,
        _ => l10n.damageTypePhysical,
      };
  final weapons = c.inventory
      .where((i) => i.isEquipped && i.type == ItemType.weapon)
      .toList();
  if (weapons.isEmpty) {
    return [
      WeaponAttack(
          name: l10n.unarmedStrike,
          hit: str + c.proficiencyBonus,
          count: 0,
          sides: 1,
          modifier: 1 + str,
          type: l10n.damageTypeBludgeoning.toLowerCase(),
          ranged: false)
    ];
  }
  return [
    for (final w in weapons)
      () {
        final tags = w.weaponProperties?.weaponTags ?? const <String>[];
        final ranged =
            w.weaponProperties?.range != null && !tags.contains('thrown');
        final mod =
            (ranged || (tags.contains('finesse') && dex > str)) ? dex : str;
        final trained = CharacterTraining.weapon(c, w);
        final dice = RegExp(r'(\d+)d(\d+)')
            .firstMatch(w.weaponProperties?.damageDice ?? '1d4');
        final range = w.weaponProperties?.range,
            long = w.weaponProperties?.longRange;
        return WeaponAttack(
            name: w.getName(locale),
            hit: mod + (trained == false ? 0 : c.proficiencyBonus),
            count: int.tryParse(dice?.group(1) ?? '1') ?? 1,
            sides: int.tryParse(dice?.group(2) ?? '4') ?? 4,
            modifier: mod,
            type: typeName(w.weaponProperties?.damageType.name ?? '')
                .toLowerCase(),
            ranged: ranged,
            note: range == null
                ? null
                : '$range${long == null ? '' : '/$long'} ${locale == 'ru' ? 'фт.' : 'ft.'}');
      }()
  ];
}

/// Rounds a concentration lasts: a minute is ten.
int concentrationRounds(Spell? spell) {
  final d = (spell?.duration ?? '').toLowerCase();
  final n = int.tryParse(RegExp(r'(\d+)').firstMatch(d)?.group(1) ?? '1') ?? 1;
  if (d.contains('hour') || d.contains('час')) return 600 * n;
  if (d.contains('day') || d.contains('дн') || d.contains('сут')) {
    return 14400 * n;
  }
  if (d.contains('round') || d.contains('раунд')) return n;
  if (d.contains('minute') || d.contains('мин')) return 10 * n;
  return 10;
}

/// The effect sync with localized names, for any combat write.
void syncEffectsIn(Character c, bool ru) => syncCombatEffects(c,
    rage: ru ? 'Ярость' : 'Rage',
    sacred: ru ? 'Священное оружие' : 'Sacred Weapon',
    concentration: (id) =>
        SpellService.getSpellById(id)?.getName(ru ? 'ru' : 'en') ?? id,
    concentrationRounds: (id) =>
        concentrationRounds(SpellService.getSpellById(id)));

/// Features the arsenal lists: usable now, with an action of their own or
/// a reserve.
List<CharacterFeature> arsenalFeatures(Character c) {
  final seen = <String>{};
  return [
    for (final f in c.features)
      if (f.type != FeatureType.passive &&
          (f.resourcePool != null ||
              const {
                FeatureType.action,
                FeatureType.bonusAction,
                FeatureType.reaction,
                FeatureType.toggle
              }.contains(f.type)) &&
          (f.associatedClass == null ||
              CharacterClassContext(
                      c, FeatureService.classKey(f.associatedClass!))
                  .canUseFeature(f)) &&
          seen.add(f.nameEn.toLowerCase()))
        f
  ];
}

TurnCost featureCost(CharacterFeature f) {
  final typed = switch (f.type) {
    FeatureType.action => TurnCost.action,
    FeatureType.bonusAction => TurnCost.bonus,
    FeatureType.reaction => TurnCost.reaction,
    _ => TurnCostKey.parse(f.actionEconomy),
  };
  if (typed != TurnCost.free) return typed;
  // Reserves carry no economy of their own; the rules give them one.
  final id = f.id.toLowerCase().replaceAll('_', '-');
  const bonus = [
    'rage',
    'second-wind',
    'cunning-action',
    'bardic-inspiration',
    'flurry',
    'step-of-the-wind',
    'patient-defense'
  ];
  const action = [
    'lay-on-hands',
    'divine-sense',
    'channel-divinity',
    'wild-shape',
    'sacred-weapon',
    'divine-intervention'
  ];
  const reaction = ['uncanny-dodge', 'deflect-missiles'];
  if (bonus.any(id.contains)) return TurnCost.bonus;
  if (action.any(id.contains)) return TurnCost.action;
  if (reaction.any(id.contains)) return TurnCost.reaction;
  return TurnCost.free;
}

/// The instrument of a feature on its class panel (wave 2 keys).
String? instrumentKey(Character c, CharacterFeature f) {
  final id = f.id.toLowerCase().replaceAll('_', '-');
  final cls = f.associatedClass == null
      ? ''
      : FeatureService.classKey(f.associatedClass!);
  bool has(String part) => id.contains(part);
  if (has('lay-on-hands')) return 'paladin-lay-on-hands';
  if (has('divine-smite')) return 'paladin-smite';
  if (has('divine-sense')) return 'paladin-divine-sense';
  if (has('channel-divinity') || has('sacred-weapon')) {
    return cls == 'cleric' ? 'cleric-channel' : 'paladin-channel';
  }
  if (has('divine-intervention')) return 'cleric-intervention';
  if (has('rage') || has('reckless') || has('frenzy')) return 'barbarian-rage';
  if (has('sneak-attack')) return 'rogue-sneak-attack';
  if (has('cunning-action')) return 'rogue-cunning';
  if (has('uncanny-dodge')) return 'rogue-uncanny-dodge';
  if (has('second-wind')) return 'fighter-second-wind';
  if (has('action-surge') || has('indomitable')) {
    return 'fighter-action-${f.id}';
  }
  if (has('ki') ||
      has('flurry') ||
      has('patient-defense') ||
      has('step-of-the-wind')) {
    return 'monk-ki';
  }
  if (has('bardic-inspiration')) return 'bard-inspiration';
  if (has('wild-shape')) return 'druid-wild-shape';
  if (has('sorcery') || has('font-of-magic')) return 'sorcerer-font';
  if (has('arcane-recovery')) return 'wizard-arcane-recovery';
  return null;
}

/* ------------------------------------------------------------- the doors */

/// The arsenal on the combat screen: three doors, each with what it holds.
class ArsenalDoors extends StatelessWidget {
  const ArsenalDoors(
      {super.key, required this.character, required this.onOpen});
  final Character character;
  final ValueChanged<ArsenalTab> onOpen;

  static List<ArsenalTab> tabs(Character c) => [
        if (SpellUse.visible(c).any((s) => SpellUse.ready(c, s)))
          ArsenalTab.spells,
        ArsenalTab.attacks,
        if (arsenalFeatures(c).isNotEmpty) ArsenalTab.feats,
      ];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ru = instrumentRu(context);
    final hero = character;
    var slots = 0;
    try {
      final s = MagicSlots.read(hero);
      slots = s.current.fold(0, (a, b) => a + b) + (s.pact?.current ?? 0);
    } catch (_) {}
    final per = CharacterTraining.attacks(hero);
    final turn = CombatTurn(hero.combatState);
    final attacks = weaponAttacks(hero, l10n, ru ? 'ru' : 'en');
    final active = [
      if (hero.isRaging) ru ? 'Ярость' : 'Rage',
      if (hero.isSacredWeaponActive) ru ? 'Священное оружие' : 'Sacred Weapon',
    ];
    final feats = arsenalFeatures(hero).length;
    String sub(ArsenalTab t) => switch (t) {
          ArsenalTab.spells => ru
              ? '$slots ${ruPlural(slots, 'ячейка', 'ячейки', 'ячеек')}'
              : '$slots slots',
          ArsenalTab.attacks => per > 1
              ? (ru
                  ? 'ещё ${math.max(0, per - turn.attacks)} из $per'
                  : '${math.max(0, per - turn.attacks)} of $per left')
              : '${attacks.first.hit >= 0 ? '+' : '−'}${attacks.first.hit.abs()} ${ru ? 'к попаданию' : 'to hit'}',
          ArsenalTab.feats => active.isNotEmpty
              ? active.join(', ')
              : ru
                  ? '$feats ${ruPlural(feats, 'умение', 'умения', 'умений')}'
                  : '$feats features',
        };
    final names = {
      ArsenalTab.spells: ru ? 'Заклинания' : 'Spells',
      ArsenalTab.attacks: ru ? 'Атаки' : 'Attacks',
      ArsenalTab.feats: ru ? 'Умения' : 'Features',
    };
    const icons = {
      ArsenalTab.spells: 'wand',
      ArsenalTab.attacks: 'sword',
      ArsenalTab.feats: 'star'
    };
    const accents = {
      ArsenalTab.spells: 5,
      ArsenalTab.attacks: 0,
      ArsenalTab.feats: 2
    };
    final list = tabs(hero);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final t in list) ...[
          if (t != list.first) const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              key: ValueKey('arsenal-door-${t.name}'),
              onTap: () {
                HapticFeedback.selectionClick();
                onOpen(t);
              },
              scale: .95,
              semanticLabel: names[t]!,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(22),
                  border: t == ArsenalTab.feats && active.isNotEmpty
                      ? Border.all(
                          color: AppAccents.of(context)
                              .at(2)
                              .withValues(alpha: .6),
                          width: 1.5)
                      : null,
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppAccents.of(context)
                                  .at(accents[t]!)
                                  .withValues(alpha: .45),
                              width: 1.5),
                        ),
                        child: InstrumentGlyph(icons[t]!,
                            size: 19,
                            color: AppAccents.of(context).at(accents[t]!)),
                      ),
                      const SizedBox(height: 10),
                      Text(names[t]!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: AppType.body,
                              fontSize: 14,
                              height: 1.15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(sub(t),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppType.body,
                              fontSize: 11.5,
                              height: 1.25,
                              color: t == ArsenalTab.feats && active.isNotEmpty
                                  ? AppAccents.of(context).at(2)
                                  : c.onSurfaceVariant)),
                    ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/* ------------------------------------------------------------- the sheet */

/// The arsenal sheet; answers with what was picked, or null.
Future<ArsenalPick?> showArsenalSheet(
        BuildContext context, Character c, ArsenalTab tab) =>
    showCompanionSheet<ArsenalPick>(context,
        builder: (_) => _ArsenalSheet(hero: c, tab: tab));

class _ArsenalSheet extends StatefulWidget {
  const _ArsenalSheet({required this.hero, required this.tab});
  final Character hero;
  final ArsenalTab tab;
  @override
  State<_ArsenalSheet> createState() => _ArsenalSheetState();
}

class _ArsenalSheetState extends State<_ArsenalSheet> {
  late ArsenalTab _tab = widget.tab;
  TurnCost? _filter;
  bool _busy = false;
  int _shift = 0, _dir = 1;

  Character get _hero => widget.hero;

  bool _show(TurnCost cost) =>
      _filter == null || cost == _filter || cost == TurnCost.free;

  Future<void> _spendSlot(MagicPool pool, int circle) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final spent =
          await GameplayActionsService.changeMagicSlot(_hero, pool, circle, -1);
      if (spent) HapticFeedback.lightImpact();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final tabs = ArsenalDoors.tabs(_hero);
    if (!tabs.contains(_tab)) _tab = tabs.first;
    final turn = CombatTurn(_hero.combatState);
    final names = {
      ArsenalTab.spells: ru ? 'Заклинания' : 'Spells',
      ArsenalTab.attacks: ru ? 'Атаки' : 'Attacks',
      ArsenalTab.feats: ru ? 'Умения' : 'Features',
    };
    const tint = {
      ArsenalTab.spells: 5,
      ArsenalTab.attacks: 0,
      ArsenalTab.feats: 2
    };
    // Every tab is laid out; the sheet keeps the tallest one's height so
    // switching never makes it jump.
    final pages = {
      for (final t in tabs)
        t: _page(context, t, AppAccents.of(context).at(tint[t]!))
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_hero.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.secondary)),
      const SizedBox(height: 8),
      SheetHeading(ru ? 'Арсенал' : 'Arsenal'),
      const SizedBox(height: 14),
      if (tabs.length > 1) ...[
        FlowSegment<ArsenalTab>(
          keyPrefix: 'arsenal-tab',
          values: tabs,
          labels: [for (final t in tabs) names[t]!],
          selected: _tab,
          onChanged: (t) => setState(() {
            _dir = tabs.indexOf(t) > tabs.indexOf(_tab) ? 1 : -1;
            _tab = t;
            _shift++;
          }),
        ),
        const SizedBox(height: 10),
      ],
      // The turn tokens ride along and filter: "what can I still do with
      // my bonus action?"
      Row(children: [
        for (final (cost, label, accent) in [
          (TurnCost.action, ru ? 'Действие' : 'Action', 0),
          (TurnCost.bonus, ru ? 'Бонусное' : 'Bonus', 1),
          (TurnCost.reaction, ru ? 'Реакция' : 'Reaction', 4),
        ]) ...[
          if (cost != TurnCost.action) const SizedBox(width: 6),
          Expanded(
            child: _Filter(
              key: ValueKey('arsenal-filter-${cost.key}'),
              label: label,
              accent: AppAccents.of(context).at(accent),
              used: turn.used(cost),
              on: _filter == cost,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _filter = _filter == cost ? null : cost;
                  _dir = 0;
                  _shift++;
                });
              },
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      Stack(children: [
        for (final t in tabs)
          Visibility(
            visible: t == _tab,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: t != _tab
                ? pages[t]!
                : TweenAnimationBuilder<double>(
                    key: ValueKey('page-$t-$_shift'),
                    tween: Tween(
                        begin: _shift == 0 ||
                                MediaQuery.disableAnimationsOf(context)
                            ? 1
                            : 0,
                        end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: AppMotion.snappyCurve,
                    builder: (context, p, child) => Opacity(
                        opacity: p.clamp(0.0, 1.0),
                        child: Transform.translate(
                            offset: Offset(18.0 * _dir * (1 - p), 0),
                            child: child)),
                    child: pages[t]!,
                  ),
          ),
      ]),
    ]);
  }

  Widget _page(BuildContext context, ArsenalTab tab, Color tint) =>
      switch (tab) {
        ArsenalTab.spells => _spells(context, tint),
        ArsenalTab.attacks => _attacks(context, tint),
        ArsenalTab.feats => _feats(context, tint),
      };

  Widget _none(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _spells(BuildContext context, Color tint) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final hero = _hero;
    final turn = CombatTurn(hero.combatState);
    final spells = SpellUse.visible(hero)
        .where((s) =>
            SpellUse.ready(hero, s) && _show(TurnCostKey.parse(s.castingTime)))
        .toList()
      ..sort((a, b) => a.level != b.level
          ? a.level - b.level
          : a.getName(locale).compareTo(b.getName(locale)));
    if (spells.isEmpty) {
      return _none(context,
          ru ? 'Нет заклинаний на это действие' : 'No spells for this action');
    }
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(hero);
    } catch (_) {}
    final circles = [
      ...{for (final s in spells) s.level}
    ]..sort();
    final children = <Widget>[];
    for (final level in circles) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      final max = level > 0 && slots != null && level <= slots.maximum.length
          ? slots.maximum[level - 1]
          : 0;
      final left = level > 0 && slots != null
          ? slots.remaining(MagicPool.shared, level)
          : 0;
      children.add(_GroupHead(
        title: level == 0
            ? (ru ? 'Заговоры' : 'Cantrips')
            : (ru ? '$level круг' : 'Level $level'),
        tint: tint,
        max: max,
        left: left,
        note: level == 0 ? (ru ? 'без ячеек' : 'no slots') : null,
        onSpend: max > 0 && !_busy
            ? () => _spendSlot(MagicPool.shared, level)
            : null,
      ));
      children.add(const SizedBox(height: 6));
      for (final s in spells.where((s) => s.level == level)) {
        final cost = TurnCostKey.parse(s.castingTime);
        final eff = spellEffect(s.id, math.max(1, s.level), 0, hero, ru: ru);
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _Row(
            key: ValueKey('arsenal-spell-${s.id}'),
            cost: cost,
            spent: turn.used(cost),
            name: s.getName(locale),
            concentration: s.concentration,
            value: eff?.value,
            tint: tint,
            onTap: () => Navigator.pop(context, SpellPick(s)),
          ),
        ));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _attacks(BuildContext context, Color tint) {
    final ru = instrumentRu(context);
    final l10n = AppLocalizations.of(context)!;
    final hero = _hero;
    if (!_show(TurnCost.action)) {
      return _none(context,
          ru ? 'Атака тратит действие' : 'An attack spends the action');
    }
    final turn = CombatTurn(hero.combatState);
    final per = CharacterTraining.attacks(hero);
    final out = per > 1 && turn.attacks >= per;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (per > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _GroupHead(
              title: ru ? 'Атак в действии' : 'Attacks per action',
              tint: AppAccents.of(context).at(0),
              max: per,
              left: math.max(0, per - turn.attacks)),
        ),
      for (final a in weaponAttacks(hero, l10n, ru ? 'ru' : 'en'))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _Row(
            key: ValueKey('arsenal-attack-${a.name}'),
            cost: TurnCost.action,
            spent: turn.used(TurnCost.action) && (per == 1 || out),
            name: a.name,
            line:
                '${a.count > 0 ? '${a.count}${ru ? 'к' : 'd'}${a.sides} ' : ''}${a.modifier >= 0 ? '+ ' : '− '}${a.modifier.abs()} ${a.type}${a.note == null ? '' : ' · ${a.note}'}',
            value: '${a.hit >= 0 ? '+' : '−'}${a.hit.abs()}',
            tint: tint,
            onTap: () => Navigator.pop(context, AttackPick(a)),
          ),
        ),
    ]);
  }

  Widget _feats(BuildContext context, Color tint) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final hero = _hero;
    final turn = CombatTurn(hero.combatState);
    final feats =
        arsenalFeatures(hero).where((f) => _show(featureCost(f))).toList();
    if (feats.isEmpty) {
      return _none(context,
          ru ? 'Нет умений на это действие' : 'No features for this action');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in feats)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Peek(
            title: f.getName(locale),
            text: f.getDescription(locale).split('\n').first,
            accent: tint,
            child: _Row(
              key: ValueKey('arsenal-feat-${f.id}'),
              cost: featureCost(f),
              spent: turn.used(featureCost(f)),
              name: f.getName(locale),
              line: f.getDescription(locale).split('\n').first,
              value: f.resourcePool == null
                  ? null
                  : '${GameplayActionsService.resourceCurrent(hero, f)}/${f.resourcePool!.maxUses}',
              on: (f.id.contains('rage') && hero.isRaging) ||
                  (f.id.contains('channel') && hero.isSacredWeaponActive),
              empty: f.resourcePool != null &&
                  GameplayActionsService.resourceCurrent(hero, f) == 0,
              tint: tint,
              onTap: () => Navigator.pop(context, FeaturePick(f)),
            ),
          ),
        ),
    ]);
  }
}

class _Filter extends StatelessWidget {
  const _Filter(
      {super.key,
      required this.label,
      required this.accent,
      required this.used,
      required this.on,
      required this.onTap});
  final String label;
  final Color accent;
  final bool used, on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      selected: on,
      scale: .95,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 260)),
        curve: AppMotion.snappyCurve,
        height: 40,
        decoration: BoxDecoration(
          color: on
              ? Color.alphaBlend(
                  accent.withValues(alpha: .18), c.surfaceContainerLow)
              : c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(on ? 10 : 14),
          border: Border.all(
              color: on ? accent.withValues(alpha: .6) : Colors.transparent,
              width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: used ? Colors.transparent : accent,
              border: used
                  ? Border.all(
                      color: c.onSurface.withValues(alpha: .25), width: 1.5)
                  : null,
            ),
            child: used
                ? LineIcon('check', size: 11, color: c.onSurfaceVariant)
                : null,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: used ? c.onSurfaceVariant : c.onSurface)),
          ),
        ]),
      ),
    );
  }
}

class _GroupHead extends StatelessWidget {
  const _GroupHead(
      {required this.title,
      required this.tint,
      required this.max,
      required this.left,
      this.note,
      this.onSpend});
  final String title;
  final Color tint;
  final int max, left;
  final String? note;
  final VoidCallback? onSpend;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(children: [
        Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
                color: tint, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w600)),
        ),
        if (note != null)
          Text(note!,
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 12.5,
                  color: c.onSurfaceVariant))
        else if (max > 0)
          Peek(
            title: title,
            text: onSpend == null
                ? ''
                : (ru
                    ? 'Касание — потратить ячейку вручную'
                    : 'Tap to spend a slot by hand'),
            accent: tint,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSpend,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  for (var i = 0; i < math.min(max, 8); i++)
                    Container(
                      width: 11,
                      height: 11,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < left ? tint : Colors.transparent,
                        border: i < left
                            ? null
                            : Border.all(color: c.outline, width: 1.6),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text('$left/$max',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A row of the arsenal in the app's list language: the cost as a token
/// (solid while the turn has it, outlined once spent), the name, a quiet
/// value in the tab's colour.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.cost,
    required this.spent,
    required this.name,
    required this.tint,
    required this.onTap,
    this.line,
    this.value,
    this.concentration = false,
    this.on = false,
    this.empty = false,
  });
  final TurnCost cost;
  final bool spent, concentration, on, empty;
  final String name;
  final String? line, value;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final accent = AppAccents.of(context).at(switch (cost) {
      TurnCost.action => 0,
      TurnCost.bonus => 1,
      TurnCost.reaction => 4,
      TurnCost.free => 3,
    });
    final letter = switch (cost) {
      TurnCost.action => ru ? 'Д' : 'A',
      TurnCost.bonus => ru ? 'БД' : 'B',
      TurnCost.reaction => ru ? 'Р' : 'R',
      TurnCost.free => '',
    };
    return Opacity(
      opacity: empty
          ? .38
          : spent
              ? .55
              : 1,
      child: Pressable(
        onTap: onTap,
        scale: .98,
        semanticLabel: name,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          decoration: BoxDecoration(
              color: on
                  ? Color.alphaBlend(
                      AppAccents.of(context).at(0).withValues(alpha: .12),
                      c.surfaceContainerLow)
                  : c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            AnimatedContainer(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 360)),
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: spent ? Colors.transparent : accent,
                borderRadius: BorderRadius.circular(spent ? 12 : 17),
                border: spent
                    ? Border.all(
                        color: c.onSurface.withValues(alpha: .2), width: 1.6)
                    : null,
              ),
              child: cost == TurnCost.free
                  ? InstrumentGlyph('spark',
                      size: 16, color: spent ? c.onSurfaceVariant : c.surface)
                  : Text(letter,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: spent ? c.onSurfaceVariant : c.surface)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: AppType.body,
                                fontSize: 14.5,
                                height: 1.2,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (concentration) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppAccents.of(context)
                                  .at(5)
                                  .withValues(alpha: .2),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(ru ? 'К' : 'C',
                              style: TextStyle(
                                  fontFamily: AppType.body,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppAccents.of(context).at(5))),
                        ),
                      ],
                    ]),
                    if (line != null && line!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(line!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: AppType.body,
                                fontSize: 12,
                                height: 1.3,
                                color: c.onSurfaceVariant)),
                      ),
                  ]),
            ),
            if (on)
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(left: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPaletteRoles.heal(context)),
                child: LineIcon('check', size: 14, color: c.surface),
              )
            else if (value != null && value!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: tint.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(11)),
                child: Text(value!,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: tint)),
              ),
          ]),
        ),
      ),
    );
  }
}

/* ----------------------------------------------------- feature instrument */

/// A feature applied through its own class instrument (wave 2): the
/// class panel opens in a sheet, windowed onto that one instrument.
/// Returns true when the hero changed while it was open.
Future<bool> showFeatureInstrument(
    BuildContext context, Character c, CharacterFeature f) async {
  final stamp = c.updatedAt;
  final cls = f.associatedClass == null
      ? null
      : FeatureService.classKey(f.associatedClass!);
  await showCompanionSheet<void>(context,
      builder: (_) => _InstrumentSheet(
          hero: c, classId: cls, focus: instrumentKey(c, f), feature: f));
  return c.updatedAt != stamp;
}

class _InstrumentSheet extends StatefulWidget {
  const _InstrumentSheet(
      {required this.hero,
      required this.classId,
      required this.focus,
      required this.feature});
  final Character hero;
  final String? classId, focus;
  final CharacterFeature feature;
  @override
  State<_InstrumentSheet> createState() => _InstrumentSheetState();
}

class _InstrumentSheetState extends State<_InstrumentSheet> {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final cost = featureCost(widget.feature);
    final panels = buildClassPanels(context, widget.hero,
        onChanged: () => setState(() {}));
    final panel = panels.where((p) => p.id == widget.classId).firstOrNull ??
        panels.firstOrNull;
    final kicker = switch (cost) {
      TurnCost.action => ru ? 'Действие' : 'Action',
      TurnCost.bonus => ru ? 'Бонусное действие' : 'Bonus action',
      TurnCost.reaction => ru ? 'Реакция' : 'Reaction',
      TurnCost.free => ru ? 'Без действия' : 'No action',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(kicker,
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.secondary)),
      const SizedBox(height: 12),
      if (panel == null)
        Text(widget.feature.getDescription(ru ? 'ru' : 'en'))
      else if (widget.focus == null)
        panel.child
      else
        InstrumentWindow(focus: widget.focus!, child: panel.child),
    ]);
  }
}

/// Shows only the instrument keyed [focus] of a class panel: the whole
/// panel lives (state, gestures, sheets), the window frames one part of
/// it and follows it as it changes size. Without such an instrument the
/// whole panel shows.
class InstrumentWindow extends StatefulWidget {
  const InstrumentWindow({super.key, required this.focus, required this.child});
  final String focus;
  final Widget child;
  @override
  State<InstrumentWindow> createState() => _InstrumentWindowState();
}

class _InstrumentWindowState extends State<InstrumentWindow>
    with SingleTickerProviderStateMixin {
  final _root = GlobalKey();
  Rect? _rect;
  bool _missing = false;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Measured every frame the sheet is open: the instrument changes size
    // as it is used, and the window follows.
    _ticker = createTicker((_) => _measure())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _measure() {
    final rootContext = _root.currentContext;
    final rootBox = rootContext?.findRenderObject() as RenderBox?;
    if (rootContext == null || rootBox == null || !rootBox.hasSize) return;
    Element? found;
    void visit(Element e) {
      if (found != null) return;
      final key = e.widget.key;
      if (key is ValueKey && key.value == widget.focus) {
        found = e;
        return;
      }
      e.visitChildElements(visit);
    }

    (rootContext as Element).visitChildElements(visit);
    final box = found?.renderObject as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) {
      if (!_missing) setState(() => _missing = true);
      return;
    }
    final rect = box.localToGlobal(Offset.zero, ancestor: rootBox) & box.size;
    if (rect != _rect || _missing) {
      setState(() {
        _rect = rect;
        _missing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    final panel = KeyedSubtree(key: _root, child: widget.child);
    if (_missing && rect == null) return panel;
    if (rect == null) {
      // The first frame lays the panel out unseen to find the instrument.
      return Opacity(
          opacity: 0,
          child: SizedBox(
              height: 1,
              child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: double.infinity,
                  child: panel)));
    }
    return ClipRect(
      child: SizedBox(
        height: rect.height,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child:
              Transform.translate(offset: Offset(0, -rect.top), child: panel),
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------- attack sheet */

/// One weapon attack in combat (wave 3 attack sheet): advantage, the
/// to-hit roll, then the damage with what the class adds — Divine Smite
/// for a slot, Improved Divine Smite, Sneak Attack once a turn, rage — a
/// critical doubling the dice. The first attack spends the action.
Future<void> showAttackSheet(
        BuildContext context, Character c, WeaponAttack a) =>
    showCompanionSheet<void>(context,
        builder: (_) => _AttackSheet(hero: c, attack: a));

class _AttackSheet extends StatefulWidget {
  const _AttackSheet({required this.hero, required this.attack});
  final Character hero;
  final WeaponAttack attack;
  @override
  State<_AttackSheet> createState() => _AttackSheetState();
}

enum _Phase { hit, damage, done }

class _AttackSheetState extends State<_AttackSheet> {
  late int _adv = widget.hero.isReckless ? 1 : 0; // -1 dis, 0 normal, 1 adv
  int _smite = 0;
  bool _sneak = false, _busy = false, _crit = false;
  _Phase _phase = _Phase.hit;
  (int, int?)? _hit; // kept d20, other d20
  int _hitKey = 0;
  List<(int sides, int value, String tag)> _damage = [];
  int _damageFlat = 0, _damageKey = 0;
  final _rnd = math.Random();

  Character get _hero => widget.hero;
  int get _paladin => _hero.classLevel('paladin');
  int get _rogue => _hero.classLevel('rogue');
  int get _barbarian => _hero.classLevel('barbarian');
  bool get _canSmite =>
      _paladin >= 2 &&
      !widget.attack.ranged &&
      _hero.features.any((f) =>
          f.id.contains('divine-smite') || f.id.contains('divine_smite'));
  int get _sneakDice => (_rogue + 1) ~/ 2;
  int get _hitBonus =>
      widget.attack.hit +
      (_hero.isSacredWeaponActive ? _hero.abilityScores.charismaModifier : 0);
  int get _rageBonus => _hero.isRaging && !widget.attack.ranged
      ? (_barbarian >= 16
          ? 4
          : _barbarian >= 9
              ? 3
              : 2)
      : 0;
  int get _brutal => _barbarian >= 17
      ? 3
      : _barbarian >= 13
          ? 2
          : _barbarian >= 9
              ? 1
              : 0;

  Future<void> _rollHit() async {
    if (_busy) return;
    final ru = instrumentRu(context);
    setState(() => _busy = true);
    final a = _rnd.nextInt(20) + 1, b = _adv == 0 ? null : _rnd.nextInt(20) + 1;
    final kept = b == null
        ? a
        : _adv > 0
            ? math.max(a, b)
            : math.min(a, b);
    try {
      await GameplayActionsService.combat(_hero, () {
        final turn = CombatTurn(_hero.combatState);
        turn.setUsed(TurnCost.action, true);
        turn.attacks = turn.attacks + 1;
        CombatActionsService.note(
            _hero,
            ru
                ? '${widget.attack.name}: ${kept + _hitBonus} к попаданию${kept == 20 ? ' · крит' : ''}'
                : '${widget.attack.name}: ${kept + _hitBonus} to hit${kept == 20 ? ' · critical' : ''}');
      });
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _hit = (kept, b == null ? null : (kept == a ? b : a));
      _hitKey++;
    });
    await Future<void>.delayed(MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 820));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _crit = kept == 20;
      _phase = kept == 1 ? _Phase.done : _Phase.damage;
    });
    if (kept == 20) HapticFeedback.mediumImpact();
  }

  Future<void> _rollDamage() async {
    if (_busy) return;
    final ru = instrumentRu(context);
    final a = widget.attack;
    final groups = <(int count, int sides, String tag)>[
      if (a.count > 0)
        (
          a.count * (_crit ? 2 : 1) + (_crit ? _brutal : 0),
          a.sides,
          a.type.length > 3 ? a.type.substring(0, 3) : a.type
        ),
      if (_paladin >= 11 && !a.ranged) (_crit ? 2 : 1, 8, ru ? 'изл' : 'rad'),
      if (_smite > 0)
        (math.min(5, _smite + 1) * (_crit ? 2 : 1), 8, ru ? 'кара' : 'smite'),
      if (_sneak) (_sneakDice * (_crit ? 2 : 1), 6, ru ? 'скрыт' : 'sneak'),
    ];
    final rolls = [
      for (final g in groups)
        for (var i = 0; i < g.$1; i++) (g.$2, _rnd.nextInt(g.$2) + 1, g.$3)
    ];
    final flat = a.modifier + _rageBonus;
    final total = rolls.fold<int>(0, (s, r) => s + r.$2) + flat;
    setState(() => _busy = true);
    try {
      await GameplayActionsService.combat(_hero, () {
        if (_smite > 0) spendSharedSlotInWrite(_hero, _smite);
        if (_sneak) CombatTurn(_hero.combatState).sneakUsed = true;
        CombatActionsService.note(
            _hero, ru ? '${a.name}: $total урона' : '${a.name}: $total damage',
            type: CombatLogType.other, amount: total);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _damage = rolls;
      _damageFlat = flat;
      _damageKey++;
    });
    await Future<void>.delayed(MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 900));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _busy = false;
      _phase = _Phase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final a = widget.attack;
    final per = CharacterTraining.attacks(_hero);
    final turn = CombatTurn(_hero.combatState);
    final a0 = AppAccents.of(context).at(0), a2 = AppAccents.of(context).at(2);
    final more = _phase == _Phase.done && turn.attacks < per;
    String label() => switch (_phase) {
          _Phase.hit =>
            '${ru ? 'Бросить атаку' : 'Roll the attack'} · ${_hitBonus >= 0 ? '+' : '−'}${_hitBonus.abs()}',
          _Phase.damage => ru ? 'Бросить урон' : 'Roll damage',
          _Phase.done => more
              ? (ru
                  ? 'Следующая атака · ${turn.attacks + 1} из $per'
                  : 'Next attack · ${turn.attacks + 1} of $per')
              : (ru ? 'Готово' : 'Done'),
        };
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(_hero);
    } catch (_) {}
    Widget tag(String icon, String text, Color accent) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: accent.withValues(alpha: .18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            InstrumentGlyph(icon, size: 13, color: c.onSurface),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        );
    final hit = _hit;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          '${ru ? 'Атака · Действие' : 'Attack · Action'}${per > 1 ? ' · ${math.min(turn.attacks + (_phase == _Phase.hit ? 1 : 0), per)} ${ru ? 'из' : 'of'} $per' : ''}',
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: a0)),
      const SizedBox(height: 8),
      SheetHeading(a.name),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (_hero.isSacredWeaponActive)
          tag(
              'sun',
              '${ru ? 'Священное оружие' : 'Sacred Weapon'} +${_hero.abilityScores.charismaModifier}',
              a2),
        if (_rageBonus > 0)
          tag(
              'axe',
              '${ru ? 'Ярость' : 'Rage'} +$_rageBonus ${ru ? 'урона' : 'damage'}',
              a0),
        if (_hero.isReckless)
          tag('bolt', ru ? 'Безрассудно' : 'Reckless',
              AppAccents.of(context).at(1)),
        if (_paladin >= 11 && !a.ranged)
          tag('star', ru ? 'Улучшенная кара +1к8' : 'Improved Smite +1d8', a2),
      ]),
      const SizedBox(height: 12),
      FlowSegment<int>(
        keyPrefix: 'attack-adv',
        values: const [-1, 0, 1],
        labels: ru
            ? const ['Помеха', 'Обычно', 'Преимущество']
            : const ['Disadvantage', 'Normal', 'Advantage'],
        selected: _adv,
        onChanged: (v) =>
            _phase == _Phase.hit ? setState(() => _adv = v) : null,
      ),
      if (hit != null) ...[
        const SizedBox(height: 12),
        _Result(
          label: ru ? 'Попадание' : 'To hit',
          dice: [
            (20, hit.$1, ''),
            if (hit.$2 != null) (20, hit.$2!, ''),
          ],
          dropped: hit.$2 == null ? const {} : {1},
          rollKey: _hitKey,
          accent: a0,
          total: hit.$1 + _hitBonus,
          crit: hit.$1 == 20,
          fumble: hit.$1 == 1,
          note: '${hit.$1} ${_hitBonus >= 0 ? '+' : '−'} ${_hitBonus.abs()}',
        ),
      ],
      if (_damage.isNotEmpty) ...[
        const SizedBox(height: 10),
        _Result(
          label: _crit
              ? (ru ? 'Урон · крит' : 'Damage · critical')
              : (ru ? 'Урон' : 'Damage'),
          dice: _damage,
          rollKey: _damageKey,
          accent: a0,
          total: _damage.fold<int>(0, (s, r) => s + r.$2) + _damageFlat,
          note: _damageFlat == 0
              ? null
              : '${ru ? 'мод' : 'mod'} ${_damageFlat >= 0 ? '+' : '−'}${_damageFlat.abs()}',
        ),
      ],
      if (_phase != _Phase.done && _damage.isEmpty) ...[
        if (_canSmite && slots != null) ...[
          const SizedBox(height: 14),
          Text(ru ? 'Божественная кара' : 'Divine Smite',
              style: const TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          Text(
              ru
                  ? 'при попадании · ячейка → 2к8 и больше'
                  : 'on a hit · a slot → 2d8 and more',
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 12,
                  color: c.onSurfaceVariant)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(children: [
              _Rung(
                  label: ru ? 'без кары' : 'none',
                  value: '—',
                  on: _smite == 0,
                  onTap: () => setState(() => _smite = 0)),
              for (var l = 1; l <= slots.maximum.length; l++)
                if (slots.maximum[l - 1] > 0)
                  _Rung(
                    key: ValueKey('smite-$l'),
                    label: '${math.min(5, l + 1)}${ru ? 'к' : 'd'}8',
                    value: '$l',
                    on: _smite == l,
                    max: slots.maximum[l - 1],
                    left: slots.remaining(MagicPool.shared, l),
                    onTap: slots.remaining(MagicPool.shared, l) > 0
                        ? () => setState(() => _smite = l)
                        : null,
                  ),
            ]),
          ),
        ],
        if (_rogue > 0) ...[
          const SizedBox(height: 12),
          Pressable(
            key: const ValueKey('attack-sneak'),
            onTap:
                turn.sneakUsed ? null : () => setState(() => _sneak = !_sneak),
            selected: _sneak,
            scale: .97,
            semanticLabel: ru ? 'Скрытая атака' : 'Sneak Attack',
            child: Opacity(
              opacity: turn.sneakUsed ? .45 : 1,
              child: AnimatedContainer(
                duration:
                    AppMotion.of(context, const Duration(milliseconds: 360)),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _sneak
                      ? Color.alphaBlend(
                          AppAccents.of(context).at(5).withValues(alpha: .2),
                          c.surfaceContainerLow)
                      : c.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _sneak
                          ? AppAccents.of(context).at(5)
                          : Colors.transparent,
                      width: 1.6),
                ),
                child: Row(children: [
                  InstrumentGlyph('mask',
                      size: 22, color: AppAccents.of(context).at(5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${ru ? 'Скрытая атака' : 'Sneak Attack'} · $_sneakDice${ru ? 'к' : 'd'}6',
                              style: const TextStyle(
                                  fontFamily: AppType.body,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                              turn.sneakUsed
                                  ? (ru
                                      ? 'Уже в этом ходу'
                                      : 'Already this turn')
                                  : (ru
                                      ? 'Раз в ход: преимущество или союзник рядом с целью'
                                      : 'Once a turn: advantage or an ally beside the target'),
                              style: TextStyle(
                                  fontFamily: AppType.body,
                                  fontSize: 11.5,
                                  color: c.onSurfaceVariant)),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ],
      const SizedBox(height: 14),
      SizedBox(
        height: 56,
        child: FilledButton(
          key: const ValueKey('attack-go'),
          style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              shape: const StadiumBorder()),
          onPressed: _busy
              ? null
              : switch (_phase) {
                  _Phase.hit => _rollHit,
                  _Phase.damage => _rollDamage,
                  _Phase.done => () => setState(() {
                        if (!more) {
                          Navigator.pop(context);
                          return;
                        }
                        _phase = _Phase.hit;
                        _hit = null;
                        _damage = [];
                        _crit = false;
                        _smite = 0;
                        _sneak = false;
                      }),
                },
          child: Text(label(),
              style: const TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }
}

class _Rung extends StatelessWidget {
  const _Rung(
      {super.key,
      required this.label,
      required this.value,
      required this.on,
      this.onTap,
      this.max = 0,
      this.left = 0});
  final String label, value;
  final bool on;
  final int max, left;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Opacity(
        opacity: onTap == null ? .35 : 1,
        child: Pressable(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          selected: on,
          scale: .95,
          semanticLabel: '$label $value',
          child: AnimatedContainer(
            duration: AppMotion.of(context, const Duration(milliseconds: 220)),
            constraints: const BoxConstraints(minWidth: 68),
            padding: const EdgeInsets.all(10),
            transform: Matrix4.translationValues(0, on ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: on
                  ? c.secondary.withValues(alpha: .22)
                  : c.onSurface.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: on
                      ? c.secondary.withValues(alpha: .6)
                      : Colors.transparent,
                  width: 1.5),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.onSurfaceVariant)),
              const SizedBox(height: 5),
              Text(value,
                  style: const TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < math.min(max, 6); i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < left ? c.secondary : Colors.transparent,
                      border: i < left
                          ? null
                          : Border.all(color: c.outline, width: 1.4),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A rolled result in a sheet: the dice tumbling, then the total rolling
/// up beside a quiet note.
class _Result extends StatelessWidget {
  const _Result({
    required this.label,
    required this.dice,
    required this.rollKey,
    required this.accent,
    required this.total,
    this.dropped = const {},
    this.crit = false,
    this.fumble = false,
    this.note,
  });
  final String label;
  final List<(int sides, int value, String tag)> dice;
  final Set<int> dropped;
  final int rollKey, total;
  final Color accent;
  final bool crit, fumble;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final shown = dice.take(12).toList(), rest = dice.length - shown.length;
    final gold = AppAccents.of(context).at(2);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: c.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < shown.length; i++)
                Opacity(
                  opacity: dropped.contains(i) ? .35 : 1,
                  child: TumbleDie(
                    shape: dieShapeFor(shown[i].$1),
                    label: '${shown[i].$2}',
                    accent: shown[i].$1 == 20
                        ? (crit && i == 0 ? gold : accent)
                        : AppAccents.of(context).at(shown[i].$1 == 6 ? 5 : 2),
                    rollKey: rollKey,
                    sides: shown[i].$1,
                    natural: shown[i].$2,
                    size: shown.length > 4 ? 42 : 52,
                    dim: dropped.contains(i),
                  ),
                ),
              if (rest > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                      color: c.onSurface.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('+$rest',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.onSurfaceVariant)),
                ),
            ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          RollingNumber(total,
              key: ValueKey('result-$label-$rollKey'),
              from: MediaQuery.disableAnimationsOf(context) ? null : 0,
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.5,
                  color: crit
                      ? gold
                      : fumble
                          ? c.primary
                          : c.onSurface)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (note != null)
                Text(note!,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.onSurfaceVariant)),
              if (crit || fumble)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: ShapeDecoration(
                        shape: StadiumBorder(
                            side: BorderSide(
                                color: (crit ? gold : c.primary)
                                    .withValues(alpha: .7),
                                width: 1.3))),
                    child: Text(
                        crit
                            ? (ru
                                ? 'Крит — кости урона удвоены'
                                : 'Critical — damage dice doubled')
                            : (ru ? 'Промах' : 'Miss'),
                        style: TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: crit ? gold : c.primary)),
                  ),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}
