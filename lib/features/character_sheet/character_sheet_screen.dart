import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import '../../core/ui/companion_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../shared/widgets/dice_roller_modal.dart';
import 'widgets/expandable_character_card.dart';
import 'widgets/overview_tab.dart';
import 'widgets/stats_tab.dart';
import 'widgets/abilities_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/journal_tab.dart';
import '../inventory/inventory_add_sheet.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import '../../core/ui/companion_kit.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class CharacterSheetScreen extends StatefulWidget {
  final Character character;

  const CharacterSheetScreen({
    super.key,
    required this.character,
  });

  @override
  State<CharacterSheetScreen> createState() => _CharacterSheetScreenState();
}

// The compact bar's band at the top and the floating island's wrap below
// it, as in the prototype (bar 64, island 50 + 6 + 6 with 6 / 10 around).
const double _barExtent = 64;
const double _islandExtent = 78;

class _CharacterSheetScreenState extends State<CharacterSheetScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  final _nestedScrollKey = GlobalKey<NestedScrollViewState>();
  int _scrollResetGeneration = 0;
  final ScrollController _scrollController = ScrollController();
  int? _tapTarget;
  // Origin of a tapped jump; the island indicator flows across it as one move.
  double? _tapFrom;
  int? _tapTo;
  // Pages are rebuilt only when the hero's data changes, never on a tab
  // change: an off-screen tab kept alive would otherwise rebuild in full on
  // every switch and swallow the page animation.
  final _activeTab = ValueNotifier<int>(0);
  int _revision = 0, _pagesRevision = -1;
  List<Widget> _pages = const [];
  // How far the hero card has scrolled away. Only light wrappers listen:
  // the card itself is never rebuilt while it folds.
  final _headerOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _scrollController.addListener(_trackHeader);
  }

  void _trackHeader() {
    if (!_scrollController.hasClients) return;
    final outer = _scrollController.positions.first;
    final y = outer.pixels;
    if (y != _headerOffset.value) _unfolding = y < _headerOffset.value;
    _headerOffset.value = y;
    if (!identical(_watched, outer)) {
      _watched?.isScrollingNotifier.removeListener(_settleFold);
      _watched = outer..isScrollingNotifier.addListener(_settleFold);
    }
  }

  // The hero card never rests half folded: once the scroll comes to rest
  // in between, it glides on to whichever end the movement was heading for.
  ScrollPosition? _watched;
  bool _unfolding = false;
  void _settleFold() {
    final outer = _watched;
    if (outer == null || outer.isScrollingNotifier.value || !mounted) return;
    final fold = _foldExtent(), y = outer.pixels;
    if (fold <= 0 || y <= .5 || y >= fold - .5) return;
    // A small pull or the tail of a fling that spills over the page's top
    // folds back; a deliberate pull of a third or more opens the card.
    final progress = y / fold;
    final open = _unfolding ? progress < .67 : progress < .33;
    final target = open ? 0.0 : fold;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(target,
          duration: AppMotion.gentleSettle, curve: AppMotion.gentleCurve);
    }
  }

  // Folded, the hero card has scrolled away whole and the island sits under
  // the compact bar.
  double _foldExtent() {
    if (!_scrollController.hasClients) return 0;
    final outer = _scrollController.positions.first;
    return outer.hasContentDimensions ? outer.maxScrollExtent : 0;
  }

  Object? _stamp() => widget.character.updatedAt;

  void _dataChanged() {
    if (mounted) setState(() => _revision++);
  }

  // Each page arrives with the strip: while it slides in, its content rises
  // and settles in step with the finger, already in place when it lands.
  List<Widget> _buildPages() => [
        PageArrival(
            controller: _pageController,
            index: 0,
            child: _TabActivity(
                index: 0,
                current: _activeTab,
                stamp: _stamp,
                builder: (_) => OverviewTab(
                    character: widget.character,
                    onCharacterUpdated: _dataChanged))),
        // Rebuilt when it becomes active, so it always shows fresh data.
        PageArrival(
            controller: _pageController,
            index: 1,
            child: _TabActivity(
                index: 1,
                current: _activeTab,
                stamp: _stamp,
                builder: (_) => StatsTab(character: widget.character))),
        PageArrival(
            controller: _pageController,
            index: 2,
            child: _TabActivity(
                index: 2,
                current: _activeTab,
                stamp: _stamp,
                followsActivity: true,
                builder: (active) => AbilitiesTab(
                    character: widget.character, isActive: active))),
        PageArrival(
            controller: _pageController,
            index: 3,
            child: _TabActivity(
                index: 3,
                current: _activeTab,
                stamp: _stamp,
                builder: (_) => InventoryTab(
                    character: widget.character,
                    showAddButton: false,
                    onCharacterUpdated: _dataChanged))),
        PageArrival(
            controller: _pageController,
            index: 4,
            child: _TabActivity(
                index: 4,
                current: _activeTab,
                stamp: _stamp,
                builder: (_) => JournalTab(character: widget.character))),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    _watched?.isScrollingNotifier.removeListener(_settleFold);
    _scrollController.removeListener(_trackHeader);
    _scrollController.dispose();
    _activeTab.dispose();
    _headerOffset.dispose();
    super.dispose();
  }

  // Overview opens with the hero card unfolded; every other tab gets the
  // room and starts with the card folded into the compact bar.
  void _settleScroll(int index) {
    if (!_scrollController.hasClients) return;
    final target = index == 0 ? 0.0 : _foldExtent();
    final inner =
        _nestedScrollKey.currentState?.innerController.positions.toList() ??
            <ScrollPosition>[];
    if (_scrollController.positions
            .every((p) => (p.pixels - target).abs() < 1) &&
        inner.every((p) => (p.pixels - p.minScrollExtent).abs() < 1)) {
      return;
    }
    // The NestedScrollView coordinator moves the header and resets the
    // attached bodies in one motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(target,
          duration: AppMotion.gentleSettle, curve: AppMotion.gentleCurve);
    }
  }

  void _expandHeader() {
    if (!_scrollController.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(0,
          duration: AppMotion.gentleSettle, curve: AppMotion.gentleCurve);
    }
  }

  void _scheduleTop(int index) {
    final generation = ++_scrollResetGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _currentIndex == index &&
          generation == _scrollResetGeneration) {
        _settleScroll(index);
      }
    });
  }

  void _selectTab(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
    _scheduleTop(index);
  }

  void _onTabChanged(int index) {
    if (_currentIndex == index) return;
    _tapTarget = index;
    _selectTab(index);
    final distance =
        ((_pageController.hasClients ? _pageController.page : null) ??
                    _currentIndex)
                .toDouble() -
            index;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
      _commitActive();
      return;
    }
    final milliseconds = 450 + 60 * (distance.abs() - 1).clamp(0, 3);
    _tapFrom = _pageController.page ?? index + distance;
    _tapTo = index;
    _pageController
        .animateToPage(index,
            duration: Duration(milliseconds: milliseconds.round()),
            curve: AppMotion.snappyCurve)
        .whenComplete(() {
      if (_tapTo == index) {
        _tapFrom = null;
        _tapTo = null;
        _commitActive();
      }
      if (mounted &&
          _tapTarget == index &&
          (_pageController.page ?? -1).round() == index) {
        _tapTarget = null;
      }
    });
  }

  // Pages learn they became active only once the strip has landed, so their
  // refresh never lands in the middle of the slide.
  void _commitActive() {
    if (mounted && _activeTab.value != _currentIndex) {
      _activeTab.value = _currentIndex;
    }
  }

  void _onPageChanged(int index) {
    if (_tapTarget != null) {
      if (_tapTarget == index) {
        _tapTarget = null;
        _scheduleTop(index);
      }
      return;
    }
    if (_currentIndex != index) _selectTab(index);
  }

  // The hero card is costly to build; it is rebuilt for data changes,
  // never because a tab changed.
  int? _headerRevision;
  Widget _headerCard = const SizedBox.shrink();
  Widget _header() {
    if (_headerRevision == _revision) return _headerCard;
    _headerRevision = _revision;
    return _headerCard = ExpandableCharacterCard(
      character: widget.character,
      onCharacterUpdated: _dataChanged,
      onDicePressed: _rollFree,
    );
  }

  void _rollFree() => showDiceRoller(
        context,
        title: AppLocalizations.of(context)!.rollDie(20),
        modifier: 0,
      );

  @override
  Widget build(BuildContext context) {
    if (_pagesRevision != _revision) {
      _pages = _buildPages();
      _pagesRevision = _revision;
    }
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      // Fields here sit at the top or in sheets over the page; the page never
      // resizes for the keyboard, so it is not laid out again on every frame
      // of the keyboard's slide.
      resizeToAvoidBottomInset: false,
      backgroundColor: c.surface,
      // The sheet scrolls under two floating glass layers, as in the
      // prototype: the compact hero bar at the top and the island below it.
      // The scroll view starts below the bar's band but does not clip, so
      // the folding card and the pages pass under the glass; the frame is
      // clipped once, at the safe area.
      body: SafeArea(
        bottom: false,
        child: ClipRect(
          child: Stack(children: [
            Positioned.fill(
              top: _barExtent,
              child: NestedScrollView(
                key: _nestedScrollKey,
                controller: _scrollController,
                clipBehavior: Clip.none,
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: _HeaderParallax(
                        offset: _headerOffset,
                        foldExtent: _foldExtent,
                        child: _header(),
                      ),
                    ),
                    // The pinned island always covers the top of the body;
                    // absorbing it keeps the fold exactly at the card's end.
                    SliverOverlapAbsorber(
                      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                          context),
                      sliver: SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyNavBarDelegate(
                          child: _buildNavBar(),
                          height: _islandExtent,
                        ),
                      ),
                    ),
                  ];
                },
                body: NotificationListener<ScrollEndNotification>(
                  onNotification: (n) {
                    if (n.depth == 0 && _tapTo == null) _commitActive();
                    return false;
                  },
                  child: SheetPageInset(
                    top: _islandExtent,
                    child: PageView(
                      controller: _pageController,
                      clipBehavior: Clip.none,
                      physics: const _SheetPagePhysics(),
                      onPageChanged: _onPageChanged,
                      children: _pages,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: _barExtent,
              child: _CompactHeroBar(
                character: widget.character,
                revision: _revision,
                offset: _headerOffset,
                foldExtent: _foldExtent,
                onDice: _rollFree,
                onExpand: _expandHeader,
              ),
            ),
          ]),
        ),
      ),
      floatingActionButtonAnimator: MediaQuery.disableAnimationsOf(context)
          ? FloatingActionButtonAnimator.noAnimation
          : FloatingActionButtonAnimator.scaling,
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton(
              key: const ValueKey('sheet-add-item'),
              tooltip: AppLocalizations.of(context)!.addItem,
              onPressed: () => _showAddItemDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // The prototype's island: a glass capsule floating over the page with a
  // flowing indicator; icons firm up and grow a little when selected.
  Widget _buildNavBar() {
    final c = Theme.of(context).colorScheme;
    const icons = ['home', 'stats', 'magic', 'bag', 'book'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(31),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            height: 50,
            child: Stack(children: [
              Positioned.fill(
                  child: _FlowingTabIndicator(
                      controller: _pageController,
                      count: icons.length,
                      current: _currentIndex,
                      tapFrom: () => _tapFrom,
                      tapTo: () => _tapTo,
                      color: Color.alphaBlend(
                          c.secondary.withValues(alpha: .24),
                          c.surface.withValues(alpha: .4)))),
              Row(children: [
                for (var i = 0; i < icons.length; i++)
                  _buildNavItem(i, icons[i]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String icon) {
    final isSelected = _currentIndex == index;
    final c = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final labels = [
      l.sheetTabOverview,
      l.stats,
      l.magic,
      l.inventory,
      l.sheetTabJournal
    ];
    return Expanded(
      child: Semantics(
          label: labels[index],
          selected: isSelected,
          button: true,
          excludeSemantics: true,
          onTap: () => _onTabChanged(index),
          child: GestureDetector(
            key: ValueKey('sheet-tab-$index'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTabChanged(index),
            child: Center(
              child: AnimatedScale(
                scale: isSelected ? 1.1 : 1,
                duration: AppMotion.of(context, AppMotion.snappySettle),
                curve: AppMotion.snappyCurve,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                      end: isSelected ? c.onSurface : c.onSurfaceVariant),
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 220)),
                  builder: (context, color, _) =>
                      LineIcon(icon, size: 22, color: color),
                ),
              ),
            ),
          )),
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    if (await showInventoryAddSheet(context, widget.character) == true &&
        mounted) {
      _dataChanged();
    }
  }
}

class _StickyNavBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyNavBarDelegate({required this.child, required this.height});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _StickyNavBarDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

/// Pages settle after a throw with a small give; a slow release glides home.
class _SheetPagePhysics extends PageScrollPhysics {
  const _SheetPagePhysics({super.parent});
  @override
  _SheetPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SheetPagePhysics(parent: buildParent(ancestor));
  @override
  SpringDescription get spring => AppMotion.bouncy;
}

/// The island's capsule follows the pages. Its leading edge moves first and
/// the trailing edge catches up, so a tap and a swipe read as the same flow,
/// and any new gesture simply takes over from the current position.
class _FlowingTabIndicator extends StatelessWidget {
  const _FlowingTabIndicator(
      {required this.controller,
      required this.count,
      required this.current,
      required this.tapFrom,
      required this.tapTo,
      required this.color});
  final PageController controller;
  final int count, current;
  final double? Function() tapFrom;
  final int? Function() tapTo;
  final Color color;

  static const _lead = Interval(0, .72, curve: Curves.easeOutCubic);
  static const _lag = Interval(.22, 1, curve: Curves.easeInOutCubic);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final slot = box.maxWidth / count;
            final page = controller.hasClients &&
                    controller.position.hasContentDimensions
                ? controller.page ?? current.toDouble()
                : current.toDouble();
            double a, b, t;
            final from = tapFrom(), to = tapTo();
            if (from != null && to != null && (to - from).abs() > .001) {
              a = from;
              b = to.toDouble();
              t = ((page - from) / (b - from)).clamp(0.0, 1.0);
            } else {
              a = page.floorToDouble();
              b = a + 1;
              t = page - a;
            }
            final forward = b >= a;
            final leftT = (forward ? _lag : _lead).transform(t);
            final rightT = (forward ? _lead : _lag).transform(t);
            const inset = 2.0;
            final left = lerpDouble(a * slot, b * slot, leftT)! + inset;
            final right =
                lerpDouble((a + 1) * slot, (b + 1) * slot, rightT)! - inset;
            return Stack(children: [
              Positioned(
                  left: left,
                  width: math.max(0, right - left),
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppRadii.pill)))),
            ]);
          }));
}

