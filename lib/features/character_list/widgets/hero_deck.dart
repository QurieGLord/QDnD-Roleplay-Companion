import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../core/models/character.dart';
import '../../../core/progression/character_class_context.dart';
import 'character_roster_visuals.dart';
import '../../../core/ui/companion_kit.dart';

/// The lobby as a deck: the card at the focus line is open, the next one
/// slides up over it while the previous tucks behind as a thin edge. Every
/// card is positioned from the scroll offset, so it follows the finger and
/// only transforms move on each frame.
class HeroDeck extends StatefulWidget {
  const HeroDeck({
    super.key,
    required this.characters,
    required this.onOpen,
    required this.onHold,
  });

  final List<Character> characters;
  final void Function(Character character, GlobalKey origin) onOpen;
  final void Function(Character character) onHold;

  @override
  State<HeroDeck> createState() => _HeroDeckState();
}

class _HeroDeckState extends State<HeroDeck> {
  final _controller = ScrollController();
  final _keys = <String, GlobalKey>{};
  int _focus = 0;
  final _sinceTick = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_tick);
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  double get _pitch => _DeckGeometry.of(context).pitch;

  // A light click each time a new card takes the focus line; a fast throw
  // through several cards ticks at most every 60 ms.
  void _tick() {
    final focus = (_controller.offset / _pitch).round();
    if (focus == _focus) return;
    _focus = focus;
    if (_sinceTick.elapsedMilliseconds >= 60) {
      _sinceTick.reset();
      HapticFeedback.selectionClick();
    }
  }

  void _tap(int index, Character character) {
    final f = _controller.hasClients ? _controller.offset / _pitch : 0.0;
    if ((f - index).abs() < .25) {
      widget.onOpen(character, _keys[character.id]!);
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(index * _pitch);
    } else {
      _controller.animateTo(index * _pitch,
          duration: AppMotion.of(context, AppMotion.gentleSettle),
          curve: AppMotion.gentleCurve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _DeckGeometry.of(context);
    final heroes = widget.characters;
    return LayoutBuilder(builder: (context, box) {
      final extent = math.max(
          box.maxHeight, (heroes.length - 1) * geometry.pitch + box.maxHeight);
      final cards = [
        for (var i = 0; i < heroes.length; i++)
          RepaintBoundary(
            key: _keys.putIfAbsent(heroes[i].id, () => GlobalKey()),
            child: ValueListenableBuilder<String?>(
              valueListenable: DeckRevealRoute.hiddenHero,
              builder: (context, hidden, card) =>
                  Opacity(opacity: hidden == heroes[i].id ? 0 : 1, child: card),
              child: DeckCard(
                key: ValueKey('character-card-${heroes[i].id}'),
                character: heroes[i],
                height: geometry.full,
                onTap: () => _tap(i, heroes[i]),
                onHold: () {
                  HapticFeedback.mediumImpact();
                  widget.onHold(heroes[i]);
                },
              ),
            ),
          ),
      ];
      return SingleChildScrollView(
        controller: _controller,
        physics: _DeckPhysics(pitch: geometry.pitch),
        child: SizedBox(
          height: extent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final offset = _controller.hasClients ? _controller.offset : 0.0;
              final f = (offset / geometry.pitch)
                  .clamp(0.0, math.max(0, heroes.length - 1).toDouble());
              return Stack(clipBehavior: Clip.none, children: [
                for (var i = 0; i < heroes.length; i++)
                  _placed(i - f, offset, geometry, cards[i]),
              ]);
            },
          ),
        ),
      );
    });
  }

  Widget _placed(double d, double offset, _DeckGeometry g, Widget card) {
    double y, scale = 1, dim = 0;
    if (d >= 0) {
      y = d * g.pitch + g.extra * d.clamp(0.0, 1.0);
    } else {
      final t = -d;
      y = -math.min(t, 1) * 10 - (t - 1).clamp(0.0, 2.0) * 8;
      scale = 1 - .045 * math.min(t, 3);
      dim = math.min(t, 1) * .35;
    }
    final open = (1 - d.abs()).clamp(0.0, 1.0);
    final hidden = d < -4;
    return Positioned(
      left: 16,
      right: 16,
      top: 12,
      height: g.full,
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..translateByDouble(0, offset + y, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1),
        child: Offstage(
          offstage: hidden,
          child: DeckOpenness(
            open: open,
            child: Stack(fit: StackFit.expand, children: [
              card,
              if (dim > 0)
                IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: dim),
                            borderRadius: BorderRadius.circular(AppRadii.xl)))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Card sizes follow the text scale so large text keeps its room.
class _DeckGeometry {
  _DeckGeometry(this.scale);
  final double scale;
  double get header => 72 * scale;
  double get pitch => header + 12;
  double get full => 214 * scale;
  double get extra => full - header;
  static _DeckGeometry of(BuildContext context) => _DeckGeometry(
      (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1.0, 1.6));
}

/// One card per gesture at a calm pace, several on a quick throw; it settles
/// on a critically damped spring, which reads as a soft, viscous stop.
class _DeckPhysics extends ScrollPhysics {
  const _DeckPhysics({required this.pitch, super.parent});
  final double pitch;

  @override
  _DeckPhysics applyTo(ScrollPhysics? ancestor) =>
      _DeckPhysics(pitch: pitch, parent: buildParent(ancestor));

  @override
  SpringDescription get spring => AppMotion.gentle;

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final page = position.pixels / pitch;
    var target = (page + velocity / pitch * .12).roundToDouble();
    if (velocity.abs() > 250 && target == page.roundToDouble()) {
      target = velocity > 0 ? page.ceilToDouble() : page.floorToDouble();
    }
    final last = (position.maxScrollExtent / pitch).roundToDouble();
    final to = target.clamp(0.0, last) * pitch;
    if ((to - position.pixels).abs() < toleranceFor(position).distance) {
      return null;
    }
    return ScrollSpringSimulation(spring, position.pixels, to, velocity,
        tolerance: toleranceFor(position));
  }
}

/// How open a deck card is (0 folded, 1 open); the card fades its body in.
class DeckOpenness extends InheritedWidget {
  const DeckOpenness({super.key, required this.open, required super.child});
  final double open;
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DeckOpenness>()?.open ?? 1;
  @override
  bool updateShouldNotify(DeckOpenness old) => old.open != open;
}

class DeckCard extends StatelessWidget {
  const DeckCard({
    super.key,
    required this.character,
    required this.height,
    required this.onTap,
    required this.onHold,
    this.face = false,
  });

  final Character character;
  final double height;
  final VoidCallback onTap, onHold;

  /// Draws the card as a picture for the sheet transition, without gestures.
  final bool face;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final accents = AppAccents.of(context);
    final classes = character.classes;
    final first = accents.forClass(
        classes.isEmpty ? character.characterClass : classes.first.id);
    final second = classes.length > 1 ? accents.forClass(classes[1].id) : null;
    final race = getLocalizedRaceName(context, character.race);
    final hp = character.maxHp > 0
        ? (character.currentHp / character.maxHp).clamp(0.0, 1.0)
        : 0.0;
    return Semantics(
      button: true,
      label:
          '${character.name}, ${l10n.characterCardIdentity(race, character.level, getCharacterClassSummary(context, character))}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onHold,
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                      first.withValues(alpha: .26), c.surfaceContainer),
                  Color.alphaBlend(
                      (second ?? first)
                          .withValues(alpha: second == null ? 0 : .16),
                      c.surfaceContainerLow),
                ],
                stops: [
                  0,
                  second == null ? .75 : .8
                ]),
            // A shadow cast upwards onto the card it slides over.
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .6),
                  blurRadius: 24,
                  spreadRadius: -14,
                  offset: const Offset(0, -10)),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                _DeckAvatar(character: character, accent: first),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(character.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.titleLarge),
                      const SizedBox(height: 3),
                      _ClassLine(character: character),
                    ])),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.onSurface.withValues(alpha: .08),
                      border: Border.all(
                          color: first.withValues(alpha: .6), width: 1.5)),
                  child: Text('${character.level}',
                      style: AppType.numeric(t.textTheme.titleMedium)),
                ),
              ]),
              const Spacer(),
              Builder(
                  builder: (context) => Opacity(
                        opacity: DeckOpenness.of(context),
                        child: Transform.translate(
                          offset:
                              Offset(0, (1 - DeckOpenness.of(context)) * 10),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [
                                  Text(l10n.hpShort,
                                      style: t.textTheme.labelMedium?.copyWith(
                                          color: c.onSurfaceVariant)),
                                  const Spacer(),
                                  Text.rich(
                                      TextSpan(children: [
                                        TextSpan(
                                            text: '${character.currentHp}'),
                                        TextSpan(
                                            text: ' / ${character.maxHp}',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: c.onSurfaceVariant)),
                                      ]),
                                      style: AppType.numeric(
                                          t.textTheme.titleLarge)),
                                ]),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                  child: SizedBox(
                                    height: 8,
                                    child:
                                        Stack(fit: StackFit.expand, children: [
                                      ColoredBox(
                                          color: c.onSurface
                                              .withValues(alpha: .09)),
                                      FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: hp,
                                          child: ColoredBox(color: c.primary)),
                                    ]),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _Stat(
                                          value: '${character.armorClass}',
                                          label: l10n.armorClassAC),
                                      const SizedBox(width: 22),
                                      Flexible(
                                        child: _Stat(
                                            value:
                                                '+${character.proficiencyBonus}',
                                            label: l10n.deckProficiency),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Flexible(
                                                child: Text(l10n.deckOpenSheet,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        t.textTheme.labelLarge),
                                              ),
                                              const SizedBox(width: 4),
                                              const LineIcon('forward',
                                                  size: 16),
                                            ]),
                                      ),
                                    ]),
                              ]),
                        ),
                      )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppType.numeric(t.textTheme.titleLarge)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.labelSmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ]);
  }
}

