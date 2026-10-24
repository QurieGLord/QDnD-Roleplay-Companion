import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';

import '../../../../core/magic/magic_slots.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/services/magic_resource_actions_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../session/value_editors.dart';
import 'instrument/instrument_kit.dart';

/// Paladin (prototype `CLASS.paladin`, fourth pass: quieter, more solemn).
/// A vessel of light measured with the finger; rings of slots for the
/// Smite whose dice roll where they lie; the oath's channel that lights the
/// weapon or turns the unholy; an eye that opens for Divine Sense.
class PaladinDivineWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature layOnHands;
  final CharacterFeature? divineSense;
  final CharacterFeature? divineSmite;
  final CharacterFeature? channelDivinityResource;
  final List<CharacterFeature> channelDivinitySpells;
  final VoidCallback? onChanged;

  const PaladinDivineWidget({
    super.key,
    required this.character,
    required this.layOnHands,
    this.divineSense,
    this.divineSmite,
    this.channelDivinityResource,
    this.channelDivinitySpells = const [],
    this.onChanged,
  });

  @override
  State<PaladinDivineWidget> createState() => _PaladinDivineWidgetState();
}

class _PaladinDivineWidgetState extends State<PaladinDivineWidget> {
  bool _busy = false;
  int _amount = 5;
  bool _self = false;
  // Smite: chosen slot, its modifiers and the last roll.
  (MagicPool, int)? _slot;
  bool _undead = false, _crit = false;
  List<int>? _rolls;
  int _smiteKey = 0;
  // Channel and sense, as the table plays them.
  int _round = 1, _wave = 0;
  bool _senseOpen = false;

  Character get _hero => widget.character;
  bool get _ru => instrumentRu(context);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _heal(ResourcePool pool) => _run(() async {
        final n = math.min(_amount, pool.currentUses);
        final result = await GameplayActionsService.activateResource(_hero, widget.layOnHands,
            amount: n, healing: _self ? n : 0);
        if (!mounted || !result.spent) return;
        HapticFeedback.lightImpact();
        _amount = math.max(1, math.min(_amount, pool.currentUses));
        widget.onChanged?.call();
        final ctx = _vesselKey.currentContext;
        if (ctx != null && ctx.mounted) floatUp(ctx, _ru ? '+$n ОЗ' : '+$n HP', AppPaletteRoles.heal(context));
      });

  Future<void> _cure() => _run(() async {
        final spent = await GameplayActionsService.spendResource(_hero, widget.layOnHands, amount: 5);
        if (!mounted || !spent) return;
        HapticFeedback.lightImpact();
        widget.onChanged?.call();
        AppSnackBar.success(context, _ru ? 'Болезнь или яд излечены' : 'Disease or poison cured');
      });

