import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';

import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../session/value_editors.dart';
import 'instrument/instrument_kit.dart';

/// Monk · Ki (prototype `CLASS.monk`). An ensō of brush strokes, one per
/// point of ki; choosing a technique makes exactly the strokes it costs
/// breathe, and touching the circle exhales them into ink.
class KiTrackerWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature kiFeature;
  final VoidCallback? onChanged;

  const KiTrackerWidget({
    super.key,
    required this.character,
    required this.kiFeature,
    this.onChanged,
  });

  @override
  State<KiTrackerWidget> createState() => _KiTrackerWidgetState();
}

class _Kata {
  const _Kata(this.feature, this.glyph, this.whenRu, this.whenEn);
  final CharacterFeature feature;
  final String glyph, whenRu, whenEn;
}

class _KiTrackerWidgetState extends State<KiTrackerWidget> with TickerProviderStateMixin {
  bool _spending = false;
  String? _pick;
  String? _stamp;
  Timer? _stampTimer;
  int _inkFrom = -1;
  late final _ink = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  int? _ma, _df;
  int _maKey = 0, _dfKey = 0;

  Character get _hero => widget.character;
  int get _level => _hero.classLevel('monk');

  @override
  void dispose() {
    _stampTimer?.cancel();
    _ink.dispose();
    _breath.dispose();
    super.dispose();
  }

  CharacterFeature? _find(List<String> keys) {
    final owner = CharacterClassContext(_hero, 'monk');
    for (final k in keys) {
      final match = _hero.features.where((f) {
        if (!owner.canUseFeature(f)) return false;
        return f.id.toLowerCase().contains(k) || f.nameEn.toLowerCase().contains(k);
      }).firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  List<_Kata> get _katas => [
        if (_find(['flurry_of_blows', 'flurry-of-blows']) case final f?) _Kata(f, 'strikes', 'бонус', 'bonus'),
        if (_find(['patient_defense', 'patient-defense']) case final f?) _Kata(f, 'shield', 'бонус', 'bonus'),
        if (_find(['step_of_the_wind', 'step-of-the-wind']) case final f?) _Kata(f, 'wind', 'бонус', 'bonus'),
        if (_find(['stunning_strike', 'stunning-strike']) case final f?) _Kata(f, 'spark', 'попадание', 'on a hit'),
        if (_find(['wholeness_of_body', 'wholeness-of-body']) case final f?) _Kata(f, 'lotus', 'действие', 'action'),
      ];

  int _cost(CharacterFeature f) =>
      f.id.toLowerCase().contains('wholeness') ? 0 : (f.consumption?.amount ?? 1);

  Future<void> _use(_Kata kata) async {
    if (_spending) return;
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final pool = widget.kiFeature.resourcePool!;
    final cost = _cost(kata.feature);
    if (pool.currentUses < cost) {
      AppSnackBar.info(context, ru ? 'Не хватает ци' : 'Not enough ki');
      return;
    }
    setState(() => _spending = true);
    final l = AppLocalizations.of(context)!;
    final before = pool.currentUses;
    try {
      bool done;
      final wholeness = kata.feature.id.toLowerCase().contains('wholeness');
      if (wholeness) {
        final healing = 3 * _level;
        if (kata.feature.resourcePool != null) {
          done = (await GameplayActionsService.activateResource(_hero, kata.feature, healing: healing)).spent;
        } else {
          await GameplayActionsService.changeHealth(_hero, healing, healing: true);
          done = true;
        }
      } else {
        done = await GameplayActionsService.spendResource(_hero, widget.kiFeature, amount: cost);
      }
      if (!mounted || !done) return;
      HapticFeedback.lightImpact();
      final stunning = kata.feature.id.toLowerCase().contains('stunning');
      setState(() {
        _inkFrom = before;
        _pick = null;
        _stamp = stunning
            ? (ru ? 'Сл ${8 + _hero.proficiencyBonus + _hero.abilityScores.wisdomModifier}' : 'DC ${8 + _hero.proficiencyBonus + _hero.abilityScores.wisdomModifier}')
            : wholeness
                ? '+${3 * _level}'
                : null;
      });
      _ink.forward(from: 0);
      _stampTimer?.cancel();
      if (_stamp != null) {
        _stampTimer = Timer(const Duration(milliseconds: 1900), () {
          if (mounted) setState(() => _stamp = null);
        });
      }
      widget.onChanged?.call();
      if (!stunning && !wholeness && mounted) {
        AppSnackBar.success(context, l.gameStateResourceUsed(kata.feature.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), '')));
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _spending = false);
    }
  }

