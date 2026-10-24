import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';

import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../session/value_editors.dart';
import 'instrument/instrument_kit.dart';

/// Bard · Inspiration (prototype `CLASS.bard`). The dice are notes on a
/// staff: flick one up (or tap it) and it glides over the bar line to the
/// allies; tap a held note and the ally rolls it right there. Cutting
/// Words, the Song of Rest and Countercharm are objects below.
class BardInspirationWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature inspirationFeature;
  final VoidCallback? onChanged;

  const BardInspirationWidget({
    super.key,
    required this.character,
    required this.inspirationFeature,
    this.onChanged,
  });

  @override
  State<BardInspirationWidget> createState() => _BardInspirationWidgetState();
}

enum _At { pool, held, gone }

class _BardInspirationWidgetState extends State<BardInspirationWidget> {
  bool _busy = false;
  // Notes keep their identity so a given die glides across the bar line.
  final _notes = <int, _At>{};
  final _rolls = <int, int>{}, _rollKeys = <int, int>{};
  int _next = 0;
  int? _cut, _song, _songKey;
  bool _charm = false;
  Timer? _cutTimer;

  Character get _hero => widget.character;
  ResourcePool? get _pool => widget.inspirationFeature.resourcePool;

  @override
  void dispose() {
    _cutTimer?.cancel();
    super.dispose();
  }

  /// Keeps as many notes in the pool as the hero has inspirations left.
  void _sync() {
    final pool = _pool;
    if (pool == null) return;
    final inPool = _notes.entries.where((e) => e.value == _At.pool).map((e) => e.key).toList();
    var need = pool.currentUses - inPool.length;
    while (need > 0) {
      final spare = _notes.entries.where((e) => e.value == _At.gone).map((e) => e.key).firstOrNull;
      _notes[spare ?? _next++] = _At.pool;
      need--;
    }
    for (final id in inPool.reversed) {
      if (need >= 0) break;
      _notes[id] = _At.gone;
      need++;
    }
  }

  int get _die {
    final declared = RegExp(r'bardic[-_]inspiration[-_][dк](\d+)', caseSensitive: false)
        .firstMatch(widget.inspirationFeature.id);
    if (declared != null) return int.parse(declared[1]!);
    final l = _hero.classLevel('bard');
    return l >= 15 ? 12 : l >= 10 ? 10 : l >= 5 ? 8 : 6;
  }

  int get _songDie {
    final l = _hero.classLevel('bard');
    return l >= 17 ? 12 : l >= 13 ? 10 : l >= 9 ? 8 : 6;
  }

  CharacterFeature? _feature(List<String> tokens) {
    final owner = CharacterClassContext(_hero, 'bard');
    return _hero.features
        .where(owner.canUseFeature)
        .where((f) => tokens.any((t) => f.id.toLowerCase().contains(t)))
        .firstOrNull;
  }

