import 'dart:math' as math;

import 'package:flutter/services.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/progression/character_class_rules.dart';
import '../../../../core/services/hit_dice_rest_service.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/expressive_kit.dart';
import '../class_widgets/instrument/instrument_kit.dart';
import '../../../../core/magic/magic_slots.dart';
import '../../../../core/services/feature_service.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/models/character.dart';
import '../../../../core/models/character_class.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/services/qdnd_bundle_codec.dart';
import '../../../../core/services/spell_service.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../../core/ui/companion_kit.dart';

/// The prototype's rest tiles: two calm tiles side by side, each an icon in
/// the violet accent and its name.
class SheetRestActions extends StatelessWidget {
  const SheetRestActions({
    super.key,
    required this.busy,
    required this.onShortRest,
    required this.onLongRest,
  });
  final bool busy;
  final VoidCallback onShortRest, onLongRest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context), c = t.colorScheme;
    final violet = AppAccents.of(context).at(5);
    Widget tile(String id, String label, String semantic, String icon,
            VoidCallback callback) =>
        Expanded(
          child: Opacity(
            opacity: busy ? .45 : 1,
            child: Pressable(
              key: ValueKey('sheet-rest-$id'),
              onTap: busy ? null : callback,
              scale: .97,
              semanticLabel: semantic,
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: c.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                  // Centred like the damage and healing buttons above.
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LineIcon(icon, size: 22, color: violet),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(label,
                              textAlign: TextAlign.center,
                              style: t.textTheme.labelLarge?.copyWith(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                ),
              ),
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile('short', l10n.restShortTile, l10n.shortRest, 'cup', onShortRest),
        const SizedBox(width: 8),
        tile('long', l10n.restLongTile, l10n.longRest, 'moon', onLongRest),
      ]),
    );
  }
}

/// Wave 3 rest (`.rest-h`, `.hdtray`, `.gain`, `.holdbtn`): one sheet with a
/// sky. A short rest is a warm afternoon — the hero's Hit Dice tumble into
/// the HP preview and what returns is listed; a long rest is a night with
/// stars and a moon, held until dawn.
Future<bool> showRestSheet(BuildContext context, Character character,
        {required bool short}) async =>
    await showCompanionSheet<bool>(context,
        bleed: true,
        builder: (_) => _RestSheet(hero: character, short: short)) ??
    false;

class _RestSheet extends StatefulWidget {
  const _RestSheet({required this.hero, required this.short});
  final Character hero;
  final bool short;
  @override
  State<_RestSheet> createState() => _RestSheetState();
}

