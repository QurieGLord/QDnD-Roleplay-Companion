import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';

import '../../../../core/magic/magic_slots.dart';
import '../../../../core/magic/spell_use.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/services/magic_resource_actions_service.dart';
import '../../../../core/services/spell_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/spell_cast_sheet.dart';
import 'instrument/instrument_kit.dart';

/// Warlock (prototype `CLASS.warlock`, fourth pass: plain sigils). The pact
/// slots are sigils of one circle — touch one to spend it, a short rest
/// lights them again. Eldritch Blast fires its beams with a d10 at the end
/// of each, marked hit or miss. Each Arcanum is a wax seal.
class WarlockMagicWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? patron;
  final CharacterFeature? pactBoon;
  final List<CharacterFeature> invocations;
  final VoidCallback? onChanged;

  const WarlockMagicWidget({
    super.key,
    required this.character,
    this.patron,
    this.pactBoon,
    this.invocations = const [],
    this.onChanged,
  });

  @override
  State<WarlockMagicWidget> createState() => _WarlockMagicWidgetState();
}

class _WarlockMagicWidgetState extends State<WarlockMagicWidget> {
  bool _busy = false;
  List<int>? _beams;
  List<bool> _hit = const [];
  int _blastKey = 0, _luckKey = 0, _crack = -1;
  int? _luck;
  // Toggleable invocations, as in the prototype: Agonizing and Repelling
  // shape the blast, Devil's Sight dims the panel.
  final Map<String, bool> _toggles = {
    'agonizing': true,
    'repelling': true,
    'devils-sight': false
  };
  bool _luckUsed = false;
  int? _gained;

  bool get _sight => _toggles['devils-sight']! && _has('devils-sight');
  String? _toggleOf(CharacterFeature inv) => _toggles.keys
      .where((k) => inv.id.toLowerCase().replaceAll('_', '-').contains(k))
      .firstOrNull;

  Character get _hero => widget.character;
  CharacterClassContext get _owner => CharacterClassContext(_hero, 'warlock');

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  CharacterFeature? _feature(List<String> tokens) => _hero.features
      .where((f) =>
          _owner.canUseFeature(f) &&
          tokens
              .any((t) => f.id.toLowerCase().replaceAll('_', '-').contains(t)))
      .firstOrNull;

  bool _has(String token) =>
      widget.invocations.any((i) => i.id.toLowerCase().contains(token)) ||
      _feature([token]) != null;