  Future<bool> _spend() async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final spent = await GameplayActionsService.spendResource(_hero, widget.inspirationFeature);
      if (spent) widget.onChanged?.call();
      return spent;
    } catch (_) {
      if (mounted) AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _give(int id) async {
    if (_notes[id] != _At.pool) return;
    if (!await _spend() || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _notes[id] = _At.held;
      _sync();
    });
  }

  void _allyRolls(int id, BuildContext noteContext) {
    final r = 1 + math.Random().nextInt(_die);
    setState(() {
      _rolls[id] = r;
      _rollKeys[id] = (_rollKeys[id] ?? 0) + 1;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (noteContext.mounted) floatUp(noteContext, '+$r', accentOf(context, 0));
      setState(() {
        _notes[id] = _At.gone;
        _rolls.remove(id);
      });
    });
  }

  Future<void> _cutting() async {
    final pool = _notes.entries.where((e) => e.value == _At.pool).map((e) => e.key).toList();
    if (pool.isEmpty) {
      AppSnackBar.info(context, instrumentRu(context) ? 'Вдохновение закончилось' : 'No inspiration left');
      return;
    }
    final id = pool.last;
    if (!await _spend() || !mounted) return;
    final r = 1 + math.Random().nextInt(_die);
    setState(() {
      _rolls[id] = r;
      _rollKeys[id] = (_rollKeys[id] ?? 0) + 1;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _notes[id] = _At.gone;
      _rolls.remove(id);
      _cut = r;
      _sync();
    });
    _cutTimer?.cancel();
    _cutTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _cut = null);
    });
  }

  Future<void> _edit() async {
    final changed = await showResourceValueEditor(context, _hero, widget.inspirationFeature);
    if (mounted && changed) setState(() => widget.onChanged?.call());
  }

  @override
  Widget build(BuildContext context) {
    final pool = _pool;
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final a0 = accentOf(context, 0), a5 = accentOf(context, 5);
    if (pool == null) {
      return LockedInstrument(
          title: widget.inspirationFeature.getName(locale),
          level: 1,
          what: ru ? 'В источнике не указан запас вдохновения' : 'The source does not define an inspiration reserve',
          accent: a0);
    }
    _sync();
    final level = _hero.classLevel('bard');
    final dn = _die, k = ru ? 'к' : 'd';
    final cutting = _feature(['cutting_word', 'cutting-word']);
    final song = _feature(['song_of_rest', 'song-of-rest']);
    final charm = _feature(['countercharm']);
    final inPool = _notes.entries.where((e) => e.value == _At.pool).map((e) => e.key).toList()..sort();
    final held = _notes.entries.where((e) => e.value == _At.held).map((e) => e.key).toList()..sort();
    final shortRest = pool.recoveryType == RecoveryType.shortRest;

    return Instrument(
      key: const ValueKey('bard-inspiration'),
      accent: a0,
      title: ru ? 'Вдохновение' : 'Inspiration',
      about: InstrumentAbout(
          title: widget.inspirationFeature.getName(locale),
          kicker: ru
              ? 'Бонусное действие · ${shortRest ? 'короткий' : 'длительный'} отдых'
              : 'Bonus action · ${shortRest ? 'short' : 'long'} rest',
          paragraphs: widget.inspirationFeature.getDescription(locale).split(RegExp(r'\n\s*\n')),
          how: ru
              ? 'Смахните ноту вверх или коснитесь её — она уйдёт к союзникам. Когда союзник использует вдохновение, коснитесь его ноты: кость бросится на месте.'
              : 'Flick a note up or tap it to give it to an ally. When the ally uses it, tap their note and the die rolls right there.'),
      trailing: RestChip(
          short: shortRest,
          onEdit: _edit,
          onRestore: () => restoreFeature(context, _hero, widget.inspirationFeature, done: () => setState(() => widget.onChanged?.call()))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          BigCount(pool.currentUses, of: pool.maxUses),
          const SizedBox(width: 10),
          const Spacer(),
          Flexible(flex: 3, child: InstrumentHint(ru ? '$k$dn · смахните вверх' : '$k$dn · flick up')),
        ]),
        const SizedBox(height: 12),
        _Staff(
          pool: inPool,
          held: held,
          dieLabel: '$k$dn',
          rolls: _rolls,
          rollKeys: _rollKeys,
          sides: dn,
          cut: _cut,
          charm: _charm,
          a0: a0,
          a5: a5,
          onGive: _busy ? null : _give,
          onAlly: _allyRolls,
        ),
        const SizedBox(height: 12),
        TileRow(gap: 8, children: [
          if (cutting != null)
            _Tool(
              glyph: 'quill',
              name: cutting.getName(locale),
              value: '−$k$dn',
              accent: a0,
              onTap: _busy ? null : _cutting,
              peek: (
                cutting.getName(locale),
                ru
                    ? 'Реакция: вычтите $k$dn из атаки, проверки или урона врага в 60 фт. Тратит вдохновение'
                    : 'Reaction: subtract a $k$dn from a creature’s attack, check or damage within 60 ft. Uses inspiration'
              ),
            ),
          if (song != null || level < 2)
            _Tool(
              glyph: 'note',
              name: song?.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), '') ?? (ru ? 'Песнь отдыха' : 'Song of Rest'),
              value: _song == null ? '$k$_songDie' : '+$_song',
              die: _songKey == null ? null : (_songDie, _songKey!),
              accent: a0,
              locked: song == null ? 2 : null,
              onTap: song == null
                  ? null
                  : () {
                      final r = 1 + math.Random().nextInt(_songDie);
                      setState(() {
                        _song = r;
                        _songKey = (_songKey ?? 0) + 1;
                      });
                    },
              peek: (
                ru ? 'Песнь отдыха' : 'Song of Rest',
                ru
                    ? 'Короткий отдых: союзники, тратящие кости хитов, восстанавливают ещё $k$_songDie'
                    : 'Short rest: allies who spend Hit Dice regain an extra $k$_songDie'
              ),
            ),
          if (charm != null || level < 6)
            _Tool(
              glyph: 'wave',
              name: charm?.getName(locale) ?? (ru ? 'Контрочарование' : 'Countercharm'),
              value: _charm ? (ru ? 'звучит' : 'playing') : (ru ? 'действие' : 'action'),
              accent: a0,
              on: _charm,
              locked: charm == null ? 6 : null,
              onTap: charm == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      setState(() => _charm = !_charm);
                    },
              peek: (
                ru ? 'Контрочарование' : 'Countercharm',
                ru
                    ? 'Действием: до конца следующего хода союзники в 30 фт. — с преимуществом против страха и очарования'
                    : 'Action: until the end of your next turn, allies within 30 ft. have advantage against fear and charm'
              ),
            ),
        ]),
        if (inPool.isEmpty && held.isEmpty) ...[
          const SizedBox(height: 8),
          InstrumentHint(
              shortRest
                  ? (ru ? 'Вдохновение вернёт короткий отдых' : 'A short rest restores inspiration')
                  : (ru ? 'Вдохновение вернёт длительный отдых' : 'A long rest restores inspiration'),
              center: true),
        ],
      ]),
    );
  }
}