class _RestSheetState extends State<_RestSheet> with TickerProviderStateMixin {
  late bool _short = widget.short;
  final _rolls = <HitDieRoll>[];
  final _rollKeys = <String, int>{};
  final _pending = <String>{};
  bool _busy = false, _dawn = false;
  int _wave = 0;
  late final _hold = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..addListener(_holdTick)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _sleep();
    });
  int _ticks = 0;
  final _stars = List.generate(22, (_) {
    final r = math.Random();
    return (r.nextDouble(), r.nextDouble() * .7, r.nextDouble() * 3);
  });

  Character get _hero => widget.hero;
  bool get _form =>
      _hero.isWildShaped &&
      _hero.beastCurrentHp != null &&
      _hero.beastMaxHp != null;
  int get _con => _hero.abilityScores.constitutionModifier;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _holdTick() {
    final third = (_hold.value * 3).floor();
    if (third > _ticks && third < 3) {
      _ticks = third;
      HapticFeedback.selectionClick();
    }
  }

  List<_RestChange> _preview(AppLocalizations l10n, String locale, bool short) {
    final after = QdndBundleCodec.cloneCharacter(_hero);
    FeatureService.prepareKnownResourcePools(after);
    if (short) {
      after.shortRest();
    } else {
      after.longRest();
    }
    return _changes(_hero, after, l10n, locale);
  }

  Future<void> _roll(int index, int die) async {
    final id = _hero.classes[index].id;
    final used = _rolls.where((r) => r.classId == id).length +
        _pending.where((p) => p.startsWith('$id:')).length;
    if (used >= _hero.hitDice[index] || _busy) return;
    final value = math.Random().nextInt(die) + 1;
    await _land(index, value);
  }

  Future<void> _enter(int index, int die) async {
    final ru = instrumentRu(context);
    final value = await showNumberKeypad(context,
        title: ru ? 'Кость хитов · к$die' : 'Hit Die · d$die',
        kicker: ru ? 'Результат своей кости' : 'Your own die result');
    if (value == null || value < 1 || value > die || !mounted) return;
    await _land(index, value);
  }

  Future<void> _land(int index, int value) async {
    final id = _hero.classes[index].id;
    final key = '$id:${_rolls.length + _pending.length}';
    setState(() {
      _pending.add(key);
      _rollKeys[key] = value;
    });
    await Future<void>.delayed(MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pending.remove(key);
      _rolls.add(HitDieRoll(id, value));
    });
  }

  Future<void> _finishShort() async {
    if (_busy) return;
    final ru = instrumentRu(context);
    setState(() => _busy = true);
    try {
      final healed = _rolls.isEmpty
          ? 0
          : await HitDiceRestService.shortRest(_hero, List.of(_rolls));
      if (_rolls.isEmpty) await GameplayActionsService.rest(_hero, short: true);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _wave++);
      await Future<void>.delayed(MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 420));
      if (!mounted) return;
      Navigator.pop(context, true);
      AppSnackBar.success(
          context,
          ru
              ? 'Короткий отдых${healed > 0 ? ': +$healed ОЗ' : ''} · ресурсы восстановлены'
              : 'Short rest${healed > 0 ? ': +$healed HP' : ''} · resources restored');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
    }
  }

  Future<void> _sleep() async {
    if (_busy) return;
    final ru = instrumentRu(context);
    setState(() => _busy = true);
    try {
      await GameplayActionsService.rest(_hero, short: false);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _dawn = true;
        _wave++;
      });
      await Future<void>.delayed(MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.pop(context, true);
      AppSnackBar.success(context,
          ru ? 'Утро: всё восстановлено' : 'Morning: everything restored');
    } catch (_) {
      if (!mounted) return;
      _hold.reset();
      setState(() => _busy = false);
      AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ru = instrumentRu(context);
    final locale = ru ? 'ru' : 'en';
    final c = Theme.of(context).colorScheme;
    final night = !_short && !_dawn;
    final a1 = AppAccents.of(context).at(1), a5 = AppAccents.of(context).at(5);
    final d = AppMotion.of(context, const Duration(milliseconds: 700));
    final header = AnimatedContainer(
      duration: d,
      padding: const EdgeInsets.fromLTRB(18, SheetGrab.inset + 4, 18, 18),
      decoration: BoxDecoration(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        gradient: LinearGradient(
          begin: const Alignment(-.3, -1),
          end: const Alignment(.3, 1),
          colors: night
              ? [
                  const Color(0xFF1D1B2E),
                  Color.alphaBlend(
                      a5.withValues(alpha: .18), c.surfaceContainer),
                  c.surfaceContainer
                ]
              : [
                  Color.alphaBlend(
                      a1.withValues(alpha: .26), c.surfaceContainer),
                  c.surfaceContainer,
                  c.surfaceContainer
                ],
          stops: night ? const [0, .7, 1] : const [0, .75, 1],
        ),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: AnimatedOpacity(
            duration: d,
            opacity: night ? 1 : 0,
            child: LayoutBuilder(
              builder: (context, box) => Stack(children: [
                for (final s in _stars)
                  Positioned(
                    left: s.$1 * box.maxWidth,
                    top: s.$2 * box.maxHeight,
                    child: _Star(delay: s.$3),
                  ),
              ]),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: d,
          curve: AppMotion.snappyCurve,
          right: night ? 16 : 8,
          top: night ? -2 : -8,
          child: AnimatedContainer(
            duration: d,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  center: const Alignment(-.3, -.3),
                  colors: night
                      ? const [Colors.white, Color(0xFFD8D2FF)]
                      : [const Color(0xFFFFD9A0), a1]),
              boxShadow: [
                BoxShadow(
                    color: (night ? const Color(0xFFD8D2FF) : a1)
                        .withValues(alpha: .55),
                    blurRadius: 32)
              ],
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((ru ? 'Привал' : 'Rest').toUpperCase(),
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: c.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(_short ? l10n.shortRest : l10n.longRest,
              style: const TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.6)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
                _short
                    ? (ru
                        ? 'Час передышки. Бросьте кости хитов — лечение сразу ляжет в ОЗ.'
                        : 'An hour to breathe. Roll Hit Dice — the healing goes straight to HP.')
                    : (ru
                        ? 'Восемь часов сна. Утром — полные ОЗ, ячейки и умения.'
                        : 'Eight hours of sleep. In the morning: full HP, slots and features.'),
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 13,
                    height: 1.4,
                    color: c.onSurface.withValues(alpha: .75))),
          ),
          const SizedBox(height: 12),
          FlowSegment<bool>(
            keyPrefix: 'rest-kind',
            values: const [true, false],
            labels: [ru ? 'Короткий' : 'Short', ru ? 'Длительный' : 'Long'],
            selected: _short,
            onChanged: _busy
                ? (_) {}
                : (v) => setState(() {
                      _short = v;
                      _rolls.clear();
                      _hold.reset();
                    }),
          ),
        ]),
      ]),
    );

    final body = _short
        ? _shortBody(context, l10n, locale)
        : _longBody(context, l10n, locale);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        child: CalmSize(
          duration: AppMotion.of(context, AppMotion.gentleSettle),
          curve: AppMotion.gentleCurve,
          alignment: Alignment.topCenter,
          child: body,
        ),
      ),
    ]);
  }

  Widget _gains(BuildContext context, List<_RestChange> changes) {
    final ru = instrumentRu(context);
    if (changes.isEmpty) {
      return _GainRow(
          icon: 'check',
          accent: AppPaletteRoles.heal(context),
          label: ru ? 'Восстанавливать нечего' : 'Nothing to recover',
          value: '',
          none: true,
          wave: 0,
          delay: 0);
    }
    return Column(children: [
      for (var i = 0; i < changes.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _GainRow(
            key: ValueKey('sheet-rest-change-${changes[i].id}'),
            icon: _gainIcon(changes[i].id),
            accent: AppAccents.of(context).at(_gainAccent(changes[i].id)),
            label: changes[i].label,
            value: changes[i].result,
            wave: _wave,
            delay: i * 70,
          ),
        ),
    ]);
  }

  static String _gainIcon(String id) => id == 'hp'
      ? 'heart'
      : id == 'hit-dice'
          ? 'dice'
          : id.startsWith('slot') || id == 'pact'
              ? 'wand'
              : id == 'channel-divinity'
                  ? 'sun'
                  : id == 'wild-shape'
                      ? 'paw'
                      : id == 'natural-recovery'
                          ? 'leaf'
                          : id == 'arcane-recovery'
                              ? 'book'
                              : 'star';
  static int _gainAccent(String id) => id == 'hp'
      ? 0
      : id == 'hit-dice'
          ? 1
          : id.startsWith('slot')
              ? 4
              : id == 'pact'
                  ? 5
                  : id == 'wild-shape' || id == 'natural-recovery'
                      ? 3
                      : 2;

  Widget _shortBody(
      BuildContext context, AppLocalizations l10n, String locale) {
    final ru = locale == 'ru';
    final c = Theme.of(context).colorScheme;
    final heal = AppPaletteRoles.heal(context);
    final current = _form ? _hero.beastCurrentHp! : _hero.currentHp;
    final maximum = math.max(1, _form ? _hero.beastMaxHp! : _hero.maxHp);
    final rolled =
        _rolls.fold<int>(0, (sum, r) => sum + math.max(0, r.value + _con));
    final preview = math.min(maximum, current + rolled);
    final changes = _preview(l10n, locale, true)
        .where((x) => x.id != 'hp' && x.id != 'hit-dice')
        .toList();
    final perClass = _hero.hitDice.length == _hero.classes.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('$current',
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceVariant)),
            const SizedBox(width: 8),
            LineIcon('forward', size: 16, color: c.onSurfaceVariant),
            const SizedBox(width: 8),
            RollingNumber(preview,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: heal)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(ru ? 'из $maximum' : 'of $maximum',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 13,
                      color: c.onSurfaceVariant)),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Stack(children: [
                Positioned.fill(
                    child:
                        ColoredBox(color: c.onSurface.withValues(alpha: .08))),
                AnimatedFractionallySizedBox(
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 520)),
                  curve: AppMotion.snappyCurve,
                  widthFactor: preview / maximum,
                  heightFactor: 1,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: heal, borderRadius: BorderRadius.circular(7))),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              _rolls.isEmpty
                  ? (ru
                      ? 'Каждая кость — кость класса + Телосложение (${_con >= 0 ? '+' : ''}$_con)'
                      : 'Each die — the class die + Constitution (${_con >= 0 ? '+' : ''}$_con)')
                  : _rolls
                      .map((r) => '${r.value}${_con >= 0 ? '+' : ''}$_con')
                      .join(' · '),
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 12.5,
                  color: c.onSurfaceVariant)),
        ]),
      ),
      const SizedBox(height: 12),
      if (perClass)
        for (var i = 0; i < _hero.classes.length; i++) ...[
          _diceTray(context, i, ru),
          const SizedBox(height: 12),
        ],
      Text((ru ? 'Вернётся' : 'Returns').toUpperCase(),
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: c.onSurfaceVariant)),
      const SizedBox(height: 8),
      _gains(context, changes),
      const SizedBox(height: 8),
      SizedBox(
        height: 56,
        child: FilledButton.icon(
          key: const ValueKey('rest-short-go'),
          style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              shape: const StadiumBorder()),
          onPressed: _busy || _pending.isNotEmpty ? null : _finishShort,
          icon: const LineIcon('cup', size: 20),
          label: Text(
              '${ru ? 'Завершить привал' : 'Finish the rest'}${preview > current ? ' · +${preview - current} ${ru ? 'ОЗ' : 'HP'}' : ''}',
              style: const TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  Widget _diceTray(BuildContext context, int index, bool ru) {
    final c = Theme.of(context).colorScheme;
    final cls = _hero.classes[index];
    final die = hitDieOf(cls);
    if (die == null) return const SizedBox.shrink();
    final accent = classAccent(context, cls.id);
    final rolled = _rolls.where((r) => r.classId == cls.id).toList();
    final pending = _pending.where((p) => p.startsWith('${cls.id}:')).toList();
    final left = _hero.hitDice[index] - rolled.length - pending.length;
    final shown = math.min(left, 10);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
                '${ru ? 'Кости хитов' : 'Hit Dice'} · ${ru ? 'к' : 'd'}$die${_hero.classes.length > 1 ? ' · ${CharacterClassContext(_hero, cls.id).name(ru ? 'ru' : 'en')}' : ''}',
                style: const TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Text(ru ? '$left из ${cls.level}' : '$left of ${cls.level}',
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.onSurfaceVariant)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in pending)
            TumbleDie(
              key: ValueKey('hd-$p'),
              shape: dieShapeFor(die),
              label: '${_rollKeys[p]}',
              accent: accent,
              rollKey: 1,
              size: 44,
              sides: die,
            ),
          for (var i = 0; i < shown; i++)
            Semantics(
              button: true,
              label: ru ? 'Бросить кость хитов' : 'Roll a Hit Die',
              child: GestureDetector(
                key: ValueKey('hd-${cls.id}-$i'),
                onTap: () => _roll(index, die),
                onLongPress: () => _enter(index, die),
                child: TumbleDie(
                    shape: dieShapeFor(die),
                    label: '${ru ? 'к' : 'd'}$die',
                    accent: accent,
                    size: 44,
                    sides: die),
              ),
            ),
          if (left > shown)
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: c.onSurface.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14)),
              child: Text('+${left - shown}',
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.onSurfaceVariant)),
            ),
          for (final r in rolled)
            Opacity(
              opacity: .32,
              child: TumbleDie(
                  shape: dieShapeFor(die),
                  label: '${r.value}',
                  accent: accent,
                  size: 44,
                  sides: die,
                  dim: true),
            ),
        ]),
        const SizedBox(height: 8),
        Text(
            ru
                ? 'Касание — бросок · удержание — своя кость'
                : 'Tap to roll · hold to enter your own die',
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 11.5,
                color: c.onSurfaceVariant)),
      ]),
    );
  }

  Widget _longBody(BuildContext context, AppLocalizations l10n, String locale) {
    final ru = locale == 'ru';
    final c = Theme.of(context).colorScheme;
    final a5 = AppAccents.of(context).at(5),
        heal = AppPaletteRoles.heal(context);
    final changes = _preview(l10n, locale, false);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _gains(context, changes),
      const SizedBox(height: 8),
      Semantics(
        key: const ValueKey('rest-long-hold'),
        button: true,
        label: ru ? 'Удерживайте — до рассвета' : 'Hold until dawn',
        // A screen reader cannot hold: its tap goes straight to dawn.
        onTap: _busy || _dawn ? null : _sleep,
        child: GestureDetector(
          onTapDown: _busy || _dawn
              ? null
              : (_) {
                  _ticks = 0;
                  _hold.forward(from: 0);
                },
          onTapUp: (_) {
            if (!_hold.isCompleted) {
              _hold.animateBack(0,
                  curve: AppMotion.snappyCurve,
                  duration: const Duration(milliseconds: 300));
            }
          },
          onTapCancel: () {
            if (!_hold.isCompleted) {
              _hold.animateBack(0,
                  curve: AppMotion.snappyCurve,
                  duration: const Duration(milliseconds: 300));
            }
          },
          child: AnimatedBuilder(
            animation: _hold,
            builder: (context, _) => AnimatedContainer(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 400)),
              constraints: const BoxConstraints(minHeight: 60),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: _dawn
                      ? heal
                      : Color.alphaBlend(
                          a5.withValues(alpha: .22), c.surfaceContainerLow),
                  borderRadius: BorderRadius.circular(30)),
              child: Stack(alignment: Alignment.center, children: [
                if (!_dawn)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: LayoutBuilder(builder: (context, _) {
                      final w = MediaQuery.sizeOf(context).width - 36;
                      return Container(
                        width: w * _hold.value,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [a5.withValues(alpha: .7), a5])),
                      );
                    }),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    LineIcon(_dawn ? 'star' : 'moon',
                        size: 20, color: _dawn ? c.surface : c.onSurface),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          _dawn
                              ? (ru ? 'Рассвет' : 'Dawn')
                              : (ru
                                  ? 'Удерживайте — до рассвета'
                                  : 'Hold — until dawn'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: AppType.body,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _dawn ? c.surface : c.onSurface)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(l10n.sheetRestPreserves,
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 12,
              color: c.onSurfaceVariant)),
    ]);
  }
}