  Future<void> _smite(int dice) async {
    final slot = _slot;
    if (slot == null || _busy) return;
    final rolls = [for (var i = 0; i < dice; i++) math.Random().nextInt(8) + 1];
    await _run(() async {
      await MagicResourceActionsService.spendSlot(_hero, slot.$1, slot.$2);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _rolls = rolls;
        _smiteKey++;
      });
      widget.onChanged?.call();
    });
  }

  Future<void> _channel(CharacterFeature option) {
    final sacred = option.id == 'channel-divinity-sacred-weapon';
    return _run(() async {
      final resource = widget.channelDivinityResource!;
      if (sacred && _hero.isSacredWeaponActive) {
        if (_round < 10) {
          HapticFeedback.selectionClick();
          setState(() => _round++);
          return;
        }
        await GameplayActionsService.endSacredWeapon(_hero);
        widget.onChanged?.call();
        return;
      }
      final spent = (await GameplayActionsService.activateResource(_hero, resource, activateSacredWeapon: sacred)).spent;
      if (!mounted || !spent) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _round = 1;
        if (!sacred) _wave++;
      });
      widget.onChanged?.call();
      if (!sacred && mounted) AppSnackBar.success(context, _optionName(option, _ru ? 'ru' : 'en'));
    });
  }

  Future<void> _sense() => _run(() async {
        if (_senseOpen) {
          HapticFeedback.selectionClick();
          setState(() => _senseOpen = false);
          return;
        }
        final f = widget.divineSense!;
        final spent = f.resourcePool == null || (await GameplayActionsService.activateResource(_hero, f)).spent;
        if (!mounted || !spent) return;
        HapticFeedback.mediumImpact();
        setState(() => _senseOpen = true);
        widget.onChanged?.call();
      });

  Future<void> _edit(CharacterFeature f) async {
    final changed = await showResourceValueEditor(context, _hero, f);
    if (mounted && changed) setState(() => widget.onChanged?.call());
  }

  String _optionName(CharacterFeature f, String locale) => f
      .getName(locale)
      .replaceAll(RegExp(r'^Божественный [Кк]анал:\s*'), '')
      .replaceAll(RegExp(r'^Channel Divinity:\s*'), '')
      .trim();

  InstrumentAbout _about(CharacterFeature f, String locale, String? how, {String? kicker}) =>
      InstrumentAbout(title: f.getName(locale), kicker: kicker, paragraphs: f.getDescription(locale).split(RegExp(r'\n\s*\n')), how: how);

  final _vesselKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final ru = _ru, locale = ru ? 'ru' : 'en';
    final owner = CharacterClassContext(_hero, 'paladin');
    final level = owner.level;
    final a2 = accentOf(context, 2), a4 = accentOf(context, 4);
    final children = <Widget>[
      _layOnHands(context, ru, locale, a2),
      if (widget.divineSmite != null && owner.canUseFeature(widget.divineSmite!))
        _smiteInstrument(context, ru, locale, a2, level)
      else if (level < 2)
        LockedInstrument(title: ru ? 'Божественная кара' : 'Divine Smite', level: 2, what: ru ? 'Кара излучением за ячейку' : 'Radiant damage for a slot', accent: a2),
      if (widget.channelDivinityResource?.resourcePool != null && owner.canUseFeature(widget.channelDivinityResource!))
        _channelInstrument(context, ru, locale, a4)
      else if (level < 3)
        LockedInstrument(title: ru ? 'Божественный канал' : 'Channel Divinity', level: 3, what: ru ? 'Умения клятвы' : 'Your oath’s channel', accent: a4),
      if (widget.divineSense != null) _senseInstrument(context, ru, locale, a4),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ]
    ]);
  }

  Widget _layOnHands(BuildContext context, bool ru, String locale, Color a2) {
    final pool = widget.layOnHands.resourcePool;
    if (pool == null || pool.maxUses <= 0) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    _amount = _amount.clamp(1, math.max(1, pool.currentUses));
    final amount = pool.currentUses == 0 ? 0 : _amount;
    return Instrument(
      key: const ValueKey('paladin-lay-on-hands'),
      accent: a2,
      title: widget.layOnHands.getName(locale),
      about: _about(widget.layOnHands, locale,
          ru ? 'Ведите пальцем по полосе света — так отмеряется объём. «Исцелить» выливает его.' : 'Slide along the light to measure an amount. “Heal” pours it out.',
          kicker: ru ? 'Действие · длительный отдых' : 'Action · long rest'),
      trailing: RestChip(
          short: false,
          onEdit: () => _edit(widget.layOnHands),
          onRestore: () => restoreFeature(context, _hero, widget.layOnHands, done: () => setState(() => widget.onChanged?.call()))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(flex: 3, child: BigCount(amount, unit: ru ? 'ОЗ' : 'HP')),
          const Spacer(),
          Peek(
            title: ru ? 'Запас' : 'Pool',
            text: ru ? '${pool.currentUses} из ${pool.maxUses} до длительного отдыха' : '${pool.currentUses} of ${pool.maxUses} until a long rest',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: a2.withValues(alpha: .14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                InstrumentGlyph('hand', size: 16, color: a2),
                const SizedBox(width: 6),
                RollingNumber(pool.currentUses, style: bigStyle(context).copyWith(fontSize: 17)),
                Text(' / ${pool.maxUses}', style: hintStyle(context).copyWith(fontSize: 12)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _Vessel(
          key: _vesselKey,
          current: pool.currentUses,
          maximum: pool.maxUses,
          amount: amount,
          accent: a2,
          onAmount: (n) {
            if (n == _amount) return;
            HapticFeedback.selectionClick();
            setState(() => _amount = n);
          },
        ),
        const SizedBox(height: 8),
        InstrumentHint(
            pool.currentUses > 0
                ? (ru ? 'Ведите пальцем по свету — отмерить' : 'Slide along the light to measure')
                : (ru ? 'Запас вернёт длительный отдых' : 'A long rest refills the pool'),
            center: true),
        const SizedBox(height: 10),
        TileRow(children: [
          GoButton(
              key: const ValueKey('paladin-lay-heal'),
              label: ru ? 'Исцелить' : 'Heal',
              glyph: 'heart',
              accent: a2,
              onTap: pool.currentUses > 0 && !_busy ? () => _heal(pool) : null),
          GhostButton(
              label: ru ? 'Очистить · 5' : 'Cure · 5',
              glyph: 'drop',
              onTap: pool.currentUses >= 5 && !_busy ? _cure : null),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _self = !_self);
            },
            scale: .95,
            selected: _self,
            semanticLabel: ru ? 'Лечить себя' : 'Heal yourself',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: _self ? a2.withValues(alpha: .2) : c.onSurface.withValues(alpha: .05)),
              child: Text(_self ? (ru ? '✓ на себя' : '✓ on yourself') : (ru ? 'на себя' : 'on yourself'),
                  style: labelStyle(context, size: 12).copyWith(color: _self ? c.onSurface : c.onSurfaceVariant)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _smiteInstrument(BuildContext context, bool ru, String locale, Color a2, int level) {
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(_hero);
    } catch (_) {}
    final rings = <(MagicPool, int, int, int)>[];
    if (slots != null) {
      for (var i = 0; i < slots.maximum.length; i++) {
        if (slots.maximum[i] > 0) rings.add((MagicPool.shared, i + 1, slots.current[i], slots.maximum[i]));
      }
      if (slots.pact != null) rings.add((MagicPool.pact, slots.pact!.circle, slots.pact!.current, slots.pact!.maximum));
    }
    if (_slot == null || !rings.any((r) => r.$1 == _slot!.$1 && r.$2 == _slot!.$2 && r.$3 > 0)) {
      final open = rings.where((r) => r.$3 > 0).firstOrNull;
      _slot = open == null ? null : (open.$1, open.$2);
    }
    final circle = _slot?.$2 ?? 1;
    final dice = (math.min(5, 1 + circle) + (_undead ? 1 : 0)) * (_crit ? 2 : 1);
    final k = ru ? 'к' : 'd';
    final improved = _hero.features.any((f) => f.id.toLowerCase().replaceAll('_', '-').contains('improved-divine-smite'));
    final c = Theme.of(context).colorScheme;
    return Instrument(
      key: const ValueKey('paladin-smite'),
      accent: a2,
      title: widget.divineSmite!.getName(locale),
      about: _about(widget.divineSmite!, locale,
          ru ? 'Выберите круг ячейки, отметьте нежить или крит, нажмите «Кара».' : 'Pick a slot, mark undead or a crit, press “Smite”.',
          kicker: ru ? 'После попадания рукопашной атакой' : 'After a melee weapon hit'),
      border: _rolls != null ? a2.withValues(alpha: .4) : null,
      trailing: InstrumentChip(ru ? 'после попадания' : 'after a hit'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final r in rings) ...[
                  _SlotRing(
                    key: ValueKey('paladin-smite-ring-${r.$1.name}-${r.$2}'),
                    circle: r.$2,
                    current: r.$3,
                    maximum: r.$4,
                    pact: r.$1 == MagicPool.pact,
                    selected: _slot?.$1 == r.$1 && _slot?.$2 == r.$2,
                    accent: a2,
                    onTap: r.$3 > 0
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _slot = (r.$1, r.$2);
                              _rolls = null;
                            });
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
          ),
          _Toggle(
              glyph: 'skull',
              on: _undead,
              accent: accentOf(context, 0),
              peek: (ru ? 'Нежить или исчадие' : 'Undead or fiend', ru ? 'Ещё +1${k}8 излучением' : 'Another +1${k}8 radiant'),
              onTap: () => setState(() {
                    _undead = !_undead;
                    _rolls = null;
                  })),
          const SizedBox(width: 6),
          _Toggle(
              glyph: 'spark',
              on: _crit,
              accent: accentOf(context, 0),
              peek: (ru ? 'Критическое попадание' : 'Critical hit', ru ? 'Все кости кары удваиваются' : 'All smite dice double'),
              onTap: () => setState(() {
                    _crit = !_crit;
                    _rolls = null;
                  })),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < dice; i++)
            TumbleDie(
                key: ValueKey('smite-die-$i'),
                shape: DieShape.d8,
                label: _rolls != null && i < _rolls!.length ? '${_rolls![i]}' : '${k}8',
                accent: a2,
                rollKey: _smiteKey,
                sides: 8,
                natural: _rolls != null && i < _rolls!.length ? _rolls![i] : null,
                size: 46),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _rolls != null
                  ? RollingNumber(_rolls!.fold(0, (a, b) => a + b), style: hugeStyle(context))
                  : Text('$dice${k}8', style: hugeStyle(context)),
              const SizedBox(height: 6),
              InstrumentHint(_rolls != null
                  ? (ru ? 'излучением' : 'radiant')
                  : _slot == null
                      ? (ru ? 'нет ячеек' : 'no slots')
                      : (ru ? 'ячейка $circle круга' : 'a level $circle slot')),
            ]),
          ),
          Pressable(
            key: const ValueKey('paladin-smite-go'),
            onTap: _slot != null && !_busy ? () => _smite(dice) : null,
            scale: .9,
            semanticLabel: ru ? 'Кара' : 'Smite',
            child: Opacity(
              opacity: _slot != null ? 1 : .35,
              child: Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: a2, borderRadius: BorderRadius.circular(26)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    LineIcon('sword', size: 24, color: onAccent(context)),
                    const SizedBox(height: 4),
                    Text((ru ? 'Кара' : 'Smite').toUpperCase(),
                        style: TextStyle(fontFamily: AppType.display, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: onAccent(context))),
                  ]),
                ),
              ),
            ),
          ),
        ]),
        if (improved) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: InstrumentChip(ru ? '+1${k}8 к каждому удару' : '+1${k}8 on every hit',
                glyph: 'sun',
                color: c.onSurface,
                peek: (ru ? 'Улучшенная божественная кара' : 'Improved Divine Smite', ru ? 'Каждое попадание рукопашным оружием: ещё +1${k}8 излучением, без ячейки' : 'Every melee weapon hit deals an extra 1${k}8 radiant, no slot')),
          ),
        ],
      ]),
    );
  }

  Widget _channelInstrument(BuildContext context, bool ru, String locale, Color a4) {
    final resource = widget.channelDivinityResource!;
    final current = GameplayActionsService.resourceCurrent(_hero, resource);
    final options = widget.channelDivinitySpells;
    final a2 = accentOf(context, 2), a1 = accentOf(context, 1);
    final sacredOn = _hero.isSacredWeaponActive;
    Widget option(CharacterFeature f) {
      final sacred = f.id == 'channel-divinity-sacred-weapon';
      final lit = sacred && sacredOn;
      final name = _optionName(f, locale);
      final turn = f.id.toLowerCase().contains('turn');
      return _OathTile(
        key: ValueKey('paladin-channel-${f.id}'),
        name: name,
        subtitle: lit
            ? (ru ? 'раунд $_round из 10' : 'round $_round of 10')
            : sacred
                ? (ru ? '+${_hero.abilityScores.charismaModifier} к атаке' : '+${_hero.abilityScores.charismaModifier} to hit')
                : turn
                    ? (ru ? 'Сл ${8 + _hero.proficiencyBonus + _hero.abilityScores.charismaModifier}' : 'DC ${8 + _hero.proficiencyBonus + _hero.abilityScores.charismaModifier}')
                    : (ru ? 'канал' : 'channel'),
        accent: sacred ? a2 : a4,
        lit: lit,
        sword: sacred,
        wave: turn ? _wave : null,
        onTap: !_busy && (current > 0 || lit) ? () => _channel(f) : null,
        peek: (name, f.getDescription(locale).split('\n').first),
      );
    }

    return Instrument(
      key: const ValueKey('paladin-channel'),
      accent: a4,
      title: AppLocalizations.of(context)!.channelDivinity,
      about: _about(resource, locale,
          ru ? 'Коснитесь клятвы. Горящее оружие отсчитывает раунды по касанию.' : 'Tap an oath. A lit weapon counts its rounds on each tap.',
          kicker: ru ? 'Действие · короткий отдых' : 'Action · short rest'),
      trailing: RestChip(
          short: true,
          onEdit: () => _edit(resource),
          onRestore: () => restoreFeature(context, _hero, resource, done: () => setState(() => widget.onChanged?.call()))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (options.isNotEmpty) Expanded(child: option(options[0])),
            Peek(
              title: ru ? 'Канал клятвы' : 'Oath channel',
              text: ru ? '$current из ${resource.resourcePool!.maxUses} до короткого отдыха' : '$current of ${resource.resourcePool!.maxUses} until a short rest',
              child: SizedBox(
                width: 46,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  InstrumentGlyph('flame', size: 28, color: current > 0 ? a1 : Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 4),
                  Text('$current/${resource.resourcePool!.maxUses}', style: bigStyle(context).copyWith(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
            ),
            if (options.length > 1) Expanded(child: option(options[1])),
          ]),
        ),
        for (final f in options.skip(2)) ...[const SizedBox(height: 8), option(f)],
        if (sacredOn) ...[
          const SizedBox(height: 12),
          Fuse(length: 10, at: _round, accent: a2),
        ],
      ]),
    );
  }

  Widget _senseInstrument(BuildContext context, bool ru, String locale, Color a4) {
    final f = widget.divineSense!;
    final pool = f.resourcePool;
    final left = pool == null ? null : GameplayActionsService.resourceCurrent(_hero, f);
    final can = _senseOpen || left == null || left > 0;
    return Opacity(
      opacity: can ? 1 : .5,
      child: Pressable(
        key: const ValueKey('paladin-divine-sense'),
        onTap: can && !_busy ? _sense : null,
        scale: .98,
        semanticLabel: f.getName(locale),
        child: Instrument(
          accent: a4,
          title: f.getName(locale),
          about: _about(f, locale, ru ? 'Коснитесь глаза — он откроется. Ещё касание закроет его.' : 'Tap the eye to open it; tap again to close.',
              kicker: ru ? 'Действие · длительный отдых' : 'Action · long rest'),
          border: _senseOpen ? a4.withValues(alpha: .4) : null,
          trailing: pool == null ? null : RestChip(
              short: false,
              onEdit: () => _edit(f),
              onRestore: () => restoreFeature(context, _hero, f, done: () => setState(() => widget.onChanged?.call()))),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              _Eye(open: _senseOpen, accent: a4),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_senseOpen ? (ru ? 'Глаза открыты' : 'Eyes open') : (ru ? 'Открыть взор' : 'Open your sight'),
                      style: bigStyle(context).copyWith(fontSize: 17)),
                  if (pool != null) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (var i = 0; i < pool.maxUses; i++) _EyeMark(on: i < (left ?? 0), accent: a4),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The vessel of light: drag measures the portion to pour, from the end of
/// the remaining pool; the value snaps with a tick, the light follows the
/// finger.
class _Vessel extends StatefulWidget {
  const _Vessel({super.key, required this.current, required this.maximum, required this.amount, required this.accent, required this.onAmount});
  final int current, maximum, amount;
  final Color accent;
  final ValueChanged<int> onAmount;
  @override
  State<_Vessel> createState() => _VesselState();
}

class _VesselState extends State<_Vessel> {
  double? _drag;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, unit = w / math.max(1, widget.maximum), end = widget.current * unit;
      final double left = (_drag ?? (end - widget.amount * unit)).clamp(0.0, math.max(0.0, end - unit)).toDouble();
      void place(double x) {
        if (widget.current <= 0) return;
        final clamped = x.clamp(0.0, math.max(0.0, end - unit));
        setState(() => _drag = clamped.toDouble());
        widget.onAmount(((end - clamped) / unit).round().clamp(1, widget.current));
      }

      final reduced = MediaQuery.disableAnimationsOf(context);
      final motion = _drag != null || reduced ? Duration.zero : const Duration(milliseconds: 420);
      return Semantics(
        slider: true,
        value: '${widget.amount}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => place(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => place(d.localPosition.dx),
          onHorizontalDragEnd: (_) => setState(() => _drag = null),
          onTapDown: (d) => place(d.localPosition.dx),
          onTapUp: (_) => setState(() => _drag = null),
          child: Container(
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: c.onSurface.withValues(alpha: .06),
              border: Border.all(color: widget.accent.withValues(alpha: .2)),
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              AnimatedPositioned(
                duration: reduced ? Duration.zero : const Duration(milliseconds: 600),
                curve: AppMotion.snappyCurve,
                left: 0,
                top: 0,
                bottom: 0,
                width: end,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                  mixColor(widget.accent, .26, c.surfaceContainer),
                  mixColor(widget.accent, .4, c.surfaceContainer)
                ]))),
              ),
              if (widget.current > 0) ...[
                AnimatedPositioned(
                  duration: motion,
                  curve: AppMotion.snappyCurve,
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: math.max(0.0, end - left),
                  child: ColoredBox(color: mixColor(widget.accent, .78, c.surfaceContainer)),
                ),
                AnimatedPositioned(
                  duration: motion,
                  curve: AppMotion.snappyCurve,
                  left: left - 19,
                  top: 13,
                  width: 38,
                  height: 38,
                  child: AnimatedScale(
                    scale: _drag != null ? 1.15 : 1,
                    duration: const Duration(milliseconds: 260),
                    curve: AppMotion.snappyCurve,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.onSurface, boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 12, spreadRadius: -4, offset: Offset(0, 4))
                      ]),
                      child: InstrumentGlyph('hand', size: 19, color: c.surface),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      );
    });
  }
}