  InstrumentAbout _about(CharacterFeature f, String locale) => InstrumentAbout(
      title: f.getName(locale),
      paragraphs: f.getDescription(locale).split(RegExp(r'\n\s*\n')));

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final level = _owner.level;
    final a5 = accentOf(context, 5),
        a0 = accentOf(context, 0),
        a2 = accentOf(context, 2);
    final c = Theme.of(context).colorScheme;
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(_hero);
    } catch (_) {}
    final pact = slots?.pact;
    final children = <Widget>[];

    if (pact != null && pact.maximum > 0) {
      children.add(Instrument(
        key: const ValueKey('warlock-pact-panel'),
        accent: a5,
        title: ru ? 'Магия договора' : 'Pact Magic',
        about: InstrumentAbout(
            title: ru ? 'Магия договора' : 'Pact Magic',
            kicker: ru ? 'Короткий отдых' : 'Short rest',
            paragraphs: [
              ru
                  ? 'Все ячейки договора одного круга, и любое заклинание колдуна накладывается этим кругом.'
                  : 'All your pact slots share one level, and every warlock spell is cast at it.',
              ru
                  ? 'Ячейки восстанавливаются после короткого и длительного отдыха.'
                  : 'They recover on a short or long rest.'
            ],
            how: ru
                ? 'Коснитесь печати — ячейка потратится. Отдых зажжёт печати снова.'
                : 'Tap a sigil to spend a slot. A rest lights them again.'),
        trailing: RestChip(
            short: true,
            onRestore: () => restoreValue(context,
                current: pact.current,
                max: pact.maximum,
                write: (v) => GameplayActionsService.editMagicSlot(_hero, MagicPool.pact, pact.circle, v),
                done: () => setState(() => widget.onChanged?.call()))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BigCount(pact.current, of: pact.maximum),
              const SizedBox(height: 6),
              InstrumentHint(ru
                  ? 'ячейки ${pact.circle} круга'
                  : 'level ${pact.circle} slots'),
            ]),
          ]),
          const SizedBox(height: 14),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 12,
              children: [
                for (var i = 0; i < pact.maximum; i++)
                  _Sigil(
                    key: ValueKey('warlock-sigil-$i'),
                    circle: pact.circle,
                    lit: i < pact.current,
                    crack: _crack == i,
                    accent: a5,
                    onTap: _busy
                        ? null
                        : () {
                            if (pact.current <= 0) {
                              AppSnackBar.info(
                                  context,
                                  ru
                                      ? 'Печати вернёт короткий отдых'
                                      : 'A short rest restores the sigils');
                              return;
                            }
                            HapticFeedback.lightImpact();
                            setState(() => _crack = pact.current - 1);
                            _run(() => MagicResourceActionsService.spendSlot(
                                _hero, MagicPool.pact, pact.circle));
                          },
                  ),
              ]),
          const SizedBox(height: 10),
          InstrumentHint(
              pact.current > 0
                  ? (ru
                      ? 'Коснитесь печати — потратить ячейку'
                      : 'Tap a sigil to spend a slot')
                  : (ru
                      ? 'Печати зажжёт короткий отдых'
                      : 'A short rest lights the sigils'),
              center: true),
        ]),
      ));
    }

    var knowsBlast = false;
    try {
      knowsBlast = SpellUse.visible(_hero)
          .any((s) => s.id.replaceAll('_', '-') == 'eldritch-blast');
    } catch (_) {}
    if (knowsBlast) children.add(_blast(context, ru, a5));

    final arcana = <(int, CharacterFeature)>[
      for (final n in [6, 7, 8, 9])
        if (GameplayActionsService.arcanumFeature(_hero, n) case final f?)
          (n, f)
    ];
    if (arcana.isNotEmpty) {
      // Arcana return only on a long rest, unlike the pact sigils above.
      children.add(LiteBlock(
        key: const ValueKey('warlock-arcanum-panel'),
        accent: a0,
        title: ru ? 'Таинственный арканум' : 'Mystic Arcanum',
        about: InstrumentAbout(
            title: ru ? 'Таинственный арканум' : 'Mystic Arcanum',
            kicker: ru ? 'Длительный отдых' : 'Long rest',
            paragraphs: [
              ru
                  ? 'Одно заклинание каждого круга с 6 по 9 — без ячейки, раз до длительного отдыха.'
                  : 'One spell of each level from 6th to 9th, cast without a slot once per long rest.'
            ],
            how: ru
                ? 'Коснитесь печати — сломать её и наложить заклинание.'
                : 'Tap a seal to break it and cast the spell.'),
        trailing: RestChip(
            short: false,
            onRestore: () => restoreValue(context,
                current: arcana.where((a) => GameplayActionsService.resourceCurrent(_hero, a.$2) > 0).length,
                max: arcana.length,
                write: (_) async {
                  for (final (n, _) in arcana) {
                    await GameplayActionsService.editArcanum(_hero, n, 1);
                  }
                },
                done: () => setState(() => widget.onChanged?.call()))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (n, f) in arcana) ...[
            if (n != arcana.first.$1) const SizedBox(height: 8),
            _Seal(
              key: ValueKey('arcanum-counter-$n'),
              circle: n,
              spell: (() {
                final id = SpellUse.arcanumSpell(_hero, n);
                return id == null
                    ? null
                    : SpellService.getSpellById(id)?.getName(locale);
              })(),
              ready: GameplayActionsService.resourceCurrent(_hero, f) > 0,
              accent: a0,
              onTap: _busy
                  ? null
                  : () async {
                      final id = SpellUse.arcanumSpell(_hero, n);
                      final spell =
                          id == null ? null : SpellService.getSpellById(id);
                      if (GameplayActionsService.resourceCurrent(_hero, f) <=
                          0) {
                        AppSnackBar.info(
                            context,
                            ru
                                ? 'Печать вернёт длительный отдых'
                                : 'A long rest restores the seal');
                        return;
                      }
                      HapticFeedback.mediumImpact();
                      if (spell != null) {
                        final cast =
                            await showSpellCastSheet(context, _hero, spell);
                        if (mounted && cast) {
                          setState(() => widget.onChanged?.call());
                        }
                      } else {
                        await _run(() async =>
                            GameplayActionsService.changeArcanum(_hero, n, -1));
                      }
                    },
            ),
          ],
        ]),
      ));
    } else if (level < 11) {
      children.add(
          LockedCell(title: ru ? 'Арканум' : 'Arcanum', level: 11, accent: a0));
    }

    final owned = widget.invocations
        .where(_owner.canUseFeature)
        .where((i) =>
            !i.nameEn.toLowerCase().contains('eldritch invocations') &&
            !i.nameRu.toLowerCase().contains('таинственные воззвания'))
        .toList();
    if (owned.isNotEmpty) {
      children.add(LiteBlock(
        accent: a5,
        title: ru ? 'Воззвания' : 'Invocations',
        trailing: InstrumentChip(ru ? 'без зарядов' : 'at will'),
        child: LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 16) / 3;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final inv in owned)
              SizedBox(
                width: w,
                child: Builder(builder: (context) {
                  final toggle = _toggleOf(inv);
                  final on = toggle != null && _toggles[toggle]!;
                  final id = inv.id.toLowerCase();
                  return _Invocation(
                    key: ValueKey('warlock-invocation-${inv.id}'),
                    name: inv.getName(locale).replaceAll(
                        RegExp(r'^(ТВ|Воззвание|EI|Eldritch Invocation):\s*'),
                        ''),
                    glyph: id.contains('agonizing')
                        ? 'flame'
                        : id.contains('repelling')
                            ? 'dash'
                            : id.contains('sight') || id.contains('minds')
                                ? 'eye'
                                : id.contains('mask')
                                    ? 'mask'
                                    : id.contains('tome') || id.contains('book')
                                        ? 'book'
                                        : id.contains('armor')
                                            ? 'shield'
                                            : id.contains('beast')
                                                ? 'paw'
                                                : 'spark',
                    accent: a5,
                    on: on,
                    note: toggle != null
                        ? (on
                            ? (ru ? 'включено' : 'on')
                            : (ru ? 'выключено' : 'off'))
                        : inv.resourcePool != null
                            ? '${inv.resourcePool!.currentUses}/${inv.resourcePool!.maxUses}'
                            : id.contains('book') || id.contains('tome')
                                ? (ru ? 'ритуалы' : 'rituals')
                                : (ru ? 'без ячейки' : 'no slot'),
                    description: inv.getDescription(locale),
                    onTap: () {
                      if (toggle != null) {
                        HapticFeedback.selectionClick();
                        setState(() => _toggles[toggle] = !on);
                        return;
                      }
                      if (inv.resourcePool != null) {
                        _run(() async {
                          final spent =
                              await GameplayActionsService.spendResource(
                                  _hero, inv);
                          if (spent && mounted) HapticFeedback.mediumImpact();
                        });
                        return;
                      }
                      showInstrumentAbout(context, _about(inv, locale), a5);
                    },
                  );
                }),
              ),
          ]);
        }),
      ));
    } else if (level < 2) {
      children.add(LockedCell(
          title: ru ? 'Воззвания' : 'Invocations', level: 2, accent: a5));
    }

    final blessing = _feature(['dark-one-s-blessing', 'dark-ones-blessing']);
    final luck = _feature(['dark-one-s-own-luck', 'dark-ones-own-luck']);
    final boon = _feature(['pact-of-the-']) ?? widget.pactBoon;
    final patronTiles = <Widget>[
      if (blessing != null)
        CellTile(
          key: const ValueKey('warlock-dark-blessing'),
          accent: a0,
          onTap: () {
            final n = math.max(1, _hero.abilityScores.charismaModifier + level);
            _run(() async {
              await GameplayActionsService.editHealth(_hero,
                  current: _hero.currentHp,
                  maximum: _hero.maxHp,
                  temporary: math.max(_hero.temporaryHp, n));
              if (mounted) {
                HapticFeedback.mediumImpact();
                setState(() => _gained = n);
                AppSnackBar.success(
                    this.context, ru ? '+$n временных ОЗ' : '+$n temporary HP');
              }
            });
          },
          peek: (
            blessing.getName(locale),
            blessing.getDescription(locale).split('\n').first
          ),
          children: [
            InstrumentGlyph('skull', size: 26, color: a0),
            InstrumentCap(ru ? 'Враг повержен' : 'Foe falls',
                accent: a0, about: _about(blessing, locale)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('+', style: bigStyle(context)),
                    RollingNumber(
                        math.max(
                            1, _hero.abilityScores.charismaModifier + level),
                        style: bigStyle(context)),
                  ]),
            ),
            InstrumentHint(_gained != null
                ? (ru ? 'получено' : 'gained')
                : (ru ? 'временных ОЗ' : 'temporary HP')),
          ],
        ),
      if (luck != null)
        CellTile(
          key: const ValueKey('warlock-dark-luck'),
          accent: a2,
          onTap: () {
            final spent = luck.resourcePool != null
                ? luck.resourcePool!.currentUses <= 0
                : _luckUsed;
            if (spent) {
              AppSnackBar.info(context,
                  ru ? 'Удачу вернёт отдых' : 'A rest restores your luck');
              return;
            }
            HapticFeedback.lightImpact();
            setState(() {
              _luck = math.Random().nextInt(10) + 1;
              _luckKey++;
              _luckUsed = true;
            });
            if (luck.resourcePool != null) {
              _run(() async =>
                  GameplayActionsService.spendResource(_hero, luck));
            }
          },
          peek: (
            luck.getName(locale),
            luck.getDescription(locale).split('\n').first
          ),
          children: [
            InstrumentCap(luck.getName(locale),
                accent: a2, about: _about(luck, locale)),
            TumbleDie(
                shape: DieShape.d10,
                label: _luck == null ? (ru ? 'к10' : 'd10') : '+$_luck',
                accent: a2,
                rollKey: _luckKey,
                sides: 10,
                natural: _luck,
                size: 42),
            InstrumentHint((luck.resourcePool != null
                    ? luck.resourcePool!.currentUses <= 0
                    : _luckUsed)
                ? (ru ? 'до отдыха' : 'until a rest')
                : (ru ? 'раз в отдых' : 'once a rest')),
          ],
        )
      else if (level < 6 && blessing != null)
        LockedCell(title: ru ? 'Удача' : 'Luck', level: 6, accent: a2),
    ];
    if (patronTiles.isNotEmpty) children.add(TileRow(children: patronTiles));
    if (boon != null && level >= 3) {
      children.add(Align(
        alignment: Alignment.centerLeft,
        child: InstrumentChip(boon.getName(locale),
            glyph: 'book',
            color: c.onSurface,
            onTap: () =>
                showInstrumentAbout(context, _about(boon, locale), a5)),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: _sight
            ? RadialGradient(colors: [
                a5.withValues(alpha: .08),
                Colors.black.withValues(alpha: .35)
              ], radius: 1.2)
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ]
      ]),
    );
  }

  Widget _blast(BuildContext context, bool ru, Color a5) {
    final total = _hero.classes.fold<int>(0, (t, e) => t + e.level);
    final beams = total >= 17
        ? 4
        : total >= 11
            ? 3
            : total >= 5
                ? 2
                : 1;
    final agonizing = _has('agonizing') && _toggles['agonizing']!;
    final repelling = _has('repelling') && _toggles['repelling']!;
    final mod = agonizing ? _hero.abilityScores.charismaModifier : 0;
    final k = ru ? 'к' : 'd';
    if (_beams != null && _beams!.length != beams) _beams = null;
    final sum = _beams == null
        ? 0
        : [
            for (var i = 0; i < beams; i++)
              if (_hit[i]) _beams![i] + mod
          ].fold(0, (a, b) => a + b);
    return Instrument(
      key: const ValueKey('warlock-eldritch-blast'),
      accent: a5,
      title: ru ? 'Мистический заряд' : 'Eldritch Blast',
      about: InstrumentAbout(
          title: ru ? 'Мистический заряд' : 'Eldritch Blast',
          kicker: ru
              ? 'Заговор · действие · 120 фт.'
              : 'Cantrip · action · 120 ft.',
          paragraphs: [
            ru
                ? 'Луч силовой энергии: атака заклинанием, 1к10 силового урона. С 5, 11 и 17 уровня — больше лучей, каждый атакует отдельно.'
                : 'A beam of force: a spell attack for 1d10 force. More beams at levels 5, 11 and 17, each attacking separately.',
          ],
          how: ru
              ? '«Залп» бросает все лучи. Коснитесь луча, который промахнулся, — сумма пересчитается.'
              : '“Volley” rolls every beam. Tap a beam that missed and the sum updates.'),
      trailing: InstrumentChip(ru ? '120 фт.' : '120 ft.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: Row(children: [
            InstrumentGlyph('hand', size: 28, color: a5),
            const SizedBox(width: 6),
            Expanded(
                child: _Beams(
                    count: beams,
                    fire: _blastKey,
                    hit: _beams == null ? null : _hit,
                    accent: a5)),
          ]),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          for (var i = 0; i < beams; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Pressable(
              onTap: _beams == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() => _hit = [..._hit]..[i] = !_hit[i]);
                    },
              scale: .92,
              semanticLabel: '${i + 1}',
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _beams == null || _hit[i] ? 1 : .4,
                child: Column(children: [
                  TumbleDie(
                      shape: DieShape.d10,
                      label: _beams == null ? '${k}10' : '${_beams![i] + mod}',
                      accent: a5,
                      rollKey: _blastKey,
                      sides: 10,
                      natural: _beams?[i],
                      size: 42),
                  const SizedBox(height: 4),
                  Text(
                      _beams == null
                          ? (ru ? 'луч ${i + 1}' : 'beam ${i + 1}')
                          : _hit[i]
                              ? (ru ? 'попал' : 'hit')
                              : (ru ? 'мимо' : 'miss'),
                      style: hintStyle(context).copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _beams != null && !_hit[i]
                              ? accentOf(context, 0)
                              : null)),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _beams != null
                  ? RollingNumber(sum, style: hugeStyle(context))
                  : Text('$beams × ${k}10${agonizing ? '+$mod' : ''}',
                      style: bigStyle(context)),
              const SizedBox(height: 4),
              InstrumentHint(_beams != null
                  ? (ru
                      ? 'силового урона · коснитесь луча-промаха'
                      : 'force damage · tap a beam that missed')
                  : '${ru ? '$beams ${beams == 1 ? 'луч' : beams < 5 ? 'луча' : 'лучей'}' : '$beams beam${beams == 1 ? '' : 's'}'}${repelling ? (ru ? ' · отталкивают' : ' · push') : ''}'),
            ]),
          ),
          GoButton(
            key: const ValueKey('warlock-volley'),
            label: ru ? 'Залп' : 'Volley',
            glyph: 'bolt',
            accent: a5,
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _beams = [
                  for (var i = 0; i < beams; i++) math.Random().nextInt(10) + 1
                ];
                _hit = List.filled(beams, true);
                _blastKey++;
              });
            },
          ),
        ]),
      ]),
    );
  }
}