/// Class identity: one class with its subclass, or each class of a
/// multiclass hero with its own level and colour dot.
class _ClassLine extends StatelessWidget {
  const _ClassLine({required this.character});
  final Character character;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final accents = AppAccents.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final style = t.textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant);
    if (character.classes.length > 1) {
      return Wrap(spacing: 10, runSpacing: 2, children: [
        for (final entry in character.classes)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: accents.forClass(entry.id))),
            const SizedBox(width: 5),
            Text(
                '${CharacterClassContext(character, entry.id).name(locale)} ${entry.level}',
                style: style?.copyWith(
                    color: c.onSurface, fontWeight: FontWeight.w600)),
          ]),
      ]);
    }
    final subclass = character.subclass == null
        ? null
        : getLocalizedSubclassName(
            context, character.characterClass, character.subclass!);
    final entry = character.classes.isEmpty ? null : character.classes.first;
    final name = entry == null
        ? getCharacterClassSummary(context, character)
        : '${CharacterClassContext(character, entry.id).name(locale)} ${entry.level}';
    return Text.rich(
        TextSpan(children: [
          TextSpan(
              text: name,
              style:
                  TextStyle(color: c.onSurface, fontWeight: FontWeight.w600)),
          if (subclass != null) TextSpan(text: '   $subclass'),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style);
  }
}

