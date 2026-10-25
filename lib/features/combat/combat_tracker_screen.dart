import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/character.dart';
import '../../core/models/combat_state.dart';
import '../../core/models/combat_turn.dart';
import '../../core/models/condition.dart';
import '../../core/progression/character_class_context.dart';
import '../../core/services/combat_actions_service.dart';
import '../../core/services/gameplay_actions_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/condition_presentation.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/dice_roller_modal.dart';
import '../../shared/widgets/spell_cast_sheet.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import '../character_sheet/widgets/session/condition_chips.dart';
import '../character_sheet/widgets/session/game_console.dart';
import '../character_sheet/widgets/session/hp_keypad_sheet.dart';
import '../character_sheet/widgets/session/life_band.dart';
import 'arsenal.dart';
import 'initiative_ceremony.dart';
import 'round_tape.dart';
import 'turn_panel.dart';

/// Wave 3 combat (`docs/prototypes/wave3`, scene "В бою"): the hero's
/// fight on one page. Life on top, the turn, the arsenal, the round tape
/// with its effects, conditions and the journal with undo; damage, the
/// d20 and healing in a glass dock. Every change goes through the shared
/// action path (G01): one write per action, rolled back on failure.
class CombatTrackerScreen extends StatefulWidget {
  final Character character;
  const CombatTrackerScreen({super.key, required this.character});
  @override
  State<CombatTrackerScreen> createState() => _CombatTrackerScreenState();
}

class _CombatTrackerScreenState extends State<CombatTrackerScreen> {
  final _undo = <CombatSnapshot>[];
  bool _busy = false;
  late Character _c = widget.character;

  bool get _ru => instrumentRu(context);