/// The staff: five lines, a bar line at 59 %, the pool to its left and the
/// dice given to allies to its right. Notes glide between the measures.
class _Staff extends StatelessWidget {
  const _Staff(
      {required this.pool,
      required this.held,
      required this.dieLabel,
      required this.rolls,
      required this.rollKeys,
      required this.sides,
      required this.cut,
      required this.charm,
      required this.a0,
      required this.a5,
      required this.onGive,
      required this.onAlly});
  final List<int> pool, held;
  final String dieLabel;
  final Map<int, int> rolls, rollKeys;
  final int sides;
  final int? cut;
  final bool charm;
  final Color a0, a5;
  final void Function(int id)? onGive;
  final void Function(int id, BuildContext context) onAlly;

  // Notes stand on a gentle melody rather than at random heights.
  static double _melody(int i) => math.sin(i * 1.1) * 13;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    return Container(
      height: 118,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: c.onSurface.withValues(alpha: .03), borderRadius: BorderRadius.circular(18)),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, bar = w * .59;
        final poolStep = math.min(46.0, (bar - 44) / math.max(1, pool.length));
        final heldStep = math.min(46.0, (w - bar - 16) / math.max(1, held.length));
        final notes = <Widget>[];
        for (var i = 0; i < pool.length; i++) {
          final id = pool[i];
          notes.add(_placed(context, id, 38 + i * poolStep, 30 + _melody(i), false));
        }
        for (var i = 0; i < held.length; i++) {
          final id = held[i];
          notes.add(_placed(context, id, bar + 8 + i * heldStep, 30 + _melody(i + 3), true));
        }
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: _StaffLines(c.onSurface, bar, charm))),
          Positioned(
              left: 8,
              top: 38,
              child: Opacity(opacity: .7, child: LineIcon('note', size: 26, color: mixColor(a0, .7, c.onSurface)))),
          ...notes,
          Positioned(
              left: 38,
              bottom: 6,
              child: Text((ru ? 'запас' : 'pool').toUpperCase(), style: _measure(context))),
          Positioned(
              left: bar + 8,
              bottom: 6,
              child: Text((ru ? 'у союзников' : 'with allies').toUpperCase(), style: _measure(context))),
          if (cut != null)
            Positioned.fill(
              child: Pulse(
                trigger: cut,
                child: ColoredBox(
                  color: c.surface.withValues(alpha: .6),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Stack(alignment: Alignment.center, children: [
                      Text('−$cut',
                          style: TextStyle(
                              fontFamily: AppType.display,
                              fontSize: 54,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: a0)),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: AppMotion.snappyCurve,
                        builder: (context, v, _) => Transform.rotate(
                          angle: -.24,
                          child: Container(
                              width: 110 * v, height: 4, decoration: BoxDecoration(color: c.onSurface, borderRadius: BorderRadius.circular(2))),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(ru ? 'к броску врага' : 'to the enemy’s roll', style: hintStyle(context)),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    );
  }

  TextStyle _measure(BuildContext context) => hintStyle(context)
      .copyWith(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: .6, height: 1);

  Widget _placed(BuildContext context, int id, double x, double y, bool isHeld) {
    final ru = instrumentRu(context);
    return _HopPositioned(
      key: ValueKey('note-$id'),
      left: x,
      top: y,
      width: 44,
      height: 50,
      child: _Note(
        label: rolls[id]?.toString() ?? dieLabel,
        rollKey: rollKeys[id] ?? 0,
        sides: sides,
        accent: isHeld ? a5 : a0,
        held: isHeld,
        onTap: isHeld ? (ctx) => onAlly(id, ctx) : (onGive == null ? null : (_) => onGive!(id)),
        onFlick: isHeld || onGive == null ? null : () => onGive!(id),
        peek: isHeld
            ? (
                ru ? 'У союзника' : 'With an ally',
                ru ? '10 минут. Коснитесь, когда союзник использует кость' : '10 minutes. Tap when the ally uses the die'
              )
            : null,
      ),
    );
  }
}

class _Note extends StatefulWidget {
  const _Note(
      {required this.label,
      required this.rollKey,
      required this.sides,
      required this.accent,
      required this.held,
      required this.onTap,
      required this.onFlick,
      this.peek});
  final String label;
  final int rollKey, sides;
  final Color accent;
  final bool held;
  final void Function(BuildContext context)? onTap;
  final VoidCallback? onFlick;
  final (String, String)? peek;
  @override
  State<_Note> createState() => _NoteState();
}

class _NoteState extends State<_Note> {
  double _dy = 0;
  @override
  Widget build(BuildContext context) {
    Widget die = _NoteHead(
        label: widget.label,
        accent: widget.accent,
        held: widget.held,
        rollKey: widget.rollKey,
        sides: widget.sides);
    die = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null ? null : () => widget.onTap!(context),
      onVerticalDragUpdate: widget.onFlick == null
          ? null
          : (d) => setState(() => _dy = math.min(0, _dy + d.delta.dy)),
      onVerticalDragEnd: widget.onFlick == null
          ? null
          : (_) {
              final flicked = _dy < -30;
              setState(() => _dy = 0);
              if (flicked) widget.onFlick!();
            },
      child: AnimatedContainer(
        duration: Duration(milliseconds: _dy == 0 ? 300 : 0),
        transform: Matrix4.translationValues(0, _dy * .7, 0)..rotateZ(_dy * -.0035),
        child: Semantics(button: true, label: widget.label, child: die),
      ),
    );
    if (widget.peek != null) die = Peek(title: widget.peek!.$1, text: widget.peek!.$2, child: die);
    return die;
  }
}

class _StaffLines extends CustomPainter {
  _StaffLines(this.ink, this.bar, this.humming);
  final Color ink;
  final double bar;
  final bool humming;
  @override
  void paint(Canvas canvas, Size size) {
    const top = 9 + 100 * .2, step = 100 * .15;
    // Soft lines that fade at both ends, like ink on a page.
    final alpha = humming ? .24 : .15;
    final line = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [
        ink.withValues(alpha: 0),
        ink.withValues(alpha: alpha),
        ink.withValues(alpha: alpha),
        ink.withValues(alpha: 0),
      ], stops: const [0, .08, .92, 1])
          .createShader(Offset.zero & size);
    for (var i = 0; i < 5; i++) {
      final y = top + i * step;
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), line);
    }
    final barPaint = Paint()
      ..color = ink.withValues(alpha: .26)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(bar, top), Offset(bar, top + 4 * step), barPaint);
  }

  @override
  bool shouldRepaint(_StaffLines old) => old.bar != bar || old.humming != humming || old.ink != ink;
}