class _DeckAvatar extends StatelessWidget {
  const _DeckAvatar({required this.character, required this.accent});
  final Character character;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fallback = Center(
        child: LineIcon(LineIcon.forClass(character.characterClass),
            color: accent, size: 22));
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Color.alphaBlend(
              accent.withValues(alpha: .18), c.surfaceContainer)),
      child: character.avatarPath != null
          ? Image.file(File(character.avatarPath!),
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
          : fallback,
    );
  }
}

/// Opens a hero's sheet out of their deck card, and folds it back into the
/// card on return (a container transform). The card hides while its sheet
/// is out, so the travelling surface is the only copy on screen. Going
/// forward the card's face fades over the sheet as it rises into place;
/// going back the same path runs in reverse, ending on the card's own face,
/// so nothing swaps when it lands. Everything moves on one spring.
class DeckRevealRoute<T> extends PageRoute<T> {
  DeckRevealRoute({
    required this.origin,
    required this.heroId,
    required this.builder,
    required this.faceBuilder,
  });

  /// The deck card currently hidden behind its open sheet.
  static final hiddenHero = ValueNotifier<String?>(null);

  final GlobalKey origin;
  final String heroId;
  final WidgetBuilder builder;

  /// Draws the card's face at a given height: the face stretches with the
  /// travelling window, so nothing behind it shows through.
  final Widget Function(BuildContext context, double height) faceBuilder;
  Rect? _from;

  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => AppMotion.gentleSettle;
  @override
  Duration get reverseTransitionDuration => AppMotion.gentleSettle;

