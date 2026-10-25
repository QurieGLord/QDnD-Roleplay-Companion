import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/models/journal_note.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import 'journal_kit.dart';
import 'journal_strings.dart';

/// What a note card shows: the board stays light, so no names, links or
/// tags here; those live on the note's own page.
class JournalCardData {
  const JournalCardData(
      {required this.key,
      required this.title,
      required this.text,
      required this.category,
      this.kinds = const [],
      this.session});
  final String key, title, text;
  final NoteCategory category;
  final List<JournalEntityKind> kinds;
  final int? session;
}

enum _Zone { shelf, board }

class _Drag {
  _Drag(this.key, this.fromShelf, this.grab, this.size, this.pointer)
      : zone = fromShelf ? _Zone.shelf : _Zone.board;
  final String key;
  final bool fromShelf;
  final Offset grab;
  final Size size;
  Offset pointer;
  _Zone zone;
  String? over;
  Duration last = Duration.zero;
  bool get away => zone != (fromShelf ? _Zone.shelf : _Zone.board);
}

/// The pinned shelf over a board of notes in two columns, as in the
/// accepted prototype. Held, a card lifts and follows the finger; the
/// others glide out of its way. Dropped on the shelf it is pinned, pulled
/// from the shelf onto the board it is unpinned. Near an edge the page
/// scrolls under the held card.
class JournalPinBoard extends StatefulWidget {
  const JournalPinBoard(
      {super.key,
      required this.pinned,
      required this.loose,
      required this.onOpen,
      required this.onCommit,
      this.emptyText});
  final List<JournalCardData> pinned, loose;
  final ValueChanged<String> onOpen;

  /// The new order of both, once a card has landed. [pinned] says whether a
  /// card changed sides (true pinned, false unpinned).
  final void Function(List<String> shelf, List<String> board, bool? pinned)
      onCommit;
  final String? emptyText;
  @override
  State<JournalPinBoard> createState() => _JournalPinBoardState();
}