/// The class's Hit Die, or null when its rules are not loaded.
int? hitDieOf(CharacterClass cls) {
  try {
    final data = CharacterClassRules.resolve(cls).data;
    return data.declares('hitDie') ? data.hitDie : null;
  } catch (_) {
    return null;
  }
}

/// A star of the night sky that twinkles a few times.
class _Star extends StatelessWidget {
  const _Star({required this.delay});
  final double delay;
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final dot = Container(
        width: 2,
        height: 2,
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: Colors.white));
    if (still) return Opacity(opacity: .5, child: dot);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 3000 + (delay * 1000).round()),
      builder: (context, p, child) => Opacity(
          opacity: .15 + .45 * (0.5 + 0.5 * math.cos(p * math.pi * 4 + delay)),
          child: child),
      child: dot,
    );
  }
}

/// What returns on a rest: a glyph in its accent, the name, and from → to.
/// After the rest each row washes with its colour in turn.
class _GainRow extends StatelessWidget {
  const _GainRow({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.wave,
    required this.delay,
    this.none = false,
  });
  final String icon, label, value;
  final Color accent;
  final int wave, delay;
  final bool none;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final parts = value.split(' → ');
    final valueText = parts.length == 2
        ? Text.rich(
            TextSpan(children: [
              TextSpan(text: parts[0]),
              // Rubik has no arrow; it comes from the text face.
              const TextSpan(
                  text: ' → ', style: TextStyle(fontFamily: AppType.body)),
              TextSpan(text: parts[1], style: TextStyle(color: accent)),
            ]),
            style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.onSurfaceVariant))
        : value.isEmpty
            ? null
            : Text(value,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accent));
    final labelText = Text(label,
        style: const TextStyle(
            fontFamily: AppType.body,
            fontSize: 13.5,
            height: 1.2,
            fontWeight: FontWeight.w600));
    // Large text: the value moves under the name instead of squeezing it.
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
    final row = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: accent.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(10)),
          child: InstrumentGlyph(icon, size: 17, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: stacked && valueText != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, const SizedBox(height: 4), valueText])
              : labelText,
        ),
        if (!stacked && valueText != null) ...[
          const SizedBox(width: 8),
          valueText,
        ],
      ]),
    );
    final body = Opacity(opacity: none ? .5 : 1, child: row);
    if (wave == 0 || MediaQuery.disableAnimationsOf(context)) return body;
    return TweenAnimationBuilder<double>(
      key: ValueKey('wave-$wave'),
      tween: Tween(begin: -delay / 700, end: 1),
      duration: Duration(milliseconds: 700 + delay),
      builder: (context, p, child) {
        final q = p.clamp(0.0, 1.0);
        final w = q < .3 ? q / .3 : 1 - (q - .3) / .7;
        return Transform.translate(
          offset: Offset(4 * w, 0),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
                color: accent.withValues(alpha: .18 * w),
                borderRadius: BorderRadius.circular(16)),
            child: child,
          ),
        );
      },
      child: body,
    );
  }
}

