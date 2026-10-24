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
import '../../../../core/services/sorcery_actions_service.dart';
import '../session/value_editors.dart';
import 'instrument/instrument_kit.dart';

/// Sorcerer · Font of Magic (prototype `CLASS.sorcerer`, fourth pass:
/// it says what flows where). Two orbs of liquid magic — sorcery points
/// and the slots of the chosen circle. The buttons name the exchange and
/// its price; dragging from one orb to the other does the same.
class SorcererMagicWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? sorceryPoints;
  final List<CharacterFeature> metamagic;
  final List<CharacterFeature> ancestryFeatures;
  final VoidCallback? onChanged;

  const SorcererMagicWidget({
    super.key,
    required this.character,
    this.sorceryPoints,
    required this.metamagic,
    required this.ancestryFeatures,
    this.onChanged,
  });

  @override
  State<SorcererMagicWidget> createState() => _SorcererMagicWidgetState();
}

class _SorcererMagicWidgetState extends State<SorcererMagicWidget> {
  bool _busy = false;
  int _circle = 1;
  String? _charged;
  Offset? _dragFrom, _dragTo;
  bool? _dragFromPoints;
  final _orbsKey = GlobalKey(), _ptsKey = GlobalKey(), _slotKey = GlobalKey();

  Character get _hero => widget.character;

  Future<bool> _apply(Future<bool> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final applied = await action();
      if (mounted && applied) widget.onChanged?.call();
      return applied;
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, instrumentRu(context) ? 'Не удалось сохранить действие. Значения не изменены.' : 'Could not save the action. Values are unchanged.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert(bool creating) async {
    final ru = instrumentRu(context);
    final circle = _circle;
    final applied = await _apply(() => SorceryActionsService.convert(_hero, circle, creating: creating, definition: widget.sorceryPoints));
    if (!mounted || !applied) return;
    HapticFeedback.lightImpact();
    final cost = SorceryActionsService.creationCosts[circle]!;
    AppSnackBar.success(
        context,
        creating
            ? (ru ? 'Создана ячейка $circle круга · −$cost ед.' : 'A level $circle slot · −$cost SP')
            : (ru ? 'Ячейка разобрана · +$circle ед.' : 'Slot converted · +$circle SP'));
  }

  int _metaCost(CharacterFeature f) =>
      f.consumption?.amount ??
      switch (f.id) {
        'metamagic-quickened-spell' => 2,
        'metamagic-heightened-spell' => 3,
        _ => 1,
      };

  Future<void> _meta(CharacterFeature f) async {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    var cost = _metaCost(f);
    if (f.id.contains('twinned')) {
      final n = await showNumberKeypad(context,
          kicker: f.getName(locale), title: ru ? 'Круг заклинания' : 'Spell level', action: ru ? 'Сдвоить' : 'Twin');
      if (n == null || !mounted) return;
      cost = math.max(1, n);
    }
    final applied = await _apply(() => SorceryActionsService.spend(_hero, cost, definition: widget.sorceryPoints));
    if (!mounted) return;
    if (!applied) {
      AppSnackBar.info(context, ru ? 'Не хватает единиц' : 'Not enough points');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _charged = f.id);
    AppSnackBar.success(context, '${f.getName(locale).replaceAll(RegExp(r'^Метамагия:\s*|^Metamagic:\s*'), '')} · −$cost');
  }