/// A sheet page that rebuilds only when it has to: when the hero's data
/// changed since it was last built and it becomes active, or when its content
/// itself depends on being active. A tab change elsewhere costs nothing.
class _TabActivity extends StatefulWidget {
  const _TabActivity(
      {required this.index,
      required this.current,
      required this.stamp,
      required this.builder,
      this.followsActivity = false});
  final int index;
  final ValueListenable<int> current;
  final Object? Function() stamp;
  final Widget Function(bool active) builder;
  final bool followsActivity;
  @override
  State<_TabActivity> createState() => _TabActivityState();
}

class _TabActivityState extends State<_TabActivity> {
  late bool _active = widget.current.value == widget.index;
  Object? _builtStamp;
  late Widget _child = _build();

  Widget _build() {
    _builtStamp = widget.stamp();
    return widget.builder(_active);
  }

  @override
  void initState() {
    super.initState();
    widget.current.addListener(_changed);
  }

  void _changed() {
    final next = widget.current.value == widget.index;
    if (next == _active) return;
    _active = next;
    final stale = widget.stamp() != _builtStamp;
    if (widget.followsActivity || (next && stale)) {
      setState(() => _child = _build());
    }
  }

  @override
  void didUpdateWidget(covariant _TabActivity old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      old.current.removeListener(_changed);
      widget.current.addListener(_changed);
    }
    // A new page list means the sheet's data changed.
    _active = widget.current.value == widget.index;
    _child = _build();
  }

  @override
  void dispose() {
    widget.current.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _child;
}