  bool get _reduced {
    final context = navigator?.context;
    return context != null && MediaQuery.disableAnimationsOf(context);
  }

  @override
  void install() {
    super.install();
    // The card comes back on the very frame the sheet lands in its place.
    animation!.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && hiddenHero.value == heroId) {
        hiddenHero.value = null;
      }
    });
  }

  @override
  TickerFuture didPush() {
    hiddenHero.value = heroId;
    final future = super.didPush();
    if (_reduced) return future;
    // A critically damped, unhurried spring: the sheet arrives without a hop.
    return controller!.animateWith(SpringSimulation(AppMotion.reveal, 0, 1, 0));
  }

  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    if (!_reduced) {
      controller!.animateBackWith(
          SpringSimulation(AppMotion.reveal, controller!.value, 0, 0));
    }
    return popped;
  }

  @override
  void dispose() {
    if (hiddenHero.value == heroId) hiddenHero.value = null;
    super.dispose();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      builder(context);

  Rect? _originRect() {
    final box = origin.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return _from;
    return _from = box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final c = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, page) {
        final p = animation.value.clamp(0.0, 1.0);
        final from = animation.isCompleted ? null : _originRect();
        if (from == null) return page!;
        final screen = Offset.zero & MediaQuery.sizeOf(context);
        final window = Rect.lerp(from, screen, p)!;
        final radius = BorderRadius.circular(AppRadii.xl * (1 - p));
        // The card's face holds at first and fades over the sheet, which
        // rises the last few pixels into place.
        final face = 1 - Curves.easeIn.transform((p / .45).clamp(0.0, 1.0));
        final lift = 24 * (1 - Curves.easeOutCubic.transform(p));
        final scale = window.width / from.width;
        return Stack(children: [
          Positioned.fromRect(
            rect: window,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                // The travelling surface lifts off the deck and settles.
                boxShadow: [
                  BoxShadow(
                      color: Colors.black
                          .withValues(alpha: .45 * math.sin(math.pi * p)),
                      blurRadius: 36,
                      spreadRadius: -12,
                      offset: const Offset(0, 16)),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: ColoredBox(
                  color: c.surface,
                  child: Stack(clipBehavior: Clip.none, children: [
                    // The page keeps the screen's size and is revealed by
                    // the window, so its layout never reflows mid-flight.
                    Positioned(
                      left: -window.left,
                      top: -window.top,
                      width: screen.width,
                      height: screen.height,
                      // Opaque on purpose: fading a whole screen (with its
                      // glass) every frame costs frames; the card's face
                      // fades over it instead.
                      child: Transform.translate(
                          offset: Offset(0, lift), child: page),
                    ),
                    if (face > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        width: from.width,
                        height: window.height / scale,
                        child: IgnorePointer(
                          child: Transform.scale(
                            alignment: Alignment.topLeft,
                            scale: scale,
                            child: Opacity(
                                opacity: face,
                                child: faceBuilder(
                                    context, window.height / scale)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