  /// Runs an action; when it changed the hero, the picture before it is
  /// kept for undo. Afterwards rage at 0 HP asks for Relentless Rage.
  Future<void> _track(Future<void> Function() action) async {
    if (_busy) return;
    final before = CombatSnapshot(_c), stamp = _c.updatedAt;
    setState(() => _busy = true);
    try {
      await action();
      if (_c.updatedAt != stamp) {
        _undo.add(before);
        if (_undo.length > 40) _undo.removeAt(0);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _relentless();
  }

  Future<void> _undoLast() async {
    if (_undo.isEmpty) {
      AppSnackBar.info(context, _ru ? 'Отменять нечего' : 'Nothing to undo');
      return;
    }
    final snap = _undo.removeLast();
    setState(() => _busy = true);
    try {
      await GameplayActionsService.restoreCombat(_c, snap);
      HapticFeedback.lightImpact();
      if (mounted) AppSnackBar.info(context, _ru ? 'Отменено' : 'Undone');
    } catch (_) {
      _undo.add(snap);
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Barbarian at 0 HP while raging: a Constitution save keeps them at 1.
  Future<void> _relentless() async {
    final c = _c;
    if (c.currentHp > 0 || !c.hasRelentlessRage || !c.isRaging) return;
    final dc = c.relentlessRageSaveDc, bonus = c.constitutionSavingThrowBonus;
    final ru = _ru;
    final roll = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(ru ? 'Неукротимая ярость' : 'Relentless Rage'),
        content: Text(ru
            ? 'Спасбросок Телосложения Сл $dc (${bonus >= 0 ? '+' : '−'}${bonus.abs()}): успех — 1 ОЗ.'
            : 'Constitution save DC $dc (${bonus >= 0 ? '+' : '−'}${bonus.abs()}): success leaves you at 1 HP.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context, Random().nextInt(20) + 1),
              child: Text(AppLocalizations.of(context)!.roll)),
        ],
      ),
    );
    if (roll == null || !mounted) return;
    final total = roll + bonus, kept = total >= dc;
    await GameplayActionsService.combat(c, () {
      if (kept) {
        c.currentHp = 1;
        c.deathSaves.reset();
      } else {
        c.endRage();
        CombatTurn(c.combatState).removeEffect('rage');
      }
      c.increaseRelentlessRageSaveDc();
      CombatActionsService.note(
          c,
          ru
              ? 'Неукротимая ярость: $total против Сл $dc'
              : 'Relentless Rage: $total vs DC $dc');
    });
    if (mounted) {
      AppSnackBar.info(
          context,
          kept
              ? (ru ? 'Ярость держит: 1 ОЗ' : 'Rage holds: 1 HP')
              : (ru ? 'Ярость угасла' : 'The rage fades'));
    }
  }

  Future<void> _end() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.endCombat),
        content: Text(l10n.endCombatConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.finish)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final rounds = _c.combatState.currentRound;
    try {
      await CombatActionsService.end(_c);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      final ru = _ru;
      Navigator.pop(context);
      AppSnackBar.info(
          context,
          ru
              ? 'Бой окончен за $rounds ${ruPlural(rounds, 'раунд', 'раунда', 'раундов')}'
              : 'Combat over in $rounds rounds');
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l10n.sheetSaveFailed);
    }
  }

  Future<void> _start() async {
    final total = await showInitiativeCeremony(context,
        bonus: _c.initiativeBonus, advantage: _c.hasFeralInstinct);
    if (total == null || !mounted) return;
    final ru = _ru;
    await _track(() => CombatActionsService.start(_c, total,
        text: ru
            ? 'Бой начат · инициатива $total'
            : 'Combat started · initiative $total'));
    await _track(
        () => GameplayActionsService.combat(_c, () => syncEffectsIn(_c, ru)));
  }

  Future<void> _nextRound() async {
    final ru = _ru;
    List<CombatEffect> ended = const [];
    await _track(() async {
      ended = await CombatActionsService.nextRound(_c,
          roundText: ru
              ? 'Раунд ${_c.combatState.currentRound + 1}'
              : 'Round ${_c.combatState.currentRound + 1}',
          endedText: (e) =>
              ru ? '${e.name}: время вышло' : '${e.name}: time is up');
    });
    HapticFeedback.mediumImpact();
    if (ended.isNotEmpty && mounted) {
      AppSnackBar.info(context,
          '${ended.map((e) => e.name).join(', ')} — ${ru ? 'закончилось' : 'ended'}');
    }
  }

  Future<void> _openArsenal(ArsenalTab tab) async {
    final pick = await showArsenalSheet(context, _c, tab);
    if (pick == null || !mounted) return;
    final ru = _ru;
    switch (pick) {
      case SpellPick(:final spell):
        var cast = false;
        await _track(() async {
          cast =
              await showSpellCastSheet(context, _c, spell, rollAfterCast: true);
          if (!cast) return;
          await GameplayActionsService.combat(_c, () {
            CombatTurn(_c.combatState)
                .setUsed(TurnCostKey.parse(spell.castingTime), true);
            syncEffectsIn(_c, ru);
            CombatActionsService.note(
                _c,
                ru
                    ? 'Наложено: ${spell.getName('ru')}'
                    : 'Cast: ${spell.getName('en')}');
          });
        });
      case AttackPick(:final attack):
        await _track(() => showAttackSheet(context, _c, attack));
      case FeaturePick(:final feature):
        await _track(() async {
          if (!await showFeatureInstrument(context, _c, feature)) return;
          await GameplayActionsService.combat(_c, () {
            CombatTurn(_c.combatState).setUsed(featureCost(feature), true);
            syncEffectsIn(_c, ru);
            CombatActionsService.note(_c, feature.getName(ru ? 'ru' : 'en'));
          });
        });
    }
  }

  Future<void> _move() async {
    final turn = CombatTurn(_c.combatState);
    final result = await showMovementSheet(context,
        kicker: _c.name, speed: _c.speed, moved: turn.moved, dash: turn.dash);
    if (!mounted || (result.moved == turn.moved && result.dash == turn.dash)) {
      return;
    }
    final ru = _ru;
    await _track(() => CombatActionsService.move(_c,
        moved: result.moved,
        dash: result.dash,
        dashText: ru ? 'Рывок · действие' : 'Dash · action'));
  }

  Future<void> _concentrationRoll() async {
    final ru = _ru;
    final roll = Random().nextInt(20) + 1;
    var kept = true;
    await _track(() async {
      kept = await CombatActionsService.concentrationSave(_c, roll,
          text: (total, dc, kept) => ru
              ? 'Концентрация ${kept ? 'удержана' : 'потеряна'}: $total против Сл $dc'
              : 'Concentration ${kept ? 'held' : 'lost'}: $total vs DC $dc');
    });
    HapticFeedback.lightImpact();
    if (mounted) {
      AppSnackBar.info(
          context,
          kept
              ? (ru ? 'Концентрация удержана' : 'Concentration held')
              : (ru ? 'Концентрация потеряна' : 'Concentration lost'));
    }
  }

  String _logText(CombatLogEntry e, AppLocalizations l10n) {
    final ru = _ru;
    switch (e.type) {
      case CombatLogType.damage:
        return ru ? 'Урон ${e.amount ?? ''}' : 'Damage ${e.amount ?? ''}';
      case CombatLogType.healing:
        return ru ? 'Лечение ${e.amount ?? ''}' : 'Healing ${e.amount ?? ''}';
      case CombatLogType.conditionAdded:
      case CombatLogType.conditionRemoved:
        final name = ConditionType.values
            .where((c) => (e.description ?? '').endsWith(c.displayName))
            .map((c) => ConditionPresentation.label(l10n, c))
            .firstOrNull;
        final on = e.type == CombatLogType.conditionAdded;
        return name == null
            ? e.description ?? ''
            : '${on ? (ru ? 'Наложено' : 'Gained') : (ru ? 'Снято' : 'Removed')}: $name';
      case CombatLogType.concentrationCheck:
        return (e.description ?? '').startsWith('Concentration check required')
            ? (ru
                ? 'Концентрация: Сл ${e.amount}'
                : 'Concentration: DC ${e.amount}')
            : e.description ?? '';
      default:
        return e.description ?? '';
    }
  }

  int _logAccent(CombatLogEntry e) => switch (e.type) {
        CombatLogType.damage => 0,
        CombatLogType.healing => 3,
        CombatLogType.deathSave => 0,
        CombatLogType.conditionAdded || CombatLogType.conditionRemoved => 5,
        CombatLogType.concentrationCheck => 5,
        CombatLogType.roundStart => 2,
        CombatLogType.other => 4,
      };

  Future<void> _logSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final ru = _ru;
    final undo = await showCompanionSheet<bool>(context, builder: (context) {
      final c = Theme.of(context).colorScheme;
      final log = _c.combatState.combatLog.reversed.toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_c.name,
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.secondary)),
        const SizedBox(height: 8),
        SheetHeading(ru ? 'Журнал боя' : 'Combat log'),
        const SizedBox(height: 14),
        if (log.isEmpty)
          Text(ru ? 'Пока пусто' : 'Nothing yet',
              style: TextStyle(color: c.onSurfaceVariant))
        else
          for (final e in log)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppAccents.of(context).at(_logAccent(e)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(_logText(e, l10n),
                          style: const TextStyle(
                              fontFamily: AppType.body, fontSize: 14.5))),
                  Text(ru ? 'р. ${e.round}' : 'r. ${e.round}',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 12,
                          color: c.onSurfaceVariant)),
                ]),
              ),
            ),
        const SizedBox(height: 8),
        ToneButton(
          key: const ValueKey('log-undo'),
          height: 50,
          expand: true,
          icon: LineIcon('back', size: 18, color: c.onSurface),
          label: ru ? 'Отменить последнее' : 'Undo the last',
          onPressed: _undo.isEmpty ? null : () => Navigator.pop(context, true),
        ),
      ]);
    });
    if (undo == true && mounted) await _undoLast();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: Hive.box<Character>('characters').listenable(),
        builder: (context, Box<Character> box, _) {
          _c = box.get(widget.character.key) ?? widget.character;
          return _page(context);
        },
      );

  Widget _section(String title, {Widget? trailing}) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.3)),
        ),
        if (trailing != null)
          DefaultTextStyle.merge(
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 13,
                  color: c.onSurfaceVariant),
              child: trailing),
      ]),
    );
  }

  Widget _page(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ru = _ru, locale = ru ? 'ru' : 'en';
    final hero = _c;
    final state = hero.combatState;
    final turn = CombatTurn(state);
    final inCombat = state.isInCombat;
    final down = hero.currentHp == 0 &&
        !(hero.isWildShaped && hero.beastCurrentHp != null);
    final classLine = [
      for (final e in hero.classes)
        '${CharacterClassContext(hero, e.id).name(locale)} ${e.level}',
    ].join(' / ');
    final sub = hero.classes.isEmpty
        ? null
        : CharacterClassContext(hero, hero.classes.first.id)
            .subclassName(locale);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final concName = hero.concentratingOn == null
        ? null
        : SpellService.getSpellById(hero.concentratingOn!)?.getName(locale) ??
            hero.concentratingOn;
    final log = state.combatLog.reversed.take(6).toList();
    Widget gap(Widget w) =>
        Padding(padding: const EdgeInsets.only(bottom: 14), child: w);

    final page = ListView(
      padding: EdgeInsets.fromLTRB(16, top + 72, 16, bottom + 120),
      children: [
        gap(Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hero.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.7)),
              const SizedBox(height: 4),
              Text([classLine, if (sub != null) sub].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 13,
                      color: c.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: c.onSurface.withValues(alpha: .07)),
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: ru ? 'КД ' : 'AC '),
                  TextSpan(
                      text: '${hero.armorClass}',
                      style: TextStyle(
                          fontFamily: AppType.display, color: c.onSurface)),
                ]),
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceVariant)),
          ),
        ])),
        gap(LifeSection(character: hero, onChanged: () => _track(() async {}))),
        if (concName != null)
          gap(_Concentration(
              name: concName,
              dc: turn.check,
              busy: _busy,
              onRoll: _concentrationRoll,
              onEnd: () => _track(() => CombatActionsService.endConcentration(
                  _c, ru ? 'Концентрация прервана' : 'Concentration ended')))),
        if (inCombat && !down) ...[
          _section(ru ? 'Мой ход' : 'My turn',
              trailing:
                  Text(ru ? 'сбросится в новом раунде' : 'resets next round')),
          const SizedBox(height: 14),
          gap(TurnTokens(
            turn: turn,
            speed: hero.speed,
            busy: _busy,
            onToggle: (cost) =>
                _track(() => CombatActionsService.toggleToken(_c, cost)),
            onMove: _move,
          )),
          _section(ru ? 'Арсенал' : 'Arsenal'),
          const SizedBox(height: 14),
          gap(ArsenalDoors(character: hero, onOpen: _openArsenal)),
        ],
        if (inCombat) ...[
          _section(ru ? 'Раунды' : 'Rounds',
              trailing: Text(ru ? 'листайте ленту' : 'pull the tape')),
          const SizedBox(height: 14),
          gap(RoundTape(
            round: state.currentRound,
            initiative: state.initiative,
            effects: turn.effects,
            busy: _busy,
            onNext: _nextRound,
            onEndEffect: (e) => _track(() => CombatActionsService.endEffect(
                _c, e.key, ru ? '${e.name}: завершено' : '${e.name}: ended')),
          )),
        ] else
          gap(SizedBox(
            height: 60,
            child: FilledButton.icon(
              key: const ValueKey('combat-start'),
              style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  shape: const StadiumBorder()),
              onPressed: _busy ? null : _start,
              icon: const LineIcon('sword', size: 20),
              label: Text(l10n.startCombat,
                  style: const TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          )),
        _section(l10n.overviewConditions),
        const SizedBox(height: 14),
        gap(SheetConditionChips(
          character: hero,
          onChanged: () {},
          onAdd: () => _track(() async {
            final r = await showConditionPicker(this.context, _c);
            if (r == ConditionPickerResult.allParameters && mounted) {
              await showGameConsole(this.context, _c);
            }
          }),
        )),
        if (log.isNotEmpty) ...[
          _section(ru ? 'Журнал' : 'Journal',
              trailing: GestureDetector(
                key: const ValueKey('combat-undo'),
                onTap: _busy ? null : _undoLast,
                child: Text(ru ? 'Отменить' : 'Undo',
                    style: TextStyle(
                        fontFamily: AppType.body,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.secondary)),
              )),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(children: [
              for (final e in log) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                      color: c.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppAccents.of(context).at(_logAccent(e)))),
                    const SizedBox(width: 6),
                    Text(_logText(e, l10n),
                        style: TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.onSurfaceVariant)),
                  ]),
                ),
                const SizedBox(width: 8),
              ],
            ]),
          ),
        ],
      ],
    );

    return Scaffold(
      // Fields here sit at the top or in sheets over the page; the page never
      // resizes for the keyboard, so it is not laid out again on every frame
      // of the keyboard's slide.
      resizeToAvoidBottomInset: false,
      backgroundColor: c.surface,
      body: Stack(children: [
        Positioned.fill(child: page),
        // The edge glows while the fight is on.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 700)),
              opacity: inCombat ? 1 : 0,
              child: CustomPaint(
                  painter: _EdgeGlow(c.primary.withValues(alpha: .16))),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: GlassSurface(
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, top + 8, 14, 10),
              child: Row(children: [
                _Round(
                    key: const ValueKey('combat-close'),
                    icon: inCombat ? 'x' : 'back',
                    label: inCombat ? l10n.endCombat : l10n.cancel,
                    onTap: inCombat ? _end : () => Navigator.pop(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: inCombat
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: ShapeDecoration(
                                shape: const StadiumBorder(),
                                color: c.primary.withValues(alpha: .2)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.primary)),
                              const SizedBox(width: 6),
                              Text(
                                  ru
                                      ? 'Бой · раунд ${state.currentRound}'
                                      : 'Combat · round ${state.currentRound}',
                                  style: TextStyle(
                                      fontFamily: AppType.body,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: c.primary)),
                            ]),
                          )
                        : Text(hero.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: AppType.display,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
                _Round(
                    key: const ValueKey('combat-log'),
                    icon: 'book',
                    label: ru ? 'Журнал боя' : 'Combat log',
                    onTap: _logSheet),
                const SizedBox(width: 10),
                _Round(
                    key: const ValueKey('combat-console'),
                    icon: 'settings',
                    label: ru ? 'Игровые параметры' : 'Game parameters',
                    onTap: () => _track(() => showGameConsole(context, _c))),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: bottom + 14,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: _DockButton(
                    key: const ValueKey('combat-damage'),
                    label: l10n.damage,
                    icon: 'minus',
                    tint: c.primary.withValues(alpha: .26),
                    onTap: () => _track(
                        () => showHpKeypad(context, _c, mode: HpChange.damage)),
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: ru ? 'Бросок' : 'Roll',
                  child: Pressable(
                    key: const ValueKey('combat-dice'),
                    onTap: () => showDiceRoller(context, title: hero.name),
                    scale: .92,
                    semanticLabel: ru ? 'Лоток костей' : 'Dice tray',
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.onSurface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x99000000),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                              spreadRadius: -8)
                        ],
                      ),
                      child: LineIcon('dice', size: 32, color: c.surface),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DockButton(
                    key: const ValueKey('combat-heal'),
                    label: l10n.heal,
                    icon: 'plus',
                    tint: AppPaletteRoles.heal(context).withValues(alpha: .22),
                    onTap: () => _track(() =>
                        showHpKeypad(context, _c, mode: HpChange.healing)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});
  final String icon, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      scale: .92,
      semanticLabel: label,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: c.onSurface.withValues(alpha: .08)),
        child: InstrumentGlyph(icon, size: 20, color: c.onSurface),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.tint,
      required this.onTap});
  final String label, icon;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      scale: .95,
      semanticLabel: label,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
            color: Color.alphaBlend(tint, c.surfaceContainer),
            borderRadius: BorderRadius.circular(28)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          InstrumentGlyph(icon, size: 20, color: c.onSurface),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