  String _dragon(String locale) {
    const map = {
      'red': ('Красный', 'Red', 'огонь', 'fire'),
      'красн': ('Красный', 'Red', 'огонь', 'fire'),
      'gold': ('Золотой', 'Gold', 'огонь', 'fire'),
      'золот': ('Золотой', 'Gold', 'огонь', 'fire'),
      'brass': ('Латунный', 'Brass', 'огонь', 'fire'),
      'латун': ('Латунный', 'Brass', 'огонь', 'fire'),
      'white': ('Белый', 'White', 'холод', 'cold'),
      'бел': ('Белый', 'White', 'холод', 'cold'),
      'silver': ('Серебряный', 'Silver', 'холод', 'cold'),
      'серебр': ('Серебряный', 'Silver', 'холод', 'cold'),
      'blue': ('Синий', 'Blue', 'молния', 'lightning'),
      'син': ('Синий', 'Blue', 'молния', 'lightning'),
      'bronze': ('Бронзовый', 'Bronze', 'молния', 'lightning'),
      'бронз': ('Бронзовый', 'Bronze', 'молния', 'lightning'),
      'black': ('Чёрный', 'Black', 'кислота', 'acid'),
      'чёрн': ('Чёрный', 'Black', 'кислота', 'acid'),
      'черн': ('Чёрный', 'Black', 'кислота', 'acid'),
      'copper': ('Медный', 'Copper', 'кислота', 'acid'),
      'медн': ('Медный', 'Copper', 'кислота', 'acid'),
      'green': ('Зелёный', 'Green', 'яд', 'poison'),
      'зелён': ('Зелёный', 'Green', 'яд', 'poison'),
      'зелен': ('Зелёный', 'Green', 'яд', 'poison'),
    };
    for (final f in widget.ancestryFeatures) {
      final text = '${f.id} ${f.getName(locale)}'.toLowerCase();
      for (final e in map.entries) {
        if (text.contains(e.key)) return locale == 'ru' ? e.value.$3 : e.value.$4;
      }
    }
    return '';
  }