/// A note crossing the bar line hops over it on a soft arc instead of
/// sliding straight across the staff.
class _HopPositioned extends StatefulWidget {
  const _HopPositioned(
      {super.key, required this.left, required this.top, required this.width, required this.height, required this.child});
  final double left, top, width, height;
  final Widget child;
  @override
  State<_HopPositioned> createState() => _HopPositionedState();
}

class _HopPositionedState extends State<_HopPositioned> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))..value = 1;
  late Offset _from = Offset(widget.left, widget.top), _to = _from;

  @override
  void didUpdateWidget(_HopPositioned old) {
    super.didUpdateWidget(old);
    final next = Offset(widget.left, widget.top);
    if (next == _to) return;
    _from = _current;
    _to = next;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  Offset get _current {
    final t = AppMotion.gentleCurve.transform(_c.value);
    final straight = Offset.lerp(_from, _to, t)!;
    // The farther the note travels, the higher it arcs.
    final lift = math.min(26.0, (_to - _from).distance * .18) * math.sin(math.pi * _c.value);
    return straight.translate(0, -lift);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final at = _current;
          return Positioned(left: at.dx, top: at.dy, width: widget.width, height: widget.height, child: child!);
        },
      );
}

/// A note of the staff: a soft tilted head with the die inside and a stem;
/// the allies' notes carry a flag. A roll flickers in the head and lands.
class _NoteHead extends StatefulWidget {
  const _NoteHead({required this.label, required this.accent, required this.held, required this.rollKey, required this.sides});
  final String label;
  final Color accent;
  final bool held;
  final int rollKey, sides;
  @override
  State<_NoteHead> createState() => _NoteHeadState();
}