class _Sigil extends StatelessWidget {
  const _Sigil(
      {super.key,
      required this.circle,
      required this.lit,
      required this.crack,
      required this.accent,
      this.onTap});
  final int circle;
  final bool lit, crack;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      scale: .9,
      semanticLabel: '$circle',
      child: Pulse(
        trigger: lit,
        scale: lit ? 1.15 : .9,
        child: SizedBox(
          width: 66,
          height: 72,
          child: CustomPaint(
            painter: _HexPainter(accent, lit, c.surfaceContainer, c.outline),
            child: Center(
                child: Text('$circle',
                    style: bigStyle(context).copyWith(
                        fontSize: 20,
                        color: lit ? c.onSurface : c.onSurfaceVariant))),
          ),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter(this.accent, this.lit, this.cont, this.outline);
  final Color accent, cont, outline;
  final bool lit;
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100, sy = size.height / 110;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final hex = Path()
      ..addPolygon(
          [p(50, 4), p(94, 29), p(94, 81), p(50, 106), p(6, 81), p(6, 29)],
          true);
    if (lit) {
      canvas.drawPath(
          hex,
          Paint()
            ..color = accent.withValues(alpha: .5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawPath(hex, Paint()..color = mixColor(accent, .34, cont));
      canvas.drawPath(
          hex,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * sx
            ..strokeJoin = StrokeJoin.round
            ..color = accent);
      final rune = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * sx
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: .18);
      canvas.drawLine(p(50, 22), p(50, 88), rune);
      canvas.drawLine(p(30, 40), p(70, 70), rune);
      canvas.drawLine(p(70, 40), p(30, 70), rune);
    } else {
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * sx
        ..color = outline;
      for (final metric in hex.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 11) {
          canvas.drawPath(metric.extractPath(d, d + 6), dash);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.lit != lit || old.accent != accent;
}

class _Beams extends StatelessWidget {
  const _Beams(
      {required this.count,
      required this.fire,
      required this.hit,
      required this.accent});
  final int count, fire;
  final List<bool>? hit;
  final Color accent;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(fire),
        tween: Tween(begin: fire == 0 ? 1 : 0, end: 1),
        duration: AppMotion.of(context, const Duration(milliseconds: 700)),
        curve: AppMotion.snappyCurve,
        builder: (context, t, _) => CustomPaint(
            size: Size.infinite,
            painter: _BeamsPainter(count, t, fire > 0, hit, accent,
                Theme.of(context).colorScheme.onSurface)),
      );
}

class _BeamsPainter extends CustomPainter {
  _BeamsPainter(
      this.count, this.t, this.fired, this.hit, this.accent, this.ink);
  final int count;
  final double t;
  final bool fired;
  final List<bool>? hit;
  final Color accent, ink;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < count; i++) {
      final y = count == 1
          ? size.height / 2
          : 8 + i * (size.height - 16) / (count - 1);
      final path = Path()
        ..moveTo(0, size.height / 2)
        ..cubicTo(size.width * .35, size.height / 2, size.width * .55, y,
            size.width, y);
      final miss = hit != null && i < hit!.length && !hit![i];
      if (!fired) {
        final dots = Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: .3);
        for (final m in path.computeMetrics()) {
          for (double d = 0; d < m.length; d += 8) {
            final pos = m.getTangentForOffset(d)?.position;
            if (pos != null) canvas.drawCircle(pos, 1, dots);
          }
        }
        continue;
      }
      final local = ((t - i * .12) / (1 - .24)).clamp(0.0, 1.0);
      for (final m in path.computeMetrics()) {
        canvas.drawPath(
            m.extractPath(0, m.length * local),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round
              ..color = miss ? ink.withValues(alpha: .15) : accent
              ..maskFilter =
                  miss ? null : const MaskFilter.blur(BlurStyle.solid, 3));
      }
    }
  }

  @override
  bool shouldRepaint(_BeamsPainter old) =>
      old.t != t || old.hit != hit || old.count != count;
}

/// An Arcanum: a sealed page; the wax splits when it is broken.
class _Seal extends StatelessWidget {
  const _Seal(
      {super.key,
      required this.circle,
      required this.spell,
      required this.ready,
      required this.accent,
      this.onTap});
  final int circle;
  final String? spell;
  final bool ready;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    return Pressable(
      onTap: onTap,
      scale: .98,
      semanticLabel: spell ?? '$circle',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(colors: [
            mixColor(const Color(0xFFF3E6C8), .1, c.surfaceContainerLow),
            c.surfaceContainerLow
          ]),
        ),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((ru ? '$circle круг' : 'Level $circle').toUpperCase(),
                  style: capStyle(context, accent)),
              const SizedBox(height: 4),
              Text(spell ?? (ru ? 'Не выбран' : 'Not chosen'),
                  style: const TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 18,
                      height: 1.15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              InstrumentHint(ready
                  ? (ru ? 'коснитесь — наложить' : 'tap to cast')
                  : (ru ? 'до длительного отдыха' : 'until a long rest')),
            ]),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: ready ? 0 : 1),
            duration: AppMotion.of(context, const Duration(milliseconds: 500)),
            curve: AppMotion.snappyCurve,
            builder: (context, broken, _) => SizedBox.square(
              dimension: 60,
              child: Stack(alignment: Alignment.center, children: [
                for (final left in [true, false])
                  Transform.translate(
                    offset: Offset((left ? -8 : 8) * broken, 6 * broken),
                    child: Transform.rotate(
                      angle: (left ? -.31 : .31) * broken,
                      child: Opacity(
                        opacity: 1 - .45 * broken,
                        child: ClipPath(
                          clipper: _HalfClipper(left),
                          child: Container(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                    center: const Alignment(-.3, -.4),
                                    colors: [
                                      mixColor(accent, .75, c.surfaceContainer),
                                      mixColor(accent, .35, c.surfaceContainer)
                                    ])),
                          ),
                        ),
                      ),
                    ),
                  ),
                Text('$circle',
                    style: bigStyle(context).copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: ready ? c.onSurface : c.onSurfaceVariant)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HalfClipper extends CustomClipper<Path> {
  _HalfClipper(this.left);
  final bool left;
  @override
  Path getClip(Size s) => left
      ? (Path()
        ..moveTo(0, 0)
        ..lineTo(s.width * .55, 0)
        ..lineTo(s.width * .45, s.height)
        ..lineTo(0, s.height)
        ..close())
      : (Path()
        ..moveTo(s.width * .55, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width, s.height)
        ..lineTo(s.width * .45, s.height)
        ..close());
  @override
  bool shouldReclip(_HalfClipper old) => old.left != left;
}

class _Invocation extends StatelessWidget {
  const _Invocation(
      {super.key,
      required this.name,
      required this.glyph,
      required this.accent,
      required this.on,
      required this.note,
      required this.description,
      required this.onTap});
  final String name, glyph, note, description;
  final Color accent;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Peek(
      title: name,
      text: description.split('\n').first,
      child: Pressable(
        onTap: onTap,
        scale: .94,
        selected: on,
        semanticLabel: name,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 116,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
              color: on
                  ? mixColor(accent, .24, c.surfaceContainer)
                  : c.onSurface.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            InstrumentGlyph(glyph, size: 24, color: accent),
            const SizedBox(height: 6),
            Expanded(
                child: Text(name,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle(context, size: 11.5))),
            Text(note, style: hintStyle(context).copyWith(fontSize: 10.5)),
          ]),
        ),
      ),
    );
  }
}
