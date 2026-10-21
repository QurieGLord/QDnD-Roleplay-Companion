import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import '../../core/ui/companion_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/ui/companion_surface.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../shared/widgets/dice_roller_modal.dart';
import 'widgets/expandable_character_card.dart';
import 'widgets/character_header_reveal.dart';
import 'widgets/overview_tab.dart';
import 'widgets/stats_tab.dart';
import 'widgets/abilities_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/journal_tab.dart';
import '../inventory/inventory_add_sheet.dart';
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

class _CharacterSheetScreenState extends State<CharacterSheetScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  final _nestedScrollKey = GlobalKey<NestedScrollViewState>();
  int _scrollResetGeneration = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isCardExpanded = false;
  double? _dragStartY;
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
  // Header collapse progress; the expensive card rebuilds only while it moves.
  final _headerProgress = ValueNotifier<double>(0);
  late final AnimationController _headerReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
      value: 1);
  late final CurvedAnimation _headerCurve = CurvedAnimation(
      parent: _headerReveal,
      curve: AppMotion.standard,
      reverseCurve: Curves.easeInOutCubic);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _scrollController.addListener(_trackHeader);
  }

  void _trackHeader() {
    if (!_scrollController.hasClients) return;
    final p = (_scrollController.positions.first.pixels / 140).clamp(0.0, 1.0);
    if ((p - _headerProgress.value).abs() > .002 || p == 0 || p == 1) {
      _headerProgress.value = p;
    }
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
    _headerCurve.dispose();
    _headerReveal.dispose();
    _pageController.dispose();
    _scrollController.removeListener(_trackHeader);
    _scrollController.dispose();
    _activeTab.dispose();
    _headerProgress.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    final inner =
        _nestedScrollKey.currentState?.innerController.positions.toList() ??
            <ScrollPosition>[];
    if (_scrollController.positions
            .every((p) => (p.pixels - p.minScrollExtent).abs() < 1) &&
        inner.every((p) => (p.pixels - p.minScrollExtent).abs() < 1)) {
      return;
    }
    // The NestedScrollView coordinator resets both the header and attached bodies.
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 260),
          curve: AppMotion.standard);
    }
  }

  void _scheduleTop(int index) {
    final generation = ++_scrollResetGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _currentIndex == index &&
          generation == _scrollResetGeneration) {
        _scrollToTop();
      }
    });
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _isCardExpanded = false;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _headerReveal.value = index == 0 ? 1 : 0;
    } else if (index == 0) {
      _headerReveal.forward();
    } else {
      _headerReveal.reverse();
    }
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

  // The hero card is costly to build; it is rebuilt for data or expansion
  // changes, never because a tab changed.
  Object? _headerKey;
  Widget _headerCard = const SizedBox.shrink();
  Widget _header() {
    final key = (_revision, _isCardExpanded);
    if (key == _headerKey) return _headerCard;
    _headerKey = key;
    return _headerCard = Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _dragStartY = event.position.dy,
          onPointerUp: (_) => _dragStartY = null,
          onPointerMove: (event) {
            if (_dragStartY == null) return;
            final delta = event.position.dy - _dragStartY!;

            // Swipe Down -> Expand
            if (delta > 28 && !_isCardExpanded) {
              setState(() {
                _isCardExpanded = true;
                _dragStartY = null;
              });
            }
            // Swipe Up -> Collapse
            else if (delta < -28 && _isCardExpanded) {
              setState(() {
                _isCardExpanded = false;
                _dragStartY = null;
              });
            }
          },
          child: ValueListenableBuilder<double>(
              valueListenable: _headerProgress,
              builder: (context, progress, _) => ExpandableCharacterCard(
                    scrollProgress: progress,
                    character: widget.character,
                    onCharacterUpdated: _dataChanged,
                    isExpanded: _isCardExpanded,
                    onDicePressed: () {
                      showDiceRoller(
                        context,
                        title: AppLocalizations.of(context)!.rollDie(20),
                        modifier: 0,
                      );
                    },
                    onDetailsToggled: (val) {
                      setState(() => _isCardExpanded = val);
                    },
                  )),
        ));
  }

  @override
  Widget build(BuildContext context) {
    if (_pagesRevision != _revision) {
      _pages = _buildPages();
      _pagesRevision = _revision;
    }
    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          key: _nestedScrollKey,
          controller: _scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              // 1. Character Card
              SliverToBoxAdapter(
                child: CharacterHeaderReveal(
                  key: const ValueKey('character-header-reveal'),
                  sizeFactor: _headerCurve,
                  child: _header(),
                ),
              ),
              // 2. Sticky Navigation Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyNavBarDelegate(
                  child: _buildNavBar(),
                  height: 80,
                ),
              ),
            ];
          },
          body: NotificationListener<ScrollEndNotification>(
            onNotification: (n) {
              if (n.depth == 0 && _tapTo == null) _commitActive();
              return false;
            },
            child: PageView(
              controller: _pageController,
              physics: const _SheetPagePhysics(),
              onPageChanged: _onPageChanged,
              children: _pages,
            ),
          ),
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

  Widget _buildNavBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
            colorScheme.surface.withValues(alpha: 0),
            colorScheme.surface,
            colorScheme.surface
          ],
              stops: const [
            0,
            .30,
            1
          ])),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CompanionNavigationGlass(
        child: SizedBox(
            height: 64,
            child: Stack(children: [
              Positioned.fill(
                  child: _FlowingTabIndicator(
                      controller: _pageController,
                      count: 5,
                      current: _currentIndex,
                      tapFrom: () => _tapFrom,
                      tapTo: () => _tapTo,
                      color: Color.alphaBlend(
                          colorScheme.secondary.withValues(alpha: .26),
                          colorScheme.secondaryContainer))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home),
                  _buildNavItem(1, Icons.analytics_outlined, Icons.analytics),
                  _buildNavItem(
                      2, Icons.auto_fix_high_outlined, Icons.auto_fix_high),
                  _buildNavItem(3, Icons.backpack_outlined, Icons.backpack),
                  _buildNavItem(4, Icons.book_outlined, Icons.book),
                ],
              ),
            ])),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

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
          child: InkWell(
            key: ValueKey('sheet-tab-$index'),
            onTap: () => _onTabChanged(index),
            borderRadius: BorderRadius.circular(AppRadii.xlPlus),
            child: Center(
              child: AnimatedScale(
                scale: isSelected ? 1.08 : 1,
                duration: AppMotion.of(context, AppMotion.snappySettle),
                curve: AppMotion.snappyCurve,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                  size: 26,
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
            const inset = 6.0;
            final left = lerpDouble(a * slot, b * slot, leftT)! + inset;
            final right =
                lerpDouble((a + 1) * slot, (b + 1) * slot, rightT)! - inset;
            return Stack(children: [
              Positioned(
                  left: left,
                  width: math.max(0, right - left),
                  top: 6,
                  bottom: 6,
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