class _JournalPinBoardState extends State<JournalPinBoard>
    with TickerProviderStateMixin {
  static const double _gap = 12;
  late List<String> _shelf, _board;
  late Map<String, JournalCardData> _data;
  final _heights = <String, double>{};
  final _cardKeys = <String, GlobalKey>{};
  final _shelfKey = GlobalKey(), _boardKey = GlobalKey();
  bool _settled = false;
  _Drag? _drag;
  String? _landing;
  OverlayEntry? _ghost;
  final _ghostAt = ValueNotifier<Offset>(Offset.zero);
  late final _lift = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Ticker _edge = createTicker(_scrollAtEdge);
  double _width = 0;
  Duration _now = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    _shelf = [for (final d in widget.pinned) d.key];
    _board = [for (final d in widget.loose) d.key];
    _data = {for (final d in [...widget.pinned, ...widget.loose]) d.key: d};
  }

  @override
  void didUpdateWidget(JournalPinBoard old) {
    super.didUpdateWidget(old);
    if (_drag == null && _landing == null) _sync();
  }

  @override
  void dispose() {
    _ghost?.remove();
    _ghostAt.dispose();
    _edge.dispose();
    _lift.dispose();
    super.dispose();
  }

  GlobalKey _keyOf(String key) => _cardKeys.putIfAbsent(key, GlobalKey.new);

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Masonry: each card takes the shorter column.
  (Map<String, Offset>, double) _layout() {
    final w = (_width - _gap) / 2;
    final cols = [0.0, 0.0], at = <String, Offset>{};
    for (final key in _board) {
      if (_drag?.key == key && _drag!.away) continue;
      final col = cols[0] <= cols[1] ? 0 : 1;
      at[key] = Offset(col * (w + _gap), cols[col]);
      cols[col] += (_heights[key] ?? 150) + _gap;
    }
    return (at, math.max(0, math.max(cols[0], cols[1]) - _gap));
  }

  Rect? _boardSlot(String key) {
    final box = _boardKey.currentContext?.findRenderObject();
    final at = _layout().$1[key];
    if (box is! RenderBox || at == null) return null;
    return box.localToGlobal(at) &
        Size((_width - _gap) / 2, _heights[key] ?? 150);
  }

  void _measured(String key, double height) {
    if (_heights[key] == height) return;
    _heights[key] = height;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      if (!_settled) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _settled = true;
        });
      }
    });
  }

  void _lifted(String key, bool fromShelf, Offset pointer) {
    final rect = _rectOf(_keyOf(key));
    if (rect == null || _drag != null || _landing != null) return;
    HapticFeedback.mediumImpact();
    final overlay = Overlay.of(context, rootOverlay: true);
    final origin = (overlay.context.findRenderObject() as RenderBox)
        .localToGlobal(Offset.zero);
    _drag = _Drag(key, fromShelf, pointer - rect.topLeft, rect.size, pointer);
    _ghostAt.value = rect.topLeft - origin;
    _ghost = OverlayEntry(
        builder: (_) => _ghostCard(key, rect.size, fromShelf));
    overlay.insert(_ghost!);
    if (MediaQuery.disableAnimationsOf(context)) {
      _lift.value = 1;
    } else {
      _lift.forward(from: 0);
    }
    _edge.start();
    setState(() {});
  }

  Widget _ghostCard(String key, Size size, bool shelf) {
    final data = _data[key];
    if (data == null) return const SizedBox.shrink();
    return ValueListenableBuilder<Offset>(
      valueListenable: _ghostAt,
      builder: (context, at, child) => Positioned(
          left: at.dx, top: at.dy, width: size.width, height: size.height,
          child: child!),
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _lift,
          builder: (context, child) {
            final t = _lift.value;
            final a = JournalLook.accent(
                context, JournalLook.categoryAccent(data.category));
            return Transform.rotate(
              angle: -1.5 * t * math.pi / 180,
              child: Transform.scale(
                scale: 1 + .05 * t,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: .7 * t),
                          blurRadius: 50,
                          spreadRadius: -18,
                          offset: const Offset(0, 26)),
                    ],
                  ),
                  child: Stack(fit: StackFit.passthrough, children: [
                    child!,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                                color: a.withValues(alpha: .5 * t), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
          child: Material(
            type: MaterialType.transparency,
            child: shelf ? _PinFace(data) : _NoteFace(data),
          ),
        ),
      ),
    );
  }

  void _moved(Offset pointer) {
    final d = _drag;
    if (d == null) return;
    d.pointer = pointer;
    final overlay = Overlay.of(context, rootOverlay: true);
    final origin = (overlay.context.findRenderObject() as RenderBox)
        .localToGlobal(Offset.zero);
    _ghostAt.value = pointer - d.grab - origin;
    _hit();
  }

  void _hit() {
    final d = _drag;
    if (d == null) return;
    final shelf = _rectOf(_shelfKey)?.inflate(24);
    final zone = shelf != null && shelf.contains(d.pointer)
        ? _Zone.shelf
        : _Zone.board;
    if (zone != d.zone) {
      d.zone = zone;
      HapticFeedback.selectionClick();
      setState(() {});
    }
    if (zone != _Zone.board) return;
    String? over;
    for (final key in _board) {
      if (key == d.key) continue;
      if (_boardSlot(key)?.contains(d.pointer) ?? false) over = key;
    }
    if (d.fromShelf) {
      d.over = over;
      return;
    }
    if (over == null) {
      d.over = null;
      return;
    }
    if (over == d.over || _now - d.last < const Duration(milliseconds: 140)) {
      return;
    }
    d.over = over;
    d.last = _now;
    final i = _board.indexOf(d.key), j = _board.indexOf(over);
    _board
      ..removeAt(i)
      ..insert(j, d.key);
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _scrollAtEdge(Duration now) {
    _now = now;
    final d = _drag;
    final scrollable = Scrollable.maybeOf(context);
    if (d == null || scrollable == null) return;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final view = box.localToGlobal(Offset.zero) & box.size;
    var v = 0.0;
    if (d.pointer.dy < view.top + 130) {
      v = -(view.top + 130 - d.pointer.dy) / 7;
    } else if (d.pointer.dy > view.bottom - 130) {
      v = (d.pointer.dy - (view.bottom - 130)) / 7;
    }
    if (v == 0) return;
    final p = scrollable.position;
    final next = (p.pixels + v.clamp(-16.0, 16.0))
        .clamp(p.minScrollExtent, p.maxScrollExtent);
    if (next == p.pixels) return;
    p.jumpTo(next);
    _hit();
  }

  void _dropped() {
    final d = _drag;
    if (d == null) return;
    _edge.stop();
    bool? pinned;
    if (!d.fromShelf && d.zone == _Zone.shelf) {
      _board.remove(d.key);
      _shelf.insert(0, d.key);
      pinned = true;
    } else if (d.fromShelf && d.zone == _Zone.board) {
      _shelf.remove(d.key);
      final at = d.over == null ? 0 : _board.indexOf(d.over!);
      _board.insert(at < 0 ? 0 : at, d.key);
      pinned = false;
    }
    HapticFeedback.lightImpact();
    final key = d.key;
    setState(() {
      _drag = null;
      _landing = key;
    });
    widget.onCommit(List.of(_shelf), List.of(_board), pinned);
    // The card flies from where it was let go to its new place.
    SchedulerBinding.instance.addPostFrameCallback((_) => _land(key));
  }

  Future<void> _land(String key) async {
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final origin = (overlay.context.findRenderObject() as RenderBox)
        .localToGlobal(Offset.zero);
    final target = _shelf.contains(key) ? _rectOf(_keyOf(key)) : _boardSlot(key);
    final from = _ghostAt.value;
    if (target != null && !MediaQuery.disableAnimationsOf(context)) {
      final flight = AnimationController(
          vsync: this, duration: AppMotion.snappySettle);
      final to = target.topLeft - origin;
      flight.addListener(() {
        final t = AppMotion.snappyCurve.transform(flight.value);
        _ghostAt.value = Offset.lerp(from, to, t)!;
      });
      _lift.reverse();
      await flight.forward();
      flight.dispose();
    }
    _ghost?.remove();
    _ghost = null;
    _lift.value = 0;
    if (mounted) setState(() => _landing = null);
  }

  void _pinBySemantics(String key, bool pin) {
    if (_drag != null || _landing != null) return;
    setState(() {
      if (pin) {
        _board.remove(key);
        _shelf.insert(0, key);
      } else {
        _shelf.remove(key);
        _board.insert(0, key);
      }
    });
    HapticFeedback.lightImpact();
    widget.onCommit(List.of(_shelf), List.of(_board), pin);
  }

  void _shiftBySemantics(String key, int by) {
    final i = _board.indexOf(key), j = i + by;
    if (i < 0 || j < 0 || j >= _board.length) return;
    setState(() {
      _board
        ..removeAt(i)
        ..insert(j, key);
    });
    widget.onCommit(List.of(_shelf), List.of(_board), null);
  }

  Widget _holdable(String key, bool shelf, Widget face) {
    final s = JournalStrings(context);
    final data = _data[key]!;
    return Semantics(
      button: true,
      label: data.title,
      customSemanticsActions: {
        CustomSemanticsAction(
                label: shelf
                    ? s.t('Открепить', 'Unpin')
                    : s.t('Закрепить', 'Pin')):
            () => _pinBySemantics(key, !shelf),
        if (!shelf && _board.indexOf(key) > 0)
          CustomSemanticsAction(label: s.t('Выше', 'Move up')): () =>
              _shiftBySemantics(key, -1),
        if (!shelf && _board.indexOf(key) < _board.length - 1)
          CustomSemanticsAction(label: s.t('Ниже', 'Move down')): () =>
              _shiftBySemantics(key, 1),
      },
      child: _Hold(
        key: _keyOf(key),
        onTap: () => widget.onOpen(key),
        onLift: (p) => _lifted(key, shelf, p),
        onMove: _moved,
        onDrop: _dropped,
        child: face,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final d = _drag;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final shelfGlow = d != null && !d.fromShelf && d.zone == _Zone.shelf;
    final boardGlow = d != null && d.fromShelf && d.zone == _Zone.board;
    final a0 = JournalLook.accent(context, 0);
    return LayoutBuilder(builder: (context, box) {
      _width = box.maxWidth;
      return _build(context, s, c, d, dur, shelfGlow, boardGlow, a0);
    });
  }

  Widget _build(BuildContext context, JournalStrings s, ColorScheme c, _Drag? d,
      Duration dur, bool shelfGlow, bool boardGlow, Color a0) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      JournalHeading(s.t('Закреплённое', 'Pinned'),
          count: _shelf.isEmpty ? null : s.t('вниз — открепить', 'drag down to unpin')),
      const SizedBox(height: 10),
      AnimatedContainer(
        key: _shelfKey,
        duration: AppMotion.of(context, AppMotion.medium),
        // A drop here is welcomed by a soft band of the pin's colour that
        // fades out above and below, never by a drawn edge.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              for (final a in const [0.0, .11, .11, 0.0])
                a0.withValues(alpha: shelfGlow ? a : 0)
            ],
            stops: const [0, .3, .7, 1],
          ),
        ),
        // The shelf runs edge to edge, like the strips above it.
        transform: Matrix4.translationValues(-20, 0, 0),
        width: _width + 40,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final key in _shelf)
                AnimatedContainer(
                  key: ValueKey('journal-shelf-$key'),
                  duration: dur,
                  curve: AppMotion.standard,
                  width: d?.key == key && d!.away ? 0 : 222,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: 210,
                      maxWidth: 210,
                      child: Opacity(
                        opacity: _landing == key ? 0 : 1,
                        child: _holdable(
                            key,
                            true,
                            d?.key == key
                                ? _Hole(child: _PinFace(_data[key]!))
                                : _PinFace(_data[key]!)),
                      ),
                    ),
                  ),
                ),
              if (_shelf.isEmpty)
                SizedBox(
                  width: math.max(140, _width),
                  child: JournalDashed(
                    color: shelfGlow ? a0.withValues(alpha: .45) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 18),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LineIcon('bookmark',
                                size: 18,
                                color: shelfGlow ? c.onSurface : c.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                  s.t('Удерживайте запись и перетащите сюда, чтобы закрепить',
                                      'Hold a note and drag it here to pin it'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                      color: shelfGlow
                                          ? c.onSurface
                                          : c.onSurfaceVariant)),
                            ),
                          ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 32),
      JournalHeading(s.t('Записи', 'Notes'),
          count: _board.isEmpty
              ? null
              : s.t('удерживайте, чтобы переставить', 'hold to rearrange')),
      const SizedBox(height: 10),
      Builder(builder: (context) {
        if (_board.isEmpty) {
          return JournalDashed(
            key: _boardKey,
            color: boardGlow ? c.secondary.withValues(alpha: .45) : null,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(widget.emptyText ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
            ),
          );
        }
        final (at, height) = _layout();
        final w = (_width - _gap) / 2;
        return AnimatedContainer(
          key: _boardKey,
          duration: AppMotion.of(context, AppMotion.medium),
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            // A soft glow under the board, no outline.
            boxShadow: [
              BoxShadow(
                  color: c.secondary.withValues(alpha: boardGlow ? .2 : 0),
                  blurRadius: 36,
                  spreadRadius: 4),
            ],
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            for (final key in _board)
              AnimatedPositioned(
                key: ValueKey('journal-board-$key'),
                duration: _settled ? dur : Duration.zero,
                curve: AppMotion.snappyCurve,
                left: at[key]?.dx ?? 0,
                top: at[key]?.dy ?? 0,
                width: w,
                child: IgnorePointer(
                  ignoring: at[key] == null,
                  child: AnimatedOpacity(
                    duration: AppMotion.of(context, AppMotion.medium),
                    opacity: at[key] == null ? 0 : 1,
                    child: _Measure(
                      onHeight: (h) => _measured(key, h),
                      // The held card keeps its gesture: only its face
                      // turns into the empty outline of its place.
                      child: Opacity(
                          opacity: _landing == key ? 0 : 1,
                          child: _holdable(
                              key,
                              false,
                              d?.key == key
                                  ? _Hole(child: _NoteFace(_data[key]!))
                                  : _NoteFace(_data[key]!))),
                    ),
                  ),
                ),
              ),
          ]),
        );
      }),
    ]);
  }
}