class _SlotRing extends StatelessWidget {
  const _SlotRing(
      {super.key,
      required this.circle,
      required this.current,
      required this.maximum,
      required this.pact,
      required this.selected,
      required this.accent,
      this.onTap});
  final int circle, current, maximum;
  final bool pact, selected;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Opacity(
      opacity: current > 0 ? 1 : .35,
      child: Pressable(
        onTap: onTap,
        scale: .92,
        selected: selected,
        semanticLabel: '$circle',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? mixColor(accent, .24, c.surfaceContainer) : null,
            border: Border.all(color: selected ? accent : accent.withValues(alpha: .35), width: selected ? 2 : 2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$circle', style: bigStyle(context).copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < math.min(maximum, 4); i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < current ? (pact ? accentOf(context, 5) : c.secondary) : null,
                      border: i < current ? null : Border.all(color: c.outline, width: 1.2)),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.glyph, required this.on, required this.accent, required this.onTap, required this.peek});
  final String glyph;
  final bool on;
  final Color accent;
  final VoidCallback onTap;
  final (String, String) peek;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Peek(
      title: peek.$1,
      text: peek.$2,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        scale: .92,
        selected: on,
        semanticLabel: peek.$1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: on ? mixColor(accent, .26, c.surfaceContainer) : c.onSurface.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(16)),
          child: InstrumentGlyph(glyph, size: 22, color: on ? c.onSurface : c.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// An oath tile: a sword that lights up, or rings that ripple outwards.
class _OathTile extends StatelessWidget {
  const _OathTile(
      {super.key,
      required this.name,
      required this.subtitle,
      required this.accent,
      required this.lit,
      required this.sword,
      required this.onTap,
      required this.peek,
      this.wave});
  final String name, subtitle;
  final Color accent;
  final bool lit, sword;
  final int? wave;
  final VoidCallback? onTap;
  final (String, String) peek;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Peek(
      title: peek.$1,
      text: peek.$2,
      child: Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Pressable(
          onTap: onTap,
          scale: .95,
          semanticLabel: name,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: lit ? mixColor(accent, .2, c.surfaceContainer) : c.onSurface.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(22),
              border: lit ? Border.all(color: accent.withValues(alpha: .55), width: 1.5) : null,
            ),
            child: Column(children: [
              SizedBox(
                height: 84,
                child: sword
                    ? Transform.rotate(angle: .52, child: CustomPaint(size: const Size(30, 84), painter: _SwordPainter(accent, lit, c.onSurface, c.surfaceContainer)))
                    : _Rings(accent: accent, wave: wave ?? 0),
              ),
              const SizedBox(height: 6),
              Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: labelStyle(context, size: 13)),
              const SizedBox(height: 4),
              Text(subtitle, style: bigStyle(context).copyWith(fontSize: 13, color: c.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SwordPainter extends CustomPainter {
  _SwordPainter(this.accent, this.lit, this.ink, this.cont);
  final Color accent, ink, cont;
  final bool lit;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 120;
    final blade = Path()
      ..moveTo(20 * s, 4 * s)
      ..lineTo(27 * s, 18 * s)
      ..lineTo(27 * s, 80 * s)
      ..lineTo(13 * s, 80 * s)
      ..lineTo(13 * s, 18 * s)
      ..close();
    canvas.drawPath(blade, Paint()..color = lit ? mixColor(Colors.white, .6, accent) : mixColor(ink, .22, cont));
    canvas.drawPath(blade, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = ink.withValues(alpha: .6));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(3 * s, 80 * s, 34 * s, 7 * s), Radius.circular(3.5 * s)), Paint()..color = accent);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(16 * s, 87 * s, 8 * s, 21 * s), Radius.circular(3 * s)), Paint()..color = mixColor(accentOf2(accent), .5, cont));
    canvas.drawCircle(Offset(20 * s, 112 * s), 5 * s, Paint()..color = accent);
  }

  static Color accentOf2(Color a) => HSLColor.fromColor(a).withHue((HSLColor.fromColor(a).hue - 20) % 360).toColor();

  @override
  bool shouldRepaint(_SwordPainter old) => old.lit != lit || old.accent != accent;
}

class _Rings extends StatelessWidget {
  const _Rings({required this.accent, required this.wave});
  final Color accent;
  final int wave;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(wave),
      tween: Tween(begin: wave == 0 ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, _) => CustomPaint(size: const Size(84, 84), painter: _RingsPainter(accent, t, wave > 0)),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.accent, this.t, this.waving);
  final Color accent;
  final double t;
  final bool waving;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final base = [9.0, 20.0, 31.0][i], alpha = [1.0, .6, .3][i];
      final grow = waving && t < 1 ? (1 + .5 * Curves.easeOut.transform(t)) : 1.0;
      final fade = waving && t < 1 ? (1 - t) : 1.0;
      canvas.drawCircle(center, base * grow, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = accent.withValues(alpha: alpha * fade.clamp(.2, 1)));
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t;
}

/// The eye of Divine Sense: closed it is a line; open it shows the iris and
/// a slow ripple.
class _Eye extends StatefulWidget {
  const _Eye({required this.open, required this.accent});
  final bool open;
  final Color accent;
  @override
  State<_Eye> createState() => _EyeState();
}

class _EyeState extends State<_Eye> with SingleTickerProviderStateMixin {
  late final _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  @override
  void didUpdateWidget(covariant _Eye old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (widget.open && !MediaQuery.disableAnimationsOf(context)) {
      if (!_ripple.isAnimating) _ripple.repeat(count: 4);
    } else {
      _ripple.stop();
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.open ? 1 : .06),
      duration: AppMotion.of(context, const Duration(milliseconds: 600)),
      curve: AppMotion.snappyCurve,
      builder: (context, open, _) => AnimatedBuilder(
        animation: _ripple,
        builder: (context, _) => CustomPaint(
            size: const Size(96, 56), painter: _EyePainter(widget.accent, open, widget.open ? _ripple.value : -1, c.surfaceContainer, c.surface)),
      ),
    );
  }
}