/// While the hero card scrolls away it drifts a little slower than the page
/// and fades, so it melts into the compact bar instead of being cut off.
class _HeaderParallax extends StatelessWidget {
  const _HeaderParallax(
      {required this.offset, required this.foldExtent, required this.child});
  final ValueListenable<double> offset;
  final double Function() foldExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      child: child,
      builder: (context, y, child) {
        final extent = foldExtent();
        if (y <= 0 || extent <= 0) return child!;
        final fade = 1 - (y / (extent * .7)).clamp(0.0, 1.0);
        return Opacity(
          opacity: fade,
          child: still
              ? child
              : Transform.translate(offset: Offset(0, y * .3), child: child),
        );
      },
    );
  }
}

/// The folded hero, as the prototype's top bar: full-width glass with the
/// hero's glyph, name, health and dice. Above the unfolded card only the
/// round back button shows; as the card folds away the bar grows in and the
/// back button leaves it, so the folded bar has no back button. A tap on the
/// bar unfolds the card again.
class _CompactHeroBar extends StatelessWidget {
  const _CompactHeroBar({
    required this.character,
    required this.revision,
    required this.offset,
    required this.foldExtent,
    required this.onDice,
    required this.onExpand,
  });
  final Character character;
  final int revision;
  final ValueListenable<double> offset;
  final double Function() foldExtent;
  final VoidCallback onDice, onExpand;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final accent = AppAccents.of(context).forClass(character.classes.isEmpty
        ? character.characterClass
        : character.classes.first.id);
    final hp = character.maxHp > 0
        ? (character.currentHp / character.maxHp).clamp(0.0, 1.0)
        : 0.0;
    final glyph = Center(
        child: LineIcon(LineIcon.forClass(character.characterClass),
            size: 17, color: accent));
    Widget bar(double start) => GlassSurface(
          child: Semantics(
            button: true,
            label: l10n.heroExpand,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onExpand,
              child: Padding(
                padding: EdgeInsets.fromLTRB(start, 8, 14, 10),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: Color.alphaBlend(
                            accent.withValues(alpha: .18), c.surfaceContainer),
                        borderRadius: BorderRadius.circular(11)),
                    child: character.avatarPath != null
                        ? Image.file(File(character.avatarPath!),
                            fit: BoxFit.cover,
                            cacheWidth: 96,
                            errorBuilder: (_, __, ___) => glyph)
                        : glyph,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.titleMedium?.copyWith(
                            fontFamily: AppType.display,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.17)),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    label: '${l10n.hpShort} ${character.currentHp} / '
                        '${character.maxHp}',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 78,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${character.currentHp}/${character.maxHp}',
                                style: AppType.numeric(t.textTheme.labelLarge)
                                    .copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              child: SizedBox(
                                height: 4,
                                child: Stack(fit: StackFit.expand, children: [
                                  ColoredBox(
                                      color:
                                          c.onSurface.withValues(alpha: .09)),
                                  FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: hp,
                                      child: ColoredBox(color: c.primary)),
                                ]),
                              ),
                            ),
                          ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundButton(
                    size: 36,
                    tooltip: l10n.diceRoller,
                    onPressed: onDice,
                    child: LineIcon('dice', size: 20, color: c.onSurface),
                  ),
                ]),
              ),
            ),
          ),
        );
    final back = _RoundButton(
      size: 40,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
      glass: true,
      child: LineIcon('back', size: 22, color: c.onSurface),
    );
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, y, _) {
        final extent = foldExtent();
        final p = extent <= 0
            ? 0.0
            : ((y - extent * .45) / (extent * .35)).clamp(0.0, 1.0);
        return Stack(fit: StackFit.expand, children: [
          if (p > 0)
            IgnorePointer(
              ignoring: p < .5,
              child: Opacity(
                opacity: p,
                child: Transform.translate(
                    offset: Offset(0, -6 * (1 - p)),
                    child: bar(64 - 50 * Curves.easeOutCubic.transform(p))),
              ),
            ),
          // Folded, the bar belongs to the page: the back button fades and
          // shrinks away and the bar's content slides into its place.
          if (p < 1)
            Positioned(
              left: 14,
              top: 10,
              child: IgnorePointer(
                ignoring: p > .5,
                child: Opacity(
                  opacity: 1 - p,
                  child: Transform.scale(scale: 1 - .2 * p, child: back),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

/// The prototype's `.round`: a 40 circle on a faint tone that dips when
/// pressed; over live content it can be glass.
class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.child,
      required this.onPressed,
      required this.tooltip,
      this.size = 40,
      this.glass = false});
  final Widget child;
  final VoidCallback onPressed;
  final String tooltip;
  final double size;
  final bool glass;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final face = SizedBox.square(dimension: size, child: Center(child: child));
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        scale: .92,
        semanticLabel: tooltip,
        child: glass
            ? GlassSurface(
                borderRadius: BorderRadius.circular(size / 2), child: face)
            : DecoratedBox(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.onSurface.withValues(alpha: .08)),
                child: face),
      ),
    );
  }
}

/// Pages not yet redesigned keep to the space below the floating island.