/// Reports its child's height after layout.
class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasure(onHeight);
  @override
  void updateRenderObject(BuildContext context, _RenderMeasure render) =>
      render.onHeight = onHeight;
}

class _RenderMeasure extends RenderProxyBox {
  _RenderMeasure(this.onHeight);
  ValueChanged<double> onHeight;
  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}

/// Tap opens, a hold lifts. The card dips while the finger rests on it, so
/// the hold reads as the start of a lift.
class _Hold extends StatefulWidget {
  const _Hold(
      {super.key,
      required this.child,
      required this.onTap,
      required this.onLift,
      required this.onMove,
      required this.onDrop});
  final Widget child;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLift, onMove;
  final VoidCallback onDrop;
  @override
  State<_Hold> createState() => _HoldState();
}

class _HoldState extends State<_Hold> {
  bool _pressed = false;
  Timer? _press;

  // The dip starts only once the finger has rested a moment, so a swipe
  // through the board never squeezes the cards it crosses.
  void _down() {
    _press?.cancel();
    _press = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _pressed = true);
    });
  }

  void _release() {
    _press?.cancel();
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _press?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapCancel: _release,
      onTapUp: (_) => _release(),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPressStart: (d) {
        _release();
        widget.onLift(d.globalPosition);
      },
      onLongPressMoveUpdate: (d) => widget.onMove(d.globalPosition),
      onLongPressEnd: (_) => widget.onDrop(),
      onLongPressCancel: _release,
      child: AnimatedScale(
        scale: _pressed && !calm ? .97 : 1,
        duration: _pressed
            ? kLongPressTimeout - const Duration(milliseconds: 220)
            : AppMotion.of(context, AppMotion.short),
        curve: _pressed ? Curves.linear : AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

class _Hole extends StatelessWidget {
  const _Hole({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Stack(children: [
      Opacity(opacity: 0, child: child),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
                color: c.onSurface.withValues(alpha: .16), width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.data, {this.pinned = false});
  final JournalCardData data;
  final bool pinned;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, JournalLook.categoryAccent(data.category));
    return Row(children: [
      LineIcon(JournalLook.categoryIcon(data.category), size: 14, color: a),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
            journalUpper(JournalLook.categoryLabel(s, data.category)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w600,
                letterSpacing: .66,
                color: Color.lerp(c.onSurface, a, .8))),
      ),
      if (pinned)
        LineIcon('bookmark', size: 15, color: JournalLook.accent(context, 0)),
    ]);
  }
}

TextStyle _titleStyle(BuildContext context) => TextStyle(
    fontFamily: AppType.display,
    fontSize: 17,
    height: 1.18,
    fontWeight: FontWeight.w600,
    letterSpacing: -.25,
    color: Theme.of(context).colorScheme.onSurface);

TextStyle _textStyle(BuildContext context) => TextStyle(
    fontFamily: AppType.body,
    fontSize: 13,
    height: 1.45,
    color: Theme.of(context).colorScheme.onSurfaceVariant);

class _NoteFace extends StatelessWidget {
  const _NoteFace(this.data);
  final JournalCardData data;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final accents = [
      for (final k in data.kinds)
        JournalLook.accent(context, JournalLook.kindAccent(k))
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Kicker(data),
        const SizedBox(height: 6),
        Text(data.title, style: _titleStyle(context)),
        if (data.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(data.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: _textStyle(context)),
        ],
        if (accents.isNotEmpty || data.session != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            JournalDots(accents),
            const Spacer(),
            if (data.session != null)
              Text(s.t('сессия ${data.session}', 'session ${data.session}'),
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 11.5,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      fontFeatures: AppType.tabular,
                      color: c.onSurface.withValues(alpha: .45))),
          ]),
        ],
      ]),
    );
  }
}

class _PinFace extends StatelessWidget {
  const _PinFace(this.data);
  final JournalCardData data;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, JournalLook.categoryAccent(data.category));
    return Container(
      width: 210,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: const Alignment(-.55, -1),
          end: const Alignment(.55, 1),
          colors: [JournalLook.mix(a, .18, c.surfaceContainerLow), c.surfaceContainerLow],
          stops: const [0, .8],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Kicker(data, pinned: true),
        const SizedBox(height: 6),
        Text(data.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(context)),
        if (data.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(data.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _textStyle(context)),
        ],
      ]),
    );
  }
}