class _NoteHeadState extends State<_NoteHead> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..value = 1;
  final _rnd = math.Random();

  @override
  void didUpdateWidget(_NoteHead old) {
    super.didUpdateWidget(old);
    if (old.rollKey != widget.rollKey && !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final rolling = v < .75;
        final label = rolling ? '${1 + _rnd.nextInt(widget.sides)}' : widget.label;
        // A soft swell while it rolls, settling on a spring.
        final swell = 1 + .14 * math.sin(math.pi * v) * (1 - v);
        return Transform.scale(
          scale: swell,
          child: CustomPaint(
            painter: _NotePainter(widget.accent, widget.held, c.surface),
            child: Align(
              alignment: const Alignment(-.18, .52),
              child: SizedBox(
                width: 32,
                child: Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: c.surface.withValues(alpha: rolling ? .7 : 1))),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotePainter extends CustomPainter {
  _NotePainter(this.accent, this.held, this.surface);
  final Color accent, surface;
  final bool held;
  @override
  void paint(Canvas canvas, Size size) {
    // Head: a tilted ellipse in the lower part of the 44 × 50 cell.
    final head = Rect.fromCenter(center: Offset(size.width * .42, size.height * .7), width: 34, height: 24);
    canvas.save();
    canvas.translate(head.center.dx, head.center.dy);
    canvas.rotate(-.32);
    canvas.translate(-head.center.dx, -head.center.dy);
    canvas.drawOval(head.shift(const Offset(0, 3)), Paint()
      ..color = accent.withValues(alpha: .35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawOval(
        head,
        Paint()
          ..shader = RadialGradient(
                  center: const Alignment(-.35, -.45),
                  colors: [Color.lerp(accent, Colors.white, .28)!, accent])
              .createShader(head));
    canvas.restore();
    // Stem from the right of the head, and a flag on the allies' notes.
    final stem = Paint()
      ..color = accent
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final x = head.right - 3;
    final y0 = head.center.dy - 5, y1 = size.height * .06;
    canvas.drawLine(Offset(x, y0), Offset(x, y1), stem);
    if (held) {
      canvas.drawPath(
          Path()
            ..moveTo(x, y1)
            ..cubicTo(x + 10, y1 + 6, x + 12, y1 + 14, x + 6, y1 + 22),
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_NotePainter old) => old.accent != accent || old.held != held;
}

/// A bard tool (`.bt`): glyph, name, a value that rolls in place.
class _Tool extends StatelessWidget {
  const _Tool(
      {required this.glyph,
      required this.name,
      required this.value,
      required this.accent,
      this.onTap,
      this.peek,
      this.on = false,
      this.locked,
      this.die});
  final String glyph, name, value;
  final Color accent;
  final VoidCallback? onTap;
  final (String, String)? peek;
  final bool on;
  final int? locked;
  final (int, int)? die;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: on ? mixColor(accent, .22, c.surfaceContainer) : c.onSurface.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InstrumentGlyph(glyph, size: 22, color: accent),
        const SizedBox(height: 6),
        WordSafeText(name, style: labelStyle(context, size: 12.5)),
        const SizedBox(height: 8),
        if (locked != null)
          Row(children: [
            InstrumentGlyph('lock', size: 15, color: c.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('$locked', style: bigStyle(context).copyWith(fontSize: 20)),
          ])
        else if (die != null)
          TumbleDie(
              shape: dieShapeFor(die!.$1),
              label: value,
              accent: accent,
              rollKey: die!.$2,
              sides: die!.$1,
              size: 40)
        else
          WordSafeText(value, style: bigStyle(context).copyWith(fontSize: 20)),
      ]),
    );
    if (locked != null) {
      tile = Opacity(opacity: .55, child: tile);
      return Peek(title: name, text: ru ? 'Откроется на $locked уровне' : 'Opens at level $locked', child: tile);
    }
    if (onTap != null) tile = Pressable(onTap: onTap, scale: .95, child: tile);
    if (peek != null) tile = Peek(title: peek!.$1, text: peek!.$2, child: tile);
    return tile;
  }
}