class _EyePainter extends CustomPainter {
  _EyePainter(this.accent, this.open, this.ripple, this.cont, this.surface);
  final Color accent, cont, surface;
  final double open, ripple;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120, cy = 35 * s;
    if (ripple >= 0) {
      final r = 18 * s * (1 + 2.4 * ripple);
      canvas.drawCircle(Offset(60 * s, cy), r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: .8 * (1 - ripple)));
    }
    canvas.save();
    canvas.translate(0, cy);
    canvas.scale(1, open);
    canvas.translate(0, -cy);
    final lid = Path()
      ..moveTo(8 * s, cy)
      ..quadraticBezierTo(60 * s, -5 * s, 112 * s, cy)
      ..quadraticBezierTo(60 * s, 75 * s, 8 * s, cy)
      ..close();
    canvas.drawPath(lid, Paint()..color = mixColor(accent, .18, cont));
    canvas.drawPath(lid, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..color = accent);
    canvas.drawCircle(Offset(60 * s, cy), 15 * s, Paint()..color = accent);
    canvas.drawCircle(Offset(60 * s, cy), 6 * s, Paint()..color = surface);
    canvas.restore();
    if (open < .5) {
      final lash = Path()
        ..moveTo(8 * s, cy)
        ..quadraticBezierTo(60 * s, 62 * s, 112 * s, cy);
      canvas.drawPath(lash, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 1 - open * 2));
    }
  }

  @override
  bool shouldRepaint(_EyePainter old) => old.open != open || old.ripple != ripple;
}

class _EyeMark extends StatelessWidget {
  const _EyeMark({required this.on, required this.accent});
  final bool on;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 12,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.elliptical(10, 6)),
        color: on ? accent : null,
        border: on ? null : Border.all(color: c.outline, width: 1.6),
      ),
      alignment: Alignment.center,
      child: on ? Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface)) : null,
    );
  }
}