  void _dragEnd() {
    final from = _dragFromPoints, to = _dragTo;
    setState(() {
      _dragFrom = null;
      _dragTo = null;
      _dragFromPoints = null;
    });
    if (from == null || to == null) return;
    final target = from ? _slotKey : _ptsKey;
    final box = target.currentContext?.findRenderObject() as RenderBox?;
    final orbs = _orbsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || orbs == null) return;
    final rect = orbs.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
    if (rect.inflate(12).contains(to)) _convert(from);
  }

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final level = _hero.classLevel('sorcerer');
    final a1 = accentOf(context, 1), a5 = accentOf(context, 5);
    final children = <Widget>[];
    if (level < 2) {
      children.add(LockedInstrument(title: ru ? 'Источник магии' : 'Font of Magic', level: 2, what: ru ? 'Единицы чародейства и гибкая магия' : 'Sorcery points and Flexible Casting', accent: a1));
    } else {
      children.add(_font(context, ru, locale, a1, a5));
    }
    final base = widget.metamagic.where((f) => f.nameEn.toLowerCase() == 'metamagic' || f.nameRu.toLowerCase() == 'метамагия').firstOrNull;
    // The numbered base features (metamagic-1…3) only grant choices.
    final options = widget.metamagic
        .where((f) => f.id != base?.id)
        .where((f) => RegExp(r'^metamagic-(?!\d+$)').hasMatch(f.id.toLowerCase().replaceAll('_', '-')))
        .toList();
    if (level >= 3 && options.isNotEmpty) {
      children.add(LiteBlock(
        accent: a1,
        title: ru ? 'Метамагия' : 'Metamagic',
        about: base == null ? null : InstrumentAbout(title: base.getName(locale), paragraphs: base.getDescription(locale).split(RegExp(r'\n\s*\n')), how: ru ? 'Коснитесь руны — единицы спишутся, руна загорится для следующего заклинания.' : 'Tap a rune: the points are spent and it glows for your next spell.'),
        trailing: InstrumentChip(ru ? 'на следующее заклинание' : 'for the next spell'),
        child: LayoutBuilder(builder: (context, box) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in options)
            _Rune(
              width: (box.maxWidth - 8) / 2,
              key: ValueKey('sorcerer-meta-${f.id}'),
              name: f.getName(locale).replaceAll(RegExp(r'^Метамагия:\s*|^Metamagic:\s*'), ''),
              glyph: f.id.contains('quickened')
                  ? 'bolt'
                  : f.id.contains('twinned')
                      ? 'twin'
                      : f.id.contains('subtle')
                          ? 'hood'
                          : f.id.contains('careful')
                              ? 'shield'
                              : f.id.contains('heightened')
                                  ? 'up'
                                  : f.id.contains('distant')
                                      ? 'target'
                                      : f.id.contains('extended')
                                          ? 'timer'
                                          : 'spark',
              cost: f.id.contains('twinned') ? (ru ? 'круг' : 'level') : '${_metaCost(f)}',
              charged: _charged == f.id,
              accent: a1,
              description: f.getDescription(locale),
              onTap: _busy ? null : () => _meta(f),
            ),
        ])),
      ));
    } else if (level < 3) {
      children.add(LockedCell(title: ru ? 'Метамагия' : 'Metamagic', level: 3, accent: a1));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ]
    ]);
  }

  Widget _font(BuildContext context, bool ru, String locale, Color a1, Color a5) {
    final pool = SorceryActionsService.view(_hero, definition: widget.sorceryPoints);
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(_hero);
    } catch (_) {}
    final circles = [
      for (var i = 0; i < math.min(5, slots?.maximum.length ?? 0); i++)
        if ((slots?.maximum[i] ?? 0) > 0 || (slots?.current[i] ?? 0) > 0) i + 1
    ];
    if (circles.isNotEmpty && !circles.contains(_circle)) _circle = circles.first;
    final cur = slots == null || _circle > slots.current.length ? 0 : slots.current[_circle - 1];
    final max = slots == null || _circle > slots.maximum.length ? 0 : slots.maximum[_circle - 1];
    final cost = SorceryActionsService.creationCosts[_circle]!;
    final element = _dragon(locale);
    final c = Theme.of(context).colorScheme;
    return Instrument(
      key: const ValueKey('sorcerer-font'),
      accent: a1,
      title: ru ? 'Источник' : 'Font of Magic',
      about: InstrumentAbout(
          title: ru ? 'Источник магии' : 'Font of Magic',
          kicker: ru ? 'Бонусное действие · единицы — длительный отдых' : 'Bonus action · points recover on a long rest',
          paragraphs: [
            ru
                ? 'Единицы чародейства можно превращать в ячейки и обратно. Создание стоит: 1 круг — 2, 2 — 3, 3 — 5, 4 — 6, 5 — 7 единиц.'
                : 'Sorcery points become slots and back. Creating costs: level 1 — 2, 2 — 3, 3 — 5, 4 — 6, 5 — 7 points.',
            ru ? 'Ячейка превращается в столько единиц, каков её круг. Созданные ячейки исчезают после длительного отдыха.' : 'A slot becomes as many points as its level. Created slots vanish after a long rest.'
          ],
          how: ru
              ? 'Выберите круг в колбах. «Создать ячейку» тратит единицы, «Разобрать ячейку» возвращает их. Можно и перетянуть от сферы к сфере.'
              : 'Pick a level in the flasks. “Create a slot” spends points, “Break a slot” returns them. You can also drag from orb to orb.'),
      trailing: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: [
        if (element.isNotEmpty) ...[
          InstrumentChip(element,
              glyph: 'flame',
              peek: widget.ancestryFeatures.isEmpty
                  ? null
                  : (widget.ancestryFeatures.first.getName(locale), widget.ancestryFeatures.first.getDescription(locale).split('\n').first)),
        ],
        RestChip(
            short: false,
            onRestore: widget.sorceryPoints == null
                ? null
                : () => restoreFeature(context, _hero, widget.sorceryPoints!, done: () => setState(() => widget.onChanged?.call())),
            onEdit: widget.sorceryPoints == null
                ? null
                : () async {
                    final changed = await showResourceValueEditor(context, _hero, widget.sorceryPoints!);
                    if (mounted && changed) setState(() => widget.onChanged?.call());
                  }),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        GestureDetector(
          onPanStart: (d) {
            final orbs = _orbsKey.currentContext?.findRenderObject() as RenderBox?;
            if (orbs == null) return;
            for (final (key, points) in [(_ptsKey, true), (_slotKey, false)]) {
              final box = key.currentContext?.findRenderObject() as RenderBox?;
              if (box == null) continue;
              final rect = orbs.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
              if (rect.contains(d.localPosition)) {
                setState(() {
                  _dragFromPoints = points;
                  _dragFrom = rect.center;
                  _dragTo = d.localPosition;
                });
              }
            }
          },
          onPanUpdate: (d) {
            if (_dragFrom != null) setState(() => _dragTo = d.localPosition);
          },
          onPanEnd: (_) => _dragEnd(),
          onPanCancel: () => setState(() => _dragFrom = _dragTo = null),
          child: Stack(key: _orbsKey, clipBehavior: Clip.none, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(children: [
                  _Orb(key: _ptsKey, fill: pool.maxUses == 0 ? 0 : pool.currentUses / pool.maxUses, value: pool.currentUses, accent: a1),
                  const SizedBox(height: 8),
                  Text(ru ? 'единицы\nчародейства' : 'sorcery\npoints', textAlign: TextAlign.center, style: hintStyle(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              SizedBox(width: 34, height: 140, child: Center(child: InstrumentGlyph('swap', size: 22, color: c.onSurfaceVariant))),
              Expanded(
                child: Column(children: [
                  _Orb(key: _slotKey, fill: max == 0 ? 0 : cur / max, value: cur, accent: a5),
                  const SizedBox(height: 8),
                  Text(ru ? 'ячейки\n$_circle круга' : 'level $_circle\nslots', textAlign: TextAlign.center, style: hintStyle(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            if (_dragFrom != null && _dragTo != null)
              Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Tether(_dragFrom!, _dragTo!, a1)))),
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(ru ? 'круг' : 'level', style: hintStyle(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          for (final n in circles) ...[
            const SizedBox(width: 6),
            _Flask(
              key: ValueKey('sorcerer-flask-$n'),
              circle: n,
              fill: slots == null || slots.maximum[n - 1] == 0 ? 0 : (slots.current[n - 1] / slots.maximum[n - 1]).clamp(0, 1).toDouble(),
              selected: n == _circle,
              accent: a5,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _circle = n);
              },
            ),
          ],
        ]),
        const SizedBox(height: 12),
        TileRow(children: [
          GoButton(
              key: const ValueKey('sorcerer-create'),
              label: ru ? 'Создать ячейку' : 'Create a slot',
              subtitle: ru ? '−$cost ед. → $_circle круг' : '−$cost SP → level $_circle',
              accent: a1,
              soft: true,
              height: 58,
              onTap: !_busy && pool.currentUses >= cost ? () => _convert(true) : null),
          GoButton(
              key: const ValueKey('sorcerer-break'),
              label: ru ? 'Разобрать ячейку' : 'Break a slot',
              subtitle: ru ? '$_circle круг → +$_circle ед.' : 'level $_circle → +$_circle SP',
              accent: a5,
              soft: true,
              height: 58,
              onTap: !_busy && cur > 0 ? () => _convert(false) : null),
        ]),
        const SizedBox(height: 8),
        InstrumentHint(ru ? 'Или перетяните от одной сферы к другой' : 'Or drag from one orb to the other', center: true),
      ]),
    );
  }
}

/// An orb of liquid magic: a glass circle, a waving surface at the level of
/// its fill, slow bubbles; the number sits in the middle.
class _Orb extends StatefulWidget {
  const _Orb({super.key, required this.fill, required this.value, required this.accent});
  final double fill;
  final int value;
  final Color accent;
  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_wave.isAnimating) _wave.repeat(count: 4);
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.fill.clamp(0, 1).toDouble()),
        duration: AppMotion.of(context, const Duration(milliseconds: 900)),
        curve: AppMotion.gentleCurve,
        builder: (context, fill, _) => AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => CustomPaint(
            painter: _OrbPainter(fill, _wave.value, widget.accent, c.onSurface, c.surfaceContainer),
            child: Center(
              child: RollingNumber(widget.value,
                  style: bigStyle(context).copyWith(fontSize: 40, shadows: const [Shadow(blurRadius: 10, color: Colors.black38, offset: Offset(0, 2))])),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.fill, this.t, this.accent, this.ink, this.cont);
  final double fill, t;
  final Color accent, ink, cont;
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2, center = size.center(Offset.zero);
    canvas.drawCircle(center, r - 1, Paint()..color = ink.withValues(alpha: .05));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r - 4)));
    final level = size.height * (1 - fill) + 4;
    Path wave(double phase, double amp) {
      final p = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        p.lineTo(x, level + math.sin(x / size.width * 2 * math.pi * 1.6 + phase) * amp);
      }
      p
        ..lineTo(size.width, size.height)
        ..close();
      return p;
    }

    canvas.drawPath(wave(-t * 2 * math.pi * .7, 4), Paint()..color = accent.withValues(alpha: .4));
    canvas.drawPath(wave(t * 2 * math.pi, 3.5), Paint()..color = mixColor(accent, .7, cont));
    final bubble = Paint()..color = Colors.white.withValues(alpha: .45);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final y = size.height - p * size.height * .5;
      if (y > level) canvas.drawCircle(Offset(size.width * (.34 + i * .14), y), 2.5 + i * .3, bubble..color = Colors.white.withValues(alpha: .45 * (1 - p)));
    }
    canvas.restore();
    canvas.drawCircle(center, r - 1, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent.withValues(alpha: .45));
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.fill != fill || old.t != t;
}