/// Concentration on the combat page: the spell and, after damage, the
/// Constitution save to roll.
class _Concentration extends StatelessWidget {
  const _Concentration(
      {required this.name,
      required this.dc,
      required this.busy,
      required this.onRoll,
      required this.onEnd});
  final String name;
  final int? dc;
  final bool busy;
  final VoidCallback onRoll, onEnd;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final a5 = AppAccents.of(context).at(5);
    final alert = dc != null;
    return AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 420)),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color:
            Color.alphaBlend(a5.withValues(alpha: .16), c.surfaceContainerLow),
        borderRadius: BorderRadius.circular(20),
        border: alert ? Border.all(color: a5, width: 1.6) : null,
      ),
      child: Row(children: [
        InstrumentGlyph('timer', size: 22, color: a5),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${ru ? 'Концентрация' : 'Concentration'} · $name',
                style: const TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w600)),
            Text(
                alert
                    ? (ru
                        ? 'Урон: спасбросок Телосложения, Сл $dc'
                        : 'Damage: Constitution save, DC $dc')
                    : (ru
                        ? 'Урон потребует спасбросок Телосложения'
                        : 'Damage will call for a Constitution save'),
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 12,
                    color: c.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 8),
        ToneButton(
          key: ValueKey(alert ? 'concentration-roll' : 'concentration-end'),
          kind: alert ? ToneKind.primary : ToneKind.plain,
          height: 38,
          fontSize: 13,
          label: alert ? (ru ? 'Бросить' : 'Roll') : (ru ? 'Прервать' : 'End'),
          onPressed: busy ? null : (alert ? onRoll : onEnd),
        ),
      ]),
    );
  }
}

/// An inner glow along the screen's edges (`.combat-edge`).
class _EdgeGlow extends CustomPainter {
  _EdgeGlow(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    const w = 36.0;
    final clear = color.withValues(alpha: 0);
    void edge(Rect r, Alignment from, Alignment to) => canvas.drawRect(
        r,
        Paint()
          ..shader =
              LinearGradient(begin: from, end: to, colors: [color, clear])
                  .createShader(r));
    edge(Rect.fromLTWH(0, 0, w, size.height), Alignment.centerLeft,
        Alignment.centerRight);
    edge(Rect.fromLTWH(size.width - w, 0, w, size.height),
        Alignment.centerRight, Alignment.centerLeft);
    edge(Rect.fromLTWH(0, 0, size.width, w), Alignment.topCenter,
        Alignment.bottomCenter);
    edge(Rect.fromLTWH(0, size.height - w, size.width, w),
        Alignment.bottomCenter, Alignment.topCenter);
  }

  @override
  bool shouldRepaint(_EdgeGlow old) => old.color != color;
}