class _RestChange {
  const _RestChange(this.id, this.label, this.result);
  final String id, label, result;
}

List<_RestChange> _changes(
    Character before, Character after, AppLocalizations l10n, String locale) {
  final changes = <_RestChange>[];
  void number(String id, String label, int old, int next, {int? maximum}) {
    if (old == next) return;
    String value(int n) => maximum == null ? '$n' : '$n / $maximum';
    changes.add(_RestChange(id, label, '${value(old)} → ${value(next)}'));
  }

  number('hp', l10n.hpShort, before.currentHp, after.currentHp,
      maximum: after.maxHp);
  for (int i = 0; i < after.spellSlots.length; i++) {
    number(
        'slot-${i + 1}',
        l10n.levelSlot(i + 1),
        i < before.spellSlots.length ? before.spellSlots[i] : 0,
        after.spellSlots[i],
        maximum: i < after.maxSpellSlots.length ? after.maxSpellSlots[i] : 0);
  }
  try {
    final old = MagicSlots.read(before).pact,
        next = MagicSlots.read(after).pact;
    if (old != null && next != null) {
      number('pact', locale == 'ru' ? 'Магия договора' : 'Pact Magic',
          old.current, next.current,
          maximum: next.maximum);
    }
  } catch (_) {}
  for (int i = 0; i < before.features.length; i++) {
    final feature = before.features[i];
    if (Character.isChannelDivinityResource(feature)) continue;
    final old = feature.resourcePool, next = after.features[i].resourcePool;
    if (old != null && next != null) {
      number(
          'pool-$i', feature.getName(locale), old.currentUses, next.currentUses,
          maximum: next.maxUses);
    }
  }
  number(
      'channel-divinity',
      l10n.channelDivinity,
      before.editableChannelDivinityCharges,
      after.editableChannelDivinityCharges,
      maximum: after.getMaxChannelDivinityCharges());
  number('wild-shape', l10n.wildShape, before.wildShapeCharges,
      after.wildShapeCharges,
      maximum: 2);
  number(
      'hit-dice',
      l10n.gameStateHitDice,
      before.hitDice.fold(0, (sum, n) => sum + n),
      after.hitDice.fold(0, (sum, n) => sum + n),
      maximum: after.maxHitDice);
  void ready(String id, String label, bool old, bool next) {
    if (old && !next) {
      changes.add(_RestChange(id, label, l10n.sheetRestReady));
    }
  }

  ready('arcane-recovery', l10n.arcaneRecovery, before.arcaneRecoveryUsed,
      after.arcaneRecoveryUsed);
  ready('natural-recovery', l10n.naturalRecovery, before.naturalRecoveryUsed,
      after.naturalRecoveryUsed);
  for (final entry in before.signatureSpellsUsed.entries) {
    ready(
        'signature-${entry.key}',
        SpellService.getSpellById(entry.key)?.getName(locale) ?? entry.key,
        entry.value,
        after.signatureSpellsUsed[entry.key] ?? false);
  }
  return changes;
}