class _Tether extends CustomPainter {
  _Tether(this.from, this.to, this.color);
  final Offset from, to;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final mid = Offset((from.dx + to.dx) / 2, math.min(from.dy, to.dy) - 40);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));
  }

  @override
  bool shouldRepaint(_Tether old) => old.from != from || old.to != to;
}

class _Flask extends StatelessWidget {
  const _Flask({super.key, required this.circle, required this.fill, required this.selected, required this.accent, required this.onTap});
  final int circle;
  final double fill;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      scale: .9,
      selected: selected,
      semanticLabel: '$circle',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 30,
        height: 40,
        transform: Matrix4.translationValues(0, selected ? -3 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.onSurface.withValues(alpha: .06),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(12)),
          border: Border.all(color: selected ? accent : Colors.transparent, width: 2),
        ),
        child: Stack(alignment: Alignment.center, children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 600),
              heightFactor: fill,
              widthFactor: 1,
              child: ColoredBox(color: mixColor(accent, .6, c.surfaceContainer)),
            ),
          ),
          Text('$circle', style: bigStyle(context).copyWith(fontSize: 13)),
        ]),
      ),
    );
  }
}

class _Rune extends StatelessWidget {
  const _Rune(
      {super.key,
      required this.name,
      required this.glyph,
      required this.cost,
      required this.charged,
      required this.accent,
      required this.description,
      required this.width,
      this.onTap});
  final double width;
  final String name, glyph, cost, description;
  final bool charged;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    return SizedBox(
      width: width,
      child: Peek(
        title: name,
        text: description.split('\n').first,
        child: Pressable(
          onTap: onTap,
          scale: .95,
          selected: charged,
          semanticLabel: name,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: charged ? mixColor(accent, .22, c.surfaceContainer) : c.onSurface.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: charged ? accent : Colors.transparent, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedRotation(
                turns: charged ? .125 : 0,
                duration: const Duration(milliseconds: 500),
                curve: AppMotion.snappyCurve,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: charged ? accent : accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                  child: InstrumentGlyph(glyph, size: 20, color: charged ? c.surface : accent),
                ),
              ),
              const SizedBox(height: 6),
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: labelStyle(context, size: 13.5)),
              const SizedBox(height: 4),
              Text(charged ? (ru ? 'заряжено' : 'charged') : '$cost ${ru ? 'ед.' : 'SP'}', style: bigStyle(context).copyWith(fontSize: 12, color: c.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}