  Future<void> _edit() async {
    final changed = await showResourceValueEditor(context, _hero, widget.kiFeature);
    if (mounted && changed) setState(() => widget.onChanged?.call());
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.kiFeature.resourcePool;
    if (pool == null) return const SizedBox.shrink();
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final a2 = accentOf(context, 2);
    final level = _level;
    final die = level >= 17 ? 10 : level >= 11 ? 8 : level >= 5 ? 6 : 4;
    final k = ru ? 'к' : 'd';
    final dex = _hero.abilityScores.dexterityModifier;
    final deflect = _find(['deflect_missiles', 'deflect-missiles']);
    final movement = _find(['unarmored_movement', 'unarmored-movement']);
    final speed = level >= 18 ? 30 : level >= 14 ? 25 : level >= 10 ? 20 : level >= 6 ? 15 : level >= 2 ? 10 : 0;
    final tools = TileRow(gap: 8, children: [
      _MonkTool(
        label: ru ? 'Удар' : 'Strike',
        accent: a2,
        onTap: () {
          final r = math.Random().nextInt(die) + 1;
          setState(() {
            _ma = r;
            _maKey++;
          });
        },
        peek: (ru ? 'Боевые искусства' : 'Martial Arts', ru ? 'Безоружный удар: $k$die + ЛОВ. Бонусной атакой после атаки' : 'Unarmed strike: $k$die + DEX. A bonus attack after the Attack action'),
        child: TumbleDie(shape: dieShapeFor(die), label: _ma == null ? '$k$die' : '${_ma! + dex}', accent: a2, rollKey: _maKey, sides: die, size: 42),
      ),
      if (deflect != null)
        _MonkTool(
          label: ru ? 'Отражение' : 'Deflect',
          accent: a2,
          onTap: () {
            final r = math.Random().nextInt(10) + 1;
            setState(() {
              _df = r + dex + level;
              _dfKey++;
            });
          },
          peek: (deflect.getName(locale), ru ? 'Реакцией: урон от дальнобойной атаки меньше на ${k}10 + ${dex + level}' : 'Reaction: reduce ranged weapon damage by ${k}10 + ${dex + level}'),
          child: TumbleDie(shape: DieShape.d10, label: _df == null ? '${k}10' : '−$_df', accent: a2, rollKey: _dfKey, sides: 10, size: 42),
        )
      else if (level < 3)
        _MonkTool(
          label: ru ? 'Отражение' : 'Deflect',
          accent: a2,
          locked: true,
          peek: (ru ? 'Отражение снарядов' : 'Deflect Missiles', ru ? 'Откроется на 3 уровне' : 'Opens at level 3'),
          child: InstrumentGlyph('lock', size: 30, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      if (speed > 0)
        _MonkTool(
          label: ru ? '+$speed фт.' : '+$speed ft.',
          accent: a2,
          peek: (movement?.getName(locale) ?? (ru ? 'Движение без доспехов' : 'Unarmored Movement'), ru ? '+$speed фт. скорости без доспехов и щита' : '+$speed ft. of speed without armor or a shield'),
          child: InstrumentGlyph('wind', size: 30, color: a2),
        ),
    ]);
    if (level < 2 || widget.kiFeature.id == 'ki_fallback') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LockedInstrument(title: ru ? 'Ци' : 'Ki', level: 2, what: ru ? 'Шквал ударов, Терпеливая оборона, Поступь ветра' : 'Flurry of Blows, Patient Defense, Step of the Wind', accent: a2),
        const SizedBox(height: 12),
        tools,
      ]);
    }
    final katas = _katas;
    final picked = katas.where((x) => x.feature.id == _pick).firstOrNull;
    final cost = picked == null ? 0 : _cost(picked.feature);
    if (picked != null && cost > 0 && !_breath.isAnimating && !MediaQuery.disableAnimationsOf(context)) {
      _breath.repeat(reverse: true, count: 6);
    } else if ((picked == null || cost == 0) && _breath.isAnimating) {
      _breath.stop();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Instrument(
        key: const ValueKey('monk-ki'),
        accent: a2,
        title: ru ? 'Ци' : 'Ki',
        about: InstrumentAbout(
            title: widget.kiFeature.getName(locale),
            kicker: ru ? 'Короткий отдых' : 'Short rest',
            paragraphs: widget.kiFeature.getDescription(locale).split(RegExp(r'\n\s*\n')),
            how: ru ? 'Выберите приём ниже — круг подсветит его цену. Коснитесь круга, чтобы применить.' : 'Choose a technique below: the circle lights its cost. Touch the circle to use it.'),
        trailing: RestChip(
            short: true,
            onEdit: _edit,
            onRestore: () => restoreFeature(context, _hero, widget.kiFeature, done: () => setState(() => widget.onChanged?.call()))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 6),
          Stack(alignment: Alignment.center, children: [
            Pressable(
              key: const ValueKey('monk-enso'),
              onTap: _spending
                  ? null
                  : () {
                      if (picked == null) {
                        AppSnackBar.info(context, ru ? 'Сначала выберите приём' : 'Choose a technique first');
                        return;
                      }
                      _use(picked);
                    },
              scale: .96,
              semanticLabel: picked == null ? (ru ? 'Ци' : 'Ki') : picked.feature.getName(locale),
              child: SizedBox.square(
                dimension: 210,
                child: Stack(alignment: Alignment.center, children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_ink, _breath]),
                    builder: (context, _) => CustomPaint(
                      size: const Size.square(210),
                      painter: _EnsoPainter(
                          max: pool.maxUses,
                          left: pool.currentUses,
                          pre: cost,
                          inkFrom: _ink.isAnimating ? _inkFrom : -1,
                          inkT: _ink.value,
                          breath: _breath.value,
                          ink: Theme.of(context).colorScheme.onSurface,
                          gold: a2),
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    RollingNumber(pool.currentUses, style: hugeStyle(context)),
                    const SizedBox(height: 6),
                    Text(
                        picked == null
                            ? (ru ? 'из ${pool.maxUses}' : 'of ${pool.maxUses}')
                            : (cost > 0 ? (ru ? 'выдох · $cost' : 'exhale · $cost') : (ru ? 'выдох' : 'exhale')),
                        style: hintStyle(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ),
            if (_stamp != null)
              Positioned(
                right: 18,
                top: 24,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: AppMotion.snappyCurve,
                  builder: (context, v, child) => Opacity(
                      opacity: v.clamp(0, 1),
                      child: Transform.rotate(angle: -.21, child: Transform.scale(scale: 2 - v, child: child))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(border: Border.all(color: accentOf(context, 0), width: 3), borderRadius: BorderRadius.circular(10)),
                    child: Text(_stamp!, style: bigStyle(context).copyWith(fontSize: 20, color: accentOf(context, 0), fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ]),
          InstrumentHint(picked == null ? (ru ? 'Выберите приём' : 'Choose a technique') : (ru ? 'Коснитесь круга — выдохнуть' : 'Touch the circle to exhale'), center: true),
          if (katas.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              // Taller with large text so a card never clips its lines.
              height: 160 + 100 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 1.0),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(top: 6),
                itemCount: katas.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final kata = katas[i];
                  final c = _cost(kata.feature);
                  final usable = kata.feature.resourcePool == null || kata.feature.resourcePool!.currentUses > 0;
                  return _KataCard(
                    key: ValueKey('monk-kata-${kata.feature.id}'),
                    name: kata.feature.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), ''),
                    glyph: kata.glyph,
                    cost: c,
                    uses: kata.feature.resourcePool == null ? null : '${kata.feature.resourcePool!.currentUses}/${kata.feature.resourcePool!.maxUses}',
                    when: ru ? kata.whenRu : kata.whenEn,
                    accent: a2,
                    selected: _pick == kata.feature.id,
                    enabled: usable,
                    description: kata.feature.getDescription(locale),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _pick = _pick == kata.feature.id ? null : kata.feature.id);
                    },
                  );
                },
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      tools,
    ]);
  }
}

class _EnsoPainter extends CustomPainter {
  _EnsoPainter(
      {required this.max,
      required this.left,
      required this.pre,
      required this.inkFrom,
      required this.inkT,
      required this.breath,
      required this.ink,
      required this.gold});
  final int max, left, pre, inkFrom;
  final double inkT, breath;
  final Color ink, gold;
  @override
  void paint(Canvas canvas, Size size) {
    if (max <= 0) return;
    final s = size.width / 200, center = size.center(Offset.zero), r = 74 * s;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.07);
    canvas.drawCircle(Offset.zero, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20 * s
      ..color = ink.withValues(alpha: .05));
    final many = max > 10;
    final span = 2 * math.pi / max, gap = math.min(12 * math.pi / 180, span * (many ? .42 : .22));
    for (var i = 0; i < max; i++) {
      final start = -math.pi / 2 + gap / 2 + i * span, sweep = span - gap;
      final rect = Rect.fromCircle(center: Offset.zero, radius: r);
      final base = many ? 9.0 : (i.isOdd ? 17.0 : 15.0);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      if (inkFrom >= 0 && i >= left && i < inkFrom) {
        // Exhaled strokes spread into ink and fade.
        paint
          ..strokeWidth = (base + 25 * inkT) * s
          ..color = Color.lerp(gold, ink, .3)!.withValues(alpha: (1 - inkT).clamp(0, 1));
        canvas.drawArc(rect, start, sweep, false, paint);
        continue;
      }
      if (i >= left) {
        paint
          ..strokeWidth = 8 * s
          ..color = ink.withValues(alpha: .1);
      } else if (i >= left - pre) {
        paint
          ..strokeWidth = (base + 7 * breath) * s
          ..color = gold.withValues(alpha: 1 - .25 * breath);
      } else {
        paint
          ..strokeWidth = base * s
          ..color = Color.lerp(ink, gold, .12)!.withValues(alpha: .88);
      }
      canvas.drawArc(rect, start, sweep, false, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EnsoPainter old) => true;
}

/// A kata card: glyph, name, its price in ki dots and when it is used.
class _KataCard extends StatelessWidget {
  const _KataCard(
      {super.key,
      required this.name,
      required this.glyph,
      required this.cost,
      required this.when,
      required this.accent,
      required this.selected,
      required this.enabled,
      required this.description,
      required this.onTap,
      this.uses});
  final String name, glyph, when, description;
  final String? uses;
  final int cost;
  final Color accent;
  final bool selected, enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final card = AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 500)),
      curve: AppMotion.snappyCurve,
      width: 112,
      padding: const EdgeInsets.all(12),
      transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
      decoration: BoxDecoration(
        color: selected ? mixColor(accent, .14, c.surfaceContainerLow) : c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? accent : accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
          child: InstrumentGlyph(glyph, size: 22, color: selected ? c.surface : accent),
        ),
        const SizedBox(height: 7),
        SizedBox(
            height: 32 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
            child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: labelStyle(context, size: 13))),
        const SizedBox(height: 7),
        SizedBox(
          height: 10 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          child: uses != null
              ? Text(uses!, style: hintStyle(context).copyWith(fontSize: 11, height: 1, fontWeight: FontWeight.w600))
              : Row(children: [
                  for (var i = 0; i < cost; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
                  ],
                ]),
        ),
        const SizedBox(height: 7),
        Text(when, style: hintStyle(context).copyWith(fontSize: 11.5)),
      ]),
    );
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Peek(
        title: name,
        text: description.split('\n').first,
        child: Pressable(onTap: enabled ? onTap : null, scale: .97, selected: selected, child: card),
      ),
    );
  }
}

class _MonkTool extends StatelessWidget {
  const _MonkTool({required this.label, required this.accent, required this.child, this.onTap, this.peek, this.locked = false});
  final String label;
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;
  final (String, String)? peek;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget tile = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: 44, child: Center(child: child)),
        const SizedBox(height: 6),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle(context, size: 12.5)),
      ]),
    );
    if (locked) tile = Opacity(opacity: .55, child: tile);
    if (onTap != null) tile = Pressable(onTap: onTap, scale: .95, semanticLabel: label, child: tile);
    if (peek != null) tile = Peek(title: peek!.$1, text: peek!.$2, child: tile);
    return tile;
  }
}
